<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/yukimemi/autoreplacer.nvim/main/assets/logo-dark.svg">
  <img src="https://raw.githubusercontent.com/yukimemi/autoreplacer.nvim/main/assets/logo.svg" alt="autoreplacer — rewrite-on-save text rules" width="520">
</picture>

<p><em>rewrite-on-save text rules.</em></p>

[![CI](https://github.com/yukimemi/autoreplacer.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/yukimemi/autoreplacer.nvim/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/yukimemi/autoreplacer.nvim/blob/main/LICENSE)
[![Neovim 0.10+](https://img.shields.io/badge/Neovim-0.10+-57A143?logo=neovim&logoColor=white)](https://neovim.io)

</div>

Apply regex replacement rules to a buffer on save — bump a `Last Change:`
timestamp, a `version = "..."` field, and so on. A pure-Lua, Neovim-only rewrite
of [autoreplacer.vim](https://github.com/yukimemi/autoreplacer.vim) (no Deno /
denops dependency). Patterns are ordinary regular expressions; replacements can
be a string template **or a Lua function**, so there is no string-eval DSL.

## Requirements

- Neovim >= 0.10

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "yukimemi/autoreplacer.nvim",
  event = { "BufRead", "BufNewFile" },
  opts = {},
}
```

`opts` is passed straight to `require("autoreplacer").setup()`.

## Configuration

The default rule keeps a `Last Change:` line current:

```lua
require("autoreplacer").setup({
  notify = false,
  log_level = "warn",
  enabled = true,
  rules = {
    {
      name = "last-change",
      patterns = { "*" },               -- filename globs
      events = { "BufWritePre" },
      range = { head = 15, tail = 15 }, -- scan the first/last N lines (nil = whole buffer)
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
})
```

### Patterns

`pattern` is an **ordinary regular expression** — very magic (`\v`) is prepended
for you, so `( ) + ? | {2,4}` work bare and only literal metacharacters need
escaping (e.g. `\.`). Add a leading `\c` for case-insensitive matching.

Very magic is close to PCRE, but a few ASCII characters are operators rather
than literals. When you mean them **literally**, escape or class them:

| Want literal | Write | Why |
| --- | --- | --- |
| `=` | `\=` | bare `=` means "0 or 1 of the previous atom" (like `?`) |
| `<` `>` | `[<]` `[>]` | bare `<` `>` are word boundaries |
| `{` `}` | match around them, e.g. `[^"]*` | the regex engine is unreliable matching literal braces |

For example, an XML `key="...version">` value is matched with
`[[\c^(.*key\="[^"]*version"[>])[^<]*([<].*)]]`.

### Replacements

`with` replaces the **whole match** and is either:

- a **string** template, where `\0`..`\9` expand to the captures:

  ```lua
  { pattern = [[(a+)(b+)]], with = [[\2\1]] }   -- swap the two groups
  ```

- a **function** receiving captures (`m[0]` = whole match, `m[1]`, `m[2]`, … =
  groups) and returning the replacement — use this for dynamic values:

  ```lua
  { pattern = [[(version = ")[0-9_]+(")]],
    with = function(m) return m[1] .. os.date("%Y%m%d_%H%M%S") .. m[2] end }
  ```

## Commands

| Command | Action |
| --- | --- |
| `:AutoReplacerRun` | Run all matching rules on the current buffer now |
| `:AutoReplacerEnable` / `:AutoReplacerDisable` / `:AutoReplacerToggle` | Control automatic replacement |

The commands work without calling `setup()`; only the automatic autocmd needs
`setup()`.

## Lua API

```lua
local ar = require("autoreplacer")
ar.run()      -- == :AutoReplacerRun
ar.enable()
ar.disable()
```

## Health

```vim
:checkhealth autoreplacer
```

## License

MIT
