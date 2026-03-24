-- lua/gutter-slime/blame.lua
-- Async git blame integration. (Phase 2 implementation)
--
-- This module will be responsible for:
--   - Detecting the git repo root for a given buffer path
--   - Determining whether a file is tracked
--   - Spawning async `git blame --incremental` jobs
--   - Parsing incremental blame output into per-line timestamps
--   - Supporting dirty-buffer blame via `--contents -` (stdin)
--
-- Phase 1 Note: This module is a stub. The plugin currently uses synthetic
-- blame data generated in init.lua. Real blame will land in Phase 2.

local M = {}

--- Detect the git repository root for a given file path.
--- Returns nil if the path is not inside a git repo.
---@param path string  absolute file path
---@return string|nil  repo root (directory containing .git)
function M.find_repo_root(path)
  -- Placeholder: will use `git rev-parse --show-toplevel` asynchronously.
  _ = path
  return nil
end

--- Check whether a file is tracked by git.
---@param path string  absolute file path
---@param repo_root string
---@return boolean
function M.is_tracked(path, repo_root)
  _ = path
  _ = repo_root
  return false
end

--- Spawn an async `git blame --incremental` job for a buffer.
--- On completion, calls callback(lines_table) where lines_table is a
--- 1-indexed array of { timestamp = integer, sha = string }.
---@param bufnr integer
---@param path string
---@param repo_root string
---@param dirty boolean  true to feed buffer contents via stdin
---@param request_id integer  used for stale-result rejection
---@param callback fun(result: table|nil)
function M.blame_async(bufnr, path, repo_root, dirty, request_id, callback)
  _ = bufnr
  _ = path
  _ = repo_root
  _ = dirty
  _ = request_id
  -- Stub: immediately call callback with nil to signal no data.
  vim.schedule(function()
    callback(nil)
  end)
end

return M
