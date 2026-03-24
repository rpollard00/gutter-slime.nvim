-- lua/gutter-slime/commands.lua
-- User-facing command implementations. The actual vim.api.nvim_create_user_command
-- calls live in plugin/gutter-slime.lua so they are available immediately at
-- startup. This module provides the implementations that those stubs call into.

local M = {}

--- Enable heatmap rendering for the current buffer (or globally).
function M.enable()
  require("gutter-slime").enable()
end

--- Disable heatmap rendering for the current buffer (or globally).
function M.disable()
  require("gutter-slime").disable()
end

--- Toggle heatmap rendering.
function M.toggle()
  require("gutter-slime").toggle()
end

--- Force a fresh blame + re-render for the current buffer.
function M.refresh()
  require("gutter-slime").refresh()
end

--- Print diagnostic information about the current buffer's heatmap state.
function M.inspect()
  require("gutter-slime").inspect()
end

return M
