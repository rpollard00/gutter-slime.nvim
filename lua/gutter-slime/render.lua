-- lua/gutter-slime/render.lua
-- Window-local statuscolumn renderer.

local M = {}

local cache = require("gutter-slime.cache")
local palette = require("gutter-slime.palette")

local _attached = {}

-- `%*` is unreliable inside `%{%...%}`. `%##` resets to Normal safely.
-- The trailing literal space preserves the usual gap between gutter and text.
local _STC = "%s%=%{&nu?(&rnu?v:relnum==0?v:lnum:v:relnum:v:lnum):''}"
  .. " %{%v:lua.require('gutter-slime.render')._stc_line()%} "

---@param bufnr integer
---@param lnum integer
---@param virtnum integer
---@return string
function M._stc_line_at(bufnr, lnum, virtnum)
  if virtnum ~= 0 then
    return " "
  end

  local bucket = cache.get_bucket(bufnr, lnum)
  if bucket == nil then
    return " "
  end

  local cfg = require("gutter-slime.config").get()
  if bucket == 0 and not cfg.show_uncommitted then
    return " "
  end

  return palette.fragment_for_bucket(bucket)
end

---@return string
function M._stc_line()
  local winid = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winid)
  return M._stc_line_at(bufnr, vim.v.lnum, vim.v.virtnum)
end

---@param winid integer
function M.attach_win(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end

  if _attached[winid] then
    vim.api.nvim_win_call(winid, function()
      vim.cmd("redrawstatus")
    end)
    return
  end

  local prev = vim.wo[winid].statuscolumn
  _attached[winid] = { prev_stc = prev }
  vim.wo[winid].statuscolumn = _STC

  vim.api.nvim_win_call(winid, function()
    vim.cmd("redrawstatus")
  end)

  require("gutter-slime.util").debug("render: attached win=%d", winid)
end

---@param winid integer
function M.detach_win(winid)
  local rec = _attached[winid]
  if not rec then
    return
  end

  if vim.api.nvim_win_is_valid(winid) then
    vim.wo[winid].statuscolumn = rec.prev_stc
    vim.api.nvim_win_call(winid, function()
      vim.cmd("redrawstatus")
    end)
  end

  _attached[winid] = nil
  require("gutter-slime.util").debug("render: detached win=%d", winid)
end

--- Detach from all tracked windows.
function M.detach_all()
  local wins = {}
  for winid in pairs(_attached) do
    wins[#wins + 1] = winid
  end
  for _, winid in ipairs(wins) do
    M.detach_win(winid)
  end
end

--- Attach in every window displaying bufnr.
---@param bufnr integer
function M.refresh_buf(bufnr)
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      M.attach_win(winid)
    end
  end
end

--- Detach from every window displaying bufnr.
---@param bufnr integer
function M.clear_buf(bufnr)
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      M.detach_win(winid)
    end
  end
end

---@return integer[]
function M.attached_wins()
  local wins = {}
  for winid in pairs(_attached) do
    wins[#wins + 1] = winid
  end
  return wins
end

return M
