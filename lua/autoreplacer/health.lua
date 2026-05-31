local M = {}

local h = vim.health
local start = h.start or h.report_start
local ok = h.ok or h.report_ok
local info = h.info or h.report_info
local warn = h.warn or h.report_warn

function M.check()
  start("autoreplacer")

  if vim.fn.has("nvim-0.10") == 1 then
    ok("Neovim >= 0.10")
  else
    warn("Neovim 0.10+ recommended")
  end

  local options = require("autoreplacer.config").options
  local state = require("autoreplacer.state")

  info("enabled: " .. tostring(state.enabled))
  local rules = options.rules or {}
  if #rules == 0 then
    warn("no rules configured")
  else
    ok(("%d rule(s) configured"):format(#rules))
    for _, rule in ipairs(rules) do
      info(
        ("- %s: %d replacement(s), events=%s"):format(
          rule.name or "(unnamed)",
          #(rule.replace or {}),
          table.concat(rule.events or { "BufWritePre" }, ",")
        )
      )
    end
  end
end

return M
