-- lua/gutter-slime/config.lua
-- Default configuration and user-config merging/validation.

local M = {}

---@class GutterSlimeConfig
---@field enabled boolean
---@field debounce_ms integer
---@field bucket_count integer
---@field recent_days number
---@field old_days number
---@field curve "exp"|"linear"|"logistic"
---@field half_life_days number
---@field show_uncommitted boolean
---@field max_file_lines integer
---@field max_file_bytes integer
---@field disable_in_diff boolean
---@field disable_in_terminal boolean
---@field disable_in_large_files boolean
---@field accent_hl string|nil
---@field debug boolean

---@type GutterSlimeConfig
M.defaults = {
  enabled = true,
  debounce_ms = 150,
  bucket_count = 7,
  recent_days = 7,
  old_days = 180,
  curve = "exp",
  half_life_days = 3,
  show_uncommitted = true,
  max_file_lines = 20000,
  max_file_bytes = 1024 * 1024,
  disable_in_diff = true,
  disable_in_terminal = true,
  disable_in_large_files = true,
  accent_hl = nil,
  debug = false,
}

---@type GutterSlimeConfig
M.current = vim.deepcopy(M.defaults)

local VALID_CURVES = { exp = true, linear = true, logistic = true }

--- Merge user-supplied options into the active config, validating key types.
---@param opts table|nil
function M.setup(opts)
  if opts == nil then
    M.current = vim.deepcopy(M.defaults)
    return
  end

  if type(opts) ~= "table" then
    vim.notify("gutter-slime: setup() expects a table or nil", vim.log.levels.ERROR)
    return
  end

  M.current = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)

  -- Validate a handful of important fields.
  if type(M.current.debounce_ms) ~= "number" or M.current.debounce_ms < 0 then
    vim.notify("gutter-slime: debounce_ms must be a non-negative number; using default", vim.log.levels.WARN)
    M.current.debounce_ms = M.defaults.debounce_ms
  end

  if not VALID_CURVES[M.current.curve] then
    vim.notify(
      string.format("gutter-slime: unknown curve %q; using 'exp'", tostring(M.current.curve)),
      vim.log.levels.WARN
    )
    M.current.curve = "exp"
  end

  if type(M.current.bucket_count) ~= "number" or M.current.bucket_count < 2 then
    vim.notify("gutter-slime: bucket_count must be >= 2; using default", vim.log.levels.WARN)
    M.current.bucket_count = M.defaults.bucket_count
  end
end

--- Return the active configuration (read-only copy for callers that need safety).
---@return GutterSlimeConfig
function M.get()
  return M.current
end

return M
