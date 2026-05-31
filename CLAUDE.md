# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## コンセプト

- **denops 廃止・pure Lua / Neovim 専用**: [`autoreplacer.vim`](https://github.com/yukimemi/autoreplacer.vim) (denops/Deno) の後継。保存時 (など) に正規表現の置換ルールをバッファへ適用する (`Last Change:` のタイムスタンプ更新、`version = "..."` のバンプ等)。
- **eval DSL 廃止**: 旧版は正規表現文字列と置換テンプレを `eval()` していた。新版は **pattern = 普通の正規表現** (very magic `\v` を自動付与) + **with = string テンプレ or Lua 関数**。任意コード実行なし。
- **設定はテーブル一本**: `g:autoreplacer_*` グローバルは全廃。`require("autoreplacer").setup({...})` のみ。`config.lua` に `M.defaults` + LuaCATS。`rules` はリストなので tbl_deep_extend の index マージを避け、ユーザ指定時は **verbatim 置換** する (`config.setup` 参照)。
- **Convention over Configuration**: `plugin/autoreplacer.lua` が `:AutoReplacer*` を eager 登録。自動置換 (autocmd) だけ `setup()` 起点。
- **Notify ゲート契約**: background ログは `lua/autoreplacer/log.lua` の `M.at/info/warn` 経由。`notify = false` で無音。ユーザ起点コマンドのみ `log.echo`。

## Git ワークフロー

- **main に直接 push しない。** フィーチャーブランチ + PR。**PR / commit は英語** (Conventional Commits)。
- 全 PR で Gemini / CodeRabbit がレビュー。指摘対処 (fix push → @-mention reply) し、actionable 消失 + オーナー (@yukimemi) 承認まで merge しない。bot-authored PR は除外。

## Development Commands

テストは **mini.test** (plenary は 2026-06-30 アーカイブ)。`scripts/run_tests.lua` が headless ランナー (失敗時 `cquit`)。

```bash
git clone --depth 1 https://github.com/echasnovski/mini.nvim deps/mini.nvim
# または既存 clone を $MINI_NVIM で再利用

set -e
status=0
for f in tests/autoreplacer/test_*.lua; do
  nvim -u NONE -l scripts/run_tests.lua "$f" || status=$?
done
exit $status

# 単一
nvim -u NONE -l scripts/run_tests.lua tests/autoreplacer/test_replacer.lua
```

- `nvim -u NONE -l` で user config を読まずに実行。spec 名は mini.test 既定の **`test_*.lua`**。

## アーキテクチャ

### ファイル構成

```text
plugin/autoreplacer.lua     — :AutoReplacer* を eager 登録
lua/autoreplacer/
  init.lua                  — setup() + Lua API (run/enable/disable)
  config.lua                — defaults + LuaCATS、rules は verbatim 置換
  log.lua                   — notify ゲート + echo
  state.lua                 — enabled フラグ (memory)
  replacer.lua              — コア: apply_one (matchlist + 位置スプライス)、ft/glob/event マッチ、head/tail 範囲、run()
  autocmd.lua               — 全ルールの events の和集合で autocmd 登録 (冪等)
  command.lua               — :AutoReplacer{Run,Enable,Disable,Toggle}
  health.lua                — :checkhealth autoreplacer
scripts/run_tests.lua
tests/autoreplacer/test_*.lua
.github/workflows/ci.yml    — test (ubuntu/macos/windows × stable/nightly) + stylua lint
```

### 置換のコア (`replacer.lua`)

- **`apply_one(line, repl)`**: `\v` を前置した pattern で `vim.fn.matchlist` (キャプチャ取得) と `vim.fn.match` (マッチ開始バイト位置) を取り、`line:sub` で**マッチ範囲だけ置換** (最初のマッチのみ、denops と同じ)。`with` が関数なら `as_func_arg` で `m[0]=whole, m[1]=group1...` に詰め替えて呼ぶ。string なら `expand_template` で `\0`..`\9` を展開。
- **マッチ条件**: `ft_matches` (`&filetype`)、`name_matches` (`glob2regpat` でファイル名 glob)、`event_matches` (発火 event がルールの events に含まれるか)。
- **範囲**: `line_indices` が head (先頭 N) + tail (末尾 N) の 0-based 行集合を返す。range 未指定なら全行。
- **`run(event)`**: enabled を見て、各ルールが event/ft/glob にマッチすれば `apply_rule`。変更行のみ `nvim_buf_set_lines`。BufWritePre で走らせれば書き込み前に反映される。

### autocmd (`autocmd.lua`)

全ルールの `events` の**和集合**で 1 つの autocmd を張り、callback で `replacer.run(ev.event)`。`setup()` 再実行で augroup を clear して冪等。

## 設計原則

- **保存を止めない.** 置換は同期だが head/tail の限定行のみ。失敗しても Neovim を止めない。
- **Notify ゲート契約.** background は `log.at` 系、ユーザ起点のみ `log.echo`。
- **テスト先行.** 正規表現/置換の挙動は `tests/autoreplacer/test_*.lua` に再現を書いてから。very magic (alternation `|` 等が bare で効く) と string/function 両 `with` を回帰で守る。
- **Windows 特性.** CI に `windows-latest`。`name_matches` のパス区切り / `nvim_buf_get_name` の正規化に注意。テストは `nvim -u NONE -l` で全 OS 共通。

## 移植元との差分 (denops 版からの設計変更)

- **eval(regex/template) を撲滅** → very-magic 正規表現 + string/function の `with`。
- config を filetype キーの map → **ルールのリスト** (filetypes / patterns / events / range / replace)。
- `${format(now, ...)}` の文字列 DSL → Lua 関数内の `os.date(...)`。
- `g:autoreplacer_config` グローバル → `setup()` テーブル。`debug` → `log_level` + notify ゲート。
