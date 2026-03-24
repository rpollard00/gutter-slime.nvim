-- lua/gutter-slime/init.lua
-- Public API and orchestration layer.
--
-- Public surface:
--   require("gutter-slime").setup(opts)
--   require("gutter-slime").enable()
--   require("gutter-slime").disable()
--   require("gutter-slime").toggle()
--   require("gutter-slime").refresh()
--   require("gutter-slime").inspect()
--
-- Internal surface (called by autocmds, commands, render):
--   _is_enabled()
--   _refresh_buf(bufnr)
--   _redraw_all()

local M = {}

local _initialized = false
local _enabled = false

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function log_debug(msg, ...)
  require("gutter-slime.util").debug(msg, ...)
end

--- Convert an absolute Unix timestamp to a bucket index 1..bucket_count.
--- Returns 0 for uncommitted lines (timestamp == 0).
---@param ts integer  Unix timestamp (0 = uncommitted)
---@return integer
local function ts_to_bucket(ts)
  if ts == 0 then
    return 0
  end

  local cfg = require("gutter-slime.config").get()
  local age_secs = os.time() - ts
  local age_days = age_secs / 86400

  if age_days < 0 then
    age_days = 0
  end

  local n = cfg.bucket_count
  local old_days = cfg.old_days

  -- Clamp ancient history into the last bucket.
  if age_days >= old_days then
    return n
  end

  -- Map [0, old_days) linearly into [1, n], then we'll sort by recency.
  -- We invert so bucket 1 = freshest, bucket n = oldest.
  -- pos: 0 (fresh) → 1 (old)
  local pos = age_days / old_days
  -- Map pos → bucket such that bucket 1 corresponds to smallest pos.
  local bucket = math.floor(pos * (n - 1)) + 1
  return math.max(1, math.min(bucket, n))
end

