# CLAUDE.md -- dotfiles

Ted's shared user environment. Works on NixOS, Crostini, standalone linux, and macOS. See `docs/use-cases.md` and `docs/design.md` for full context.

## Key principles

1. One environment, all hosts. Platform differences handled by `contexts/`.
2. Symlinks over copies.
3. Single-file bash init -- one entry point (`init.bash`) replaces `.bashrc`, `.bash_profile`, `.profile`. Explicit mode detection, no hidden sourcing rules. Does not use `programs.bash`, but `home.sessionVariables`, `home.sessionPath`, and `programs.*` modules are used freely.
4. Idempotent deployment. `update-env` works on fresh or existing machines.
5. Nix for packages, dotfiles for config. `home.nix` says what to install. Dotfiles say how to configure.
6. Nix owns declarative, shell-independent config. Bash owns shell-evaluated, session-dependent behavior. Decision test: can it be expressed as static data without bash evaluating shell state? If yes -> nix. If no -> bash. See `docs/design.md` [Nix/bash boundary](docs/design.md#nixbash-boundary).

## Structure

- `shared.nix` -- shared packages, programs, and config imported by all contexts.
- `contexts/` -- platform overrides (crostini, linux, macos). Each has its own `home.nix` that imports `shared.nix` and adds platform-specific packages.
- `context` -- symlink at repo root pointing to active platform.
- Top-level `home.nix`, `gitconfig`, `tmux.conf` -- symlinks to the active context's versions.
- `bash/apps/<app>/` -- per-app modules with `init.bash` (hooks) and `cmds.bash` (aliases/functions).
- `bash/settings/` -- base, login, interactive, env, cmds.
- `claude/` -- Claude Code config. `settings.json` and `CLAUDE.md` (base) deployed via `home.file` in stage 1. `CLAUDE-era.md` (era, guides) and memory redirects deployed by update-env stage 2.
- `scripts/` -- vpn-connect, khal-notify, op-run launcher, and other utilities.
- `op-run/` -- 1Password credentialed-tool launcher: `projects.bash` (per-project credential registry, path-keyed), `machines/<hostname>.allow` (per-machine vault allowlist). See [op-run/README.md](op-run/README.md) for deployment, project onboarding, exit-code reference.
- `update-env` -- idempotent deployment script (lives in repo root, deployed to `~/.local/bin/`).

## Text encoding

ASCII only. No em-dashes, en-dashes, arrows, or fancy punctuation -- use `--`, `-`, `->`, etc. Exception: user-facing rendered output may use Unicode where it materially improves display (sparkline bars, panel glyphs, notification text). Allowed files: `scripts/load-sparkline`, `scripts/panel`, `scripts/khal-notify`.

## Making changes

- **Docs first, then implementation.** Update `docs/use-cases.md` and `docs/design.md` to describe the intended behavior before writing code. Red/green TDD the implementation per the Khorikov guide.
- **Packages:** shared packages go in `shared.nix`. Platform-specific packages go in the relevant `contexts/*/home.nix`. If a `programs.<name>` module exists, prefer that.
- **Env vars / PATH:** use `home.sessionVariables` or `home.sessionPath` in `shared.nix` -- they flow into the shell via `hm-session-vars.sh`, sourced directly by `init.bash`.
- **Shell integration / aliases / functions:** add a module under `bash/apps/`.
- **Shared packages are in `shared.nix`** -- no need to sync across contexts manually. Platform-specific packages go in individual context files.
- **Validate nix changes** with `nix-instantiate --parse` before committing. Use `home-manager build` for deeper validation (evaluates options and builds derivations).
- **Run `tesht`** before committing -- tests are configuration validation: they describe the intended shell environment and should fail when config drifts. Fix the config to satisfy the assertions; do not rewrite tests to match accidental behavior.
- **Calendar config and notify-send-bridge** live in `contexts/linux-base.nix`, imported by both `contexts/desktop/home.nix` and `contexts/crostini/home.nix`. macos imports `shared.nix` directly and skips this layer.
- **NixOS deployment:** `~/nixos-config/flake.nix` imports `contexts/desktop/home.nix` via a local path flake input. Changes take effect on nixos-rebuild without pushing first. System-level config belongs in nixos-config, not here. After changing dotfiles, run `nix flake update dotfiles` in `~/nixos-config` before rebuilding -- the flake lock caches a hash of the dotfiles directory and won't see changes until updated. **Never run `nix run ~/dotfiles#home-manager -- switch` on NixOS (calumny/caltrop)** -- home-manager runs as a NixOS module via nixos-rebuild; running the standalone HM applies the wrong generation and breaks Sway/waybar. The correct rebuild is `cd ~/nixos-config && mk switch` (or `nix build` then `sudo nixos-rebuild switch --flake .#<host>`).

## Development tools

- **`flake.nix`** -- home-manager configs (`crostini`, `debian`, `linux`, `macos`), lockfile-pinned bash tools, gpoc flake input, and multi-system dev shell. Enter dev shell with `nix develop`.
- **`mk`** -- project command runner (uses mk.bash). Subcommands:
  - `mk test` -- run tesht, create test badge
  - `mk cover` -- run kcov coverage (Linux only), create coverage badge
  - `mk lines` -- run scc source line count, create lines badge
  - `mk badges` -- run all three and create all badges
- **Coverage** -- kcov instruments bash and reports line coverage. `--include-path bash` scopes reporting to the `bash/` directory.
- **SLOC** -- scc counts source lines of code (the "Code" column in CSV output). `cmd.lines` targets `bash/` and `scripts/`.
- **Cyclomatic complexity** -- scc calculates this for bash (the "Complexity" column in CSV output). Available via `scc bash/ scripts/`.

## Docs

- `docs/use-cases.md` -- what this repo does and for whom.
- `docs/design.md` -- how components work, deployment flow, bash init flow.
- `docs/security.md` -- security model: threat actors, trust boundaries, confidentiality/integrity models, accepted risks.
- `docs/secrets-lifecycle.md` -- credential and secrets operational procedures: bootstrap, rotation, recovery.
- `docs/environment-lifecycle.md` -- environment lifecycle: bootstrap, maintenance, multi-machine sync, development workflow.
- `docs/uc-init.md` -- use cases for every init.bash feature employed in the config.
- Keep all updated when making changes. When changing credential handling, trust boundaries, or `~/secrets/` consumers, review `docs/security.md` and `docs/secrets-lifecycle.md` for sync.
