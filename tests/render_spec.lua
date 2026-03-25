-- tests/render_spec.lua
-- Unit tests for render module (extmark-based).

describe("render", function()
  local render

  before_each(function()
    package.loaded["gutter-slime.render"] = nil
    package.loaded["gutter-slime.cache"] = nil
    package.loaded["gutter-slime.palette"] = nil
    package.loaded["gutter-slime.config"] = nil
    package.loaded["gutter-slime.util"] = nil
    render = require("gutter-slime.render")
    require("gutter-slime.config").setup()
    require("gutter-slime.palette").build()
  end)

  it("namespace() returns a valid integer", function()
    local ns = render.namespace()
    assert.is_number(ns)
    assert.is_true(ns > 0)
  end)

  it("render() places extmarks for lines with bucket data", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local cache = require("gutter-slime.cache")
    -- Seed cache with 3 lines of bucket data.
    local rid = cache.new_request(bufnr)
    cache.store(bufnr, rid, 1, { 1, 2, 3 }, { 100, 200, 300 })

    render.render(bufnr)

    local marks = vim.api.nvim_buf_get_extmarks(bufnr, render.namespace(), 0, -1, {})
    assert.equals(3, #marks)

    render.clear(bufnr)
  end)

  it("clear() removes all extmarks for a buffer", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local cache = require("gutter-slime.cache")
    local rid = cache.new_request(bufnr)
    cache.store(bufnr, rid, 1, { 1, 2 }, { 100, 200 })

    render.render(bufnr)
    render.clear(bufnr)

    local marks = vim.api.nvim_buf_get_extmarks(bufnr, render.namespace(), 0, -1, {})
    assert.equals(0, #marks)
  end)

  it("render() is idempotent (second call replaces first)", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local cache = require("gutter-slime.cache")
    local rid = cache.new_request(bufnr)
    cache.store(bufnr, rid, 1, { 1, 2, 3 }, { 100, 200, 300 })

    render.render(bufnr)
    render.render(bufnr) -- should clear-and-redraw, not double-up

    local marks = vim.api.nvim_buf_get_extmarks(bufnr, render.namespace(), 0, -1, {})
    assert.equals(3, #marks)

    render.clear(bufnr)
  end)
end)
