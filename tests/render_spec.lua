-- tests/render_spec.lua
-- Unit tests for render module attach/detach logic.

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

  it("is_attached() returns false for an unknown window", function()
    assert.is_false(render.is_attached(99999))
  end)

  it("attach() and detach() round-trip on a real window", function()
    local winid = vim.api.nvim_get_current_win()
    render.attach(winid)
    assert.is_true(render.is_attached(winid))
    render.detach(winid)
    assert.is_false(render.is_attached(winid))
  end)

  it("attach() is idempotent", function()
    local winid = vim.api.nvim_get_current_win()
    render.attach(winid)
    render.attach(winid) -- second call should not change state
    assert.is_true(render.is_attached(winid))
    render.detach(winid)
  end)

  it("detach_all() clears all attached windows", function()
    local winid = vim.api.nvim_get_current_win()
    render.attach(winid)
    render.detach_all()
    assert.is_false(render.is_attached(winid))
  end)
end)
