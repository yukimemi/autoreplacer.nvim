local M = {}

local AUGROUP = "autoreplacer"

-- Union of every rule's events (default BufWritePre).
local function all_events()
  local events, seen = {}, {}
  for _, rule in ipairs(require("autoreplacer.config").options.rules or {}) do
    for _, e in ipairs(rule.events or { "BufWritePre" }) do
      if not seen[e] then
        seen[e] = true
        events[#events + 1] = e
      end
    end
  end
  if #events == 0 then
    events = { "BufWritePre" }
  end
  return events
end

---Install the replacement autocmd. Idempotent: clears the augroup on re-setup.
function M.register()
  local group = vim.api.nvim_create_augroup(AUGROUP, { clear = true })
  vim.api.nvim_create_autocmd(all_events(), {
    group = group,
    callback = function(ev)
      require("autoreplacer.replacer").run(ev.event)
    end,
  })
end

function M.unregister()
  pcall(vim.api.nvim_del_augroup_by_name, AUGROUP)
end

return M