--- Generate synthetic bucket data for a buffer (Phase 1 vertical slice).
--- Assigns buckets in a cycling pattern so every bucket level is visible.
---@param bufnr integer
local function apply_synthetic_blame(bufnr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local cfg = require("gutter-slime.config").get()
  local n = cfg.bucket_count
  local now = os.time()

  local buckets = {}
  local timestamps = {}

  for i = 1, line_count do
    -- Cycle through buckets including uncommitted (0) when show_uncommitted.
    local max_b = cfg.show_uncommitted and n or n
    local raw = (i - 1) % (max_b + (cfg.show_uncommitted and 1 or 0))
    local bucket_id
    local ts

    if cfg.show_uncommitted and raw == 0 then
      bucket_id = 0
      ts = 0
    else
      local b = cfg.show_uncommitted and raw or (raw + 1)
      bucket_id = b
      -- Manufacture a timestamp that would map to this bucket.
      local pos = (b - 1) / math.max(n - 1, 1)
      ts = now - math.floor(pos * cfg.old_days * 86400)
    end

    buckets[i] = bucket_id
    timestamps[i] = ts
  end

  local cache = require("gutter-slime.cache")
  local req_id = cache.new_request(bufnr)
  local tick = vim.b[bufnr].changedtick or 0
  cache.store(bufnr, req_id, tick, buckets, timestamps)

  log_debug("synthetic blame applied: buf=%d lines=%d", bufnr, line_count)
end

--- Attach (or re-attach) the renderer to all windows displaying bufnr.
---@param bufnr integer
local function attach_windows(bufnr)
  local render = require("gutter-slime.render")
  for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
    if not render.is_attached(winid) then
      render.attach(winid)
    end
  end
end

--- Detach renderer from all windows displaying bufnr.
---@param bufnr integer
local function detach_windows(bufnr)
  local render = require("gutter-slime.render")
  for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
    render.detach(winid)
  end
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Primary setup entry point. Call once from your config.
---@param opts table|nil
function M.setup(opts)
  require("gutter-slime.config").setup(opts)

  if not _initialized then
    require("gutter-slime.palette").build()
    require("gutter-slime.autocmds").setup()
    _initialized = true
  else
    -- Re-setup: rebuild palette with potentially new config.
    require("gutter-slime.palette").build()
  end

  local cfg = require("gutter-slime.config").get()
  _enabled = cfg.enabled

  if _enabled then
    log_debug("setup complete (enabled)")
    -- Refresh the current buffer immediately if we're in a window.
    local bufnr = vim.api.nvim_get_current_buf()
    M._refresh_buf(bufnr)
  else
    log_debug("setup complete (disabled)")
  end
end

--- Enable heatmap rendering globally.
function M.enable()
  _enabled = true
  require("gutter-slime.config").current.enabled = true
  if not _initialized then
    M.setup()
    return
  end
  require("gutter-slime.palette").build()
  local bufnr = vim.api.nvim_get_current_buf()
  M._refresh_buf(bufnr)
  vim.notify("gutter-slime enabled", vim.log.levels.INFO)
end

--- Disable heatmap rendering globally and detach all windows.
function M.disable()
  _enabled = false
  require("gutter-slime.config").current.enabled = false
  require("gutter-slime.render").detach_all()
  vim.notify("gutter-slime disabled", vim.log.levels.INFO)
end

--- Toggle heatmap rendering.
function M.toggle()
  if _enabled then
    M.disable()
  else
    M.enable()
  end
end

--- Force a fresh refresh of the current buffer.
function M.refresh()
  local bufnr = vim.api.nvim_get_current_buf()
  require("gutter-slime.cache").clear_buf(bufnr)
  M._refresh_buf(bufnr)
end

--- Print diagnostic information about the current buffer's state.
function M.inspect()
  local bufnr = vim.api.nvim_get_current_buf()
  local cache = require("gutter-slime.cache")
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local bucket = cache.get_bucket(bufnr, lnum)
  local ts = cache.get_timestamp(bufnr, lnum)
  local tick = cache.get_changedtick(bufnr)
  local req = cache.current_request(bufnr)

  local lines = {
    string.format("gutter-slime inspect  buf=%d  enabled=%s", bufnr, tostring(_enabled)),
    string.format("  cursor line : %d", lnum),
    string.format("  bucket      : %s", tostring(bucket)),
    string.format("  timestamp   : %s", ts and os.date("%Y-%m-%d %H:%M:%S", ts) or "nil"),
    string.format("  changedtick : %s", tostring(tick)),
    string.format("  request_id  : %d", req),
  }

  local palette = require("gutter-slime.palette")
  local groups = palette.group_names()
  table.insert(lines, string.format("  palette     : %d groups", #groups))
  for _, g in ipairs(groups) do
    table.insert(lines, "    " .. g)
  end

  -- Show windows attached to this buffer.
  local render = require("gutter-slime.render")
  local attached = {}
  for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
    if render.is_attached(winid) then
      table.insert(attached, tostring(winid))
    end
  end
  table.insert(lines, string.format("  attached windows: %s", table.concat(attached, ", ")))

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

-- ---------------------------------------------------------------------------
-- Internal surface
-- ---------------------------------------------------------------------------

--- Check whether the plugin is globally enabled.
---@return boolean
function M._is_enabled()
  return _enabled
end

--- Refresh heatmap data for a single buffer and (re-)attach windows.
---@param bufnr integer
function M._refresh_buf(bufnr)
  if not _enabled then
    return
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local util = require("gutter-slime.util")
  if not util.is_eligible_buffer(bufnr) then
    log_debug("_refresh_buf: buf=%d ineligible, skipping", bufnr)
    return
  end

  -- Phase 1: use synthetic blame data. Phase 2 will replace this with real git blame.
  apply_synthetic_blame(bufnr)
  attach_windows(bufnr)
  vim.cmd("redraw")
end

--- Force a re-render of all windows that are currently attached.
function M._redraw_all()
  local render = require("gutter-slime.render")
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if render.is_attached(winid) then
      render.redraw(winid)
    end
  end
end

return M
