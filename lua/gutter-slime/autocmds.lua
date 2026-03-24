-- lua/gutter-slime/autocmds.lua
-- Registers all autocommands that drive heatmap updates.
-- Called once from init.lua after setup().

local M = {}

local augroup_id = nil
local debounce_timers = {} -- bufnr -> uv timer

--- Cancel any pending debounce timer for a buffer.
---@param bufnr integer
local function cancel_timer(bufnr)
  local t = debounce_timers[bufnr]
  if t then
    pcall(function()
      t:stop()
      t:close()
    end)
    debounce_timers[bufnr] = nil
  end
end

--- Schedule a debounced refresh for bufnr.
---@param bufnr integer
local function debounced_refresh(bufnr)
  local cfg = require("gutter-slime.config").get()
  cancel_timer(bufnr)

  local timer = (vim.uv or vim.loop).new_timer()
  debounce_timers[bufnr] = timer
  timer:start(cfg.debounce_ms, 0, function()
    cancel_timer(bufnr)
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        require("gutter-slime")._refresh_buf(bufnr)
      end
    end)
  end)
end

--- Create the autocommand group and register all triggers.
function M.setup()
  if augroup_id then
    -- Already set up; clear and recreate for idempotency.
    vim.api.nvim_del_augroup_by_id(augroup_id)
  end

  augroup_id = vim.api.nvim_create_augroup("GutterSlime", { clear = true })

  -- Immediate refresh on buffer/window enter and write.
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "BufWritePost", "FocusGained" }, {
    group = augroup_id,
    desc = "gutter-slime: trigger refresh",
    callback = function(ev)
      local gs = require("gutter-slime")
      if not gs._is_enabled() then
        return
      end
      gs._refresh_buf(ev.buf)
    end,
  })

  -- Debounced refresh while typing.
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = augroup_id,
    desc = "gutter-slime: debounced refresh on text change",
    callback = function(ev)
      local gs = require("gutter-slime")
      if not gs._is_enabled() then
        return
      end
      debounced_refresh(ev.buf)
    end,
  })

  -- Palette rebuild on colorscheme change.
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup_id,
    desc = "gutter-slime: rebuild palette on colorscheme change",
    callback = function()
      local gs = require("gutter-slime")
      if not gs._is_enabled() then
        return
      end
      require("gutter-slime.palette").build()
      -- Re-render all windows that have heatmap active.
      gs._redraw_all()
    end,
  })

  -- Cleanup when a buffer is unloaded.
  vim.api.nvim_create_autocmd("BufUnload", {
    group = augroup_id,
    desc = "gutter-slime: clean up buffer state on unload",
    callback = function(ev)
      cancel_timer(ev.buf)
      require("gutter-slime.cache").clear_buf(ev.buf)
    end,
  })
end

--- Tear down all autocommands and outstanding timers.
function M.teardown()
  if augroup_id then
    pcall(vim.api.nvim_del_augroup_by_id, augroup_id)
    augroup_id = nil
  end
  for bufnr, _ in pairs(debounce_timers) do
    cancel_timer(bufnr)
  end
end

return M
