-- lua/gutter-slime/config.lua
-- Default configuration and user-config merging/validation.

local M = {}

---@class GutterSlimeConfig
---@field enabled boolean
---@field debounce_ms integer
---@field bucket_count integer
---@field old_days number
---@field show_uncommitted boolean
---@field disable_in_diff boolean
---@field accent_hl string|nil
---@field debug boolean

---@type GutterSlimeConfig
M.defaults = {
  enabled = true,
  debounce_ms = 150,
  bucket_count = 7,
  old_days = 180,
  show_uncommitted = true,
  disable_in_diff = true,
  accent_hl = nil,
  debug = false,
}

---@type GutterSlimeConfig
M.current = vim.deepcopy(M.defaults)

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

  if type(M.current.bucket_count) ~= "number" or M.current.bucket_count < 2 then
    vim.notify("gutter-slime: bucket_count must be >= 2; using default", vim.log.levels.WARN)
    M.current.bucket_count = M.defaults.bucket_count
  end

  if type(M.current.old_days) ~= "number" or M.current.old_days <= 0 then
    vim.notify("gutter-slime: old_days must be > 0; using default", vim.log.levels.WARN)
    M.current.old_days = M.defaults.old_days
  end
end

--- Return the active configuration (read-only copy for callers that need safety).
---@return GutterSlimeConfig
function M.get()
  return M.current
end

return M
