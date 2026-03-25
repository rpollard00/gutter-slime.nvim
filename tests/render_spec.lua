-- tests/render_spec.lua
-- Unit tests for the statuscolumn-based render module.

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

  after_each(function()
    -- Always clean up attached windows so state doesn't leak between tests.
    render.detach_all()
  end)

  -- -------------------------------------------------------------------------
  -- attach_win / detach_win
  -- -------------------------------------------------------------------------

  it("attach_win() sets a non-empty statuscolumn on the window", function()
    local winid = vim.api.nvim_get_current_win()
    render.attach_win(winid)

    local stc = vim.wo[winid].statuscolumn
    assert.is_truthy(stc and stc ~= "")
    assert.is_truthy(stc:find("gutter%-slime"))
  end)

  it("detach_win() restores the previous statuscolumn", function()
    local winid = vim.api.nvim_get_current_win()
    local original = vim.wo[winid].statuscolumn

    render.attach_win(winid)
    render.detach_win(winid)

    assert.equals(original, vim.wo[winid].statuscolumn)
  end)

  it("attach_win() is idempotent (double attach stays attached once)", function()
    local winid = vim.api.nvim_get_current_win()

    render.attach_win(winid)
    local stc_after_first = vim.wo[winid].statuscolumn
    render.attach_win(winid) -- second call should be a no-op
    local stc_after_second = vim.wo[winid].statuscolumn

    assert.equals(stc_after_first, stc_after_second)
    -- Only recorded once.
    assert.equals(1, #render.attached_wins())
  end)

  it("attached_wins() returns all attached window ids", function()
    local winid = vim.api.nvim_get_current_win()
    assert.equals(0, #render.attached_wins())

    render.attach_win(winid)
    assert.equals(1, #render.attached_wins())
    assert.equals(winid, render.attached_wins()[1])

    render.detach_win(winid)
    assert.equals(0, #render.attached_wins())
  end)

  it("detach_all() removes statuscolumn from every attached window", function()
    local winid = vim.api.nvim_get_current_win()
    render.attach_win(winid)
    assert.equals(1, #render.attached_wins())

    render.detach_all()
    assert.equals(0, #render.attached_wins())
    -- statuscolumn should be restored to empty (default).
    assert.equals("", vim.wo[winid].statuscolumn)
  end)

  -- -------------------------------------------------------------------------
  -- _stc_line()
  -- -------------------------------------------------------------------------

  it("_stc_line() returns a plain space when v:virtnum != 0", function()
    -- Simulate a wrapped continuation line.
    vim.v.virtnum = 1
    local result = render._stc_line()
    vim.v.virtnum = 0
    assert.equals(" ", result)
  end)

  it("_stc_line() returns a plain space when no cache data exists", function()
    vim.v.virtnum = 0
    vim.v.lnum = 1
    -- Cache is empty — no blame data stored.
    local result = render._stc_line()
    assert.equals(" ", result)
  end)

  it("_stc_line() returns a highlight string when cache has a bucket", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local cache = require("gutter-slime.cache")
    local rid = cache.new_request(bufnr)
    cache.store(bufnr, rid, 1, { 2 }, { 100 }) -- line 1 = bucket 2

    vim.v.virtnum = 0
    vim.v.lnum = 1
    local result = render._stc_line()
    -- Should contain a highlight group name and a space.
    assert.is_truthy(result:find("^%%#GutterSlime"))
    assert.is_truthy(result:find(" "))
  end)

  it("refresh_buf() attaches windows showing bufnr", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local cache = require("gutter-slime.cache")
    local rid = cache.new_request(bufnr)
    cache.store(bufnr, rid, 1, { 1 }, { 100 })

    render.refresh_buf(bufnr)

    local winid = vim.api.nvim_get_current_win()
    assert.is_truthy(vim.wo[winid].statuscolumn:find("gutter%-slime"))
  end)

  it("clear_buf() detaches windows showing bufnr", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local winid = vim.api.nvim_get_current_win()
    render.attach_win(winid)

    render.clear_buf(bufnr)

    assert.equals(0, #render.attached_wins())
  end)
end)
