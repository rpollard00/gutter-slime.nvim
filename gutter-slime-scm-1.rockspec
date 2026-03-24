package = "gutter-slime"
version = "scm-1"
source = {
  url = "git+https://github.com/YOUR_USER/gutter-slime.git",
}
description = {
  summary = "Neovim plugin: per-line git recency heatmap in the gutter",
  detailed = [[
    gutter-slime visualizes per-line git recency in the sign column using a
    theme-aware background gradient. Brighter gutter cells indicate recently
    changed lines; darker cells indicate older changes.
  ]],
  homepage = "https://github.com/YOUR_USER/gutter-slime",
  license = "MIT",
}
dependencies = {
  "lua >= 5.1",
}
build = {
  type = "builtin",
  modules = {
    ["gutter-slime"] = "lua/gutter-slime/init.lua",
    ["gutter-slime.config"] = "lua/gutter-slime/config.lua",
    ["gutter-slime.blame"] = "lua/gutter-slime/blame.lua",
    ["gutter-slime.cache"] = "lua/gutter-slime/cache.lua",
    ["gutter-slime.palette"] = "lua/gutter-slime/palette.lua",
    ["gutter-slime.render"] = "lua/gutter-slime/render.lua",
    ["gutter-slime.autocmds"] = "lua/gutter-slime/autocmds.lua",
    ["gutter-slime.commands"] = "lua/gutter-slime/commands.lua",
    ["gutter-slime.util"] = "lua/gutter-slime/util.lua",
    ["gutter-slime.health"] = "lua/gutter-slime/health.lua",
  },
}
