-- lua/gutter-slime/cache.lua
-- Per-buffer blame state store.

local M = {}

---@type table<integer, table>
local _store = {}

local _next_request_id = 0

--- Allocate a fresh request id.
---@param bufnr integer
---@return integer
function M.new_request(bufnr)
  _next_request_id = _next_request_id + 1
  local entry = M._ensure(bufnr)
  entry.request_id = _next_request_id
  return _next_request_id
end

--- Return the current request id.
---@param bufnr integer
---@return integer
function M.current_request(bufnr)
  local entry = _store[bufnr]
  return entry and entry.request_id or 0
end

--- Store blame results if request_id still matches.
---@param bufnr integer
---@param request_id integer
---@param changedtick integer
---@param buckets integer[]
---@param timestamps integer[]
---@return boolean  true if stored, false if stale
function M.store(bufnr, request_id, changedtick, buckets, timestamps)
  local entry = _store[bufnr]
  if not entry or entry.request_id ~= request_id then
    return false
  end
  entry.changedtick = changedtick
  entry.buckets = buckets
  entry.timestamps = timestamps
  return true
end

--- Return the bucket id for a line.
---@param bufnr integer
---@param lnum integer
---@return integer|nil
function M.get_bucket(bufnr, lnum)
  local entry = _store[bufnr]
  if not entry or not entry.buckets then
    return nil
  end
  return entry.buckets[lnum]
end

--- Return the buckets table for bufnr.
---@param bufnr integer
---@return integer[]|nil
function M.get_buckets(bufnr)
  local entry = _store[bufnr]
  return entry and entry.buckets or nil
end

--- Return the timestamp for a line.
---@param bufnr integer
---@param lnum integer
---@return integer|nil
function M.get_timestamp(bufnr, lnum)
  local entry = _store[bufnr]
  if not entry or not entry.timestamps then
    return nil
  end
  return entry.timestamps[lnum]
end

---@param bufnr integer
---@return integer[]|nil
function M.get_timestamps(bufnr)
  local entry = _store[bufnr]
  return entry and entry.timestamps or nil
end

--- Return cached changedtick for bufnr.
---@param bufnr integer
---@return integer|nil
function M.get_changedtick(bufnr)
  local entry = _store[bufnr]
  return entry and entry.changedtick or nil
end

--- Remove buffer state.
---@param bufnr integer
function M.clear_buf(bufnr)
  _store[bufnr] = nil
end

--- Ensure a buffer entry exists.
---@param bufnr integer
---@return table
function M._ensure(bufnr)
  if not _store[bufnr] then
    _store[bufnr] = {
      changedtick = nil,
      request_id = 0,
      buckets = nil,
      timestamps = nil,
    }
  end
  return _store[bufnr]
end

return M
