-- Eager registration so the `:AutoReplacer*` commands work without calling
-- `require("autoreplacer").setup()` (convention over configuration). Automatic
-- replacement (the autocmd) only starts from `setup()`.
if vim.g.loaded_autoreplacer then
  return
end
vim.g.loaded_autoreplacer = true

require("autoreplacer.command").register()
