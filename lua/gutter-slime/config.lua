-- lua/gutter-slime/config.lua
-- Default configuration and user-config merging/validation.

local M = {}

local VIEW_KEYS = {
  bucket_mode = true,
  recent_days = true,
  old_days = true,
  curve = true,
}

local VALID_CURVES = {
  linear = true,
  recent = true,
  old = true,
  smooth = true,
}

local VALID_GRADIENT_STYLES = {
  monotone = true,
  vibrant = true,
  muted = true,
  slime = true,
  rainbow = true,
  thermal = true,
  custom = true,
}

local VALID_BUCKET_MODES = {
  absolute = true,
  relative_time = true,
  relative_quantile = true,
}

---@class GutterSlimeConfig
---@field enabled boolean
---@field debounce_ms integer
---@field bucket_count integer
---@field bucket_mode string
---@field recent_days number|string
---@field old_days number|string
---@field curve string
---@field relative { curve: string, min_span_days: number|string }
---@field show_uncommitted boolean
---@field disable_in_diff boolean
---@field accent_hl string|nil
---@field gradient { style: string, curve: string, min_contrast: number, min_contrast_by_style: table<string, number>, accent_hl: string|nil, custom: { stops: string[], uncommitted: string|nil } }
---@field jj { enabled: boolean, current_change: boolean, marker: string, marker_hl: string|nil }
---@field debug boolean

---@type GutterSlimeConfig
M.defaults = {
  enabled = true,
  debounce_ms = 150,
  bucket_count = 16,
  bucket_mode = "absolute",
  recent_days = 0,
  old_days = 180,
  curve = "recent",
  relative = {
    curve = "linear",
    min_span_days = 0,
  },
  show_uncommitted = true,
  disable_in_diff = true,
  accent_hl = nil,
  gradient = {
    style = "monotone",
    curve = "linear",
    min_contrast = 4,
    min_contrast_by_style = {
      monotone = 4,
      vibrant = 4,
      muted = 2,
      slime = 4,
      rainbow = 3,
      thermal = 4,
    },
    accent_hl = nil,
    custom = {
      stops = {},
      uncommitted = nil,
    },
  },
  jj = {
    enabled = true,
    current_change = true,
    marker = "▌",
    marker_hl = nil,
  },
  debug = false,
}

---@type GutterSlimeConfig
M.current = vim.deepcopy(M.defaults)

---@type { bucket_mode: string, recent_days: number, old_days: number, curve: string }
M.view_defaults = {
  bucket_mode = M.defaults.bucket_mode,
  recent_days = M.defaults.recent_days,
  old_days = M.defaults.old_days,
  curve = M.defaults.curve,
}

---@param msg string
---@param level integer
local function notify(msg, level)
  vim.notify("gutter-slime: " .. msg, level)
end

---@param value any
---@return string[]
local function normalize_stop_list(value)
  local util = require("gutter-slime.util")

  if type(value) ~= "table" then
    return {}
  end

  local stops = {}
  for _, entry in ipairs(value) do
    local normalized = util.normalize_hex(entry)
    if normalized then
      table.insert(stops, normalized)
    end
  end
  return stops
end

