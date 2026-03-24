-- tests/init.lua
-- Test harness bootstrap for busted.
-- Add the plugin root to the Lua path so specs can require() plugin modules.

local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")

-- Ensure lua/ subdirectory is on the path.
package.path = package.path
  .. ";"
  .. plugin_root
  .. "/lua/?.lua"
  .. ";"
  .. plugin_root
  .. "/lua/?/init.lua"
