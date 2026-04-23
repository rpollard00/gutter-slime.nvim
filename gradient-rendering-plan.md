# Gradient Rendering Handoff Plan

## Current Repository State

- VCS: jj-vcs.
- Current working change: `vtmykuol` (working-copy commit id will change as this file is edited), described as `feat(palette): add gradient sampling curves`.
- Current working change status: contains this handoff file, `gradient-rendering-plan.md`.
- Parent change: `loypuzly a8b94d7e`, described as `feat(palette): blend gradients in linear color space`.
- Do not revert prior changes and do not push to a remote.
- Continue using `jj describe` for each change description and `jj new` between increments. No staging or committing is needed with jj.

## Completed Increment 1

Description:

```sh
jj describe -m "feat(palette): blend gradients in linear color space"
```

Files changed in that increment:

- `lua/gutter-slime/util.lua`
- `tests/palette_spec.lua`

What changed:

- `util.blend_hex()` now blends colors through linearized sRGB instead of direct sRGB channel interpolation.
- This keeps endpoints exact while making gradient midpoints perceptually brighter and less muddy.
- Added a focused test asserting `#000000` to `#ffffff` at `0.5` samples to `#bcbcbc`, which is expected for linear-light blending.

Verification already run:

```sh
make test
```

Result:

- Full test suite passed.
- Totals observed: blame 14 passed, render 10 passed, palette 17 passed, bucket 20 passed.

## Interrupted Increment 2

Current change:

```sh
jj describe -m "feat(palette): add gradient sampling curves"
```

Status:

- Contains this handoff file, `gradient-rendering-plan.md`.
- No implementation files modified yet in this increment.
- Intended patch was not applied because the harness sandbox failed on file reads and `apply_patch`.

Goal:

Add a separate `gradient.curve` option that affects visual sampling across bucket highlight colors only. This should not change timestamp-to-bucket mapping, which is still controlled by top-level `curve`.

Suggested implementation:

1. Update `lua/gutter-slime/config.lua`:
   - Extend the `GutterSlimeConfig` annotation for `gradient` to include `curve: string`.
   - Add default `gradient.curve = "linear"`.
   - Validate `gradient.curve` in `normalize_gradient()` using the existing `VALID_CURVES` table.
   - Warn with something like `gradient.curve must be one of linear, recent, old, smooth; using default`.

2. Update `lua/gutter-slime/palette.lua`:
   - Add a local `apply_gradient_curve(pos, curve)` helper mirroring the top-level age curves:
     - `linear`: `pos`
     - `recent`: `math.sqrt(pos)`
     - `old`: `pos ^ 1.6`
     - `smooth`: `pos * pos * (3 - 2 * pos)`
   - In `M.build()`, after calculating `pos`, sample the gradient with the curved value:
     - `local curved = util.clamp(apply_gradient_curve(pos, cfg.gradient.curve), 0, 1)`
     - `local bucket_bg = util.sample_hex_gradient(desc.committed_stops, curved)`
   - Preserve exact freshest and oldest endpoints for bucket 1 and bucket N.

3. Update `tests/palette_spec.lua`:
   - Add a test that `config.setup({ gradient = { curve = "recent" } })` stores the setting.
   - Add a custom three-bucket gradient test showing the middle bucket differs between `linear` and `recent` visual curves while bucket 1 and bucket N remain exact endpoints.
   - Add a validation test for an invalid `gradient.curve` falling back to `linear`.

4. Update docs because this is user-facing:
   - `README.md` configuration block: add `curve = "linear"` under `gradient`.
   - `README.md` text: explain that top-level `curve` maps age to buckets, while `gradient.curve` maps buckets to visual color intensity.
   - `doc/gutter-slime.txt`: mirror the configuration and option documentation.

5. Run:

```sh
make test
```

Then start the next increment:

```sh
jj new
```

## Remaining Suggested Increments

### Increment 3: Precompute Statuscolumn Fragments

Suggested jj description:

```sh
jj describe -m "perf(render): cache bucket statuscolumn fragments"
```

Goal:

Avoid allocating the highlight string for every rendered line in `render._stc_line_at()`.

Suggested implementation:

- In `palette.lua`, maintain a table mapping bucket id to the rendered fragment, for example:
  - `0 -> "%#GutterSlimeBucket0# %##"`
  - `1 -> "%#GutterSlimeBucket1# %##"`
- Rebuild this table in `palette.build()`.
- Expose a helper like `palette.fragment_for_bucket(bucket_id)`.
- Change `render._stc_line_at()` to return that fragment instead of constructing it inline.
- Keep `group_for_bucket()` for tests and public-ish internal use.
- Add/update render or palette tests to assert fragments match expected highlight group formatting.

Run `make test`, then `jj new`.

### Increment 4: Safer Statuscolumn Composition

Suggested jj description:

```sh
jj describe -m "feat(render): preserve existing statuscolumn content"
```

Goal:

Reduce conflicts with users who already configure `statuscolumn`.

Suggested implementation options:

- Conservative option: add config `render = { preserve_statuscolumn = true }` or `statuscolumn = { mode = "append" }`.
- Store previous statuscolumn as today, but compose gutter-slime as a suffix/prefix when prior statuscolumn is non-empty.
- Be careful with `%{%...%}` nesting and highlight resets.
- Tests should cover attach/detach preserving an existing non-empty `statuscolumn`.

This is user-facing, so update `README.md` and `doc/gutter-slime.txt`.

Run `make test`, then `jj new`.

### Increment 5: Minimum Contrast Guardrails

Suggested jj description:

```sh
jj describe -m "feat(palette): enforce minimum bucket contrast"
```

Goal:

Prevent theme-derived gradients from becoming indistinguishable against `SignColumn`, `LineNr`, or `Normal` backgrounds.

Suggested implementation:

- Add luminance helpers in `util.lua` or `palette.lua`.
- During palette build, detect adjacent bucket colors with too little luminance delta.
- Apply a small mix adjustment toward the accent or away from base background until each adjacent bucket has a minimum difference.
- Keep custom gradients as user-authored unless a config flag opts into contrast correction.
- Add tests with low-contrast custom or theme-derived colors.

This is user-facing if configurable, so update docs.

Run `make test`.

## Harness Notes

The harness had repeated failures like:

```text
bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted
```

Effects observed:

- Plain `sed`, `rg`, `python3`, and `apply_patch` failed under the sandbox.
- Escalated read-only `sed` worked earlier after approval.
- `apply_patch` failed because it could not read files through the sandbox helper.
- A narrow `perl -0pi` edit command was attempted during the second increment but was interrupted; `jj status` afterward showed no working-copy changes.

When resuming in a healthier harness, prefer `apply_patch` for manual edits again.
