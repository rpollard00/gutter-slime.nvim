-- lua/gutter-slime/config.lua
-- Default configuration and user-config merging/validation.

local M = {}

local VIEW_KEYS = {
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

---@class GutterSlimeConfig
---@field enabled boolean
---@field debounce_ms integer
---@field bucket_count integer
---@field recent_days number|string
---@field old_days number|string
---@field curve string
---@field show_uncommitted boolean
---@field disable_in_diff boolean
---@field accent_hl string|nil
---@field debug boolean

---@type GutterSlimeConfig
M.defaults = {
  enabled = true,
  debounce_ms = 150,
  bucket_count = 7,
  recent_days = 0,
  old_days = 180,
  curve = "recent",
  show_uncommitted = true,
  disable_in_diff = true,
  accent_hl = nil,
  debug = false,
}

---@type GutterSlimeConfig
M.current = vim.deepcopy(M.defaults)

---@type { recent_days: number, old_days: number, curve: string }
M.view_defaults = {
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
---@param baseline { recent_days: number, old_days: number, curve: string }
local function normalize(cfg, baseline)
  if type(cfg.debounce_ms) ~= "number" or cfg.debounce_ms < 0 then
    notify("debounce_ms must be a non-negative number; using default", vim.log.levels.WARN)
    cfg.debounce_ms = M.defaults.debounce_ms
  end

  if type(cfg.bucket_count) ~= "number" or cfg.bucket_count < 2 then
    notify("bucket_count must be >= 2; using default", vim.log.levels.WARN)
    cfg.bucket_count = M.defaults.bucket_count
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

  cfg.recent_days = recent
  cfg.old_days = old

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
  M.view_defaults = {
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

---@return { recent_days: number, old_days: number, curve: string }
function M.get_view_defaults()
  return vim.deepcopy(M.view_defaults)
end

---@return string[]
function M.curve_names()
  return { "linear", "recent", "old", "smooth" }
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
  if patch.curve ~= nil and (type(next_cfg.curve) ~= "string" or not VALID_CURVES[next_cfg.curve]) then
    return false, "curve must be one of linear, recent, old, smooth"
  elseif type(next_cfg.curve) ~= "string" or not VALID_CURVES[next_cfg.curve] then
    return false, "curve must be one of linear, recent, old, smooth"
  end

  M.current.recent_days = recent
  M.current.old_days = old
  M.current.curve = next_cfg.curve
  return true, nil
end

function M.reset_view()
  M.current.recent_days = M.view_defaults.recent_days
  M.current.old_days = M.view_defaults.old_days
  M.current.curve = M.view_defaults.curve
end

return M
