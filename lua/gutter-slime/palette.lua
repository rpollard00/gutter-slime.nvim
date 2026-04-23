-- lua/gutter-slime/palette.lua
-- Theme-aware highlight group generation.

local M = {}
local util = require("gutter-slime.util")

local _built_groups = {}
local _built_fragments = {}
local GROUP_PREFIX = "GutterSlimeBucket"

M.BUCKET_UNCOMMITTED = 0

---@return string[]
function M.group_names()
  return vim.deepcopy(_built_groups)
end

---@return string
local function resolve_base_bg()
  for _, hl in ipairs({ "SignColumn", "LineNr", "Normal" }) do
    local c = util.get_hl_color(hl, "bg")
    if c then
      return c
    end
  end
  return "#1e1e2e"
end

---@return boolean
local function is_dark_bg()
  if vim.o.background == "light" then
    return false
  end

  local hex = util.get_hl_color("Normal", "bg")
  if hex then
    local r, g, b = util.hex_to_rgb(hex)
    local lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
    return lum < 0.5
  end

  return true
end

---@param names string[]
---@return string|nil
local function first_fg(names)
  for _, name in ipairs(names) do
    local c = util.get_hl_color(name, "fg")
    if c then
      return c
    end
  end
  return nil
end

---@param cfg table
---@return string
local function resolve_theme_accent(cfg)
  local gradient = cfg.gradient or {}

  if gradient.accent_hl then
    local c = util.get_hl_color(gradient.accent_hl, "fg")
    if c then
      return c
    end
  end

  return first_fg({ "DiagnosticInfo", "Function", "Keyword", "Statement", "Identifier", "Normal" }) or "#7aa2f7"
end

---@param cfg table
---@return string
local function resolve_vibrant_accent(cfg)
  local gradient = cfg.gradient or {}

  if gradient.accent_hl then
    local c = util.get_hl_color(gradient.accent_hl, "fg")
    if c then
      return c
    end
  end

  return first_fg({
    "DiagnosticOk",
    "DiagnosticInfo",
    "DiagnosticHint",
    "Function",
    "String",
    "Keyword",
    "Statement",
    "Identifier",
    "Normal",
  }) or "#8bd5ff"
end

---@param base_bg string
---@param accent string
---@param dark boolean
---@return string[] committed_stops, string uncommitted
local function build_monotone_stops(base_bg, accent, dark)
  local strongest = dark and 0.50 or 0.40
  local freshest = util.blend_hex(base_bg, accent, strongest)
  local mid = util.blend_hex(base_bg, accent, strongest * 0.55)
  local oldest = util.blend_hex(base_bg, accent, strongest * 0.12)
  local uncommitted = util.blend_hex(base_bg, accent, dark and 0.55 or 0.45)
  return { oldest, mid, freshest }, uncommitted
end

---@param base_bg string
---@param accent string
---@param dark boolean
---@return string[] committed_stops, string uncommitted
local function build_vibrant_stops(base_bg, accent, dark)
  local soft = util.blend_hex(base_bg, accent, dark and 0.18 or 0.14)
  local mid = util.blend_hex(base_bg, accent, dark and 0.48 or 0.40)
  local freshest = util.blend_hex(base_bg, accent, dark and 0.80 or 0.68)
  local uncommitted = util.blend_hex(base_bg, accent, dark and 0.90 or 0.78)
  return { soft, mid, freshest }, uncommitted
end

---@param base_bg string
---@param accent string
---@param dark boolean
---@return string[] committed_stops, string uncommitted
local function build_muted_stops(base_bg, accent, dark)
  local soft = util.blend_hex(base_bg, accent, dark and 0.08 or 0.06)
  local mid = util.blend_hex(base_bg, accent, dark and 0.20 or 0.16)
  local freshest = util.blend_hex(base_bg, accent, dark and 0.34 or 0.26)
  local uncommitted = util.blend_hex(base_bg, accent, dark and 0.40 or 0.32)
  return { soft, mid, freshest }, uncommitted
end

---@param base_bg string
---@param dark boolean
---@return string[] committed_stops, string uncommitted
local function build_slime_stops(base_bg, dark)
  local ooze = dark and "#7ef06b" or "#4eab34"
  local soft = util.blend_hex(base_bg, ooze, dark and 0.18 or 0.14)
  local mid = util.blend_hex(base_bg, ooze, dark and 0.42 or 0.34)
  local freshest = util.blend_hex(base_bg, ooze, dark and 0.72 or 0.58)
  local uncommitted = util.blend_hex(base_bg, ooze, dark and 0.84 or 0.70)
  return { soft, mid, freshest }, uncommitted
