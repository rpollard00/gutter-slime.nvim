-- plugin/gutter-slime.lua

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
vim.api.nvim_create_user_command("GutterSlimeSetCurve", function(opts)
  require("gutter-slime").set_curve(opts.args)
end, {
  nargs = 1,
  complete = function()
    return require("gutter-slime.config").curve_names()
  end,
  desc = "Set gutter-slime age curve",
})
vim.api.nvim_create_user_command("GutterSlimeSetGradientStyle", function(opts)
  require("gutter-slime").set_gradient_style(opts.args)
end, {
  nargs = 1,
  complete = function()
    return require("gutter-slime.config").gradient_style_names()
  end,
  desc = "Set gutter-slime gradient style",
})
vim.api.nvim_create_user_command("GutterSlimeSetOld", function(opts)
  require("gutter-slime").set_old(opts.args)
end, {
  nargs = 1,
  desc = "Set gutter-slime old_days window edge",
})
vim.api.nvim_create_user_command("GutterSlimeSetRange", function(opts)
  local args = vim.split(vim.trim(opts.args), "%s+", { trimempty = true })
  if #args ~= 2 then
    vim.notify("gutter-slime: GutterSlimeSetRange expects {recent} {old}", vim.log.levels.WARN)
    return
  end
  require("gutter-slime").set_range(args[1], args[2])
end, {
  nargs = "+",
  desc = "Set gutter-slime recent_days and old_days",
})
vim.api.nvim_create_user_command("GutterSlimeAdjustOld", function(opts)
  require("gutter-slime").adjust_old(opts.args)
end, {
  nargs = 1,
  desc = "Adjust gutter-slime old_days by a duration",
})
vim.api.nvim_create_user_command("GutterSlimeStepOldNewer", lazy_cmd("step_old_newer"), {
  desc = "Step gutter-slime old_days toward the present",
})
vim.api.nvim_create_user_command("GutterSlimeStepOldOlder", lazy_cmd("step_old_older"), {
  desc = "Step gutter-slime old_days farther into history",
})
vim.api.nvim_create_user_command("GutterSlimeZoomIn", lazy_cmd("zoom_in"), {
  desc = "Zoom gutter-slime toward recent history",
})
vim.api.nvim_create_user_command("GutterSlimeZoomOut", lazy_cmd("zoom_out"), {
  desc = "Zoom gutter-slime farther into history",
})
vim.api.nvim_create_user_command("GutterSlimeResetView", lazy_cmd("reset_view"), {
  desc = "Reset gutter-slime view to setup defaults",
})
