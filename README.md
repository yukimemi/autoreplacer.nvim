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

With [rvpm](https://github.com/yukimemi/rvpm) (recommended):

```sh
rvpm add yukimemi/autoreplacer.nvim --on-event BufReadPre,BufNewFile --on-cmd '/^AutoReplacer.*$/' --setup '{}'
```

`--setup` takes a TOML inline table, so a bare
`rvpm add yukimemi/autoreplacer.nvim --setup '{}'` is enough to register the
plugin and have rvpm call `setup()` with no options.

Or in `config.toml`:

```toml
[[plugins]]
url = "https://github.com/yukimemi/autoreplacer.nvim"
on_event = ["BufReadPre", "BufNewFile"]
on_cmd = ["/^AutoReplacer.*$/"]
setup = {}
```

> Here `setup()` is **required**: the commands come up either way, but nothing
> is switched automatically until `require("autoreplacer").setup(...)` installs the
> autocmds. **rvpm >= 3.48.0 handles it for you** — the presence of a `setup`
> field in the `[[plugins]]` entry makes rvpm call
> `require("autoreplacer").setup(<opts>)` right before the plugin's `after.lua`.
> `setup = {}` calls it with no options; `setup = { notify = false }` passes that
> table straight through. Use a hook
> (`rvpm edit yukimemi/autoreplacer.nvim --after`) when the options need a Lua
> function, which TOML cannot express — and if a single `setup()` call needs both
> plain data and a Lua function, keep the whole call in `after.lua` and drop the
> `setup` field. Never set the plugin up from both places: calling
> `require("autoreplacer").setup(...)` twice is a configuration error.

Or with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "yukimemi/autoreplacer.nvim",
  event = { "BufReadPre", "BufNewFile" },
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
