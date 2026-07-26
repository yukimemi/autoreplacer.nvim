# AGENTS.md

Guidance for AI agents (Claude / Codex / Gemini) working in this
repo. The yukimemi/* shared conventions live in the
`<!-- kata:agents:* -->` blocks below, sourced from
`yukimemi/pj-base` / `pj-nvim` via `kata apply` — see those for git
workflow, PR review cycle, test / lint commands, and renri's worktree
usage.

The sections above the marker blocks are autoreplacer-specific and
consumer-owned: edit them freely; `kata apply` won't touch them.

## コンセプト

- **denops 廃止・pure Lua / Neovim 専用**: [`autoreplacer.vim`](https://github.com/yukimemi/autoreplacer.vim) (denops/Deno) の後継。保存時 (など) に正規表現の置換ルールをバッファへ適用する (`Last Change:` のタイムスタンプ更新、`version = "..."` のバンプ等)。
- **eval DSL 廃止**: 旧版は正規表現文字列と置換テンプレを `eval()` していた。新版は **pattern = 普通の正規表現** (very magic `\v` を自動付与) + **with = string テンプレ or Lua 関数**。任意コード実行なし。
- **設定はテーブル一本**: `g:autoreplacer_*` グローバルは全廃。`require("autoreplacer").setup({...})` のみ。`config.lua` に `M.defaults` + LuaCATS。`rules` はリストなので tbl_deep_extend の index マージを避け、ユーザ指定時は **verbatim 置換** する (`config.setup` 参照)。
- **Convention over Configuration**: `plugin/autoreplacer.lua` が `:AutoReplacer*` を eager 登録。自動置換 (autocmd) だけ `setup()` 起点。
- **Notify ゲート契約**: background ログは `lua/autoreplacer/log.lua` の `M.at/info/warn` 経由。`notify = false` で無音。ユーザ起点コマンドのみ `log.echo`。

## テストが mini.test である理由

一般的なテスト / lint コマンドは下の `kata:agents:nvim:*` ブロックにある。ここに
書くのは **この選択の背景** だけ。

`nvim -u NONE -l scripts/run_tests.lua` で走らせるため、子プロセスがユーザの
`~/.config/nvim/init.lua` を読まない。plenary の `PlenaryBustedFile` は子 nvim を
spawn する際に `-u` を引き継がないので、ユーザ環境によっては作業ツリーではなく
rtp 上の**古いコピー**を読んでテストが通ってしまう事故が起きる。

補足: 以前このファイルには「plenary は 2026-06-30 アーカイブ」と書かれていたが、
これは誤り。plenary は現在もアーカイブされていない (`archived=false`、最終 push
2026-04-10)。採用理由は上記の実行モデルであって、上流の生死ではない。

spec ファイル名は mini.test 既定の **`test_*.lua`** (plenary の `*_spec.lua` ではない)。

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
deps/                       — CI が clone するテスト依存 (mini.nvim)。gitignore 済み
.github/workflows/ci.yml    — kata-managed (yukimemi/pj-nvim)。3 OS × stable/nightly + stylua lint
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

<!-- kata:agents:base:begin -->
## Shared conventions

This file is the agent-agnostic source of truth (per the
[agents.md](https://agents.md) convention). The matching
`CLAUDE.md` and `GEMINI.md` files are thin shims that point back
here so each tool's auto-load behaviour still finds something.
**Edit AGENTS.md, not the shims.**

### Git workflow

- **No direct push to `main`.** Open a PR.
  - Exception: trivial typo / whitespace / docs wording fixes.
- Branch names: `feat/...`, `fix/...`, `chore/...`.
- **PR titles + bodies in English. Commit messages in English.**
- **Releases are PR-driven, tagging is automatic.** Bump
  `[workspace.package].version` (workspace) or `[package].version`
  (single crate) in a `chore/release-vX.Y.Z` PR. On merge to `main`,
  `.github/workflows/auto-tag.yml` (kata-managed) detects the bump,
  pushes the `vX.Y.Z` tag, and that tag fires `release.yml` for
  binary builds + crates.io publish. **Do not run `git tag` by
  hand** — the bot tag will collide and the manual push fails.

### PR review cycle

- Every PR runs reviews from **Claude Code**
  (`.github/workflows/claude-review.yml`, kata-managed) and
  **CodeRabbit**. Wait for both bots to post, address their
  comments (push fixes to the PR branch), and merge only after
  feedback is resolved. The claude-review workflow skips
  review-exempt PRs by itself (its job-level `if:` excludes
  `chore/release-*`, `kata-apply/auto`, `apm-bump/auto`, and
  Renovate / Dependabot authors) — a missing Claude review on
  those PRs is expected, not a failure.
- **The PR that first adopts these templates cannot review
  itself.** `claude-code-action` requires the workflow file to
  already exist on the default branch with identical content
  (otherwise a PR could rewrite the workflow to exfiltrate the
  token), so on the adoption PR it logs "Skipping action due to
  workflow validation" and exits 0 without reviewing — a green
  check with no review attached. Expected: merge on CI + owner
  approval, and the workflow starts working from the next PR on.
  If the repo has neither `CLAUDE_CODE_OAUTH_TOKEN` nor
  `ANTHROPIC_API_KEY` set, the credential guard fails the job
  loudly instead — set one and re-run (subscription path:
  `claude setup-token` → `gh secret set`; pay-as-you-go: store
  `ANTHROPIC_API_KEY` and swap the action input to
  `anthropic_api_key`).
- **The Claude full review fires once, at PR open** (plus
  `ready_for_review` / `reopened`) — fix pushes do **not** re-trigger
  it (`synchronize` is deliberately off the trigger list; a full
  re-review per push doubled up with the mention-driven re-check
  below and burned tokens for no extra signal). Verification of
  fixes rides the `@claude` thread replies. After a large rework
  that changes the PR's shape, request a fresh full pass
  explicitly: `@claude please re-review the full PR`. CodeRabbit
  still reviews pushes on its own cadence (its app config, not
  this workflow).
- **After opening a PR, immediately enter the review-monitoring
  loop — do not ask the user whether to start it.** Drive the
  cadence with `/loop` — fixed-interval mode (e.g.
  `/loop 60s …`) schedules ticks via `CronCreate`; dynamic mode
  (no interval, `/loop …`) self-paces via `ScheduleWakeup`. The
  agent actively pulls fresh state each tick with
  `gh pr view <N> --json state,reviews,comments,statusCheckRollup`
  and `gh api repos/<owner>/<repo>/pulls/<N>/comments` (the
  latter covers inline review comments, which `gh pr view`
  does not surface) and reacts to new bot feedback. Passive
  watchers (background `gh` polls, file watchers, hooks) cannot
  trigger active follow-up, so they are not a substitute —
  without an active wake-up the agent never re-reads the PR.
- **Default polling interval: 60s.** Claude Code review /
  CodeRabbit typically reply within ~1–5 minutes of a push or
  thread reply, so a 60s tick catches them on the next wake-up
  without burning cache: 60s sits well inside the 5-minute
  prompt-cache TTL, so the conversation context stays cached
  across ticks. Do **not** stretch the interval to 300s — that
  is the worst-of-both window (you pay the cache miss without
  amortizing it). If the PR is idle but a bot re-review is still
  expected (e.g. a CodeRabbit rate-limit refill window), step
  **up** to 1200–1800s instead.
- **Stop the loop entirely when only owner approval is missing.**
  Once review bots are quiet (or quiet-by-exception — version-bump
  skip, Renovate/Dependabot skip), CI is green, and there is no
  other expected follow-up, the *only* remaining action is human
  approval. GitHub already notifies the owner; the agent
  re-entering on every cron tick to find the same "still waiting
  on owner" state burns cache and adds no value. Stop scheduling
  further wake-ups (`CronDelete` in fixed-interval mode; simply
  omit the next `ScheduleWakeup` in dynamic mode) and report the
  wait state to the user. The owner restarts the loop after their
  next push if a fresh bot pass is wanted, or merges directly.
  (A CodeRabbit rate-limit window doesn't qualify on its own — a
  re-review is still expected once the quota refills, so step up
  to 1200–1800s instead and let it ride. Stopping is only correct
  when the owner has explicitly chosen to skip the bot pass per
  the rate-limit exception below.)
- **Reply to reviewers after pushing a fix — in each thread, not
  at the top level.** Every finding lives in its own inline review
  thread; answer *each* one as an in-thread reply, carrying an
  **@-mention** (`@claude` / `@coderabbitai`). Use the review-
  comment *replies* endpoint — `gh api repos/<owner>/<repo>/pulls/<N>/comments/<comment_id>/replies -f body=…`
  (or `-F in_reply_to=<comment_id> -f body=…` on the comments
  endpoint — `body` is required there too) — and
  get each comment's `<comment_id>` from
  `gh api repos/<owner>/<repo>/pulls/<N>/comments`. A single
  top-level `gh pr comment` does **not** count: it leaves every
  inline thread unresolved, the bot can't tie your response to the
  finding it raised, and the per-finding audit trail is lost.
  Reply in-thread even when you're **declining** a suggestion —
  say why; a silent skip reads as overlooked. Note `@claude` also
  triggers the interactive responder
  (`.github/workflows/claude.yml`, kata-managed) — it will
  re-check the fix and reply on the thread. Since fix pushes no
  longer re-trigger the full review, this mention-driven re-check
  is the **only** Claude-side verification of a fix — don't skip
  it for substantive fixes; do skip it for pure FYI notes that
  need no verification.
- A review thread is **settled** the moment the latest bot reply
  is ack-only ("Thank you" / "Understood" / a re-review summary
  with no new findings) or 30 minutes elapse with no actionable
  comment.
- **Merge gate**: review bots quiet AND owner explicit approval.
- Bot-authored PRs (Renovate / Dependabot) skip the bot-review
  gate; CI green + owner approval is enough.
- **Version-bump-only PRs** (a single `chore/release-vX.Y.Z`
  branch whose entire diff is `[workspace.package].version` /
  `[package].version` + the matching inter-crate refs +
  `Cargo.lock`) **also skip the bot-review gate.** There is
  nothing for the bots to find in a version bump, and the
  release pipeline downstream of merge (auto-tag → release.yml)
  is time-sensitive. CI green + owner approval is enough.
- **Treat CodeRabbit rate-limit notices as "quiet" for the
  merge gate.** If CodeRabbit only posts a "Review limit
  reached" quota-exhaustion message (no findings, no inline
  comments), it has produced no review content — there is
  nothing to address. Re-trigger with `@coderabbitai review`
  once the quota refills if you want a real pass; for small or
  time-sensitive PRs, merge on owner approval without waiting.

### Worktree workflow

> **Before your FIRST edit to any file, run `renri add` — NEVER edit the
> main checkout.** Read-only inspection (Read / Grep / Glob) stays on the
> main checkout; the instant you intend to *change* a file, you must
> already be in a worktree. The trap that keeps catching agents: diving
> into a fix the moment the diagnosis lands and editing in place. A
> concurrent agent shares the main checkout — your in-place edits will
> clobber theirs or be clobbered, and in a jj-colocated repo a stray
> working-copy commit entangles unrelated WIP into your branch. If you
> slip and edit in the main checkout, capture the diff first (jj already
> snapshotted it into the working-copy commit, so `jj diff > patch`; for
> git, `git stash` or save a patch — if you got as far as committing on a
> branch, just push it). Then reset the main checkout to pristine main
> (`jj new main@origin`, or `git switch -`), `renri add` a worktree, and
> re-apply the captured diff there.

Use [`renri`](https://github.com/yukimemi/renri) for any
commit-bound change. From the main checkout:

```sh
renri add <branch-name> --from main@origin            # create a worktree (jj-first), off latest upstream main
renri --vcs git add <branch-name> --from origin/main  # force a git worktree, off latest upstream main
renri remove <branch-name> -y --non-interactive  # cleanup after merge (agent-safe; see note)
renri prune                        # GC stale worktrees
```

Read-only inspection can stay on the main checkout.

**Always pass `--from <upstream main>`** (`main@origin` for jj,
`origin/main` for git). Without it, `renri add` forks off the *cwd
worktree's current HEAD* — in a long-lived main checkout that often
lags upstream, so the PR later shows up CONFLICTING against a `main`
that had already moved (e.g. a refactor merged upstream before the
branch was cut), forcing a manual re-port of the whole change.
`renri add` does fetch first, but fetching only updates `main@origin`
— it never moves the checkout's HEAD, so an explicit `--from` is what
guarantees a fresh base.

**Agents / non-interactive shells:** `renri remove` prints a details
panel and waits for a confirmation prompt — without `-y` it **hangs**,
and `--non-interactive` *alone* errors asking for `-y`. Always pass
`-y`, and add `--non-interactive` so a mistyped/omitted name fails
instead of opening a fuzzy picker (the same picker-fallback applies to
`remove` / `cd` / `exec` with no name). Use `-f`/`--force` to remove a
worktree that still has uncommitted changes or conflicts. To sweep
every merged-PR worktree in one shot: `renri remove --merged -y`.

### kata-managed sections

Several files in this repo are managed by `kata apply` from the
[`yukimemi/pj-presets`](https://github.com/yukimemi/pj-presets)
templates — the bytes between `<!-- kata:*:begin -->` and
`<!-- kata:*:end -->` markers, plus the overwrite-always files
listed in `.kata/applied.toml`. **Editing those bytes locally
won't survive the next `kata apply`** — push the change to the
upstream template repo (`yukimemi/pj-base` / `yukimemi/pj-rust` /
…) instead. The marker scopes are layered:

- `kata:agents:base:*` — language-agnostic conventions (this section).
- `kata:agents:rust:*` — added when `pj-rust` applies.
- `kata:agents:rust-cli:*` — added when `pj-rust-cli` applies.
<!-- kata:agents:base:end -->
<!-- kata:agents:nvim:begin -->
### Neovim plugin workflow

This repo follows the shared Neovim plugin conventions. The
language-agnostic conventions block above (`kata:agents:base:*`)
covers git workflow, PR review cycle, and worktree usage.

### Test / lint

There is no build step — Lua is interpreted, so the whole gate is
"tests pass and stylua is clean":

```sh
stylua --check .                    # format gate (what CI runs)
stylua .                            # apply formatting
```

Tests run through Neovim itself, one file per invocation. Which
framework is in play depends on `nvim.test_runner` in
`.kata/vars.toml`:

```sh
# test_runner = "mini"  (deps/mini.nvim)
nvim -u NONE -l scripts/run_tests.lua tests/<plugin>/test_foo.lua

# test_runner = "plenary"  (deps/plenary.nvim)
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/<plugin>/foo_spec.lua"
```

**Run one file per `nvim` invocation, and match CI's discovery
pattern.** CI enumerates specs with `find tests -type f -name …` and
loops in the shell rather than letting the framework walk the
directory: `PlenaryBustedDirectory` spawns `pwsh` on Windows runners
to enumerate files, and pwsh's ~5s startup blows plenary's internal
timeout. A file-at-a-time loop behaves identically on all three OSes
and keeps a crash in one spec from taking the rest of the suite with
it.

### Test dependencies live in `deps/`

CI clones the framework into `deps/mini.nvim` or `deps/plenary.nvim`.
Keep `deps/` out of the repo (it is in `.gitignore`) and out of
formatting (`.styluaignore`). If your `minimal_init.lua` hardcodes a
different path, fix the init file rather than the workflow — the
workflow is kata-managed and a local edit will be reverted.

### Neovim version support

CI runs the full matrix: `ubuntu` / `macos` / `windows` x `stable` /
`nightly`. A nightly-only failure is still a failure — either guard
the API behind a version check or fix the call. Don't reach for a
newer API without confirming it exists on `stable`; `vim.fn.has()` or
a `pcall` around the lookup is the usual guard.

### Lint / format policy

`.stylua.toml` is kata-managed (sourced from `yukimemi/pj-nvim`).
Edits to it in this repo won't survive the next `kata apply`; if a
setting is wrong, push the fix to `yukimemi/pj-nvim` so every Neovim
plugin using these templates picks it up. `.styluaignore` is
consumer-owned after the first apply — extend it freely.

### CI workflow

`.github/workflows/ci.yml` is kata-managed. The source lives in
`yukimemi/pj-nvim/.github/workflows/ci.yml.tera` (the `.tera` suffix
keeps GitHub Actions from running the source inside pj-nvim itself
and opts the file into kata's Tera rendering). Action versions are
pinned in `.kata/vars.toml` and bumped by Renovate, so don't edit
them inline in the workflow — the bump would be clobbered on the
next apply.
<!-- kata:agents:nvim:end -->
