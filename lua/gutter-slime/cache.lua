-- lua/gutter-slime/cache.lua
-- Per-buffer blame state store.
--
-- Schema for a buffer entry:
--   {
--     changedtick  = integer,   -- vim.b.changedtick at time of last successful blame
--     request_id   = integer,   -- monotonically incrementing id to drop stale results
--     buckets      = integer[], -- 1-indexed, bucket id per line (0 = uncommitted)
--     timestamps   = integer[], -- 1-indexed, unix timestamp per line (0 = uncommitted)
--   }

local M = {}

---@type table<integer, table>  bufnr -> entry
local _store = {}

local _next_request_id = 0

--- Allocate a fresh request id for bufnr and return it.
--- Callers should pass this id when storing results and check it on arrival.
---@param bufnr integer
---@return integer
function M.new_request(bufnr)
  _next_request_id = _next_request_id + 1
  local entry = M._ensure(bufnr)
  entry.request_id = _next_request_id
  return _next_request_id
end

--- Return the current outstanding request id for bufnr (or 0 if none).
---@param bufnr integer
---@return integer
function M.current_request(bufnr)
  local entry = _store[bufnr]
  return entry and entry.request_id or 0
end

--- Store blame results for bufnr, but only if request_id matches the outstanding one.
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

--- Return the bucket id for line lnum (1-indexed) in bufnr, or nil if no data.
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

--- Return the full buckets table for bufnr, or nil if no data.
---@param bufnr integer
---@return integer[]|nil
function M.get_buckets(bufnr)
  local entry = _store[bufnr]
  return entry and entry.buckets or nil
end

--- Return the timestamp for line lnum (1-indexed) in bufnr, or nil.
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

--- Return cached changedtick for bufnr, or nil.
---@param bufnr integer
---@return integer|nil
function M.get_changedtick(bufnr)
  local entry = _store[bufnr]
  return entry and entry.changedtick or nil
end

--- Remove all state for a buffer (called on BufUnload).
---@param bufnr integer
function M.clear_buf(bufnr)
  _store[bufnr] = nil
end

--- Remove all state for all buffers.
function M.clear_all()
  _store = {}
end

--- Internal: ensure entry exists for bufnr, return it.
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
