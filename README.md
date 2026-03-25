# gutter-slime

A Neovim plugin that visualizes per-line git recency in the gutter using a theme-aware background gradient.

Brighter gutter cells indicate recently changed lines. Darker cells indicate older changes. The brightness scale uses absolute age thresholds so the same commit age looks similar across different files and repositories.

## Features

- Per-line git recency heatmap rendered as a narrow strip in `statuscolumn`
- Theme-aware palette: derives accent and base colours from the active colorscheme
- Absolute age buckets: consistent visual meaning across all buffers and repos
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
  old_days = 180,
  show_uncommitted = true,
  disable_in_diff = true,
  accent_hl = nil,   -- highlight group whose fg drives the bright accent
  debug = false,
})
```

## Commands

| Command | Description |
|---|---|
| `:GutterSlimeEnable` | Enable the heatmap |
| `:GutterSlimeDisable` | Disable the heatmap |
| `:GutterSlimeToggle` | Toggle the heatmap |
| `:GutterSlimeRefresh` | Force a fresh blame run for the current buffer |
| `:GutterSlimeInspect` | Print diagnostic state for the current buffer |

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
- **Phase 5** (current): Release polish and documentation cleanup

## License

MIT
