-- lua/gutter-slime/util.lua
-- Small shared helpers used across multiple modules.

local M = {}

--- Log a debug message.
---@param msg string
---@param ... any
function M.debug(msg, ...)
  local cfg = require("gutter-slime.config").get()
  if not cfg.debug then
    return
  end
  local formatted = select("#", ...) > 0 and string.format(msg, ...) or msg
  vim.notify("[gutter-slime] " .. formatted, vim.log.levels.DEBUG)
end

--- Check whether a buffer should be rendered.
---@param bufnr integer
---@return boolean
function M.is_eligible_buffer(bufnr)
  local cfg = require("gutter-slime.config").get()

  local buftype = vim.bo[bufnr].buftype
  if buftype ~= "" then
    return false
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name:find("^%a[%a%d+%-%.]*://") then
    return false
  end

  if name == "" then
    return false
  end

  if cfg.disable_in_diff then
    for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
      if vim.wo[winid].diff then
        return false
      end
    end
  end

  return true
end

--- Clamp a value.
---@param v number
---@param lo number
---@param hi number
---@return number
function M.clamp(v, lo, hi)
  if v < lo then
    return lo
  end
  if v > hi then
    return hi
  end
  return v
end

--- Linearly interpolate between two values.
---@param a number
---@param b number
---@param t number
---@return number
function M.lerp(a, b, t)
  return a + (b - a) * M.clamp(t, 0, 1)
end

--- Parse a hex color string.
---@param hex string
---@return integer, integer, integer
function M.hex_to_rgb(hex)
  hex = hex:gsub("^#", "")
  if #hex == 3 then
    local r = tonumber(hex:sub(1, 1), 16) or 0
    local g = tonumber(hex:sub(2, 2), 16) or 0
    local b = tonumber(hex:sub(3, 3), 16) or 0
    return r * 17, g * 17, b * 17
  end
  local r = tonumber(hex:sub(1, 2), 16) or 0
  local g = tonumber(hex:sub(3, 4), 16) or 0
  local b = tonumber(hex:sub(5, 6), 16) or 0
  return r, g, b
end

--- Convert RGB to hex.
---@param r integer
---@param g integer
---@param b integer
---@return string
function M.rgb_to_hex(r, g, b)
  return string.format("#%02x%02x%02x", r, g, b)
end

---@param channel integer
---@return number
local function srgb_to_linear(channel)
  local c = M.clamp(channel, 0, 255) / 255
  if c <= 0.04045 then
    return c / 12.92
  end
  return ((c + 0.055) / 1.055) ^ 2.4
end

---@param value number
---@return integer
local function linear_to_srgb(value)
  local c = M.clamp(value, 0, 1)
  if c <= 0.0031308 then
    c = c * 12.92
  else
    c = 1.055 * (c ^ (1 / 2.4)) - 0.055
  end
  return math.floor((c * 255) + 0.5)
end

--- Blend two hex colors.
---@param a string
---@param b string
---@param t number
---@return string
function M.blend_hex(a, b, t)
  local ar, ag, ab = M.hex_to_rgb(a)
  local br, bg, bb = M.hex_to_rgb(b)
  return M.rgb_to_hex(
    linear_to_srgb(M.lerp(srgb_to_linear(ar), srgb_to_linear(br), t)),
    linear_to_srgb(M.lerp(srgb_to_linear(ag), srgb_to_linear(bg), t)),
    linear_to_srgb(M.lerp(srgb_to_linear(ab), srgb_to_linear(bb), t))
  )
end

--- Normalize a hex color string.
---@param hex string
---@return string|nil
function M.normalize_hex(hex)
  if type(hex) ~= "string" then
    return nil
  end

  local trimmed = vim.trim(hex)
  local short = trimmed:match("^#?(%x%x%x)$")
  if short then
    local r = short:sub(1, 1)
    local g = short:sub(2, 2)
    local b = short:sub(3, 3)
    return string.format("#%s%s%s%s%s%s", r, r, g, g, b, b):lower()
  end

  local full = trimmed:match("^#?(%x%x%x%x%x%x)$")
  if full then
    return ("#" .. full):lower()
  end

  return nil
end

--- Check whether a value is a valid hex color.
---@param hex any
---@return boolean
function M.is_hex_color(hex)
  return M.normalize_hex(hex) ~= nil
end

--- Sample a multi-stop gradient at position t.
---@param stops string[]
---@param t number
---@return string
function M.sample_hex_gradient(stops, t)
  if #stops == 0 then
    return "#000000"
  end
  if #stops == 1 then
    return stops[1]
  end

  local pos = M.clamp(t, 0, 1) * (#stops - 1)
  local idx = math.floor(pos) + 1
  if idx >= #stops then
    return stops[#stops]
  end

  local local_t = pos - math.floor(pos)
  return M.blend_hex(stops[idx], stops[idx + 1], local_t)
end

--- Get a highlight color.
---@param group string
---@param attr "fg"|"bg"
---@return string|nil
function M.get_hl_color(group, attr)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
  if not ok or not hl then
    return nil
  end
  local key = attr == "fg" and "fg" or "bg"
  local val = hl[key]
  if not val or val == -1 then
    return nil
  end
  return string.format("#%06x", val)
end

return M
