-- lua/gutter-slime/render.lua
-- Sign-column heatmap renderer using extmark sign_hl_group.
--
-- Instead of manipulating statuscolumn (which owns the entire gutter), we
-- place one extmark per buffer line with sign_hl_group pointing at the
-- appropriate bucket highlight group. This colors only the sign column
-- background for that line, leaving line numbers and any other statuscolumn
-- content completely untouched.
--
-- The namespace is shared across all buffers; clearing it per-buffer before
-- each redraw is O(n lines) but cheap since extmarks are stored in a B-tree.

local M = {}
local cache = require("gutter-slime.cache")
local palette = require("gutter-slime.palette")

local NS = vim.api.nvim_create_namespace("gutter_slime")

-- Sign text: two spaces gives a colored sign cell with no visible glyph.
-- Using two characters matches the default signcolumn width so it fills
-- the cell cleanly even when signcolumn=yes:2.
local SIGN_TEXT = "  "

-- Priority for our signs. Lower than error/warning diagnostics (default 10)
-- so diagnostic signs win when they overlap, but above 0 so we're visible.
local SIGN_PRIORITY = 5

--- Draw heatmap extmarks for every line in bufnr.
--- Clears any previous marks in the namespace first.
---@param bufnr integer
function M.render(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Wipe previous marks for this buffer.
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)

  local cfg = require("gutter-slime.config").get()
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  for lnum = 1, line_count do
    local bucket = cache.get_bucket(bufnr, lnum)
    if bucket ~= nil then
      if bucket ~= 0 or cfg.show_uncommitted then
        local group = palette.group_for_bucket(bucket)
        -- nvim_buf_set_extmark uses 0-based row indices.
        vim.api.nvim_buf_set_extmark(bufnr, NS, lnum - 1, 0, {
          sign_hl_group = group,
          sign_text = SIGN_TEXT,
          priority = SIGN_PRIORITY,
        })
      end
    end
  end

  require("gutter-slime.util").debug("render: drew %d lines for buf %d", line_count, bufnr)
end

--- Clear all heatmap extmarks from bufnr.
---@param bufnr integer
function M.clear(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  end
end

--- Clear heatmap extmarks from all buffers.
function M.clear_all()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    M.clear(bufnr)
  end
end

--- Return the namespace id (useful for tests).
---@return integer
function M.namespace()
  return NS
end

return M
