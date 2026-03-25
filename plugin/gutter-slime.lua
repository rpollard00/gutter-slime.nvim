-- plugin/gutter-slime.lua
-- Lightweight bootstrap.

if vim.g.loaded_gutter_slime == 1 then
  return
end
vim.g.loaded_gutter_slime = 1

-- Require Neovim >= 0.10.
if vim.fn.has("nvim-0.10") == 0 then
  vim.notify("gutter-slime requires Neovim >= 0.10", vim.log.levels.WARN)
  return
end

-- Expose commands immediately so lazy loaders can trigger setup via command.
local function lazy_cmd(action)
  return function(opts)
    require("gutter-slime")[action](opts)
  end
end

vim.api.nvim_create_user_command("GutterSlimeEnable", lazy_cmd("enable"), { desc = "Enable gutter-slime" })
vim.api.nvim_create_user_command("GutterSlimeDisable", lazy_cmd("disable"), { desc = "Disable gutter-slime" })
vim.api.nvim_create_user_command("GutterSlimeToggle", lazy_cmd("toggle"), { desc = "Toggle gutter-slime" })
vim.api.nvim_create_user_command("GutterSlimeRefresh", lazy_cmd("refresh"), { desc = "Refresh gutter-slime for current buffer" })
vim.api.nvim_create_user_command("GutterSlimeInspect", lazy_cmd("inspect"), { desc = "Inspect gutter-slime state for current buffer" })
