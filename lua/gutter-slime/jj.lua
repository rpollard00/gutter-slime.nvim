-- lua/gutter-slime/jj.lua
-- Optional Jujutsu integration helpers.

local M = {}

local uv = vim.uv or vim.loop

local function safe_close(handle)
  if handle and not handle:is_closing() then
    handle:close()
  end
end

---@param cmd string[]
---@param cwd string|nil
---@param callback fun(code: integer, out: string)
local function spawn(cmd, cwd, callback)
  local stdout_chunks = {}
  local stdout = uv.new_pipe(false)

  local handle
  local opts = {
    args = { unpack(cmd, 2) },
    stdio = { nil, stdout, nil },
    cwd = cwd,
  }

  handle = uv.spawn(cmd[1], opts, function(code)
    stdout:read_stop()
    safe_close(stdout)
    safe_close(handle)
    local out = table.concat(stdout_chunks)
    vim.schedule(function()
      callback(code, out)
    end)
  end)

  if not handle then
    safe_close(stdout)
    vim.schedule(function()
      callback(-1, "")
    end)
    return
  end

  stdout:read_start(function(err, data)
    if not err and data then
      stdout_chunks[#stdout_chunks + 1] = data
    end
  end)
end

---@param text string
---@return string|nil
local function parse_commit_id(text)
  local id = text:match("([0-9a-fA-F]+)")
  if id and #id == 40 then
    return id:lower()
  end
  return nil
end

---@param path string
---@param callback fun(commit_id: string|nil)
function M.current_commit_async(path, callback)
  local cfg = require("gutter-slime.config").get()
  if not cfg.jj.enabled or not cfg.jj.current_change then
    callback(nil)
    return
  end

  if vim.fn.executable("jj") ~= 1 then
    callback(nil)
    return
  end

  local cwd = vim.fn.fnamemodify(path, ":h")
  spawn({ "jj", "root" }, cwd, function(code, _out)
    if code ~= 0 then
      callback(nil)
      return
    end

    spawn({ "jj", "log", "-r", "@", "--no-graph", "-T", "commit_id" }, cwd, function(log_code, out)
      if log_code ~= 0 then
        callback(nil)
        return
      end
      callback(parse_commit_id(out))
    end)
  end)
end

return M
