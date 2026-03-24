-- tests/palette_spec.lua
-- Unit tests for palette highlight group generation.

describe("palette", function()
  local palette

  before_each(function()
    package.loaded["gutter-slime.palette"] = nil
    package.loaded["gutter-slime.config"] = nil
    package.loaded["gutter-slime.util"] = nil
    palette = require("gutter-slime.palette")
    -- Set up minimal config defaults before tests.
    require("gutter-slime.config").setup()
  end)

  it("group_names() is empty before build()", function()
    local groups = palette.group_names()
    assert.equals(0, #groups)
  end)

  it("build() populates group names", function()
    palette.build()
    local groups = palette.group_names()
    assert.is_true(#groups > 0)
  end)

  it("build() creates bucket_count + 1 groups (including uncommitted)", function()
    palette.build()
    local groups = palette.group_names()
    local cfg = require("gutter-slime.config").get()
    -- +1 for the uncommitted bucket (index 0)
    assert.equals(cfg.bucket_count + 1, #groups)
  end)

  it("group_for_bucket(0) returns uncommitted group", function()
    local g = palette.group_for_bucket(0)
    assert.equals("GutterSlimeBucket0", g)
  end)

  it("group_for_bucket(1) returns first committed group", function()
    local g = palette.group_for_bucket(1)
    assert.equals("GutterSlimeBucket1", g)
  end)

  it("group_for_bucket clamps to bucket_count", function()
    palette.build()
    local cfg = require("gutter-slime.config").get()
    local g = palette.group_for_bucket(cfg.bucket_count + 100)
    assert.equals("GutterSlimeBucket" .. cfg.bucket_count, g)
  end)
end)
