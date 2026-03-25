# gutter-slime

A Neovim plugin that visualizes per-line git recency in the gutter using a theme-aware background gradient.

Brighter gutter cells indicate recently changed lines. Darker cells indicate older changes. The brightness scale uses absolute age thresholds so the same commit age looks similar across different files and repositories.

## Features

- Per-line git recency heatmap rendered via `signcolumn`
- Theme-aware palette: derives accent and base colours from the active colorscheme
- Absolute age buckets: consistent visual meaning across all buffers and repos
- Uncommitted/unsaved line highlighting
- Async git blame with debouncing and caching
- Graceful handling of non-git buffers and large files

## Requirements

- Neovim >= 0.10

## Installation

**lazy.nvim**

```lua
{
  "YOUR_USER/gutter-slime",
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
  recent_days = 7,
  old_days = 180,
  curve = "exp",
  half_life_days = 3,
  show_uncommitted = true,
  max_file_lines = 20000,
  max_file_bytes = 1024 * 1024,
  disable_in_diff = true,
  disable_in_terminal = true,
  disable_in_large_files = true,
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

The plugin defines `GutterSlimeBucket0` through `GutterSlimeBucketN` (where N = `bucket_count`). Override any of them in your colorscheme config:

```lua
vim.api.nvim_set_hl(0, "GutterSlimeBucket0", { bg = "#ff8800" })
```

## Implementation Phases

- **Phase 0** (complete): Project scaffold, config, commands, health check
- **Phase 1** (complete): Rendering vertical slice with synthetic blame data
- **Phase 2** (complete): Real async git blame for tracked files
- **Phase 3** (planned): Modified buffer and uncommitted line support
- **Phase 4** (planned): Palette refinement and theme robustness
- **Phase 5** (planned): Performance and stability hardening
- **Phase 6** (planned): Documentation and release readiness

## License

MIT
