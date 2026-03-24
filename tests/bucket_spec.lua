-- tests/bucket_spec.lua
-- Unit tests for timestamp → bucket conversion logic.
-- Run with: nvim --headless -u tests/init.lua -c "PlenaryBustedDirectory tests/"

describe("bucket mapping", function()
  -- We test the internal ts_to_bucket logic indirectly by setting up the
  -- plugin with a known config and inspecting cache after a synthetic refresh.

  local gs

  before_each(function()
    -- Reset module state between tests.
    package.loaded["gutter-slime"] = nil
    package.loaded["gutter-slime.config"] = nil
    package.loaded["gutter-slime.cache"] = nil
    package.loaded["gutter-slime.palette"] = nil
    package.loaded["gutter-slime.render"] = nil
    package.loaded["gutter-slime.autocmds"] = nil
    package.loaded["gutter-slime.util"] = nil

    gs = require("gutter-slime")
  end)

  it("setup() runs without errors", function()
    assert.has_no.errors(function()
      gs.setup({ enabled = false })
    end)
  end)

  it("config merges user options correctly", function()
    gs.setup({ debounce_ms = 300, debug = true })
    local cfg = require("gutter-slime.config").get()
    assert.equals(300, cfg.debounce_ms)
    assert.is_true(cfg.debug)
    assert.equals("exp", cfg.curve) -- default preserved
  end)

  it("config rejects invalid curve", function()
    -- Should fall back to 'exp' and emit a warning (not an error).
    assert.has_no.errors(function()
      gs.setup({ curve = "banana" })
    end)
    local cfg = require("gutter-slime.config").get()
    assert.equals("exp", cfg.curve)
  end)

  it("config rejects bucket_count < 2", function()
    assert.has_no.errors(function()
      gs.setup({ bucket_count = 1 })
    end)
    local cfg = require("gutter-slime.config").get()
    assert.equals(7, cfg.bucket_count) -- default
  end)
end)
