local MiniTest = require("mini.test")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      require("autoreplacer.config").setup()
      require("autoreplacer.state").enabled = true
    end,
  },
})

T["apply_one with a function inserts computed text"] = function()
  local r = require("autoreplacer.replacer")
  local out, changed = r.apply_one("Version: 123", {
    pattern = [[(Version: ).*$]],
    with = function(m)
      return m[1] .. "X"
    end,
  })
  eq(changed, true)
  eq(out, "Version: X")
end

T["apply_one with a string template expands captures"] = function()
  local r = require("autoreplacer.replacer")
  local out = (r.apply_one("xxaaabbyy", { pattern = [[(a+)(b+)]], with = [[\2\1]] }))
  eq(out, "xxbbaaayy")
end

T["apply_one reports no change when the pattern misses"] = function()
  local r = require("autoreplacer.replacer")
  local out, changed = r.apply_one("nothing here", { pattern = [[(zzz)]], with = [[\1]] })
  eq(changed, false)
  eq(out, "nothing here")
end

T["very magic is on: alternation and quantifiers work bare"] = function()
  local r = require("autoreplacer.replacer")
  local out = (r.apply_one("cat", { pattern = [[(cat|dog)]], with = [[<\1>]] }))
  eq(out, "<cat>")
end

T["run updates a Last Change line via the default rule"] = function()
  vim.cmd("enew")
  vim.bo.filetype = "lua"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "-- Last Change : 2000/01/01 00:00:00.",
    "local x = 1",
  })

  require("autoreplacer.replacer").run("BufWritePre")

  local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
  eq(line:match("^%-%- Last Change : ") ~= nil, true)
  eq(line:match("%d%d%d%d/%d%d/%d%d %d%d:%d%d:%d%d%.$") ~= nil, true)
  eq(line ~= "-- Last Change : 2000/01/01 00:00:00.", true)
  -- a non-matching line is untouched
  eq(vim.api.nvim_buf_get_lines(0, 1, 2, false)[1], "local x = 1")
end

T["rules are skipped when the filename glob does not match"] = function()
  require("autoreplacer.config").setup({
    rules = {
      {
        name = "xml-only",
        patterns = { "*.xml" },
        events = { "BufWritePre" },
        replace = { { pattern = [[(v)]], with = [[\1!]] } },
      },
    },
  })

  vim.cmd("enew")
  vim.api.nvim_buf_set_name(0, vim.fn.tempname() .. ".lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "v" })

  require("autoreplacer.replacer").run("BufWritePre")
  eq(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1], "v")
end

T["disabled state suppresses replacement"] = function()
  require("autoreplacer.state").enabled = false
  vim.cmd("enew")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "-- Last Change : 2000/01/01 00:00:00." })
  require("autoreplacer.replacer").run("BufWritePre")
  eq(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1], "-- Last Change : 2000/01/01 00:00:00.")
end

return T
