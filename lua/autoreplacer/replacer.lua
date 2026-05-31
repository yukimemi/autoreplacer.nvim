local M = {}

local function cfg()
  return require("autoreplacer.config").options
end

-- Expand `\0`..`\9` in a string template against a matchlist result
-- (`m[1]` = whole match, `m[2]` = group 1, ...).
local function expand_template(tpl, m)
  return (tpl:gsub("\\(%d)", function(d)
    return m[tonumber(d) + 1] or ""
  end))
end

-- Remap a matchlist result to the function-arg shape: `t[0]` = whole match,
-- `t[1]` = group 1, ... so users can write `m[1]` for the first group.
local function as_func_arg(m)
  local t = {}
  for i = 1, #m do
    t[i - 1] = m[i]
  end
  return t
end

---Apply one replacement to a line (first match only). Returns the new line and
---whether it changed.
---@param line string
---@param repl autoreplacer.Replacement
---@return string, boolean
function M.apply_one(line, repl)
  local re = "\\v" .. repl.pattern
  local m = vim.fn.matchlist(line, re)
  if #m == 0 then
    return line, false
  end
  local whole = m[1]
  if whole == "" then
    return line, false
  end
  local s = vim.fn.match(line, re) -- byte offset of the match start (0-based)
  if s < 0 then
    return line, false
  end

  local newtext
  if type(repl.with) == "function" then
    newtext = repl.with(as_func_arg(m))
  else
    newtext = expand_template(repl.with, m)
  end
  if type(newtext) ~= "string" then
    return line, false
  end

  local replaced = line:sub(1, s) .. newtext .. line:sub(s + #whole + 1)
  return replaced, replaced ~= line
end

local function ft_matches(rule)
  local fts = rule.filetypes
  if not fts or #fts == 0 then
    return true
  end
  return vim.tbl_contains(fts, vim.bo.filetype)
end

local function name_matches(rule, fullpath)
  local pats = rule.patterns
  if not pats or #pats == 0 then
    return true
  end
  for _, p in ipairs(pats) do
    if vim.fn.match(fullpath, vim.fn.glob2regpat(p)) >= 0 then
      return true
    end
  end
  return false
end

local function event_matches(rule, event)
  if not event then
    return true
  end
  return vim.tbl_contains(rule.events or { "BufWritePre" }, event)
end

-- 0-based line indices a rule scans: head lines + tail lines (or the whole
-- buffer when no range is set).
local function line_indices(rule, total)
  local range = rule.range
  if not range or (not range.head and not range.tail) then
    local idx = {}
    for i = 0, total - 1 do
      idx[i + 1] = i
    end
    return idx
  end
  local set = {}
  for i = 0, math.min(range.head or 0, total) - 1 do
    set[i] = true
  end
  for i = math.max(0, total - (range.tail or 0)), total - 1 do
    set[i] = true
  end
  local idx = {}
  for i in pairs(set) do
    idx[#idx + 1] = i
  end
  table.sort(idx)
  return idx
end

---@param rule autoreplacer.Rule
function M.apply_rule(rule)
  local total = vim.api.nvim_buf_line_count(0)
  for _, i in ipairs(line_indices(rule, total)) do
    local line = vim.api.nvim_buf_get_lines(0, i, i + 1, false)[1]
    if line then
      local changed = false
      for _, repl in ipairs(rule.replace or {}) do
        local newline, did = M.apply_one(line, repl)
        if did then
          line = newline
          changed = true
        end
      end
      if changed then
        vim.api.nvim_buf_set_lines(0, i, i + 1, false, { line })
        require("autoreplacer.log").info(("line %d updated"):format(i + 1))
      end
    end
  end
end

---Run every rule that matches the current buffer (and the given event, if any).
---@param event? string
function M.run(event)
  if not require("autoreplacer.state").enabled then
    return
  end
  local bufpath = vim.fs.normalize(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p"))
  for _, rule in ipairs(cfg().rules or {}) do
    if event_matches(rule, event) and ft_matches(rule) and name_matches(rule, bufpath) then
      M.apply_rule(rule)
    end
  end
end

return M
