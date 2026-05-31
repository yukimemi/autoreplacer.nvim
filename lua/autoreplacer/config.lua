local M = {}

---@class autoreplacer.Replacement
---@field pattern string  An ordinary regular expression. Very magic (`\v`) is
---  prepended automatically, so `( ) + ? | {2,4}` work bare and only literal
---  metacharacters need escaping (e.g. `\.`). Case-insensitive via a leading `\c`.
---@field with string|fun(m: table): string  Replacement for the whole match.
---  As a string, `\0`..`\9` expand to the captures. As a function, it receives
---  `m` where `m[0]` is the whole match and `m[1]`, `m[2]`, ... are the capture
---  groups, and returns the replacement (e.g. insert `os.date(...)`).

---@class autoreplacer.Rule
---@field name? string
---@field filetypes? string[]  Restrict to these `&filetype`s. nil/empty = any.
---@field patterns? string[]   Filename globs the buffer must match. Default {"*"}.
---@field events? string[]     Autocmd events that trigger this rule. Default {"BufWritePre"}.
---@field range? { head?: integer, tail?: integer }  Lines scanned from the top/bottom. nil = whole buffer.
---@field replace autoreplacer.Replacement[]

---@class autoreplacer.Options
---@field notify boolean   Emit `vim.notify` on replacement (gated by `log_level`). Default false.
---@field log_level "trace"|"debug"|"info"|"warn"|"error"
---@field enabled boolean  Whether automatic replacement starts on. Default true.
---@field rules autoreplacer.Rule[]

M.defaults = {
  notify = false,
  log_level = "warn",
  enabled = true,
  rules = {
    {
      name = "last-change",
      patterns = { "*" },
      events = { "BufWritePre" },
      range = { head = 15, tail = 15 },
      replace = {
        {
          pattern = [[(.*Last Change.*: ).*\.$]],
          with = function(m)
            return m[1] .. os.date("%Y/%m/%d %H:%M:%S") .. "."
          end,
        },
      },
    },
  },
}

M.options = vim.deepcopy(M.defaults)

---@param opts? autoreplacer.Options
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
  -- tbl_deep_extend turns list-like `rules` into a merged map when both sides
  -- have them; when the user passes rules, take theirs verbatim.
  if opts and opts.rules then
    M.options.rules = opts.rules
  end
end

return M
