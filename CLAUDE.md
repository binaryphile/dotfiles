# CLAUDE.md — dotfiles

Ted's shared user environment. Works on NixOS and Crostini. See `docs/use-cases.md` and `docs/design.md` for full context.

## Key principles

1. One environment, all hosts. Platform differences handled by `contexts/`.
2. Symlinks over copies.
3. Custom bash init — not home-manager's `programs.bash`.
4. Nix for packages, dotfiles for config. `home.nix` says what to install. Dotfiles say how to configure.

## Structure

- `contexts/` — platform overrides (crostini, linux, macos, nixos). Each has its own `home.nix`.
- `context` — symlink at repo root pointing to active platform.
- Top-level `home.nix`, `gitconfig`, `tmux.conf` — symlinks to the active context's versions.
- `bash/apps/<app>/` — per-app modules with `env.bash`, `init.bash`, `cmds.bash`, `detect.bash`, `deps`.
- `bash/settings/` — base, login, interactive, env, cmds.
- `scripts/update-env` — idempotent deployment script.

## Making changes

- **Packages:** add to `home.packages` in all relevant `contexts/*/home.nix` files. Some apps (e.g., Firefox) use `programs.<name>` instead.
- **App config:** if it needs shell integration, add a module under `bash/apps/`.
- **All contexts must stay in sync** for shared packages. Platform-specific packages go in comments or conditionals within individual context files.
- **Validate nix changes** with `nix-instantiate --parse` before committing.
- **NixOS note:** `~/nixos-config/flake.nix` imports `contexts/linux/home.nix` via a local path flake input pointing to `~/dotfiles`. Changes take effect on `sudo nixos-rebuild switch` without pushing first. System-level config belongs in nixos-config, not here. **Important:** after changing dotfiles, run `nix flake update dotfiles` in `~/nixos-config` before `nixos-rebuild switch` — the flake lock caches a hash of the dotfiles directory and won't see changes until updated.

## Docs

- `docs/use-cases.md` — what this repo does and for whom.
- `docs/design.md` — how components work, deployment phases, bash init flow.
- Keep both updated when making changes.
