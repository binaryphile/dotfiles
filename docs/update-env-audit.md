# update-env-audit

`update-env-audit` reports compliance state for `update-env` stage-1 convergence: are the declared symlinks present, do they point where update-env says they should, are retired binaries gone, is git's `hooksPath` configured on managed repos, do CLAUDE.md imports look right, are flake.lock nixpkgs revs aligned with the canonical pin?

It exists because the manual audit you do when you suspect drift takes 30 minutes and you only run it after something breaks. This runs the same checks in seconds and gives you an exit code suitable for CI / cron / a tray widget.

## Usage

```sh
update-env-audit              # text output, one line per finding
update-env-audit --json       # JSON array of {status, category, detail}
update-env-audit --help       # flags
```

Exit `0` if every finding is `OK`. Exit `1` if any finding is non-`OK` (drift detected). The exit code never silently lies: a clean `OK` report exits 0, a single `DRIFT` exits 1.

## What it checks (v1)

Seven categories. Each pushes findings into a single flat list.

| Category | What it catches |
|---|---|
| `phase1Symlinks` | Missing `~/.bashrc`, `~/.profile`, `~/.bash_profile`, `~/.shellcheckrc`, `~/config`, `~/local`, `~/ssh`, `~/.netrc`, `~/dotfiles/context` |
| `binSymlinksBroken` | Dangling symlinks under `~/.local/bin/` (link exists but target doesn't — the class that retired-script removals leave behind) |
| `binSymlinksTargets` | Bin symlinks pointing somewhere update-env doesn't declare (wrong-target-but-valid drift) |
| `retiredBinaries` | Known-dead paths still present (e.g., `~/.local/bin/mk` after 2026-06-01, `~/.claude/commands/g.md`) |
| `gitHooksPath` | Managed repos (`dotfiles`, `jeeves`, `finances`) without `core.hooksPath=.githooks` |
| `claudeMdMarkers` | Missing era / tesht / tandem-protocol grep markers in `~/.claude/CLAUDE.md` |
| `flakeLockCanonical` | nixpkgs rev drift across all `flake.lock` files in `~/projects/*` + `~/dotfiles` vs era's canonical |

## Status taxonomy

Five exact prefixes; that's the whole vocabulary:

- **`OK`** — check passed
- **`MISSING`** — a declared artifact is absent
- **`BROKEN`** — symlink exists, target doesn't
- **`RESIDUAL`** — retired artifact still present (should be removed)
- **`DRIFT`** — present but disagrees with the declared / canonical value

In text mode each finding renders as `[STATUS] category: detail`. In JSON each is an object with `status`, `category`, `detail` fields. No envelope; the document root is the array.

## Source of truth

For the bin-symlink categories (`binSymlinksBroken`, `binSymlinksTargets`), the expected (source, link) pairs come from parsing `update-env`'s own `task.Ln` lines at audit-run time. If update-env adds or removes a `task.Ln` call, the next audit picks it up. There's no hand-maintained table that can drift.

## Deferred (v2 follow-up)

These categories were scoped out of v1 to keep the cycle bounded. The follow-up task tracks them: per-project shellcheckrc, MCP registration, slash-commands globs, memory redirects, agent.toml presence, per-project nix-wrapper, systemd services, op-run/checksums, project-clones-present (the full 23-directory list).

## See also

- Use case: `docs/use-cases.md` UC-15
- Design notes: `docs/design.md` § update-env-audit (UC-15)
- Companion fix: `update-env` task.Ln-hardening amendments and `task.bash` literal-target-equality predicate (tasks.jeeves #18178) ensure stage-1 convergence is deterministic; this script audits whether convergence actually happened.