---@param cfg GutterSlimeConfig
local function normalize_gradient(cfg)
  local util = require("gutter-slime.util")
  local defaults = M.defaults.gradient
  local gradient = cfg.gradient

  if type(gradient) ~= "table" then
    notify("gradient must be a table; using defaults", vim.log.levels.WARN)
    gradient = vim.deepcopy(defaults)
    cfg.gradient = gradient
  end

  if gradient.accent_hl == nil and type(cfg.accent_hl) == "string" and cfg.accent_hl ~= "" then
    gradient.accent_hl = cfg.accent_hl
  end

  if type(gradient.style) ~= "string" or not VALID_GRADIENT_STYLES[gradient.style] then
    notify("gradient.style must be one of monotone, vibrant, muted, slime, rainbow, thermal, custom; using default", vim.log.levels.WARN)
    gradient.style = defaults.style
  end

  if type(gradient.curve) ~= "string" or not VALID_CURVES[gradient.curve] then
    notify("gradient.curve must be one of linear, recent, old, smooth; using default", vim.log.levels.WARN)
    gradient.curve = defaults.curve
  end

  if type(gradient.min_contrast) ~= "number" or gradient.min_contrast < 0 then
    notify("gradient.min_contrast must be a non-negative number; using default", vim.log.levels.WARN)
    gradient.min_contrast = defaults.min_contrast
  end

  if type(gradient.min_contrast_by_style) ~= "table" then
    notify("gradient.min_contrast_by_style must be a table; using defaults", vim.log.levels.WARN)
    gradient.min_contrast_by_style = vim.deepcopy(defaults.min_contrast_by_style)
  else
    for style, value in pairs(gradient.min_contrast_by_style) do
      if not VALID_GRADIENT_STYLES[style] or style == "custom" or type(value) ~= "number" or value < 0 then
        notify("gradient.min_contrast_by_style entries must map built-in styles to non-negative numbers; removing invalid entry", vim.log.levels.WARN)
        gradient.min_contrast_by_style[style] = nil
      end
    end
  end

  if gradient.accent_hl ~= nil and type(gradient.accent_hl) ~= "string" then
    notify("gradient.accent_hl must be a string or nil; clearing override", vim.log.levels.WARN)
    gradient.accent_hl = nil
  end

  if type(gradient.custom) ~= "table" then
    notify("gradient.custom must be a table; using defaults", vim.log.levels.WARN)
    gradient.custom = vim.deepcopy(defaults.custom)
  end

  gradient.custom.stops = normalize_stop_list(gradient.custom.stops)
  if gradient.style == "custom" and #gradient.custom.stops == 0 then
    notify("gradient.custom.stops must contain at least one hex color for custom style; using monotone", vim.log.levels.WARN)
    gradient.style = "monotone"
  end

  if gradient.custom.uncommitted ~= nil then
    local normalized = util.normalize_hex(gradient.custom.uncommitted)
    if normalized then
      gradient.custom.uncommitted = normalized
    else
      notify("gradient.custom.uncommitted must be a hex color; clearing override", vim.log.levels.WARN)
      gradient.custom.uncommitted = nil
    end
  end

  cfg.accent_hl = gradient.accent_hl
end

---@param cfg GutterSlimeConfig
local function normalize_jj(cfg)
  local defaults = M.defaults.jj
  local jj = cfg.jj

  if type(jj) ~= "table" then
    notify("jj must be a table; using defaults", vim.log.levels.WARN)
    jj = vim.deepcopy(defaults)
    cfg.jj = jj
  end

  if type(jj.enabled) ~= "boolean" then
    notify("jj.enabled must be a boolean; using default", vim.log.levels.WARN)
    jj.enabled = defaults.enabled
  end

  if type(jj.current_change) ~= "boolean" then
    notify("jj.current_change must be a boolean; using default", vim.log.levels.WARN)
    jj.current_change = defaults.current_change
  end

  if type(jj.marker) ~= "string" or jj.marker == "" then
    notify("jj.marker must be a non-empty string; using default", vim.log.levels.WARN)
    jj.marker = defaults.marker
  end

  if jj.marker_hl ~= nil and type(jj.marker_hl) ~= "string" then
    notify("jj.marker_hl must be a string or nil; clearing override", vim.log.levels.WARN)
    jj.marker_hl = nil
  end
end

---@param cfg GutterSlimeConfig
local function normalize_relative(cfg)
  local defaults = M.defaults.relative
  local relative = cfg.relative

  if type(relative) ~= "table" then
    notify("relative must be a table; using defaults", vim.log.levels.WARN)
    relative = vim.deepcopy(defaults)
    cfg.relative = relative
  end

  if type(relative.curve) ~= "string" or not VALID_CURVES[relative.curve] then
    notify("relative.curve must be one of linear, recent, old, smooth; using default", vim.log.levels.WARN)
    relative.curve = defaults.curve
  end

  local min_span, min_span_err = M.parse_duration_days(relative.min_span_days)
  if min_span == nil then
    notify("relative.min_span_days " .. min_span_err .. "; using default", vim.log.levels.WARN)
    min_span = defaults.min_span_days
  end
  relative.min_span_days = min_span
