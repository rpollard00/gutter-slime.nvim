-- lua/gutter-slime/health.lua
-- :checkhealth gutter-slime implementation.

local M = {}

--- Run health checks.
function M.check()
  local h = vim.health

  h.start("gutter-slime")

  if vim.fn.has("nvim-0.10") == 1 then
    h.ok("Neovim >= 0.10 detected")
  else
    h.error("Neovim >= 0.10 is required")
  end

  local git = vim.fn.exepath("git")
  if git ~= "" then
    local ver = vim.fn.system("git --version 2>&1")
    h.ok("git found: " .. ver:gsub("\n", ""))
  else
    h.error("git not found in PATH; blame functionality will not work")
  end

  if vim.fn.exists("&statuscolumn") == 1 then
    h.ok("'statuscolumn' option is available")
  else
    h.error("'statuscolumn' option is not available; rendering will not work")
  end

  local cfg = require("gutter-slime.config").get()
  if cfg.enabled then
    h.ok("plugin is enabled")
  else
    h.warn("plugin is disabled (enabled=false in config)")
  end

  if cfg.debug then
    h.warn("debug mode is active; extra notifications will appear")
  else
    h.ok("debug mode is off")
  end

  local palette = require("gutter-slime.palette")
  local groups = palette.group_names()
  if #groups > 0 then
    h.ok(string.format("palette has %d highlight groups defined", #groups))
  else
    h.warn("palette has not been built yet; call setup() or open a file")
  end
end

return M
