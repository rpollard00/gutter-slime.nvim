-- lua/gutter-slime/render.lua
-- Heatmap renderer using statuscolumn (window-local).
--
-- Strategy:
--   Each eligible window gets a window-local &statuscolumn expression that
--   appends a single colored cell (one space) at the right edge of the gutter.
--   The cell background is looked up per-line from the cache — no extmarks are
--   written; the statuscolumn expression is evaluated by Neovim on every redraw
--   and calls _stc_line() which does a cache lookup in O(1).
--
-- Public API:
--   attach_win(winid)   -- set statuscolumn on window and record it
--   detach_win(winid)   -- restore previous statuscolumn and unrecord
--   detach_all()        -- detach every tracked window
--   refresh_win(winid)  -- force redraw of a single window (calls nvim_win_call)
--   refresh_buf(bufnr)  -- attach/refresh all windows currently showing bufnr
--   clear_buf(bufnr)    -- detach all windows currently showing bufnr
--   clear_all()         -- alias for detach_all()
--
-- Internal (called from statuscolumn expression per line):
--   _stc_line()         -- returns highlight + space string for the current line

local M = {}

local cache = require("gutter-slime.cache")
local palette = require("gutter-slime.palette")

-- winid -> { prev_stc = string }
local _attached = {}

-- The statuscolumn expression.  Neovim evaluates this once per visible line.
-- %s     = sign column
-- %=%l   = right-aligned line number (respects relativenumber automatically
--          because we use %l/%r via the built-in, but we want %{&nu ? ... : ""}
--          to mirror the default exactly; use %{%...%} for the dynamic part.
-- The heatmap strip is the last element: a Lua call that returns the colored
-- cell string.  We use the outer-%{%...%} form so that the returned string is
-- re-parsed for % items, which lets the function embed %#HlGroup# escapes.
--
-- Default Neovim statuscolumn (when &statuscolumn=="") is roughly:
--   signs | fold | number
-- We replicate the number portion via %{%v:lua.GutterSlimeNum()%} so the user
-- keeps relative/absolute number behavior, then append our strip.
--
-- Simpler and more robust: preserve the user's existing default by NOT touching
-- the number/fold columns and ONLY prepending/appending our strip cell.
-- We build:  <existing default columns>  <our strip>
--
-- The user has no third-party statuscolumn plugin, so &statuscolumn is "" when
-- we attach (Neovim's built-in default).  We reconstruct the default explicitly
-- so we can append our cell:
--
--   %s              sign column
--   %=%{&nu?(&rnu?v:relnum:v:lnum):""} right-aligned line number
--   %{%v:lua.require('gutter-slime.render')._stc_line()%}  heatmap cell
--
-- Note: %* inside %{%...%} causes rendering artefacts; _stc_line() uses
-- %## (reset to Normal) instead to terminate the highlight, which is safe
-- inside re-parsed %{%...%} blocks.

-- The trailing " " after the Lua cell restores the implicit right-padding that
-- Neovim's built-in default gutter provides between the number column and the
-- buffer text.  A custom &statuscolumn removes that padding, so we add it back
-- explicitly as a Normal-highlighted space.
local _STC = "%s%=%{&nu?(&rnu?v:relnum==0?v:lnum:v:relnum:v:lnum):''}"
  .. " %{%v:lua.require('gutter-slime.render')._stc_line()%} "

-- ---------------------------------------------------------------------------
-- Internal: per-line cell renderer (called from statuscolumn expression)
-- ---------------------------------------------------------------------------

--- Called by the statuscolumn expression once per visible line.
--- Must be fast: only a table lookup + string concat.
---@return string  statuscolumn fragment (may contain %#HlGroup# escapes)
function M._stc_line()
  -- v:virtnum != 0 → wrapped continuation line; emit blank, no color.
  if vim.v.virtnum ~= 0 then
    return " "
  end

  local winid = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local lnum = vim.v.lnum

  local bucket = cache.get_bucket(bufnr, lnum)
  if bucket == nil then
    return " "
  end

  local cfg = require("gutter-slime.config").get()
  if bucket == 0 and not cfg.show_uncommitted then
    return " "
  end

  local group = palette.group_for_bucket(bucket)
  -- %#Group# sets the highlight; %## resets to Normal afterward.
  -- The trailing space is the visible cell content.
  return "%#" .. group .. "# %##"
end

-- ---------------------------------------------------------------------------
-- Window attach / detach
-- ---------------------------------------------------------------------------

--- Attach the heatmap statuscolumn to a window.
--- Saves the previous &statuscolumn so it can be restored on detach.
--- Safe to call multiple times on the same window (idempotent).
---@param winid integer
function M.attach_win(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end

  if _attached[winid] then
    -- Already attached; force a redraw to pick up fresh cache data.
    vim.api.nvim_win_call(winid, function()
      vim.cmd("redrawstatus")
    end)
    return
  end

  local prev = vim.wo[winid].statuscolumn
  _attached[winid] = { prev_stc = prev }
  vim.wo[winid].statuscolumn = _STC

  vim.api.nvim_win_call(winid, function()
    vim.cmd("redrawstatus")
  end)

  require("gutter-slime.util").debug("render: attached win=%d", winid)
end

--- Detach the heatmap statuscolumn from a window and restore its previous value.
---@param winid integer
function M.detach_win(winid)
  local rec = _attached[winid]
  if not rec then
    return
  end

  if vim.api.nvim_win_is_valid(winid) then
    vim.wo[winid].statuscolumn = rec.prev_stc
    vim.api.nvim_win_call(winid, function()
      vim.cmd("redrawstatus")
    end)
  end

  _attached[winid] = nil
  require("gutter-slime.util").debug("render: detached win=%d", winid)
end

--- Detach the heatmap statuscolumn from every tracked window.
function M.detach_all()
  -- Iterate over a copy of keys so we can mutate _attached during the loop.
  local wins = {}
  for winid in pairs(_attached) do
    wins[#wins + 1] = winid
  end
  for _, winid in ipairs(wins) do
    M.detach_win(winid)
  end
end

-- ---------------------------------------------------------------------------
-- Buffer-level helpers
-- ---------------------------------------------------------------------------

--- Attach (or refresh) the heatmap on every window currently displaying bufnr.
---@param bufnr integer
function M.refresh_buf(bufnr)
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      M.attach_win(winid)
    end
  end
end

--- Detach the heatmap from every window currently displaying bufnr.
---@param bufnr integer
function M.clear_buf(bufnr)
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      M.detach_win(winid)
    end
  end
  -- Also detach any windows that may now show a different buffer but were
  -- recorded while showing bufnr (handles buffer-switch-without-close).
  -- We don't track bufnr per window here, so a full sweep isn't needed —
  -- the window was already detached above if it still shows bufnr.
end

--- Alias kept for callers that used the old extmark-based API.
function M.clear_all()
  M.detach_all()
end

--- Force a redraw of a specific window.
---@param winid integer
function M.refresh_win(winid)
  if vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_call(winid, function()
      vim.cmd("redrawstatus")
    end)
  end
end

-- ---------------------------------------------------------------------------
-- Compat shims for callers that used the old render() / clear() API
-- ---------------------------------------------------------------------------

--- Old API: render extmarks for bufnr.  Now attaches statuscolumn instead.
---@param bufnr integer
function M.render(bufnr)
  M.refresh_buf(bufnr)
end

--- Old API: clear extmarks for bufnr.  Now detaches statuscolumn.
---@param bufnr integer
function M.clear(bufnr)
  M.clear_buf(bufnr)
end

--- Return the set of currently attached window ids (useful for tests/inspect).
---@return integer[]
function M.attached_wins()
  local wins = {}
  for winid in pairs(_attached) do
    wins[#wins + 1] = winid
  end
  return wins
end

return M
