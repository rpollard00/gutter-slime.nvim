# Curve And Zoom Plan

## Goal

Add a configurable age-mapping curve and a discoverable adjustment surface so users can:

- emphasize very recent changes when investigating regressions
- zoom the visible age window inward toward the last few days or hours
- spread bucket resolution across the part of history they care about
- adjust the active view from keymaps without rerunning `git blame`

This feature changes age-to-bucket mapping only. It does not change palette fade behavior.

## Agreed Product Direction

- Keep the current palette generation in `lua/gutter-slime/palette.lua` unchanged.
- Add new controls to the age-mapping logic in `lua/gutter-slime/init.lua`.
- Expose discoverable `GutterSlime*` commands and matching Lua helpers.
- Support sub-day windows so users can zoom into the last `48h`, `12h`, or `1h`.
- In v1, interactive zoom changes only the old edge of the window.
- Keep `recent_days` configurable now, but do not add step helpers for it yet.
- Treat zoom as a session-local view adjustment with a reset back to the configured baseline.

## Mental Model

- `recent_days` is the fresh edge of the visible age window.
- `old_days` is the stale edge of the visible age window.
- Ages `<= recent_days` map to the freshest committed bucket.
- Ages `>= old_days` map to the oldest committed bucket.
- Ages inside the window are normalized and then shaped by `curve` before bucket assignment.

This means zooming in by moving `old_days` closer to the present collapses older history into the oldest bucket and spreads more resolution across recent changes.

## Config Surface

Add these config keys:

```lua
require("gutter-slime").setup({
  recent_days = 0,
  old_days = 180,
  curve = "recent",
})
```

### Duration Input Rules

Both config and commands accept the same duration forms:

- Lua numbers are interpreted as days: `14`, `0.5`
- plain numeric strings are interpreted as days: `"14"`, `"0.5"`
- suffixed day strings: `"7d"`, `"0.5d"`
- suffixed hour strings: `"48h"`, `"2h"`, `"1.5h"`

All accepted values are normalized internally to fractional days.

### Validation Rules

- `bucket_count >= 2`
- `recent_days >= 0`
- `old_days > 0`
- `recent_days < old_days`
- `curve` must be one of the supported presets

Invalid config falls back to defaults with a warning.

## Curve Presets

Initial preset set:

- `linear` - even spacing across the visible window
- `recent` - more separation near the fresh edge
- `old` - more separation near the stale edge
- `smooth` - gentler middle-ground shaping

Default: `recent`

Reason: the main use case is to distinguish very recent edits while bug hunting or reviewing recent churn.

## Mapping Algorithm

Current code maps `age_days / old_days` linearly. Replace that with a windowed mapping:

1. compute line age in seconds
2. convert to fractional days
3. clamp age into `[recent_days, old_days]`
4. normalize to `0..1`
5. apply the selected curve preset
6. map the curved position into committed bucket ids `1..bucket_count`

Special case:

- timestamp `0` remains the uncommitted bucket `0`

## Interactive Adjustment Surface

Add matching command and Lua helper surfaces.

### Commands

- `:GutterSlimeSetCurve {name}`
- `:GutterSlimeSetOld {value}`
- `:GutterSlimeSetRange {recent} {old}`
- `:GutterSlimeAdjustOld {+/-value}`
- `:GutterSlimeStepOldNewer`
- `:GutterSlimeStepOldOlder`
- `:GutterSlimeZoomIn`
- `:GutterSlimeZoomOut`
- `:GutterSlimeResetView`

### Lua Helpers

- `require("gutter-slime").set_curve(name)`
- `require("gutter-slime").set_old(value)`
- `require("gutter-slime").set_range(recent, old)`
- `require("gutter-slime").adjust_old(delta)`
- `require("gutter-slime").step_old_newer()`
- `require("gutter-slime").step_old_older()`
- `require("gutter-slime").zoom_in()`
- `require("gutter-slime").zoom_out()`
- `require("gutter-slime").reset_view()`

### Behavior Notes

- In v1, `zoom_in()` and `zoom_out()` are discoverable aliases around old-edge stepping.
- `recent_days` stays fixed during interactive zoom.
- `reset_view()` restores the baseline set by `setup()` rather than hardcoded defaults.

## Zoom Ladder

Do not use a single fixed step size. Use a curated ladder so zoom steps get tighter as the window gets smaller.

Recommended ladder in days:

```text
180, 120, 90, 60, 30, 21, 14, 10, 7, 5, 3, 2, 1.5, 1,
0.75, 0.5, 0.333, 0.25, 0.167, 0.125, 0.083, 0.042
```

Approximate human-readable equivalents:

- `180d, 120d, 90d, 60d, 30d, 21d, 14d, 10d, 7d, 5d, 3d, 2d`
- `36h, 24h, 18h, 12h, 8h, 6h, 4h, 3h, 2h, 1h`

Minimum zoom floor: `1h`

Expected behavior:

- `zoom_in()` moves `old_days` to the next smaller ladder value
- `zoom_out()` moves `old_days` to the next larger ladder value
- direct setters may still choose values between ladder entries as long as they pass validation

## Performance And Data Flow

Interactive view changes should not rerun `git blame`.

Implementation direction:

- keep storing per-line timestamps in the cache
- add a rebucket-from-cache path that recomputes bucket ids from cached timestamps
- redraw attached windows after rebucketing

This makes curve and zoom adjustments feel instant and keeps keymap-driven exploration cheap.

## State Model

Maintain two layers of view state:

- configured baseline state from `setup()`
- active session view state used for rendering and interactive adjustment

Rules:

- setup seeds both baseline and active state
- interactive commands mutate active state only
- `reset_view()` copies baseline state back into active state

This preserves user defaults while allowing temporary exploration.

## Parsing And UX Notes

- Share one duration parser between config validation and command handling.
- Accept `48h`, `7d`, `0.5d`, `1.5h`, numeric values, and plain numeric strings.
- Command errors should notify and no-op instead of corrupting active state.
- `:GutterSlimeSetCurve` should offer completion for known curve names.
- Inspect output should eventually include the active view window and selected curve.

## Files Expected To Change

- `lua/gutter-slime/config.lua`
- `lua/gutter-slime/init.lua`
- `lua/gutter-slime/cache.lua`
- `plugin/gutter-slime.lua`
- `lua/gutter-slime/health.lua`
- `README.md`
- `doc/gutter-slime.txt`
- `tests/bucket_spec.lua`
- likely a new parser-focused spec, or expanded bucket tests

## Test Plan

Add or update tests for:

- duration parsing for numbers, numeric strings, `d` strings, and `h` strings
- config validation and default fallback behavior
- `recent_days < old_days` enforcement
- sub-day windows such as `48h`, `12h`, and `1h`
- bucket mapping under each curve preset
- zoom ladder movement in both directions
- floor clamping at `1h`
- direct `set_old()` and `adjust_old()` behavior
- rebucketing cached timestamps without starting a new blame request
- `reset_view()` restoring configured baseline values

## Deferred For Later

Not part of the initial implementation:

- sliding the whole window forward or backward by moving both endpoints together
- step helpers for `recent_days`
- user-defined custom curve functions
- changes to palette fade shaping
- per-window view state

## Implementation Order

1. add duration parsing and config validation
2. add active-view state and curve-aware bucket mapping
3. add rebucket-from-cache support
4. add Lua helpers and `GutterSlime*` commands
5. update inspect and health output as needed
6. update README and help docs
7. add tests for parsing, mapping, zoom, and rebucketing
