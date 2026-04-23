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

  h.ok(string.format("view window: recent_days=%.3f old_days=%.3f curve=%s", cfg.recent_days, cfg.old_days, cfg.curve))
  h.ok(string.format("gradient style: %s", cfg.gradient.style))

  if cfg.jj.enabled then
    local jj = vim.fn.exepath("jj")
    if jj == "" then
      h.ok("jj integration enabled but jj not found; integration will stay inactive")
    else
      h.ok("jj found: " .. jj)
      vim.fn.system("jj root 2>&1")
      if vim.v.shell_error ~= 0 then
        h.ok("current directory is not a jj repo; jj integration will stay inactive")
      else
        local commit_id = vim.fn.system("jj log -r @ --no-graph -T commit_id 2>&1"):match("([0-9a-fA-F]+)")
        if vim.v.shell_error == 0 and commit_id and #commit_id == 40 then
          if commit_id:match("^0+$") then
            h.ok("jj current @ resolves to Git zero SHA; zero-SHA blame lines will be marked")
          else
            h.ok("jj current @ id resolved: " .. commit_id:sub(1, 12))
            h.ok("zero-SHA blame lines in this jj repo will also be marked as current changes")
          end
        else
          h.warn("jj repo detected, but current @ did not resolve to a 40-character id")
        end
      end
    end
  else
    h.ok("jj integration is disabled")
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
