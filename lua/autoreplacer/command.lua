local M = {}

---Register the `:AutoReplacer*` user commands. Safe to call more than once.
function M.register()
  local function cmd(name, fn, desc)
    vim.api.nvim_create_user_command(name, fn, { desc = desc })
  end

  cmd("AutoReplacerRun", function()
    require("autoreplacer.replacer").run(nil) -- nil event = run every matching rule
  end, "autoreplacer: run all matching rules on the current buffer now")

  cmd("AutoReplacerEnable", function()
    require("autoreplacer.state").enabled = true
    require("autoreplacer.log").echo("automatic replacement enabled")
  end, "autoreplacer: resume automatic replacement")

  cmd("AutoReplacerDisable", function()
    require("autoreplacer.state").enabled = false
    require("autoreplacer.log").echo("automatic replacement disabled")
  end, "autoreplacer: pause automatic replacement")

  cmd("AutoReplacerToggle", function()
    local state = require("autoreplacer.state")
    state.enabled = not state.enabled
    require("autoreplacer.log").echo(
      state.enabled and "automatic replacement enabled" or "automatic replacement disabled"
    )
  end, "autoreplacer: toggle automatic replacement")
end

return M
