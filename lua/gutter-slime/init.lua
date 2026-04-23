-- lua/gutter-slime/init.lua
-- Public API and orchestration layer.

local M = {}

local _initialized = false
local _enabled = false

local ZERO_SHA = "0000000000000000000000000000000000000000"

local ZOOM_LADDER_DAYS = {
  180,
  120,
  90,
  60,
  30,
  21,
  14,
  10,
  7,
  5,
  3,
  2,
  1.5,
  1,
  0.75,
  0.5,
  1 / 3,
  0.25,
  1 / 6,
  0.125,
  1 / 12,
  1 / 24,
}

local function log_debug(msg, ...)
  require("gutter-slime.util").debug(msg, ...)
end

---@param pos number
---@param curve string
---@return number
local function apply_curve(pos, curve)
  if curve == "linear" then
    return pos
  end
  if curve == "recent" then
    return math.sqrt(pos)
  end
  if curve == "old" then
    return pos ^ 1.6
  end
  if curve == "smooth" then
    return pos * pos * (3 - 2 * pos)
  end
  return pos
end

---@param ts integer
---@return integer
local function ts_to_absolute_bucket(ts)
  if ts == 0 then
    return 0
  end

  local cfg = require("gutter-slime.config").get()
  local util = require("gutter-slime.util")
  local age_secs = os.time() - ts
  local age_days = age_secs / 86400

  if age_days < 0 then
    age_days = 0
  end

  local n = cfg.bucket_count
  local recent_days = cfg.recent_days
  local old_days = cfg.old_days

  if age_days <= recent_days then
    return 1
  end
  if age_days >= old_days then
    return n
  end

  local span = old_days - recent_days
  local pos = (age_days - recent_days) / span
  local curved = util.clamp(apply_curve(pos, cfg.curve), 0, 1)
  local bucket = math.floor(curved * (n - 1)) + 1
  return math.max(1, math.min(bucket, n))
end

---@param timestamps integer[]
---@return integer[]
local function timestamps_to_absolute_buckets(timestamps)
  local buckets = {}
  for i, ts in ipairs(timestamps) do
    buckets[i] = ts_to_absolute_bucket(ts)
  end
  return buckets
end

---@param timestamps integer[]
---@return integer[]
local function timestamps_to_relative_time_buckets(timestamps)
  local cfg = require("gutter-slime.config").get()
  local util = require("gutter-slime.util")
  local n = cfg.bucket_count
  local min_ts = nil
  local max_ts = nil

  for _, ts in ipairs(timestamps) do
    if ts > 0 then
      min_ts = min_ts and math.min(min_ts, ts) or ts
      max_ts = max_ts and math.max(max_ts, ts) or ts
    end
  end

  local buckets = {}
  if not min_ts or not max_ts then
    for i, ts in ipairs(timestamps) do
      buckets[i] = ts == 0 and 0 or 1
    end
    return buckets
  end

  local span_secs = max_ts - min_ts
  if span_secs <= 0 or (span_secs / 86400) < cfg.relative.min_span_days then
    for i, ts in ipairs(timestamps) do
      buckets[i] = ts == 0 and 0 or 1
    end
    return buckets
  end

  for i, ts in ipairs(timestamps) do
    if ts == 0 then
      buckets[i] = 0
    else
      local pos = (max_ts - ts) / span_secs
      local curved = util.clamp(apply_curve(pos, cfg.relative.curve), 0, 1)
      local bucket = math.floor(curved * (n - 1)) + 1
      buckets[i] = math.max(1, math.min(bucket, n))
    end
  end
  return buckets
end

