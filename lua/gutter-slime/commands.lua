-- lua/gutter-slime/commands.lua
-- Command implementations.

local M = {}

--- Enable rendering.
function M.enable()
  require("gutter-slime").enable()
end

--- Disable rendering.
function M.disable()
  require("gutter-slime").disable()
end

--- Toggle rendering.
function M.toggle()
  require("gutter-slime").toggle()
end

--- Refresh the current buffer.
function M.refresh()
  require("gutter-slime").refresh()
end

--- Print diagnostic state.
function M.inspect()
  require("gutter-slime").inspect()
end

return M
