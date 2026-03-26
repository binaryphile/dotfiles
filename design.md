# Dotfiles Design

How this repo satisfies [use-cases.md](use-cases.md).

Ted's shared user environment. Works on all hosts. NixOS system and Sway design: `~/nixos-config/design.md`.

## Principles

1. **One environment, all hosts.** Same config on NixOS and Crostini. Platform differences handled by `contexts/`.
2. **Symlinks over copies.** Configs live here. Home directory gets symlinks.
3. **Custom bash init.** Not home-manager's `programs.bash`. Each app manages its own env, init, and commands.
4. **Idempotent deployment.** `update-env` works on fresh or existing machines. Converges to desired state.
5. **Nix for packages, dotfiles for config.** `home.nix` says what to install. Dotfiles say how to configure.

## What this repo owns

- `home.nix` — package list, session variables
- Bash — custom app-based init system
- Git — identity, aliases, global ignore
- Tmux, SSH, Ranger, Liquidprompt — platform-aware via `contexts/`
- Neovim — separate `dot_vim` repo

## Structure

```
home.nix                        # Packages, session vars
bash/
  init.bash                     # Entry point → .bashrc, .bash_profile, .profile
  apps/                         # Per-app modules (env, init, cmds, deps)
  settings/                     # Base, login, interactive, env, cmds
  lib/                          # Init system internals
contexts/                       # Platform overrides (crostini, linux, macos)
gitconfig, gitignore_global     # Git
tmux.conf                       # Context-dependent symlink
ssh/                            # Client config
ranger/                         # File manager
liquidprompt/                   # Prompt theme
scripts/                        # Setup utilities
```

## Component Design

### Deployment — UC-4

`update-env` takes a bare machine to fully configured. Seven phases:

1. Git repo updates (conditional, subsequent runs)
2. System upgrades + SSH credentials
3. Clone this repo, symlink dotfiles
4. Install Nix (via Lix), install home-manager, run `home-manager switch`
5. Clone and link dev tools (fp.bash, mk.bash, task.bash, tesht)
6. VPN client, Neovim plugins, file manager config
7. SSH key generation (ed25519, with passphrases)

Idempotent. Platform detection via task.bash APIs. NixOS skips Nix install and apt. Needs updates for full NixOS support.

On NixOS, `~/nixos-config/flake.nix` imports `home.nix` via flake input. Dotfile symlinks still deployed by `update-env`.

### Bash Init — UC-1

Custom. Does not use `programs.bash`.

`bash/init.bash` is symlinked to `.bashrc`, `.bash_profile`, `.profile`. Single entry point for all shell modes. Supports `source ~/.bashrc reload` for live reloading.

Init flow:
1. Resolve repo root via symlink
2. Source `lib/initutil.bash` (shell detection, sourcing helpers, `SplitSpace`/`Globbing` controls)
3. Login or reload → source `settings/env.bash`
4. Source `context/init.bash` (platform-specific, if present)
5. Source `lib/apps.bash` (loads all app modules)
6. Source `settings/base.bash`, `settings/cmds.bash`
7. Interactive → source `settings/interactive.bash`
8. Interactive login or reload → source `settings/login.bash`

Each app gets a directory under `bash/apps/<app>/` with optional files:
- `env.bash` — variables (all shells)
- `detect.bash` — availability check
- `init.bash` — setup (interactive)
- `cmds.bash` — aliases and functions (interactive)
- `deps` — dependencies on other app modules

`bash/lib/`:
- `initutil.bash` — shell detection, sourcing helpers, IFS/globbing controls
- `apps.bash` — app module loader
- `truth.bash` — boolean utilities
- `validate.bash`, `validate-apps.bash` — config validation

### Contexts — cross-cutting

`contexts/` holds platform overrides. A `context` symlink at repo root points to the active platform.

Each context can override `home.nix`, `gitconfig`, `tmux.conf`, and other configs. Top-level files like `gitconfig` and `home.nix` are symlinks to their context version.

### Packages — UC-1, UC-2, UC-3

Declared in `home.nix`. See the file for the current list.

### VPN — UC-1

GlobalProtect VPN with Okta SAML SSO. Two packages:
- `openconnect` — CLI VPN client with `--protocol=gp` for GlobalProtect
- `gp-saml-gui` — opens browser for Okta login, extracts auth cookie for openconnect

Workflow:
```bash
eval $(gp-saml-gui --portal --clientos=Windows --external access.digi.com)
echo "$COOKIE" | sudo openconnect --protocol=gp -u "$USER" --os="$OS" \
  --usergroup=gateway:"$PRELOGIN" --passwd-on-stdin "$HOST"
```

`--external` uses Firefox (for 1Password extension) instead of built-in WebKit.

### Relationship to nixos-config

```nix
dotfiles = {
  url = "github:binaryphile/dotfiles";
  flake = false;
};
```

NixOS imports `"${dotfiles}/contexts/linux/home.nix"` directly (the `home.nix` symlink chain doesn't resolve in the nix store) and layers Sway on top. Package changes happen here.

## Open Questions

- Does the `linux` context work for NixOS, or does NixOS need its own?
- On NixOS, home-manager runs as a NixOS module. Does `update-env` skip its home-manager phase?