end

---@param value any
---@param opts? { allow_negative?: boolean }
---@return number|nil, string|nil
function M.parse_duration_days(value, opts)
  opts = opts or {}

  if type(value) == "number" then
    if value ~= value then
      return nil, "must not be NaN"
    end
    if not opts.allow_negative and value < 0 then
      return nil, "must be >= 0"
    end
    return value, nil
  end

  if type(value) ~= "string" then
    return nil, "must be a number or duration string"
  end

  local text = vim.trim(value)
  if text == "" then
    return nil, "must not be empty"
  end

  local num = tonumber(text)
  if num ~= nil then
    if not opts.allow_negative and num < 0 then
      return nil, "must be >= 0"
    end
    return num, nil
  end

  local amount, unit = text:match("^([+-]?%d+%.?%d*)([dDhH])$")
  if not amount then
    amount, unit = text:match("^([+-]?%d*%.%d+)([dDhH])$")
  end
  if not amount then
    return nil, "must look like 7, 7d, or 12h"
  end

  local n = tonumber(amount)
  if n == nil then
    return nil, "contains an invalid number"
  end
  if not opts.allow_negative and n < 0 then
    return nil, "must be >= 0"
  end

  unit = unit:lower()
  if unit == "d" then
    return n, nil
  end
  return n / 24, nil
end

---@param cfg GutterSlimeConfig
---@param baseline { bucket_mode: string, recent_days: number, old_days: number, curve: string }
local function normalize(cfg, baseline)
  if type(cfg.debounce_ms) ~= "number" or cfg.debounce_ms < 0 then
    notify("debounce_ms must be a non-negative number; using default", vim.log.levels.WARN)
    cfg.debounce_ms = M.defaults.debounce_ms
  end

  if type(cfg.bucket_count) ~= "number" or cfg.bucket_count < 2 then
    notify("bucket_count must be >= 2; using default", vim.log.levels.WARN)
    cfg.bucket_count = M.defaults.bucket_count
  end

  if type(cfg.bucket_mode) ~= "string" or not VALID_BUCKET_MODES[cfg.bucket_mode] then
    notify("bucket_mode must be one of absolute, relative_time, relative_quantile; using default", vim.log.levels.WARN)
    cfg.bucket_mode = M.defaults.bucket_mode
  end

  local recent, recent_err = M.parse_duration_days(cfg.recent_days)
  if recent == nil then
    notify("recent_days " .. recent_err .. "; using default", vim.log.levels.WARN)
    recent = M.defaults.recent_days
  end

  local old, old_err = M.parse_duration_days(cfg.old_days)
  if old == nil then
    notify("old_days " .. old_err .. "; using default", vim.log.levels.WARN)
    old = M.defaults.old_days
  end

  if recent < 0 then
    notify("recent_days must be >= 0; using default", vim.log.levels.WARN)
    recent = M.defaults.recent_days
  end

  if old <= 0 then
    notify("old_days must be > 0; using default", vim.log.levels.WARN)
    old = M.defaults.old_days
  end

  if recent >= old then
    notify("recent_days must be < old_days; using defaults", vim.log.levels.WARN)
    recent = M.defaults.recent_days
    old = M.defaults.old_days
  end

  if type(cfg.curve) ~= "string" or not VALID_CURVES[cfg.curve] then
    notify("curve must be one of linear, recent, old, smooth; using default", vim.log.levels.WARN)
    cfg.curve = M.defaults.curve
  end

  normalize_gradient(cfg)
  normalize_jj(cfg)
  normalize_relative(cfg)

  cfg.recent_days = recent
  cfg.old_days = old

  baseline.bucket_mode = cfg.bucket_mode
  baseline.recent_days = recent
  baseline.old_days = old
  baseline.curve = cfg.curve
end

