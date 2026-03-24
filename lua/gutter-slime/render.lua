-- lua/gutter-slime/render.lua
-- statuscolumn-based gutter heatmap renderer.
--
-- Design constraints (from the plan):
--   - Only color true buffer lines; skip wrapped screen rows (v:virtnum != 0).
--   - The render function must be constant-time per line: no blame queries,
--     no palette generation, only a cache lookup + string return.
--   - Coexist with line numbers and other statuscolumn content where possible.
--
-- Integration model (Phase 1 / MVP):
--   When the plugin attaches to a window it prepends its own statuscolumn
--   expression to whatever was already set, storing the original value so it
--   can be restored on detach.

local M = {}
local cache = require("gutter-slime.cache")
local palette = require("gutter-slime.palette")

-- winid -> original statuscolumn string (before we touched it)
local _original_statuscolumn = {}

-- The Lua function expression embedded in statuscolumn.
-- Must be a global (or vim.g / package.loaded path) because statuscolumn is
-- evaluated as a Vimscript expression that can call v:lua functions.
_G.__gutter_slime_statuscolumn = function()
  -- v:virtnum ~= 0 means this is a wrapped continuation row; skip it.
  if vim.v.virtnum ~= 0 then
    return ""
  end

  -- In statuscolumn context the expression is evaluated for the window being
  -- drawn; nvim_get_current_win() returns that window's id.
  local winid = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local lnum = vim.v.lnum
  local bucket = cache.get_bucket(bufnr, lnum)

  if bucket == nil then
    return " "
  end

  local cfg = require("gutter-slime.config").get()
  if bucket == 0 and not cfg.show_uncommitted then
    return " "
  end

  local group = palette.group_for_bucket(bucket)
  -- Return a highlight-group-wrapped space. Inside %{%...%} we can return
  -- statuscolumn item strings including %#Hl# tokens. We do NOT use %* here
  -- because Neovim resets the highlight after each %{%...%} block anyway.
  return "%#" .. group .. "# "
end

--- Attach the heatmap renderer to a window.
---@param winid integer
function M.attach(winid)
  if _original_statuscolumn[winid] ~= nil then
    -- Already attached.
    return
  end

  local ok, current = pcall(vim.api.nvim_win_get_option, winid, "statuscolumn")
  if not ok then
    current = ""
  end

  _original_statuscolumn[winid] = current or ""

  -- Prepend our cell to whatever was already in statuscolumn.
  -- %{%...%} forces re-evaluation of the expression per line.
  local our_expr = "%{%v:lua.__gutter_slime_statuscolumn()%}"
  local new_sc = our_expr .. (_original_statuscolumn[winid] ~= "" and _original_statuscolumn[winid] or "")
  vim.api.nvim_win_set_option(winid, "statuscolumn", new_sc)

  require("gutter-slime.util").debug("render: attached to win %d", winid)
end

--- Detach the renderer from a window, restoring the previous statuscolumn.
---@param winid integer
function M.detach(winid)
  if _original_statuscolumn[winid] == nil then
    return
  end

  if vim.api.nvim_win_is_valid(winid) then
    pcall(vim.api.nvim_win_set_option, winid, "statuscolumn", _original_statuscolumn[winid])
  end

  _original_statuscolumn[winid] = nil
  require("gutter-slime.util").debug("render: detached from win %d", winid)
end

--- Detach from all tracked windows.
function M.detach_all()
  for winid, _ in pairs(_original_statuscolumn) do
    M.detach(winid)
  end
end

--- Force a visual redraw of a window so the statuscolumn re-evaluates.
---@param winid integer
function M.redraw(winid)
  if vim.api.nvim_win_is_valid(winid) then
    vim.cmd("redraw")
  end
end

--- Return true if a window currently has the renderer attached.
---@param winid integer
---@return boolean
function M.is_attached(winid)
  return _original_statuscolumn[winid] ~= nil
end

return M
