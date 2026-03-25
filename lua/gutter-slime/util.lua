-- lua/gutter-slime/util.lua
-- Small shared helpers used across multiple modules.

local M = {}

--- Log a debug message when debug mode is active.
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

--- Log a warning.
---@param msg string
---@param ... any
function M.warn(msg, ...)
  local formatted = select("#", ...) > 0 and string.format(msg, ...) or msg
  vim.notify("[gutter-slime] " .. formatted, vim.log.levels.WARN)
end

--- Log an error.
---@param msg string
---@param ... any
function M.err(msg, ...)
  local formatted = select("#", ...) > 0 and string.format(msg, ...) or msg
  vim.notify("[gutter-slime] " .. formatted, vim.log.levels.ERROR)
end

--- Return current Unix timestamp as an integer.
---@return integer
function M.now()
  return os.time()
end

--- Convert days to seconds.
---@param days number
---@return number
function M.days_to_secs(days)
  return days * 86400
end

--- Check whether a buffer should be considered for heatmap rendering.
--- Returns false for special buffer types, diff windows, and terminals.
---@param bufnr integer
---@return boolean
function M.is_eligible_buffer(bufnr)
  local cfg = require("gutter-slime.config").get()

  -- Only normal file buffers (buftype == "") are eligible.
  local buftype = vim.bo[bufnr].buftype
  if buftype ~= "" then
    return false
  end

  -- Exclude URI-scheme buffers (oil://, fugitive://, etc.). These have
  -- buftype="" but their name contains a scheme and are not real files.
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name:find("^%a[%a%d+%-%.]*://") then
    return false
  end

  -- Unnamed/scratch buffers have nothing to blame.
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

--- Clamp a value between lo and hi.
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

--- Linear interpolation between a and b by t in [0,1].
---@param a number
---@param b number
---@param t number
---@return number
function M.lerp(a, b, t)
  return a + (b - a) * M.clamp(t, 0, 1)
end

--- Parse a hex color string (#rrggbb or #rgb) into r,g,b components [0-255].
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

--- Convert r,g,b components [0-255] to a #rrggbb hex string.
---@param r integer
---@param g integer
---@param b integer
---@return string
function M.rgb_to_hex(r, g, b)
  return string.format("#%02x%02x%02x", r, g, b)
end

--- Blend two #rrggbb hex colors by fraction t (0 = full a, 1 = full b).
---@param a string
---@param b string
---@param t number
---@return string
function M.blend_hex(a, b, t)
  local ar, ag, ab = M.hex_to_rgb(a)
  local br, bg, bb = M.hex_to_rgb(b)
  return M.rgb_to_hex(
    math.floor(M.lerp(ar, br, t) + 0.5),
    math.floor(M.lerp(ag, bg, t) + 0.5),
    math.floor(M.lerp(ab, bb, t) + 0.5)
  )
end

--- Safely get a highlight attribute. Returns nil if the group/key don't exist.
---@param group string
---@param attr "fg"|"bg"
---@return string|nil  hex color or nil
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
