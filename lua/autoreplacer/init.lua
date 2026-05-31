local M = {}

---Configure autoreplacer and start automatic replacement.
---@param opts? autoreplacer.Options
function M.setup(opts)
  local cfg = require("autoreplacer.config")
  cfg.setup(opts)
  require("autoreplacer.state").enabled = cfg.options.enabled
  require("autoreplacer.command").register()
  require("autoreplacer.autocmd").register()
end

-- Convenience Lua API.

---Run all matching rules on the current buffer now.
function M.run()
  require("autoreplacer.replacer").run(nil)
end

function M.enable()
  require("autoreplacer.state").enabled = true
end

function M.disable()
  require("autoreplacer.state").enabled = false
end

return M
