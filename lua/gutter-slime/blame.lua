-- lua/gutter-slime/blame.lua
-- Async git blame integration.
--
-- `git blame --incremental` output format reference:
--   <40-hex-sha> <orig_line> <final_line> <line_count>
--   author <name>
--   author-mail <email>
--   author-time <unix-timestamp>
--   author-tz <+HHMM>
--   committer <name>
--   committer-mail <email>
--   committer-time <unix-timestamp>
--   committer-tz <+HHMM>
--   summary <text>
--   [previous <sha> <filename>]
--   filename <name>
--
-- Repeated hunks for the same SHA may omit metadata, so parse_incremental()
-- caches metadata by SHA while walking the stream.

local M = {}

local ZERO_SHA = string.rep("0", 40)
local uv = vim.uv or vim.loop

---@param handle userdata|nil
local function safe_close(handle)
  if not handle then
    return
  end
  if handle.is_closing and handle:is_closing() then
    return
  end
  pcall(function()
    handle:close()
  end)
end

--- Return a repo-relative pathspec when possible.
---@param path string
---@param repo_root string
---@return string
function M.pathspec_for_repo(path, repo_root)
  local prefix = repo_root
  if prefix:sub(-1) ~= "/" then
    prefix = prefix .. "/"
  end
  if path:sub(1, #prefix) == prefix then
    return path:sub(#prefix + 1)
  end
  return path
end

--- Build a git blame command.
---@param pathspec string
---@param dirty boolean
---@return string[]
function M.build_blame_command(pathspec, dirty)
  local cmd = { "git", "blame", "--incremental" }
  if dirty then
    table.insert(cmd, "--contents")
    table.insert(cmd, "-")
  end
  table.insert(cmd, "--")
  table.insert(cmd, pathspec)
  return cmd
end

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

--- Spawn a process and collect stdout.
---@param cmd string[]
---@param cwd string|nil
---@param stdin_data string|nil
---@param callback fun(code: integer, out: string)
local function spawn(cmd, cwd, stdin_data, callback)
  local stdout_chunks = {}
  local stdout = uv.new_pipe(false)
  local stdin_pipe = stdin_data and uv.new_pipe(false) or nil

  local handle
  local opts = {
    args = { unpack(cmd, 2) },
    stdio = { stdin_pipe, stdout, nil },
    cwd = cwd,
  }

  handle = uv.spawn(cmd[1], opts, function(code)
    stdout:read_stop()
    safe_close(stdout)
    safe_close(stdin_pipe)
    safe_close(handle)
    local out = table.concat(stdout_chunks)
    vim.schedule(function()
      callback(code, out)
    end)
  end)

  if not handle then
    safe_close(stdout)
    safe_close(stdin_pipe)
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

  if stdin_pipe and stdin_data then
    stdin_pipe:write(stdin_data, function()
      stdin_pipe:shutdown(function()
        safe_close(stdin_pipe)
      end)
    end)
  end
end

-- ---------------------------------------------------------------------------
-- Incremental blame output parser
-- ---------------------------------------------------------------------------

--- Parse `git blame --incremental` output into per-line records.
---
---@param output string
---@param line_count integer
---@return table
function M.parse_incremental(output, line_count)
  local result = {}
  for i = 1, line_count do
    result[i] = { timestamp = 0, sha = ZERO_SHA }
  end

  local meta_cache = {}

  local lines = vim.split(output, "\n", { plain = true })
  local i = 1
  local total = #lines

  while i <= total do
    local line = lines[i]

    local sha, _orig, final_str, count_str =
      line:match("^([0-9a-f]+)%s+(%d+)%s+(%d+)%s+(%d+)$")

    if sha and #sha == 40 then
      local final_line = tonumber(final_str)
      local hunk_count = tonumber(count_str)

      if not meta_cache[sha] then
        meta_cache[sha] = { timestamp = 0 }
      end

      i = i + 1
      while i <= total do
        local mline = lines[i]
        local ts = mline:match("^author%-time%s+(%d+)$")
        if ts then
          if meta_cache[sha].timestamp == 0 then
            meta_cache[sha].timestamp = tonumber(ts) or 0
          end
        end
        if mline:match("^filename%s+") then
          i = i + 1
          break
        end
        i = i + 1
      end

      local ts = meta_cache[sha].timestamp
      local is_uncommitted = sha == ZERO_SHA
      for l = final_line, final_line + hunk_count - 1 do
        if l >= 1 and l <= line_count then
          result[l] = {
            timestamp = is_uncommitted and 0 or ts,
            sha = sha,
          }
        end
      end
    else
      i = i + 1
    end
  end

  return result
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Detect the git repository root for a path.
---@param path string
---@param callback fun(root: string|nil)
function M.find_repo_root(path, callback)
  local dir = vim.fn.fnamemodify(path, ":h")
  spawn(
    { "git", "rev-parse", "--show-toplevel" },
    dir,
    nil,
    function(code, out)
      if code ~= 0 or out == "" then
        callback(nil)
        return
      end
      local root = out:match("^(.-)%s*$")
      callback(root ~= "" and root or nil)
    end
  )
end

--- Check whether a file is tracked by git.
---@param path string
---@param repo_root string
---@param callback fun(tracked: boolean)
function M.is_tracked(path, repo_root, callback)
  local pathspec = M.pathspec_for_repo(path, repo_root)
  spawn(
    { "git", "ls-files", "--error-unmatch", "--", pathspec },
    repo_root,
    nil,
    function(code, _out)
      callback(code == 0)
    end
  )
end

--- Run async blame for a buffer.
---@param bufnr integer
---@param path string
---@param repo_root string|nil
---@param dirty boolean
---@param request_id integer
---@param request_tick integer
---@param callback fun(result: table|nil)
function M.blame_async(bufnr, path, repo_root, dirty, request_id, request_tick, callback)
  local cache = require("gutter-slime.cache")
  local util = require("gutter-slime.util")

  local function is_stale()
    if cache.current_request(bufnr) ~= request_id then
      return true
    end
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return true
    end
    local current_tick = vim.b[bufnr].changedtick or 0
    return current_tick ~= request_tick
  end

  local function run_blame(root)
    if is_stale() then
      return
    end

    local line_count = vim.api.nvim_buf_line_count(bufnr)

    if line_count == 0 then
      callback(nil)
      return
    end

    local pathspec = M.pathspec_for_repo(path, root)
    local cmd = M.build_blame_command(pathspec, dirty)

    local stdin_data = nil
    if dirty then
      local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      stdin_data = table.concat(buf_lines, "\n") .. "\n"
    end

    spawn(cmd, root, stdin_data, function(code, out)
      if is_stale() then
        return
      end

      if code ~= 0 then
        util.debug("blame job failed: buf=%d code=%d", bufnr, code)
        callback(nil)
        return
      end

      local parsed = M.parse_incremental(out, line_count)
      callback(parsed)
    end)
  end

  local function after_tracked(tracked)
    if is_stale() then
      return
    end
    if not tracked then
      util.debug("blame: buf=%d path not tracked, skipping", bufnr)
      callback(nil)
      return
    end
    run_blame(repo_root)
  end

  local function after_root(root)
    if is_stale() then
      return
    end
    if not root then
      util.debug("blame: buf=%d no git repo found, skipping", bufnr)
      callback(nil)
      return
    end
    repo_root = root
    M.is_tracked(path, root, after_tracked)
  end

  if repo_root then
    M.is_tracked(path, repo_root, after_tracked)
  else
    M.find_repo_root(path, after_root)
  end
end

return M