---@param timestamps integer[]
---@return integer[]
local function timestamps_to_relative_quantile_buckets(timestamps)
  local cfg = require("gutter-slime.config").get()
  local util = require("gutter-slime.util")
  local n = cfg.bucket_count
  local counts = {}
  local sorted = {}
  local total = 0

  for _, ts in ipairs(timestamps) do
    if ts > 0 then
      if not counts[ts] then
        sorted[#sorted + 1] = ts
        counts[ts] = 0
      end
      counts[ts] = counts[ts] + 1
      total = total + 1
    end
  end

  table.sort(sorted, function(a, b)
    return a > b
  end)

  local by_timestamp = {}
  if total > 0 then
    local seen = 0
    for _, ts in ipairs(sorted) do
      local count = counts[ts]
      local pos = #sorted == 1 and 0 or (seen + ((count - 1) / 2)) / (total - 1)
      local curved = util.clamp(apply_curve(pos, cfg.relative.curve), 0, 1)
      local bucket = math.floor(curved * (n - 1)) + 1
      by_timestamp[ts] = math.max(1, math.min(bucket, n))
      seen = seen + count
    end
  end

  local buckets = {}
  for i, ts in ipairs(timestamps) do
    buckets[i] = ts == 0 and 0 or (by_timestamp[ts] or 1)
  end
  return buckets
end

---@param timestamps integer[]
---@return integer[]
local function timestamps_to_buckets(timestamps)
  local mode = require("gutter-slime.config").get().bucket_mode
  if mode == "relative_time" then
    return timestamps_to_relative_time_buckets(timestamps)
  end
  if mode == "relative_quantile" then
    return timestamps_to_relative_quantile_buckets(timestamps)
  end
  return timestamps_to_absolute_buckets(timestamps)
end

---@param bufnr integer
---@return boolean
local function rebucket_buf(bufnr)
  local cache = require("gutter-slime.cache")
  local timestamps = cache.get_timestamps(bufnr)
  if not timestamps then
    return false
  end

  local buckets = timestamps_to_buckets(timestamps)

  local stored = cache.store(
    bufnr,
    cache.current_request(bufnr),
    cache.get_changedtick(bufnr) or 0,
    buckets,
    timestamps,
    cache.get_jj_current(bufnr)
  )
  if stored and _enabled and vim.api.nvim_buf_is_valid(bufnr) then
    require("gutter-slime.render").refresh_buf(bufnr)
  end
  return stored
end

local function rebucket_all()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      rebucket_buf(bufnr)
    end
  end
  if _enabled then
    M._redraw_all()
  end
end

---@param current number
---@param toward_present boolean
---@return number
local function step_old_days(current, toward_present)
  if toward_present then
    for _, entry in ipairs(ZOOM_LADDER_DAYS) do
      if entry < current then
        return entry
      end
    end
    return ZOOM_LADDER_DAYS[#ZOOM_LADDER_DAYS]
  end

  for i = #ZOOM_LADDER_DAYS, 1, -1 do
    local entry = ZOOM_LADDER_DAYS[i]
    if entry > current then
      return entry
    end
  end
  return ZOOM_LADDER_DAYS[1]
end

---@param patch table
---@param ok_msg string|nil
---@return boolean
local function apply_view_patch(patch, ok_msg)
  local ok, err = require("gutter-slime.config").update_view(patch)
  if not ok then
    vim.notify("gutter-slime: " .. err, vim.log.levels.WARN)
    return false
  end

  rebucket_all()
  if ok_msg then
    vim.notify(ok_msg, vim.log.levels.INFO)
  end
  return true
end

---@param style string
---@param ok_msg string|nil
---@return boolean
local function apply_gradient_style(style, ok_msg)
  local ok, err = require("gutter-slime.config").update_gradient_style(style)
  if not ok then
    vim.notify("gutter-slime: " .. err, vim.log.levels.WARN)
    return false
  end

  require("gutter-slime.palette").build()
  if _enabled then
    M._redraw_all()
  end
  if ok_msg then
    vim.notify(ok_msg, vim.log.levels.INFO)
  end
  return true
end

---@param bufnr integer
local function is_jj_current_entry(entry, jj_current_sha)
  if not jj_current_sha or not entry then
    return false
  end
  return entry.sha == jj_current_sha or entry.sha == ZERO_SHA
end

local function apply_real_blame(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    return
  end

  local cache = require("gutter-slime.cache")
  local render = require("gutter-slime.render")
  local req_id = cache.new_request(bufnr)
  local request_tick = vim.b[bufnr] and vim.b[bufnr].changedtick or 0
  local dirty = vim.bo[bufnr].modified

  local function run_blame(jj_current_sha)
    require("gutter-slime.blame").blame_async(
      bufnr,
      path,
      nil,
      dirty,
      req_id,
      request_tick,
      function(result)
        local current_tick = vim.api.nvim_buf_is_valid(bufnr) and (vim.b[bufnr].changedtick or 0) or -1
        if cache.current_request(bufnr) ~= req_id or current_tick ~= request_tick then
          log_debug("apply_real_blame: stale result discarded buf=%d req=%d", bufnr, req_id)
          return
        end

        if not result then
          log_debug("apply_real_blame: no blame result buf=%d", bufnr)
          cache.store(bufnr, req_id, request_tick, {}, {})
          render.clear_buf(bufnr)
          return
        end

        local timestamps = {}
        local jj_current = jj_current_sha and {} or nil
        for i, entry in ipairs(result) do
          timestamps[i] = entry.timestamp
          if is_jj_current_entry(entry, jj_current_sha) then
            jj_current[i] = true
          end
        end
        local buckets = timestamps_to_buckets(timestamps)

        local stored = cache.store(bufnr, req_id, request_tick, buckets, timestamps, jj_current)
        if stored then
          log_debug("apply_real_blame: stored buf=%d lines=%d", bufnr, #buckets)
          if vim.api.nvim_buf_is_valid(bufnr) then
            render.refresh_buf(bufnr)
          end
        end
      end
    )
  end

  require("gutter-slime.jj").current_commit_async(path, function(jj_current_sha)
    local current_tick = vim.api.nvim_buf_is_valid(bufnr) and (vim.b[bufnr].changedtick or 0) or -1
    if cache.current_request(bufnr) ~= req_id or current_tick ~= request_tick then
      log_debug("apply_real_blame: stale jj result discarded buf=%d req=%d", bufnr, req_id)
      return
    end
    run_blame(jj_current_sha)
  end)
end

---@param opts table|nil
function M.setup(opts)
  require("gutter-slime.config").setup(opts)

  if not _initialized then
    require("gutter-slime.palette").build()
    require("gutter-slime.autocmds").setup()
    _initialized = true
  else
    require("gutter-slime.palette").build()
  end

  local cfg = require("gutter-slime.config").get()
  _enabled = cfg.enabled

  if _enabled then
    log_debug("setup complete (enabled)")
    local bufnr = vim.api.nvim_get_current_buf()
    M._refresh_buf(bufnr)
  else
    log_debug("setup complete (disabled)")
  end
end

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

function M.disable()
  _enabled = false
  require("gutter-slime.config").current.enabled = false
  require("gutter-slime.render").detach_all()
  vim.notify("gutter-slime disabled", vim.log.levels.INFO)
end

function M.toggle()
  if _enabled then
    M.disable()
  else
    M.enable()
  end
end

function M.refresh()
  local bufnr = vim.api.nvim_get_current_buf()
  require("gutter-slime.cache").clear_buf(bufnr)
  M._refresh_buf(bufnr)
end

---@param name string
---@return boolean
function M.set_curve(name)
  return apply_view_patch({ curve = name }, string.format("gutter-slime curve: %s", name))
end

---@param mode string
---@return boolean
function M.set_bucket_mode(mode)
  return apply_view_patch({ bucket_mode = mode }, string.format("gutter-slime bucket_mode: %s", mode))
end

---@param value string|number
---@return boolean
function M.set_old(value)
  local days, err = require("gutter-slime.config").parse_duration_days(value)
  if days == nil then
    vim.notify("gutter-slime: old_days " .. err, vim.log.levels.WARN)
    return false
  end
  return apply_view_patch({ old_days = days }, string.format("gutter-slime old_days: %.3f", days))
end

---@param recent string|number
---@param old string|number
---@return boolean
function M.set_range(recent, old)
  local config = require("gutter-slime.config")
  local recent_days, recent_err = config.parse_duration_days(recent)
  if recent_days == nil then
    vim.notify("gutter-slime: recent_days " .. recent_err, vim.log.levels.WARN)
    return false
  end
  local old_days, old_err = config.parse_duration_days(old)
  if old_days == nil then
    vim.notify("gutter-slime: old_days " .. old_err, vim.log.levels.WARN)
    return false
  end
  return apply_view_patch(
    { recent_days = recent_days, old_days = old_days },
    string.format("gutter-slime range: %.3f..%.3f days", recent_days, old_days)
  )
end

---@param delta string|number
---@return boolean
function M.adjust_old(delta)
  local config = require("gutter-slime.config")
  local delta_days, err = config.parse_duration_days(delta, { allow_negative = true })
  if delta_days == nil then
    vim.notify("gutter-slime: adjust_old " .. err, vim.log.levels.WARN)
    return false
  end

  local old_days = config.get().old_days + delta_days
  return apply_view_patch({ old_days = old_days }, string.format("gutter-slime old_days: %.3f", old_days))
end

---@return boolean
function M.step_old_newer()
  local cfg = require("gutter-slime.config").get()
  local next_old = step_old_days(cfg.old_days, true)
  return apply_view_patch(
    { old_days = next_old },
    string.format("gutter-slime old_days: %.3f", next_old)
  )
end

---@return boolean
function M.step_old_older()
  local cfg = require("gutter-slime.config").get()
  local next_old = step_old_days(cfg.old_days, false)
  return apply_view_patch(
    { old_days = next_old },
    string.format("gutter-slime old_days: %.3f", next_old)
  )
end

---@return boolean
function M.zoom_in()
  return M.step_old_newer()
end

---@return boolean
function M.zoom_out()
  return M.step_old_older()
end

---@return boolean
function M.reset_view()
  require("gutter-slime.config").reset_view()
  rebucket_all()
  vim.notify("gutter-slime view reset", vim.log.levels.INFO)
  return true
end

---@param style string
---@return boolean
function M.set_gradient_style(style)
  return apply_gradient_style(style, string.format("gutter-slime gradient: %s", style))
end

function M.inspect()
  local bufnr = vim.api.nvim_get_current_buf()
  local cache = require("gutter-slime.cache")
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local bucket = cache.get_bucket(bufnr, lnum)
  local ts = cache.get_timestamp(bufnr, lnum)
  local tick = cache.get_changedtick(bufnr)
  local req = cache.current_request(bufnr)
  local cfg = require("gutter-slime.config").get()

  local lines = {
    string.format("gutter-slime inspect  buf=%d  enabled=%s", bufnr, tostring(_enabled)),
    string.format("  cursor line : %d", lnum),
    string.format("  bucket      : %s", tostring(bucket)),
    string.format("  timestamp   : %s", ts and os.date("%Y-%m-%d %H:%M:%S", ts) or "nil"),
    string.format("  changedtick : %s", tostring(tick)),
    string.format("  request_id  : %d", req),
    string.format("  recent_days : %.3f", cfg.recent_days),
    string.format("  old_days    : %.3f", cfg.old_days),
    string.format("  curve       : %s", cfg.curve),
    string.format("  bucket_mode : %s", cfg.bucket_mode),
  }

  local palette = require("gutter-slime.palette")
  local palette_desc = palette.describe()
  local groups = palette.group_names()
  table.insert(lines, string.format("  palette     : %d groups", #groups))
  if palette_desc then
    table.insert(lines, string.format("  gradient    : %s", palette_desc.style))
    table.insert(lines, string.format("  base bg     : %s", palette_desc.base_bg))
    table.insert(lines, string.format("  accent      : %s", palette_desc.accent))
  end
  for _, g in ipairs(groups) do
    table.insert(lines, "    " .. g)
  end

  local render = require("gutter-slime.render")
  local attached = render.attached_wins()
  table.insert(lines, string.format("  attached wins: %d", #attached))
  for _, wid in ipairs(attached) do
    table.insert(lines, string.format("    win=%d buf=%d", wid, vim.api.nvim_win_get_buf(wid)))
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

---@return boolean
function M._is_enabled()
  return _enabled
end

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
    require("gutter-slime.render").clear_buf(bufnr)
    log_debug("_refresh_buf: buf=%d ineligible, skipping", bufnr)
    return
  end

  apply_real_blame(bufnr)
end

function M._redraw_all()
  local render = require("gutter-slime.render")
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    local bufnr = vim.api.nvim_win_get_buf(winid)
    if require("gutter-slime.util").is_eligible_buffer(bufnr)
      and require("gutter-slime.cache").get_buckets(bufnr)
    then
      render.attach_win(winid)
    else
      render.detach_win(winid)
    end
  end
end

M._ts_to_bucket = ts_to_absolute_bucket
M._timestamps_to_buckets = timestamps_to_buckets
M._zoom_ladder_days = ZOOM_LADDER_DAYS
M._is_jj_current_entry = is_jj_current_entry

return M
