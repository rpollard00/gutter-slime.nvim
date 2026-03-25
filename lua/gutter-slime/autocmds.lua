-- lua/gutter-slime/autocmds.lua
-- Autocommands that drive heatmap updates.

local M = {}

local augroup_id = nil
local debounce_timers = {} -- bufnr -> uv timer

--- Cancel a buffer debounce timer.
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

--- Schedule a debounced refresh.
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

--- Register plugin autocommands.
function M.setup()
  if augroup_id then
    vim.api.nvim_del_augroup_by_id(augroup_id)
  end

  augroup_id = vim.api.nvim_create_augroup("GutterSlime", { clear = true })

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

  vim.api.nvim_create_autocmd({ "WinEnter" }, {
    group = augroup_id,
    desc = "gutter-slime: attach statuscolumn on window enter",
    callback = function()
      local render = require("gutter-slime.render")
      local gs = require("gutter-slime")
      if not gs._is_enabled() then
        return
      end
      local winid = vim.api.nvim_get_current_win()
      local bufnr = vim.api.nvim_win_get_buf(winid)
      local util = require("gutter-slime.util")
      if not util.is_eligible_buffer(bufnr) then
        render.detach_win(winid)
        return
      end
      if require("gutter-slime.cache").get_buckets(bufnr) then
        render.attach_win(winid)
      else
        render.detach_win(winid)
      end
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup_id,
    desc = "gutter-slime: detach statuscolumn on window close",
    callback = function(ev)
      local winid = tonumber(ev.match)
      if winid then
        require("gutter-slime.render").detach_win(winid)
      end
    end,
  })

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

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup_id,
    desc = "gutter-slime: rebuild palette on colorscheme change",
    callback = function()
      local gs = require("gutter-slime")
      if not gs._is_enabled() then
        return
      end
      require("gutter-slime.palette").build()
      gs._redraw_all()
    end,
  })

  vim.api.nvim_create_autocmd("BufUnload", {
    group = augroup_id,
    desc = "gutter-slime: clean up buffer state on unload",
    callback = function(ev)
      cancel_timer(ev.buf)
      require("gutter-slime.cache").clear_buf(ev.buf)
      require("gutter-slime.render").clear_buf(ev.buf)
    end,
  })
end

--- Tear down autocommands and timers.
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
