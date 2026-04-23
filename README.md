# gutter-slime

A Neovim plugin that visualizes per-line git recency in the gutter using a configurable, theme-aware background gradient.

Brighter gutter cells indicate recently changed lines. Darker cells indicate older changes. The brightness scale uses an adjustable age window, so you can zoom from long-term history down into the last few hours without rerunning blame.

## Features

- Per-line git recency heatmap rendered as a narrow strip in `statuscolumn`
- Configurable gradient styles: monotone, vibrant, muted, slime, rainbow, thermal, or custom stops
- Adjustable age buckets with curve presets and zoom helpers
- Uncommitted/unsaved line highlighting
- Composes with an existing non-empty `statuscolumn` expression
- Async git blame with debouncing and caching
- Graceful handling of non-git buffers, diff windows, and special URI buffers

## Requirements

- Neovim >= 0.10
- `git` available in `PATH`

## Installation

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

## Development

The tests use Plenary's busted runner.

- Install `plenary.nvim` somewhere on your runtime path, or let the default `lazy.nvim` path work.
- Run `make test` from the repo root.
- If Plenary is installed elsewhere, run `make test PLENARY_DIR=/path/to/plenary.nvim`.

The default `PLENARY_DIR` is `~/.local/share/nvim/lazy/plenary.nvim`.

## Configuration

```lua
require("gutter-slime").setup({
  enabled = true,
  debounce_ms = 150,
  bucket_count = 16,
  bucket_mode = "absolute", -- absolute | relative_time | relative_quantile
  recent_days = 0,
  old_days = 180,
  curve = "recent",
  relative = {
    curve = "linear",       -- linear | recent | old | smooth
    min_span_days = 0,      -- collapse tiny relative_time spans into the freshest bucket
  },
  show_uncommitted = true,
  disable_in_diff = true,
  accent_hl = nil,   -- legacy alias for gradient.accent_hl
  gradient = {
    style = "monotone", -- monotone | vibrant | muted | slime | rainbow | thermal | custom
    curve = "linear",   -- linear | recent | old | smooth; visual color sampling only
    min_contrast = 4,    -- fallback adjacent bucket luminance gap; 0 disables when explicitly set
    min_contrast_by_style = {
      monotone = 4,
      vibrant = 4,
      muted = 2,
      slime = 4,
      rainbow = 3,
      thermal = 4,
    },
    accent_hl = nil,     -- highlight group whose fg drives theme-based styles
    custom = {
      stops = {},        -- oldest to freshest color stops
      uncommitted = nil, -- optional override for bucket 0
    },
  },
  jj = {
    enabled = true,         -- auto-detect jj repos; set false to disable
    current_change = true,  -- mark lines attributed to jj's current @ commit
    marker = "▌",
    marker_hl = nil,        -- optional highlight group whose fg colors the marker
  },
  debug = false,
})
```

`recent_days`, `old_days`, and `relative.min_span_days` accept Lua numbers as days or strings like `"14"`, `"7d"`, and `"48h"`.

`bucket_mode = "absolute"` uses the top-level `recent_days`, `old_days`, and
`curve` settings. `bucket_mode = "relative_time"` fits buckets to the oldest
and newest committed timestamps in each buffer. `bucket_mode =
"relative_quantile"` fits buckets to the distribution of committed lines in
each buffer, which gives dense clusters more visual detail. Uncommitted lines
stay in bucket 0 in all modes.

The top-level `curve` controls how line ages are assigned to buckets in
absolute mode. `relative.curve` controls relative modes.
`gradient.curve` only controls how those buckets sample the visual color ramp.
`gradient.min_contrast` protects built-in styles from collapsing into
indistinguishable adjacent buckets on low-contrast themes. Built-in styles use
`gradient.min_contrast_by_style` defaults tuned for their luminance range; if
you explicitly set `gradient.min_contrast`, that global value overrides the
style defaults. Custom gradients are rendered as authored.

Jujutsu support is auto-detected and safe for Git-only repositories. When `jj`
is available and the buffer is inside a jj repository using the Git backend,
gutter-slime resolves jj's current `@` id and overlays `jj.marker` on lines
whose Git blame SHA matches that id. Because current jj working-copy changes may
show up in Git blame as the all-zero "not committed yet" SHA, zero-SHA blame
lines are also marked while inside a detected jj repo. The marker foreground is
chosen per bucket from theme/git/diagnostic foregrounds with enough contrast,
falling back to black or white when the theme colors would be unreadable. Set
`jj.marker_hl` to force a specific marker color, or `jj.enabled = false` to skip
all jj detection.

Gradient styles:

- `monotone`: restrained theme-derived fade toward a single accent
- `vibrant`: prefers brighter, more colorful theme foreground groups for the freshest side
- `muted`: softer low-contrast theme-derived gradient
- `slime`: green ooze preset blended against the active gutter/background tone
- `rainbow`: multi-hue arcade gradient blended into the active theme background
- `thermal`: thermal-camera ramp from deep blue through magenta/red/orange/yellow to white
- `custom`: interpolates across `gradient.custom.stops`

For custom gradients, list stops from oldest to freshest. The freshest committed bucket uses the last stop.

Example custom gradient:

```lua
require("gutter-slime").setup({
  gradient = {
    style = "custom",
    curve = "recent",
    custom = {
      stops = { "#16351e", "#2e6f38", "#56b84f", "#b1ff7a" },
      uncommitted = "#d2ff96",
    },
  },
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
| `:GutterSlimeSetBucketMode {name}` | Set the active bucket mode |
| `:GutterSlimeSetCurve {name}` | Set the active age curve |
| `:GutterSlimeSetGradientStyle {name}` | Set the active gradient style |
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
vim.keymap.set("n", "<leader>gm", "<cmd>GutterSlimeSetBucketMode relative_quantile<cr>")
vim.keymap.set("n", "<leader>gs", "<cmd>GutterSlimeSetGradientStyle slime<cr>")
```

## Highlight Groups

The plugin defines `GutterSlimeBucket0` through `GutterSlimeBucketN` (where `N = bucket_count`). `GutterSlimeBucket0` is used for uncommitted lines. When jj current-change markers are enabled, companion groups named like `GutterSlimeBucket1JjCurrent` are used for the marker foreground over the same bucket background. Override any of them in your colorscheme config:

```lua
vim.api.nvim_set_hl(0, "GutterSlimeBucket0", { bg = "#ff8800" })
```

## License

MIT
