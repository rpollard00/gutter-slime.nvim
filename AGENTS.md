# AGENTS

## Development Notes

- Neovim plugin root: this repository
- Main runtime modules live under `lua/gutter-slime/`
- User commands are defined in `plugin/gutter-slime.lua`
- Tests live under `tests/`

## Running Tests

- The test suite uses `plenary.nvim` and its busted runner.
- Run all tests from the repo root with `make test`.
- If Plenary is installed outside the default lazy.nvim path, run `make test PLENARY_DIR=/path/to/plenary.nvim`.

## Editing Guidelines

- Keep the plugin dependency-free at runtime.
- Prefer small, direct changes that match existing Lua style.
- Update `README.md` and `doc/gutter-slime.txt` when user-facing behavior changes.
- Add or update tests for behavior changes when practical.
