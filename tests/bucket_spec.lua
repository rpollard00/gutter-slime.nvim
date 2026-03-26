-- tests/bucket_spec.lua
-- Unit tests for config parsing, age-window mapping, and zoom helpers.

describe("bucket mapping", function()
  local gs
  local config
  local cache
  local render

  local function reset_modules()
    package.loaded["gutter-slime"] = nil
    package.loaded["gutter-slime.config"] = nil
    package.loaded["gutter-slime.cache"] = nil
    package.loaded["gutter-slime.palette"] = nil
    package.loaded["gutter-slime.render"] = nil
    package.loaded["gutter-slime.autocmds"] = nil
    package.loaded["gutter-slime.util"] = nil
    package.loaded["gutter-slime.blame"] = nil

    gs = require("gutter-slime")
    config = require("gutter-slime.config")
    cache = require("gutter-slime.cache")
    render = require("gutter-slime.render")
  end

  before_each(function()
    reset_modules()
  end)

  after_each(function()
    render.detach_all()
  end)

  it("setup() runs without errors", function()
    assert.has_no.errors(function()
      gs.setup({ enabled = false })
    end)
  end)

  it("config merges user options correctly", function()
    gs.setup({ debounce_ms = 300, debug = true })
    local cfg = config.get()
    assert.equals(300, cfg.debounce_ms)
    assert.is_true(cfg.debug)
    assert.equals(0, cfg.recent_days)
    assert.equals(180, cfg.old_days)
    assert.equals("recent", cfg.curve)
    assert.equals("monotone", cfg.gradient.style)
  end)

  it("set_gradient_style() updates the active style", function()
    gs.setup({ enabled = false })

    assert.is_true(gs.set_gradient_style("thermal"))
    assert.equals("thermal", config.get().gradient.style)
  end)

  it("set_gradient_style() rejects custom without stops", function()
    gs.setup({ enabled = false })

    assert.is_false(gs.set_gradient_style("custom"))
    assert.equals("monotone", config.get().gradient.style)
  end)

  it("set_gradient_style() accepts custom when stops exist", function()
    gs.setup({
      enabled = false,
      gradient = {
        custom = {
          stops = { "#112233", "#445566" },
        },
      },
    })

    assert.is_true(gs.set_gradient_style("custom"))
    assert.equals("custom", config.get().gradient.style)
  end)

  it("parse_duration_days accepts numbers, day strings, and hour strings", function()
    local parse = config.parse_duration_days
    assert.equals(14, select(1, parse(14)))
    assert.equals(7, select(1, parse("7d")))
    assert.equals(2, select(1, parse("48h")))
    assert.equals(0.5, select(1, parse("12h")))
    assert.equals(1.5, select(1, parse("1.5d")))
    assert.equals(3, select(1, parse("3")))
  end)

  it("config rejects invalid old_days", function()
    assert.has_no.errors(function()
      gs.setup({ old_days = 0 })
    end)
    local cfg = config.get()
    assert.equals(180, cfg.old_days)
  end)

  it("config rejects recent_days >= old_days", function()
    assert.has_no.errors(function()
      gs.setup({ recent_days = "2d", old_days = "2d" })
    end)
    local cfg = config.get()
    assert.equals(0, cfg.recent_days)
    assert.equals(180, cfg.old_days)
  end)

  it("config rejects bucket_count < 2", function()
    assert.has_no.errors(function()
      gs.setup({ bucket_count = 1 })
    end)
    local cfg = config.get()
    assert.equals(7, cfg.bucket_count)
  end)

  it("maps sub-day windows with linear bucketing", function()
    gs.setup({ enabled = false, bucket_count = 7, recent_days = 0, old_days = "48h", curve = "linear" })
    local now = os.time()

    assert.equals(1, gs._ts_to_bucket(now - 60 * 60))
    assert.equals(2, gs._ts_to_bucket(now - 8 * 60 * 60))
    assert.equals(4, gs._ts_to_bucket(now - 24 * 60 * 60))
    assert.equals(7, gs._ts_to_bucket(now - 48 * 60 * 60))
    assert.equals(7, gs._ts_to_bucket(now - 72 * 60 * 60))
  end)

  it("recent curve gives more detail to fresh edits than linear", function()
    local now = os.time()

    gs.setup({ enabled = false, bucket_count = 7, recent_days = 0, old_days = "48h", curve = "linear" })
    local linear_bucket = gs._ts_to_bucket(now - 18 * 60 * 60)

    gs.setup({ enabled = false, bucket_count = 7, recent_days = 0, old_days = "48h", curve = "recent" })
    local recent_bucket = gs._ts_to_bucket(now - 18 * 60 * 60)

    assert.is_true(recent_bucket <= linear_bucket)
  end)

  it("old curve gives more detail to stale edits than linear", function()
    local now = os.time()

    gs.setup({ enabled = false, bucket_count = 7, recent_days = 0, old_days = "48h", curve = "linear" })
    local linear_bucket = gs._ts_to_bucket(now - 18 * 60 * 60)

    gs.setup({ enabled = false, bucket_count = 7, recent_days = 0, old_days = "48h", curve = "old" })
    local old_bucket = gs._ts_to_bucket(now - 18 * 60 * 60)

    assert.is_true(old_bucket >= linear_bucket)
  end)

  it("_refresh_buf() detaches the strip for ineligible buffers", function()
    gs.setup({ enabled = true })

    local winid = vim.api.nvim_get_current_win()
    render.attach_win(winid)
    assert.equals(1, #render.attached_wins())

    local bufnr = vim.api.nvim_get_current_buf()
    vim.bo[bufnr].buftype = "nofile"

    gs._refresh_buf(bufnr)

    assert.equals(0, #render.attached_wins())
  end)

  it("zoom_in() steps old_days toward the present and stops at 1h", function()
    gs.setup({ enabled = false, old_days = "2h" })

    assert.is_true(gs.zoom_in())
    assert.equals(1 / 24, config.get().old_days)

    assert.is_true(gs.zoom_in())
    assert.equals(1 / 24, config.get().old_days)
  end)

  it("zoom_out() steps old_days farther into history", function()
    gs.setup({ enabled = false, old_days = "12h" })

    assert.is_true(gs.zoom_out())
    assert.equals(0.75, config.get().old_days)

    assert.is_true(gs.zoom_out())
    assert.equals(1, config.get().old_days)
  end)

  it("set_old() accepts hour strings", function()
    gs.setup({ enabled = false })

    assert.is_true(gs.set_old("36h"))
    assert.equals(1.5, config.get().old_days)
  end)

  it("adjust_old() accepts signed hour strings", function()
    gs.setup({ enabled = false, old_days = "48h" })

    assert.is_true(gs.adjust_old("-12h"))
    assert.equals(1.5, config.get().old_days)
  end)

  it("reset_view() restores setup baseline values", function()
    gs.setup({ enabled = false, recent_days = "12h", old_days = "72h", curve = "linear" })

    assert.is_true(gs.set_curve("old"))
    assert.is_true(gs.set_old("24h"))
    assert.is_true(gs.reset_view())

    local cfg = config.get()
    assert.equals(0.5, cfg.recent_days)
    assert.equals(3, cfg.old_days)
    assert.equals("linear", cfg.curve)
  end)

  it("rebuckets cached timestamps without rerunning blame", function()
    gs.setup({ enabled = false, bucket_count = 7, recent_days = 0, old_days = "48h", curve = "linear" })

    local bufnr = vim.api.nvim_get_current_buf()
    local winid = vim.api.nvim_get_current_win()
    local now = os.time()
    local rid = cache.new_request(bufnr)

    cache.store(bufnr, rid, 1, { 1, 4 }, { now - 60 * 60, now - 24 * 60 * 60 })
    render.attach_win(winid)

    assert.is_true(gs.set_curve("old"))

    assert.equals(1, cache.get_bucket(bufnr, 1))
    assert.is_true(cache.get_bucket(bufnr, 2) >= 4)
    assert.equals(1, #render.attached_wins())
  end)
end)
