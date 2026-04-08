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
- Claude Code — settings managed via `home.file`
- Neovim — separate `dot_vim` repo

## Structure

```
shared.nix                      # Shared packages, programs, config (imported by all contexts)
home.nix                        # Symlink to active context's home.nix
claude/                         # Claude Code config: settings.json + CLAUDE.md (managed by home.file)
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

`update-env` takes a bare machine to fully configured. Lives in `~/projects/task.bash/update-env`, deployed to `~/.local/bin/`. Eight phases:

0. Git repo updates (conditional, subsequent runs)
1. System upgrades + SSH credentials (apt: crostini/debian only; credentials: crostini only)
2. Clone this repo, symlink dotfiles
3. Install Nix + home-manager (crostini/debian/linux/macos only — skipped on NixOS, system-managed there)
4. Platform-specific setup (crostini only)
5. Clone and link dev tools (fp.bash, mk.bash, task.bash, tesht)
6. VPN script, Neovim plugins, file manager config
7. SSH key generation (crostini/linux only)

Idempotent. Platform detection: macos → crostini → nixos/$HOSTNAME → debian → linux.

**Private repos** (e.g., jeeves) are cloned manually, not by update-env:
```bash
git clone git@bitbucket.org:accelecon/jeeves ~/projects/jeeves
```

On NixOS, `~/nixos-config/flake.nix` imports `home.nix` via flake input. Dotfile symlinks still deployed by `update-env`.

### Bash Init — UC-1

Custom. Does not use `programs.bash`. However, other `programs.*` modules and `home.sessionVariables`/`home.sessionPath` are used freely — principle 3 only prohibits HM managing bash startup files.

`bash/apps/home-manager/env.bash` is a symlink to `~/.nix-profile/etc/profile.d/hm-session-vars.sh`. This means `home.sessionVariables` and `home.sessionPath` flow into the custom init automatically during login.

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

Current app modules:
- `direnv` — custom PROMPT_COMMAND hook (appends, not prepends — ordering matters because `deps` declares liquidprompt first)
- `git` — 44 shell aliases + workflow functions (europe, wolf, venice, etc.)
- `home-manager` — symlink to `hm-session-vars.sh` (bridges `home.sessionVariables` into custom init)
- `keychain` — SSH agent via keychain eval (id_ed25519)
- `liquidprompt` — sources vendored prompt theme
- `mnencode` — randword function
- `pandoc` — shannon (markdown reformatter) function
- `stg` — 30+ stgit aliases + workflow functions

`bash/lib/`:
- `initutil.bash` — shell detection, sourcing helpers, IFS/globbing controls
- `apps.bash` — app module loader

See [uc-init.md](uc-init.md) for full use case documentation of the init system.

### Contexts — cross-cutting

`contexts/` holds platform overrides. A `context` symlink at repo root points to the active platform.

Each context can override `home.nix`, `gitconfig`, `tmux.conf`, and other configs. Top-level files like `gitconfig` and `home.nix` are symlinks to their context version.

Machine-specific contexts (e.g., `calumny`) symlink most files to their platform context (e.g., `../nixos/home.nix`) and add machine-specific config like `btop.conf`. This keeps platform config shared while allowing per-machine overrides. `update-env` conditionally links optional files like `btop.conf` only when the active context provides them.

### Packages — UC-1, UC-2, UC-3

Declared in `home.nix`. See the file for the current list. By category:

**Dev tools (UC-1):** git, neovim, tmux, stgit, gh, claude-code, jira-cli-go, scc, pandoc, diff-so-fancy, silver-searcher (ag), highlight, asciinema, asciinema-agg

**System/CLI (UC-3):** btop (linux uses bottom), htop, ncdu, jq, tree, rsync, coreutils, dig, zip, mnemonicode

**Wayland (UC-2):** wl-clipboard, cliphist, libnotify

**Apps (UC-2):** Firefox (via `programs.firefox`), Obsidian, signal-desktop

**VPN (UC-1):** openconnect, gp-saml-gui, vpn-slice

**Calendar (UC-1):** khal, vdirsyncer (linux and crostini — systemd integration)

**File management (UC-3):** ranger

### Programs managed by home-manager modules

Some tools use `programs.*` instead of `home.packages` for declarative config:

- `programs.direnv` — direnv + nix-direnv for `use flake` support. Bash integration disabled (custom hook in `bash/apps/direnv/init.bash`).
- `programs.bat` — default style via config file, no shell alias needed.
- `programs.firefox` — declarative search engine and extension policies.
- `programs.khal`, `programs.vdirsyncer` — calendar sync (linux and crostini).

### Session environment managed by nix

`home.sessionVariables` and `home.sessionPath` in `home.nix` can replace bash app modules for pure environment setup. Currently empty — available for future use.

### Firefox — UC-2

Managed via `programs.firefox` (home-manager module), not `home.packages`. This enables declarative profile and search engine configuration.

- Default search engine: DuckDuckGo (via `policies.SearchEngines.Default`)
- Extensions auto-installed via `policies.ExtensionSettings` with `force_installed`: uBlock Origin, Privacy Badger, Vimium
- All extensions enabled in private browsing (`private_browsing = true`)
- Uses policies instead of per-profile config — policies apply to all profiles regardless of profile path, which varies per machine
- Works on both NixOS (home-manager as NixOS module) and Debian/Crostini (standalone home-manager) — policies are baked into the wrapped Firefox package at build time

### VPN — UC-1

GlobalProtect VPN with Okta SAML SSO. Two packages:
- `openconnect` — CLI VPN client with `--protocol=gp` for GlobalProtect
- `gp-saml-gui` — opens browser for Okta login, extracts auth cookie for openconnect

Usage: `vpn-connect` (symlinked from `dotfiles/scripts/vpn-connect` to `~/.local/bin/`)

The script:
1. Opens gp-saml-gui WebKit window for Okta SAML login
2. Extracts auth cookie
3. Connects via openconnect with vpn-slice for split-tunnel routing

Split tunnel routes `stash.digi.com`, `dm1.idigi.com`, and `dm1.devdevicecloud.com` through VPN. All other traffic stays on normal internet. `dm1.devdevicecloud.com` resolves to public AWS IPs — vpn-slice routes them via the VPN gateway's whitelisted IP.

The `-s` argument uses the full nix profile path (`/etc/profiles/per-user/ted/bin/vpn-slice`) because openconnect runs as root via sudo, and root's PATH doesn't include ted's profile. Without the full path, root finds the system vpn-slice (without dnspython) and `/etc/hosts` entries don't get written.

Notes:
- Portal mode, not gateway (server returns portal-style cookie)
- `--authgroup="US East"` pre-selects gateway, avoids interactive prompt that conflicts with stdin pipe
- Uses built-in WebKit window (not `--external`, which doesn't render properly in Firefox)
- `vpn-slice` replaces vpnc-script — only specified hosts route through VPN
- NixOS requires `environment.etc.hosts.mode = "0644"` for vpn-slice to write `/etc/hosts`
- Passwordless sudo for openconnect via NixOS sudoers rule

### direnv — UC-1

Automatically loads project-specific environments when entering a directory with `.envrc`. Works with Nix devShells via `use flake` in `.envrc`.

Managed via `programs.direnv` with `nix-direnv.enable = true` for cached `use flake` support. HM bash integration is disabled (`enableBashIntegration = false`) because the custom init uses its own PROMPT_COMMAND hook in `bash/apps/direnv/init.bash`. The custom hook appends (not prepends) to PROMPT_COMMAND so it runs after liquidprompt, which is declared as a dependency in `bash/apps/direnv/deps`.

### DNS Diagnostics — UC-1

`dig` (from bind dnsutils) for hostname resolution troubleshooting, especially useful when debugging VPN split tunnel routing.

### GitHub CLI — UC-1

`gh` for PR management, repo operations, and issue tracking from the terminal.

### Calendar — UC-1

Work calendar synced from OWA via published ICS URL. Three components:

**vdirsyncer** syncs the ICS URL to `~/.calendars/work/` every 5 minutes (systemd timer). The ICS URL is a secret stored in `~/secrets/calendar-ics.url` — vdirsyncer reads it at runtime via `url.fetch = ["command", "cat", ...]` so the URL never appears in committed config.

**khal** reads the local calendar and expands recurring events, handling rescheduled instances (`RECURRENCE-ID`), cancellations (`EXDATE`), and timezone conversion. CLI: `khal list today`.

**khal-notify** (`scripts/khal-notify`) runs every minute via systemd timer, checks for events starting in 60, 30, 10, 5, or 1 minutes and sends desktop notifications via `notify-send` (displayed by mako on Sway, or via ChromeOS notifications on Crostini). The 5-minute and 1-minute notifications use critical urgency. A statefile (`~/.local/state/khal-notify/sent`) prevents duplicate notifications, cleaned daily.

Config lives in both `contexts/linux/home.nix` and `contexts/crostini/home.nix` using home-manager's `accounts.calendar`, `programs.khal`, `programs.vdirsyncer`, and `services.vdirsyncer` modules plus custom systemd units for khal-notify. On NixOS, the khal-notify ExecStart uses the `${dotfiles}` flake input path; on Crostini (standalone home-manager), it uses `${config.home.homeDirectory}/dotfiles/scripts/khal-notify`.

### Relationship to nixos-config

```nix
dotfiles = {
  url = "path:/home/ted/dotfiles";
  flake = false;
};
```

NixOS imports `"${dotfiles}/contexts/linux/home.nix"` directly (the `home.nix` symlink chain doesn't resolve in the nix store) and layers Sway on top. Package changes happen here. The local path input means changes take effect on `nixos-rebuild switch` without pushing to GitHub first.

## Resolved Questions

- On NixOS, home-manager runs as a NixOS module. Does `update-env` skip its home-manager phase? **Yes.** `platform()` detects NixOS via `/etc/NIXOS` (with host-specific context support via `$HOSTNAME`) and gates Phase 3 (Nix + home-manager install) to non-NixOS platforms only.
