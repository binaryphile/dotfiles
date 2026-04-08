# CLAUDE.md — dotfiles

Ted's shared user environment. Works on NixOS and Crostini. See `docs/use-cases.md` and `docs/design.md` for full context.

## Key principles

1. One environment, all hosts. Platform differences handled by `contexts/`.
2. Symlinks over copies.
3. Single-file bash init — one entry point (`init.bash`) replaces `.bashrc`, `.bash_profile`, and `.profile`. The conventional three-file model hides complexity behind an opaque sourcing taxonomy; init.bash makes every mode decision explicit and readable. Does not use `programs.bash`, but `home.sessionVariables`, `home.sessionPath`, and `programs.*` modules are used freely.
4. Nix for packages, dotfiles for config. `home.nix` says what to install. Dotfiles say how to configure. Pure env vars and PATH go in `home.sessionVariables`/`home.sessionPath`; interactive shell logic stays in bash.

## Structure

- `shared.nix` — shared packages, programs, and config imported by all contexts.
- `contexts/` — platform overrides (crostini, linux, macos). Each has its own `home.nix` that imports `shared.nix` and adds platform-specific packages.
- `context` — symlink at repo root pointing to active platform.
- Top-level `home.nix`, `gitconfig`, `tmux.conf` — symlinks to the active context's versions.
- `bash/apps/<app>/` — per-app modules with `env.bash`, `init.bash`, `cmds.bash`, `detect.bash`, `deps`.
- `bash/settings/` — base, login, interactive, env, cmds.
- `claude/` — Claude Code config (`settings.json`, `CLAUDE.md`), deployed via `home.file`.
- `scripts/` — vpn-connect, khal-notify, and other utilities.
- `update-env` — idempotent deployment script (lives in `~/projects/task.bash/`, deployed to `~/.local/bin/`).

## Making changes

- **Packages:** shared packages go in `shared.nix`. Platform-specific packages go in the relevant `contexts/*/home.nix`. If a `programs.<name>` module exists, prefer that.
- **Env vars / PATH:** use `home.sessionVariables` or `home.sessionPath` — they flow into the custom init via `bash/apps/home-manager/env.bash` (symlink to `hm-session-vars.sh`).
- **Shell integration / aliases / functions:** add a module under `bash/apps/`.
- **Shared packages are in `shared.nix`** — no need to sync across contexts manually. Platform-specific packages go in individual context files.
- **Validate nix changes** with `nix-instantiate --parse` before committing. Use `home-manager build` for deeper validation (evaluates options and builds derivations).
- **Run `tesht`** before committing — tests are configuration validation: they describe the intended shell environment and should fail when config drifts. Fix the config to satisfy the assertions; do not rewrite tests to match accidental behavior.
- **Calendar config** lives in both `contexts/linux/home.nix` and `contexts/crostini/home.nix`. Changes should be synced between them.
- **NixOS note:** `~/nixos-config/flake.nix` imports `contexts/linux/home.nix` via a local path flake input pointing to `~/dotfiles`. Changes take effect on `sudo nixos-rebuild switch` without pushing first. System-level config belongs in nixos-config, not here. **Important:** after changing dotfiles, run `nix flake update dotfiles` in `~/nixos-config` before `nixos-rebuild switch` — the flake lock caches a hash of the dotfiles directory and won't see changes until updated.

## Docs

- `docs/use-cases.md` — what this repo does and for whom.
- `docs/design.md` — how components work, deployment phases, bash init flow.
- `docs/uc-init.md` — use cases for every init.bash feature employed in the config.
- Keep all updated when making changes.
