local MiniTest = require("mini.test")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T["defaults provide the last-change rule"] = function()
  local cfg = require("autoreplacer.config")
  cfg.setup()
  eq(#cfg.options.rules, 1)
  eq(cfg.options.rules[1].name, "last-change")
  eq(cfg.options.log_level, "warn")
end

T["user rules replace the defaults verbatim (not merged by index)"] = function()
  local cfg = require("autoreplacer.config")
  cfg.setup({
    rules = {
      { name = "a", replace = {} },
      { name = "b", replace = {} },
    },
  })
  eq(#cfg.options.rules, 2)
  eq(cfg.options.rules[1].name, "a")
  eq(cfg.options.rules[2].name, "b")
end

T["scalar options still deep-merge"] = function()
  local cfg = require("autoreplacer.config")
  cfg.setup({ notify = true, log_level = "debug" })
  eq(cfg.options.notify, true)
  eq(cfg.options.log_level, "debug")
  eq(#cfg.options.rules, 1) -- default rule retained when rules not given
end

return T
