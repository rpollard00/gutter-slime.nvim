# gutter-slime

A Neovim plugin that visualizes per-line git recency in the gutter using a theme-aware background gradient.

Brighter gutter cells indicate recently changed lines. Darker cells indicate older changes. The brightness scale uses an adjustable age window, so you can zoom from long-term history down into the last few hours without rerunning blame.

## Features

- Per-line git recency heatmap rendered as a narrow strip in `statuscolumn`
- Theme-aware palette: derives accent and base colours from the active colorscheme
- Adjustable age buckets with curve presets and zoom helpers
- Uncommitted/unsaved line highlighting
- Async git blame with debouncing and caching
- Graceful handling of non-git buffers, diff windows, and special URI buffers

## Requirements

- Neovim >= 0.10
- `git` available in `PATH`

## Installation

No LuaRocks or external plugin dependencies are required.

**lazy.nvim**

```lua
{
  "rpollard00/gutter-slime.nvim",
  config = function()
    require("gutter-slime").setup()
  end,
}
```

## Quick Start

```lua
require("gutter-slime").setup()
```

Run `:checkhealth gutter-slime` to verify the environment.

## Configuration

```lua
require("gutter-slime").setup({
  enabled = true,
  debounce_ms = 150,
  bucket_count = 7,
  recent_days = 0,
  old_days = 180,
  curve = "recent",
  show_uncommitted = true,
  disable_in_diff = true,
  accent_hl = nil,   -- highlight group whose fg drives the bright accent
  debug = false,
})
```

`recent_days` and `old_days` accept Lua numbers as days or strings like `"14"`, `"7d"`, and `"48h"`.

## Commands

| Command | Description |
|---|---|
| `:GutterSlimeEnable` | Enable the heatmap |
| `:GutterSlimeDisable` | Disable the heatmap |
| `:GutterSlimeToggle` | Toggle the heatmap |
| `:GutterSlimeRefresh` | Force a fresh blame run for the current buffer |
| `:GutterSlimeInspect` | Print diagnostic state for the current buffer |
| `:GutterSlimeSetCurve {name}` | Set the active age curve |
| `:GutterSlimeSetOld {value}` | Set the stale edge of the active age window |
| `:GutterSlimeSetRange {recent} {old}` | Set both active age-window endpoints |
| `:GutterSlimeAdjustOld {+/-value}` | Move the stale edge by a duration |
| `:GutterSlimeStepOldNewer` | Step the stale edge toward the present |
| `:GutterSlimeStepOldOlder` | Step the stale edge farther into history |
| `:GutterSlimeZoomIn` | Zoom into more recent history |
| `:GutterSlimeZoomOut` | Zoom out to include older history |
| `:GutterSlimeResetView` | Reset the active age window to setup defaults |

Examples:

```lua
vim.keymap.set("n", "]g", "<cmd>GutterSlimeZoomIn<cr>")
vim.keymap.set("n", "[g", "<cmd>GutterSlimeZoomOut<cr>")
vim.keymap.set("n", "<leader>gr", "<cmd>GutterSlimeSetOld 48h<cr>")
vim.keymap.set("n", "<leader>gl", "<cmd>GutterSlimeSetCurve linear<cr>")
```

## Highlight Groups

The plugin defines `GutterSlimeBucket0` through `GutterSlimeBucketN` (where `N = bucket_count`). `GutterSlimeBucket0` is used for uncommitted lines. Override any of them in your colorscheme config:

```lua
vim.api.nvim_set_hl(0, "GutterSlimeBucket0", { bg = "#ff8800" })
```

## Implementation Phases

- **Phase 0** (complete): Project scaffold, config, commands, health check
- **Phase 1** (complete): Theme-aware bucket palette and gutter rendering
- **Phase 2** (complete): Async `git blame --incremental` for tracked files
- **Phase 3** (complete): Dirty-buffer blame and uncommitted line support
- **Phase 4** (complete): `statuscolumn` strip renderer with window-local attach/detach
- **Phase 5** (current): Release polish, adjustable age mapping, and view controls

## License

MIT