--- Merge user options into the active config.
---@param opts table|nil
function M.setup(opts)
  if opts == nil then
    M.current = vim.deepcopy(M.defaults)
    M.view_defaults = {
      bucket_mode = M.defaults.bucket_mode,
      recent_days = M.defaults.recent_days,
      old_days = M.defaults.old_days,
      curve = M.defaults.curve,
    }
    return
  end

  if type(opts) ~= "table" then
    notify("setup() expects a table or nil", vim.log.levels.ERROR)
    return
  end

  M.current = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
  if
    type(opts.gradient) == "table"
    and opts.gradient.min_contrast ~= nil
    and opts.gradient.min_contrast_by_style == nil
  then
    M.current.gradient.min_contrast_by_style = {}
  end
  M.view_defaults = {
    bucket_mode = M.defaults.bucket_mode,
    recent_days = M.defaults.recent_days,
    old_days = M.defaults.old_days,
    curve = M.defaults.curve,
  }

  normalize(M.current, M.view_defaults)
end

--- Return the active config.
---@return GutterSlimeConfig
function M.get()
  return M.current
end

---@return { bucket_mode: string, recent_days: number, old_days: number, curve: string }
function M.get_view_defaults()
  return vim.deepcopy(M.view_defaults)
end

---@return string[]
function M.curve_names()
  return { "linear", "recent", "old", "smooth" }
end

---@return string[]
function M.bucket_mode_names()
  return { "absolute", "relative_time", "relative_quantile" }
end

---@return string[]
function M.gradient_style_names()
  return { "monotone", "vibrant", "muted", "slime", "rainbow", "thermal", "custom" }
end

---@param style string
---@return boolean, string|nil
function M.update_gradient_style(style)
  if type(style) ~= "string" or not VALID_GRADIENT_STYLES[style] then
    return false, "gradient style must be one of monotone, vibrant, muted, slime, rainbow, thermal, custom"
  end

  if style == "custom" and #M.current.gradient.custom.stops == 0 then
    return false, "gradient.custom.stops must contain at least one hex color before using custom style"
  end

  M.current.gradient.style = style
  M.current.accent_hl = M.current.gradient.accent_hl
  return true, nil
end

---@param patch table
---@return boolean, string|nil
function M.update_view(patch)
  local next_cfg = vim.deepcopy(M.current)
  for key, value in pairs(patch) do
    if VIEW_KEYS[key] then
      next_cfg[key] = value
    end
  end

  local recent, recent_err = M.parse_duration_days(next_cfg.recent_days)
  if recent == nil then
    return false, "recent_days " .. recent_err
  end

  local old, old_err = M.parse_duration_days(next_cfg.old_days)
  if old == nil then
    return false, "old_days " .. old_err
  end

  if recent < 0 then
    return false, "recent_days must be >= 0"
  end
  if old <= 0 then
    return false, "old_days must be > 0"
  end
  if recent >= old then
    return false, "recent_days must be < old_days"
  end
  if patch.bucket_mode ~= nil and (type(next_cfg.bucket_mode) ~= "string" or not VALID_BUCKET_MODES[next_cfg.bucket_mode]) then
    return false, "bucket_mode must be one of absolute, relative_time, relative_quantile"
  elseif type(next_cfg.bucket_mode) ~= "string" or not VALID_BUCKET_MODES[next_cfg.bucket_mode] then
    return false, "bucket_mode must be one of absolute, relative_time, relative_quantile"
  end
  if patch.curve ~= nil and (type(next_cfg.curve) ~= "string" or not VALID_CURVES[next_cfg.curve]) then
    return false, "curve must be one of linear, recent, old, smooth"
  elseif type(next_cfg.curve) ~= "string" or not VALID_CURVES[next_cfg.curve] then
    return false, "curve must be one of linear, recent, old, smooth"
  end

  M.current.bucket_mode = next_cfg.bucket_mode
  M.current.recent_days = recent
  M.current.old_days = old
  M.current.curve = next_cfg.curve
  return true, nil
end

function M.reset_view()
  M.current.bucket_mode = M.view_defaults.bucket_mode
  M.current.recent_days = M.view_defaults.recent_days
  M.current.old_days = M.view_defaults.old_days
  M.current.curve = M.view_defaults.curve
end

return M