end

---@param base_bg string
---@param dark boolean
---@return string[] committed_stops, string uncommitted
local function build_rainbow_stops(base_bg, dark)
  local rainbow = dark
      and {
        { color = "#7a63d2", mix = 0.16 },
        { color = "#4d82ff", mix = 0.26 },
        { color = "#38cfff", mix = 0.38 },
        { color = "#59e06f", mix = 0.52 },
        { color = "#f0d85a", mix = 0.68 },
        { color = "#ff84aa", mix = 0.82 },
      }
    or {
      { color = "#8b65c9", mix = 0.12 },
      { color = "#2d87c8", mix = 0.20 },
      { color = "#2ca9c9", mix = 0.30 },
      { color = "#2f9a4f", mix = 0.42 },
      { color = "#d39a30", mix = 0.56 },
      { color = "#d9557f", mix = 0.70 },
    }
  local toned = {}
  for _, stop in ipairs(rainbow) do
    table.insert(toned, util.blend_hex(base_bg, stop.color, stop.mix))
  end
  local uncommitted = util.blend_hex(base_bg, dark and "#ff8fd8" or "#d14ca0", dark and 0.88 or 0.74)
  return toned, uncommitted
end

---@param base_bg string
---@param dark boolean
---@return string[] committed_stops, string uncommitted
local function build_thermal_stops(base_bg, dark)
  local thermal = dark
      and {
        { color = "#1a2e8a", mix = 0.38 },
        { color = "#5c2d91", mix = 0.50 },
        { color = "#a1267b", mix = 0.62 },
        { color = "#d42f4d", mix = 0.74 },
        { color = "#f0672f", mix = 0.84 },
        { color = "#f4b73f", mix = 0.92 },
        { color = "#fff4cf", mix = 0.98 },
      }
    or {
      { color = "#23479a", mix = 0.30 },
      { color = "#6c379b", mix = 0.40 },
      { color = "#ab2d7c", mix = 0.52 },
      { color = "#d43e4e", mix = 0.64 },
      { color = "#ea7440", mix = 0.76 },
      { color = "#efb84f", mix = 0.86 },
      { color = "#fff6db", mix = 0.95 },
    }
  local toned = {}
  for _, stop in ipairs(thermal) do
    table.insert(toned, util.blend_hex(base_bg, stop.color, stop.mix))
  end
  local uncommitted = util.blend_hex(base_bg, dark and "#fffdf2" or "#fffaf0", dark and 1.0 or 0.96)
  return toned, uncommitted
end

