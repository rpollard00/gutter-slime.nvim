-- tests/blame_spec.lua
-- Unit tests for blame.parse_incremental (pure function, no Neovim required).

-- Minimal vim stub so the module can be required outside Neovim.
if not vim then
  ---@diagnostic disable-next-line: lowercase-global
  vim = {
    split = function(str, sep, opts)
      local plain = opts and opts.plain
      local result = {}
      local pattern = plain and sep:gsub("([^%w])", "%%%1") or sep
      local s = 1
      while true do
        local i, j = str:find(pattern, s, plain)
        if not i then
          result[#result + 1] = str:sub(s)
          break
        end
        result[#result + 1] = str:sub(s, i - 1)
        s = j + 1
      end
      return result
    end,
  }
end

-- Stub out heavy dependencies so we can load blame.lua in isolation.
package.loaded["gutter-slime.cache"] = {}
package.loaded["gutter-slime.util"] = { debug = function() end }

local blame = require("gutter-slime.blame")

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Build a minimal git blame --incremental block for a single commit hunk.
---@param sha string  40-char hex sha
---@param orig_line integer
---@param final_line integer
---@param count integer
---@param author_time integer  unix timestamp
---@param filename string
---@return string
local function make_hunk(sha, orig_line, final_line, count, author_time, filename)
  return table.concat({
    string.format("%s %d %d %d", sha, orig_line, final_line, count),
    "author Test Author",
    "author-mail <test@example.com>",
    string.format("author-time %d", author_time),
    "author-tz +0000",
    "committer Test Author",
    "committer-mail <test@example.com>",
    string.format("committer-time %d", author_time),
    "committer-tz +0000",
    "summary test commit",
    string.format("filename %s", filename),
    "",
  }, "\n")
end

local ZERO_SHA = string.rep("0", 40)
local SHA1 = string.rep("a", 40)
local SHA2 = string.rep("b", 40)
local SHA3 = string.rep("c", 40)

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

describe("blame.parse_incremental", function()
  it("returns a table of the correct length for a single hunk", function()
    local ts = 1700000000
    local output = make_hunk(SHA1, 1, 1, 3, ts, "foo.lua")
    local result = blame.parse_incremental(output, 3)
    assert.equal(3, #result)
  end)

  it("assigns the author-time timestamp to covered lines", function()
    local ts = 1700000000
    local output = make_hunk(SHA1, 1, 1, 3, ts, "foo.lua")
    local result = blame.parse_incremental(output, 3)
    for i = 1, 3 do
      assert.equal(ts, result[i].timestamp)
      assert.equal(SHA1, result[i].sha)
    end
  end)

  it("maps the zero SHA to timestamp 0 (uncommitted)", function()
    local output = make_hunk(ZERO_SHA, 1, 1, 2, 0, "foo.lua")
    local result = blame.parse_incremental(output, 2)
    assert.equal(0, result[1].timestamp)
    assert.equal(0, result[2].timestamp)
    assert.equal(ZERO_SHA, result[1].sha)
  end)

  it("handles multiple hunks with different SHAs", function()
    local ts1 = 1700000000
    local ts2 = 1600000000
    local output = make_hunk(SHA1, 1, 1, 2, ts1, "foo.lua")
      .. make_hunk(SHA2, 3, 3, 3, ts2, "foo.lua")
    local result = blame.parse_incremental(output, 5)
    assert.equal(ts1, result[1].timestamp)
    assert.equal(ts1, result[2].timestamp)
    assert.equal(ts2, result[3].timestamp)
    assert.equal(ts2, result[4].timestamp)
    assert.equal(ts2, result[5].timestamp)
  end)

  it("handles a second hunk for the same SHA without re-emitting metadata", function()
    -- First block has full metadata; second hunk for the same SHA omits it.
    local ts = 1700000000
    local first_block = make_hunk(SHA1, 1, 1, 2, ts, "foo.lua")
    -- Second hunk: same SHA, no metadata lines (just header + filename).
    local second_block = string.format("%s 3 3 1\nfilename foo.lua\n", SHA1)
    local output = first_block .. second_block
    local result = blame.parse_incremental(output, 3)
    assert.equal(ts, result[1].timestamp)
    assert.equal(ts, result[2].timestamp)
    -- Line 3 should also get the cached timestamp from the first block.
    assert.equal(ts, result[3].timestamp)
  end)

  it("defaults uncovered lines to zero timestamp and zero SHA", function()
    -- Only cover line 2 of a 4-line file.
    local ts = 1700000000
    local output = make_hunk(SHA1, 2, 2, 1, ts, "foo.lua")
    local result = blame.parse_incremental(output, 4)
    assert.equal(0, result[1].timestamp)
    assert.equal(ZERO_SHA, result[1].sha)
    assert.equal(ts, result[2].timestamp)
    assert.equal(0, result[3].timestamp)
    assert.equal(0, result[4].timestamp)
  end)

  it("handles an empty output string", function()
    local result = blame.parse_incremental("", 5)
    assert.equal(5, #result)
    for i = 1, 5 do
      assert.equal(0, result[i].timestamp)
    end
  end)

  it("handles a single line file", function()
    local ts = 1700000001
    local output = make_hunk(SHA3, 1, 1, 1, ts, "single.lua")
    local result = blame.parse_incremental(output, 1)
    assert.equal(1, #result)
    assert.equal(ts, result[1].timestamp)
    assert.equal(SHA3, result[1].sha)
  end)

  it("does not overflow when hunk extends beyond line_count", function()
    -- Hunk claims to cover lines 1-5 but file only has 3 lines.
    local ts = 1700000000
    local output = make_hunk(SHA1, 1, 1, 5, ts, "foo.lua")
    local result = blame.parse_incremental(output, 3)
    -- Should not error and result should have exactly line_count entries.
    assert.equal(3, #result)
    for i = 1, 3 do
      assert.equal(ts, result[i].timestamp)
    end
  end)

  it("handles hunks with orig_line != final_line (renamed/moved lines)", function()
    local ts = 1700000000
    -- orig=10 final=1, count=2: git moved lines from line 10 to line 1.
    local output = make_hunk(SHA1, 10, 1, 2, ts, "renamed.lua")
    local result = blame.parse_incremental(output, 5)
    assert.equal(ts, result[1].timestamp)
    assert.equal(ts, result[2].timestamp)
    assert.equal(0, result[3].timestamp)
  end)
end)

describe("blame pathspec and command helpers", function()
  it("converts absolute paths under the repo to repo-relative pathspecs", function()
    local path = "/tmp/repo/lua/gutter-slime/init.lua"
    local root = "/tmp/repo"
    assert.equal("lua/gutter-slime/init.lua", blame.pathspec_for_repo(path, root))
  end)

  it("leaves paths outside the repo unchanged", function()
    local path = "/other/place/file.lua"
    local root = "/tmp/repo"
    assert.equal(path, blame.pathspec_for_repo(path, root))
  end)

  it("builds a clean blame command without --contents", function()
    local cmd = blame.build_blame_command("lua/gutter-slime/init.lua", false)
    assert.same({ "git", "blame", "--incremental", "--", "lua/gutter-slime/init.lua" }, cmd)
  end)

  it("builds a dirty-buffer blame command with --contents -", function()
    local cmd = blame.build_blame_command("lua/gutter-slime/init.lua", true)
    assert.same({
      "git",
      "blame",
      "--incremental",
      "--contents",
      "-",
      "--",
      "lua/gutter-slime/init.lua",
    }, cmd)
  end)
end)
