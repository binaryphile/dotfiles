# Feature request: per-session CLAUDE.md override

## Motivation

Operators with heavy `~/.claude/CLAUDE.md` pay full boot cost on every
session even when the session is narrowly scoped. In the current dotfiles
setup, the full user-level CLAUDE.md loads `@~/projects/era/docs/evtctl.md`
(55KB), `@~/projects/era/docs/era.md` (144KB), and
`@~/projects/tandem-protocol/README.md` (52KB) -- approximately 259KB of
imported reference content on top of the 7KB base file. Orchestrator sessions
only need a subset: evtctl dispatch commands, grade ceremony shape, and era
memory discipline. Tesht docs, full era.md internals, and Phase 1-4 ceremony
detail are unnecessary overhead for that session type.

## Proposed mechanism

Per-session override via one of (in preference order):

1. `--memory <path>` CLI flag specifying an alternate CLAUDE.md
2. `CLAUDE_USER_MEMORY` env var pointing to an alternate path
3. `userMemoryPath` field in `settings.json`

Behavior: replace the user-level `~/.claude/CLAUDE.md` load with the
specified file for that session only. Project-level `.claude/CLAUDE.md` and
`.claude.local.md` continue to load additively as today.

## Current workaround

This cycle (icarus #54856) implemented a file-swap mechanism via
`update-env --claude-mode {full,thin}`:

- `--claude-mode thin` deploys `claude/CLAUDE-thin.md` (10.8KB pre-composed,
  no `@` imports) to `~/.claude/CLAUDE.md`, replacing the full version.
- `--claude-mode full` (default) deploys `claude/CLAUDE.md` with the full
  import chain.
- A 2-field tab-separated sentinel (`<source_path>\t<sha256>`) tracks which
  source is deployed. A mode switch triggers re-deploy; same-source/hash
  skips the copy.
- Append tasks (`claudeEraConfigTask`, `claudeTeshtConfigTask`,
  `claudeTandemConfigTask`) skip in thin mode via a shared guard
  (`claudeModeSkipIfThin`).
- `claude-mode` helper reads the sentinel and prints `full`, `thin`, or
  `unknown (...)` for discoverability.

The workaround has two trade-offs:

1. **Mode is window-scoped, not session-scoped.** `update-env --claude-mode thin`
   switches the deployment for ALL subsequent sessions until `update-env
   --claude-mode full` restores it. There is no mechanism to run one session
   in thin mode while keeping another in full mode simultaneously.
2. **Mode requires an explicit update-env invocation.** Operators must remember
   to switch, and must switch back. The default-full safety property (thin
   only when explicitly passed) prevents accidental deployment, but increases
   friction for workflows that switch modes frequently.

A per-session `--memory` flag (or env var) would eliminate both trade-offs:
the operator passes it on the `claude` invocation and never touches the
deployed `~/.claude/CLAUDE.md`.

## Use case

Multi-mode workflows where the session purpose is known at launch:

- "investigation" sessions: full reference loaded (era.md internals,
  evtctl back-compat, tesht docs all relevant)
- "orchestrator" sessions: slim reference (dispatch loop, grade ceremony
  shape, era memory discipline -- enough to drive cycles end-to-end without
  loading developer-tool docs)

Operators on metered plans (e.g., Pro 5h rolling window) benefit from
avoiding boot cost on large import chains when the session doesn't use them.
The degree of benefit is measurable once a per-session `cache_creation`
capture mechanism lands (tracked separately in icarus #55085 -- prerequisite
for empirical A/B comparison of full vs thin deployment modes).

## Operator-visible size delta (this cycle's measurement)

- Full mode source: `claude/CLAUDE.md` (7.4KB) + `@` imports at runtime
  (~259KB imported content per `wc -c` on evtctl.md + era.md + tandem-protocol/README.md)
- Thin mode source: `claude/CLAUDE-thin.md` (10.8KB, no imports)

The thin file was authored to cover the orchestrator dispatch loop without
importing large reference docs. The empirical cache_creation delta between
the two modes cannot be measured from this cycle's implementation alone --
see icarus #55085.
