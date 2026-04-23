-- tests/palette_spec.lua
-- Unit tests for palette highlight group generation.

describe("palette", function()
  local palette
  local config

  before_each(function()
    package.loaded["gutter-slime.palette"] = nil
    package.loaded["gutter-slime.config"] = nil
    package.loaded["gutter-slime.util"] = nil
    palette = require("gutter-slime.palette")
    config = require("gutter-slime.config")
    -- Set up minimal config defaults before tests.
    config.setup()
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
    local cfg = config.get()
    local g = palette.group_for_bucket(cfg.bucket_count + 100)
    assert.equals("GutterSlimeBucket" .. cfg.bucket_count, g)
  end)

  it("fragment_for_bucket() returns cached statuscolumn highlight fragments", function()
    palette.build()

    assert.equals("%#GutterSlimeBucket0# %##", palette.fragment_for_bucket(0))
    assert.equals("%#GutterSlimeBucket1# %##", palette.fragment_for_bucket(1))
  end)

  it("fragment_for_bucket() clamps committed buckets", function()
    config.setup({ bucket_count = 3 })
    palette.build()

    assert.equals("%#GutterSlimeBucket3# %##", palette.fragment_for_bucket(100))
  end)

  it("defaults to monotone gradient style", function()
    local desc = palette.describe()
    assert.equals("monotone", desc.style)
    assert.equals("linear", desc.curve)
    assert.equals(8, desc.min_contrast)
    assert.equals(3, #desc.committed_stops)
  end)

  it("stores a separate gradient sampling curve", function()
    config.setup({ gradient = { curve = "recent" } })
    local desc = palette.describe()

    assert.equals("recent", desc.curve)
    assert.equals("recent", config.get().gradient.curve)
  end)

  it("falls back to linear for invalid gradient curves", function()
    config.setup({ gradient = { curve = "invalid" } })

    assert.equals("linear", config.get().gradient.curve)
  end)

  it("falls back to default minimum contrast for invalid values", function()
    config.setup({ gradient = { min_contrast = -1 } })

    assert.equals(8, config.get().gradient.min_contrast)
  end)

  it("supports vibrant, muted, slime, rainbow, and thermal preset styles", function()
    for _, style in ipairs({ "vibrant", "muted", "slime", "rainbow", "thermal" }) do
      config.setup({ gradient = { style = style } })
      local desc = palette.describe()
      assert.equals(style, desc.style)
      assert.is_true(#desc.committed_stops > 0)
      assert.is_truthy(desc.uncommitted:match("^#%x%x%x%x%x%x$"))
    end
  end)

  it("rainbow preset exposes multiple distinct stops", function()
    config.setup({ gradient = { style = "rainbow" } })
    local desc = palette.describe()
    assert.is_true(#desc.committed_stops >= 6)
    assert.not_equals(desc.committed_stops[1], desc.committed_stops[#desc.committed_stops])
  end)

  it("rainbow preset ramps luminosity toward fresher buckets", function()
    config.setup({ gradient = { style = "rainbow" } })
    local desc = palette.describe()

    local function luminance(hex)
      local r, g, b = require("gutter-slime.util").hex_to_rgb(hex)
      return 0.2126 * r + 0.7152 * g + 0.0722 * b
    end

    assert.is_true(luminance(desc.committed_stops[1]) < luminance(desc.committed_stops[#desc.committed_stops]))
  end)

  it("thermal preset runs blue to white without green midpoints", function()
    config.setup({ gradient = { style = "thermal" } })
    local desc = palette.describe()

    assert.is_true(#desc.committed_stops >= 7)
    assert.is_truthy(desc.accent:match("^#%x%x%x%x%x%x$"))
    local r, g, b = require("gutter-slime.util").hex_to_rgb(desc.accent)
    assert.is_true(r >= 240 and g >= 230 and b >= 190)
    assert.not_equals(desc.committed_stops[1], desc.committed_stops[#desc.committed_stops])
  end)

  it("maps freshest bucket to freshest stop and oldest bucket to oldest stop", function()
    config.setup({ bucket_count = 3, gradient = { style = "custom", custom = { stops = { "#111111", "#777777", "#fefefe" } } } })
    palette.build()

    local oldest = vim.api.nvim_get_hl(0, { name = "GutterSlimeBucket3", link = false }).bg
    local freshest = vim.api.nvim_get_hl(0, { name = "GutterSlimeBucket1", link = false }).bg

    assert.equals(0x111111, oldest)
    assert.equals(0xfefefe, freshest)
  end)

  it("applies gradient curve without changing endpoint buckets", function()
    config.setup({
      bucket_count = 3,
      gradient = {
        style = "custom",
        curve = "recent",
        custom = { stops = { "#000000", "#777777", "#ffffff" } },
      },
    })
    palette.build()

    local oldest = vim.api.nvim_get_hl(0, { name = "GutterSlimeBucket3", link = false }).bg
    local middle = vim.api.nvim_get_hl(0, { name = "GutterSlimeBucket2", link = false }).bg
    local freshest = vim.api.nvim_get_hl(0, { name = "GutterSlimeBucket1", link = false }).bg

    assert.equals(0x000000, oldest)
    assert.equals(0xffffff, freshest)
    assert.not_equals(0x777777, middle)
  end)

  it("enforces minimum contrast for built-in gradients", function()
    vim.api.nvim_set_hl(0, "SignColumn", { bg = "#000000" })
    vim.api.nvim_set_hl(0, "LineNr", { bg = "#000000" })
    vim.api.nvim_set_hl(0, "Normal", { bg = "#000000" })
    vim.api.nvim_set_hl(0, "DiagnosticInfo", { fg = "#202020" })

    config.setup({
      bucket_count = 2,
      gradient = {
        style = "monotone",
        min_contrast = 20,
        accent_hl = "DiagnosticInfo",
      },
    })
    palette.build()

    local freshest = vim.api.nvim_get_hl(0, { name = "GutterSlimeBucket1", link = false }).bg
    local oldest = vim.api.nvim_get_hl(0, { name = "GutterSlimeBucket2", link = false }).bg

    local function luminance(rgb)
      local r = math.floor(rgb / 0x10000) % 0x100
      local g = math.floor(rgb / 0x100) % 0x100
      local b = rgb % 0x100
      return 0.2126 * r + 0.7152 * g + 0.0722 * b
    end

    assert.is_true(math.abs(luminance(freshest) - luminance(oldest)) >= 20)
  end)

  it("uses custom gradient stops and uncommitted override", function()
    config.setup({
      gradient = {
        style = "custom",
        custom = {
          stops = { "#102030", "#405060", "#708090" },
          uncommitted = "#a0b0c0",
        },
      },
    })

    local desc = palette.describe()
    assert.equals("custom", desc.style)
    assert.same({ "#102030", "#405060", "#708090" }, desc.committed_stops)
    assert.equals("#a0b0c0", desc.uncommitted)
  end)

  it("normalizes short custom hex colors", function()
    config.setup({
      gradient = {
        style = "custom",
        custom = {
          stops = { "#123", "456", "#789abc" },
          uncommitted = "abc",
        },
      },
    })

    local cfg = config.get()
    assert.same({ "#112233", "#445566", "#789abc" }, cfg.gradient.custom.stops)
    assert.equals("#aabbcc", cfg.gradient.custom.uncommitted)
  end)

  it("falls back to monotone when custom style has no valid stops", function()
    config.setup({ gradient = { style = "custom", custom = { stops = { "nope" } } } })
    assert.equals("monotone", config.get().gradient.style)
  end)

  it("maps legacy accent_hl into gradient accent_hl", function()
    config.setup({ accent_hl = "Function" })
    assert.equals("Function", config.get().gradient.accent_hl)
  end)

  it("samples gradients in linear color space", function()
    local util = require("gutter-slime.util")

    assert.equals("#000000", util.blend_hex("#000000", "#ffffff", 0))
    assert.equals("#ffffff", util.blend_hex("#000000", "#ffffff", 1))
    assert.equals("#bcbcbc", util.blend_hex("#000000", "#ffffff", 0.5))
  end)
end)
