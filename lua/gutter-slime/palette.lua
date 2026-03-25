-- lua/gutter-slime/palette.lua
-- Theme-aware highlight group generation.
--
-- Highlight group naming convention:
--   GutterSlimeBucket0  -> uncommitted lines (brightest / most saturated)
--   GutterSlimeBucket1  -> most recent committed bucket
--   GutterSlimeBucketN  -> oldest bucket (near-invisible, blends into gutter)
--
-- The palette rebuilds on ColorScheme autocommand (wired in autocmds.lua).

local M = {}
local util = require("gutter-slime.util")

-- Cache of last-built group names so health.lua can inspect them.
local _built_groups = {}

-- Prefix for all highlight groups this plugin owns.
local GROUP_PREFIX = "GutterSlimeBucket"

-- Special bucket index for uncommitted lines.
M.BUCKET_UNCOMMITTED = 0

--- Return list of currently-defined group names (for health checks).
---@return string[]
function M.group_names()
  return vim.deepcopy(_built_groups)
end

--- Resolve the gutter base background colour.
--- Tries SignColumn → LineNr → Normal → hardcoded fallback.
---@return string  hex colour
local function resolve_base_bg()
  for _, hl in ipairs({ "SignColumn", "LineNr", "Normal" }) do
    local c = util.get_hl_color(hl, "bg")
    if c then
      return c
    end
  end
  -- Absolute fallback: assume dark background.
  return "#1e1e2e"
end

--- Resolve an accent colour from the theme.
--- Priority: user-configured accent_hl → DiagnosticInfo fg → Function fg →
---           Keyword fg → conservative neutral.
---@return string  hex colour
local function resolve_accent()
  local cfg = require("gutter-slime.config").get()

  if cfg.accent_hl then
    local c = util.get_hl_color(cfg.accent_hl, "fg")
    if c then
      return c
    end
  end

  -- Ordered list of candidate highlight groups for accent derivation.
  local candidates = {
    { "DiagnosticInfo", "fg" },
    { "Function", "fg" },
    { "Keyword", "fg" },
    { "Statement", "fg" },
    { "Identifier", "fg" },
    { "Normal", "fg" },
  }

  for _, pair in ipairs(candidates) do
    local c = util.get_hl_color(pair[1], pair[2])
    if c then
      return c
    end
  end

  -- Fallback: a neutral blue-grey that reads on both dark and light.
  return "#7aa2f7"
end

--- Determine whether the theme background is "dark" or "light".
---@return boolean  true if dark
local function is_dark_bg()
  local bg = vim.o.background
  if bg == "light" then
    return false
  end
  -- Heuristic: check Normal bg luminance.
  local hex = util.get_hl_color("Normal", "bg")
  if hex then
    local r, g, b = util.hex_to_rgb(hex)
    -- Perceived luminance (BT.709)
    local lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
    return lum < 0.5
  end
  return true
end

--- Build all bucket highlight groups from the current theme.
--- Safe to call multiple times; always overwrites.
function M.build()
  local cfg = require("gutter-slime.config").get()
  local n = cfg.bucket_count -- number of committed buckets (1..n)

  local base_bg = resolve_base_bg()
  local accent = resolve_accent()
  local dark = is_dark_bg()

  _built_groups = {}

  -- Uncommitted bucket: slightly more vivid than bucket 1.
  -- Blend accent with base using a factor slightly above the freshest bucket.
  local uncommitted_t = dark and 0.55 or 0.45
  local uncommitted_bg = util.blend_hex(base_bg, accent, uncommitted_t)
  local uncommitted_group = GROUP_PREFIX .. M.BUCKET_UNCOMMITTED
  vim.api.nvim_set_hl(0, uncommitted_group, { bg = uncommitted_bg })
  table.insert(_built_groups, uncommitted_group)

  -- Committed buckets 1..n: bucket 1 is freshest (most accent), bucket n is
  -- oldest (closest to base_bg).
  --
  -- The blend fraction uses an exponential curve driven purely by the
  -- normalised bucket position [0, 1]. We span a fixed number of half-lives
  -- across the full bucket range so the curve is always visually spread out
  -- regardless of the actual day values in config.
  --
  -- HALF_LIVES_ACROSS_RANGE controls how steeply brightness falls off.
  -- 2.5 half-lives means bucket n has ~18% of bucket 1's blend value —
  -- visible but clearly dimmer. Increase for a steeper drop-off.
  local HALF_LIVES_ACROSS_RANGE = 2.5
  local max_t = dark and 0.50 or 0.40 -- blend fraction for bucket 1 (freshest)

  for i = 1, n do
    -- Normalised position: 0 = freshest (bucket 1), 1 = oldest (bucket n).
    local pos = (i - 1) / math.max(n - 1, 1)
    -- Exponential decay across the bucket range.
    local decay = math.exp(-math.log(2) * pos * HALF_LIVES_ACROSS_RANGE)
    local t = decay * max_t
    local bucket_bg = util.blend_hex(base_bg, accent, t)
    local group = GROUP_PREFIX .. i
    vim.api.nvim_set_hl(0, group, { bg = bucket_bg })
    table.insert(_built_groups, group)
  end

  util.debug("palette built: base=%s accent=%s groups=%d", base_bg, accent, #_built_groups)
end

--- Return the highlight group name for bucket id.
--- bucket_id == 0  → uncommitted
--- bucket_id >= 1  → committed bucket (clamped to bucket_count)
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

return M