---@param cfg table
---@param base_bg string
---@param dark boolean
---@return string[] committed_stops, string uncommitted, string accent
local function resolve_style(cfg, base_bg, dark)
  local style = cfg.gradient.style

  if style == "custom" then
    local stops = vim.deepcopy(cfg.gradient.custom.stops)
    local uncommitted = cfg.gradient.custom.uncommitted or stops[#stops]
    return stops, uncommitted, stops[#stops]
  end

  if style == "slime" then
    local stops, uncommitted = build_slime_stops(base_bg, dark)
    return stops, uncommitted, stops[#stops]
  end

  if style == "rainbow" then
    local stops, uncommitted = build_rainbow_stops(base_bg, dark)
    return stops, uncommitted, stops[#stops]
  end

  if style == "thermal" then
    local stops, uncommitted = build_thermal_stops(base_bg, dark)
    return stops, uncommitted, stops[#stops]
  end

  if style == "vibrant" then
    local accent = resolve_vibrant_accent(cfg)
    local stops, uncommitted = build_vibrant_stops(base_bg, accent, dark)
    return stops, uncommitted, accent
  end

  if style == "muted" then
    local accent = resolve_theme_accent(cfg)
    local stops, uncommitted = build_muted_stops(base_bg, accent, dark)
    return stops, uncommitted, accent
  end

  local accent = resolve_theme_accent(cfg)
  local stops, uncommitted = build_monotone_stops(base_bg, accent, dark)
  return stops, uncommitted, accent
end

---@param pos number
---@param curve string
---@return number
local function apply_gradient_curve(pos, curve)
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

---@param hex string
---@return number
local function luminance(hex)
  local r, g, b = util.hex_to_rgb(hex)
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

---@param colors string[]
---@param base_bg string
---@param min_delta number
local function enforce_bucket_contrast(colors, base_bg, min_delta)
  if min_delta <= 0 then
    return
  end

  local base_lum = luminance(base_bg)
  local fresh_target = base_lum < 128 and "#ffffff" or "#000000"
  if #colors > 0 and math.abs(base_lum - luminance(colors[1])) < min_delta then
    local current = colors[1]
    local best = current
    for step = 1, 10 do
      local candidate = util.blend_hex(current, fresh_target, step / 10)
      best = candidate
      if math.abs(base_lum - luminance(candidate)) >= min_delta then
        break
      end
    end
    colors[1] = best
  end

  for i = 2, #colors do
    local prev_lum = luminance(colors[i - 1])
    local current = colors[i]
    if math.abs(prev_lum - luminance(current)) < min_delta then
      local best = current
      for step = 1, 10 do
        local candidate = util.blend_hex(current, base_bg, step / 10)
        best = candidate
        if math.abs(prev_lum - luminance(candidate)) >= min_delta then
          break
        end
      end
      colors[i] = best
    end
  end
end

---@param cfg table
---@return number
local function resolve_min_contrast(cfg)
  local style = cfg.gradient.style
  local by_style = cfg.gradient.min_contrast_by_style or {}
  if type(by_style[style]) == "number" then
    return by_style[style]
  end
  return cfg.gradient.min_contrast
end

---@return { style: string, curve: string, min_contrast: number, base_bg: string, accent: string, committed_stops: string[], uncommitted: string }|nil
function M.describe()
  local cfg = require("gutter-slime.config").get()
  local base_bg = resolve_base_bg()
  local dark = is_dark_bg()
  local committed_stops, uncommitted, accent = resolve_style(cfg, base_bg, dark)
  return {
    style = cfg.gradient.style,
    curve = cfg.gradient.curve,
    min_contrast = resolve_min_contrast(cfg),
    base_bg = base_bg,
    accent = accent,
    committed_stops = vim.deepcopy(committed_stops),
    uncommitted = uncommitted,
  }
end

function M.build()
  local cfg = require("gutter-slime.config").get()
  local n = cfg.bucket_count
  local desc = M.describe()
  if not desc then
    return
  end

  _built_groups = {}
  _built_fragments = {}

  local uncommitted_group = GROUP_PREFIX .. M.BUCKET_UNCOMMITTED
  vim.api.nvim_set_hl(0, uncommitted_group, { bg = desc.uncommitted })
  table.insert(_built_groups, uncommitted_group)
  _built_fragments[M.BUCKET_UNCOMMITTED] = "%#" .. uncommitted_group .. "# %##"

  local bucket_colors = {}
  for i = 1, n do
    local pos = 1 - ((i - 1) / math.max(n - 1, 1))
    local curved = util.clamp(apply_gradient_curve(pos, cfg.gradient.curve), 0, 1)
    bucket_colors[i] = util.sample_hex_gradient(desc.committed_stops, curved)
  end

  if desc.style ~= "custom" then
    enforce_bucket_contrast(bucket_colors, desc.base_bg, desc.min_contrast)
  end

  for i, bucket_bg in ipairs(bucket_colors) do
    local group = GROUP_PREFIX .. i
    vim.api.nvim_set_hl(0, group, { bg = bucket_bg })
    table.insert(_built_groups, group)
    _built_fragments[i] = "%#" .. group .. "# %##"
  end

  util.debug(
    "palette built: style=%s base=%s accent=%s groups=%d",
    desc.style,
    desc.base_bg,
    desc.accent,
    #_built_groups
  )
end

---@param bucket_id integer
---@return string
function M.group_for_bucket(bucket_id)
  if bucket_id == M.BUCKET_UNCOMMITTED then
    return GROUP_PREFIX .. M.BUCKET_UNCOMMITTED
  end

  local cfg = require("gutter-slime.config").get()
  local clamped = math.max(1, math.min(bucket_id, cfg.bucket_count))
  return GROUP_PREFIX .. clamped
end

---@param bucket_id integer
---@return string
function M.fragment_for_bucket(bucket_id)
  local fragment = _built_fragments[bucket_id]
  if fragment then
    return fragment
  end

  return "%#" .. M.group_for_bucket(bucket_id) .. "# %##"
end

return M
