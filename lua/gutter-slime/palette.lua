-- lua/gutter-slime/palette.lua
-- Theme-aware highlight group generation.

local M = {}
local util = require("gutter-slime.util")

local _built_groups = {}
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

---@return string
local function resolve_accent()
  local cfg = require("gutter-slime.config").get()

  if cfg.accent_hl then
    local c = util.get_hl_color(cfg.accent_hl, "fg")
    if c then
      return c
    end
  end

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

  return "#7aa2f7"
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

--- Use fixed exponential falloff so bucket brightness keeps a stable meaning
--- across different files and repos.
function M.build()
  local cfg = require("gutter-slime.config").get()
  local n = cfg.bucket_count

  local base_bg = resolve_base_bg()
  local accent = resolve_accent()
  local dark = is_dark_bg()

  _built_groups = {}

  local uncommitted_t = dark and 0.55 or 0.45
  local uncommitted_bg = util.blend_hex(base_bg, accent, uncommitted_t)
  local uncommitted_group = GROUP_PREFIX .. M.BUCKET_UNCOMMITTED
  vim.api.nvim_set_hl(0, uncommitted_group, { bg = uncommitted_bg })
  table.insert(_built_groups, uncommitted_group)

  local HALF_LIVES_ACROSS_RANGE = 2.5
  local max_t = dark and 0.50 or 0.40

  for i = 1, n do
    local pos = (i - 1) / math.max(n - 1, 1)
    local decay = math.exp(-math.log(2) * pos * HALF_LIVES_ACROSS_RANGE)
    local t = decay * max_t
    local bucket_bg = util.blend_hex(base_bg, accent, t)
    local group = GROUP_PREFIX .. i
    vim.api.nvim_set_hl(0, group, { bg = bucket_bg })
    table.insert(_built_groups, group)
  end

  util.debug("palette built: base=%s accent=%s groups=%d", base_bg, accent, #_built_groups)
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

return M
