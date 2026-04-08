# Dotfiles Design

How this repo satisfies [use-cases.md](use-cases.md).

Ted's shared user environment. Works on all hosts. NixOS system and Sway design: `~/nixos-config/design.md`.

## Principles

1. **One environment, all hosts.** Same config on NixOS and Crostini. Platform differences handled by `contexts/`.
2. **Symlinks over copies.** Configs live here. Home directory gets symlinks.
3. **Single-file bash init.** One entry point replaces `.bashrc`, `.bash_profile`, `.profile`. Explicit mode detection, no hidden sourcing rules. See [Why a single entry point](#why-a-single-entry-point).
4. **Idempotent deployment.** `update-env` works on fresh or existing machines. Converges to desired state.
5. **Nix for packages, dotfiles for config.** `home.nix` says what to install. Dotfiles say how to configure.
6. **Nix owns declarative config. Bash owns shell-evaluated behavior.** Decision test: can this be expressed as static data or generated config without bash evaluating shell state? If yes → nix. If no → bash. See [Nix/bash boundary](#nixbash-boundary).

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

#### Why a single entry point

The conventional bash init model splits startup across `.profile`, `.bash_profile`, and `.bashrc`. Which file runs depends on an interaction of login vs non-login, interactive vs non-interactive, bash vs sh, local vs remote — a sourcing taxonomy complex enough that even experienced engineers cannot reliably state the full rules. The result is shell behavior that is difficult to predict, debug, or control.

`init.bash` replaces all three files with a single entry point. Mode detection is explicit (`ShellIsLogin`, `ShellIsInteractive`, `Reload`) and every sourcing decision is visible in the code. No hidden file-selection rules, no "bash checks for .bash_profile first but falls back to .profile unless..." — the user reads one file and knows exactly what runs when.

This design does not use `programs.bash` (home-manager's bash module). However, other `programs.*` modules and `home.sessionVariables`/`home.sessionPath` are used freely — principle 3 only prohibits HM managing bash startup files.

#### Current architecture

`bash/init.bash` is symlinked to `.bashrc`, `.bash_profile`, `.profile`. Supports `source ~/.bashrc reload` for live reloading.

`bash/apps/home-manager/env.bash` is a symlink to `~/.nix-profile/etc/profile.d/hm-session-vars.sh`. This means `home.sessionVariables` and `home.sessionPath` flow into the custom init automatically during login.

Init flow:
1. Resolve repo root via symlink
2. Source `lib/initutil.bash` (shell detection, sourcing helpers, `SplitSpace`/`Globbing` controls)
3. Login or reload → source `settings/env.bash`
4. Source `context/init.bash` (platform-specific, if present)
5. Source `lib/apps.bash` (loads all app modules via detect → filter → order pipeline)
6. Source `settings/base.bash`, `settings/cmds.bash`
7. Interactive → source `settings/interactive.bash`
8. Interactive login or reload → source `settings/login.bash`

Each app gets a directory under `bash/apps/<app>/` with optional files:
- `env.bash` — variables (all shells) — *transitional: target is elimination via `home.sessionVariables`*
- `detect.bash` — availability check — *transitional: redundant for nix-managed packages*
- `init.bash` — setup (interactive)
- `cmds.bash` — aliases and functions (interactive)
- `deps` — dependencies on other app modules — *transitional: target is explicit ordering in init.bash*

Current app modules:
- `direnv` — PROMPT_COMMAND hook (uses `deps` for liquidprompt ordering — target: explicit hook in init.bash)
- `git` — 44 shell aliases + workflow functions (europe, wolf, venice, etc.)
- `home-manager` — symlink bridge to `hm-session-vars.sh` (target: direct sourcing from init.bash)
- `keychain` — SSH agent via keychain eval (target: reclassify as hook in init.bash)
- `liquidprompt` — vendored prompt (uses `detect.bash` — target: nix-packaged, unconditional)
- `mnencode` — randword function
- `pandoc` — shannon (markdown reformatter) function
- `stg` — 30+ stgit aliases + workflow functions

`bash/lib/`:
- `initutil.bash` — shell detection, sourcing helpers, IFS/globbing controls
- `apps.bash` — app module loader (detect → filter → order → source)

See [uc-init.md](uc-init.md) for full use case documentation of the init system.

#### Transition

The current architecture uses a generalized app module framework (detection, ordering, multi-phase sourcing) that was designed for 20+ modules. With nix absorbing the declarative layer, 8 modules remain and most use only `cmds.bash`. The target architecture simplifies the framework to match actual usage. Until the refactor lands, new integrations should follow the current app module pattern but categorize their behavior by the target-state decision matrix below.

### Nix/bash boundary

Principle 6 governs where new configuration belongs. The boundary has shifted over time as nix absorbed more responsibility.

**Nix owns** (declarative, shell-independent):
- Packages (`home.packages`, `shared.nix`)
- Program config (`programs.direnv`, `programs.bat`, `programs.firefox`, `programs.khal`, `programs.vdirsyncer`)
- Session variables and PATH (`home.sessionVariables`, `home.sessionPath`)
- File deployment (`home.file`)
- Services (`systemd.user.services`, `systemd.user.timers`)

**Bash owns** (shell-evaluated, session-dependent):
- Shell mode detection and sourcing order (`init.bash`)
- PROMPT_COMMAND hooks (liquidprompt, direnv, eternal history)
- Eval-based integrations that start processes (`keychain`)
- The `Alias`/`reveal` mechanism (wraps every alias with transparency)
- Interactive aliases and workflow functions (`cmds.bash`)
- IFS/globbing safety and namespace cleanup

**When adding a new tool**, these concerns can be combined:

| Concern | Where it goes |
|---------|--------------|
| Package installation | `shared.nix` (all hosts) or context `home.nix` (platform-specific) |
| Declarative program config | `programs.<name>` if a home-manager module exists |
| Environment variable | `home.sessionVariables` |
| PATH addition | `home.sessionPath` |
| Shell startup hook (PROMPT_COMMAND, eval) | Hook in `init.bash` (target) or `bash/apps/<tool>/init.bash` (current) |
| Interactive aliases/functions | `bash/apps/<tool>/cmds.bash` |

A tool may need several of these. For example, direnv uses nix for the package (`programs.direnv`), bash for the PROMPT_COMMAND hook (`bash/apps/direnv/init.bash`), and could have aliases in a `cmds.bash` file.

### Target architecture

**Design goals:**
- Predictable startup behavior from a single readable file
- Minimal order-sensitive code
- Declarative config in nix; shell-specific behavior isolated to bash
- A broken command script should not destabilize hook initialization
- Adding a new tool should require at most one decision (nix, hook, or commands) and one file

**Hooks** (order-sensitive, rare) are sourced explicitly in `init.bash` in a defined order. Currently: liquidprompt → direnv → keychain. Order matters because direnv's PROMPT_COMMAND hook must append after liquidprompt's. Adding a hook means adding a line to `init.bash` — explicit, visible, no discovery mechanism needed.

**Commands** (order-independent, common) are auto-discovered from `bash/apps/*/cmds.bash`. Currently: git, stg, mnencode, pandoc. Order doesn't matter — aliases and functions are independent. Adding commands means dropping a `cmds.bash` file in a new directory.

**Session variables** are sourced directly from `hm-session-vars.sh` in `init.bash` (login only), replacing the current indirect path through the home-manager app module symlink. Both `~/.nix-profile/...` and `/etc/profiles/per-user/$USER/...` paths are checked for NixOS/standalone portability.

**`settings/env.bash`** target is elimination. PATH additions move to `home.sessionPath`. CFGDIR, SECRETS, XDG_CONFIG_HOME move to `home.sessionVariables`. EDITOR and PAGER become simple nix assignments — nix guarantees nvim and less are available. A minimal bootstrap fallback may be retained for recovery shells where home-manager hasn't been applied.

**What this eliminates:**
- `bash/lib/apps.bash` loader (detection pipeline, dependency ordering)
- `detect.bash` files (nix packages are always on PATH; the test suite validates presence at build time)
- `deps` files (one relationship exists — liquidprompt → direnv — handled by explicit ordering in init.bash)
- `env.bash` phase (nix handles environment setup via hm-session-vars.sh)
- ~85 lines of support functions from `initutil.bash` that only serve the above

**Failure isolation:** In the target architecture, hook sourcing and command sourcing are separate passes — a syntax error in a `cmds.bash` file does not prevent hooks from running. In both current and target architectures, `TestAndSource` silently skips missing files, and `source` failures in one module do not abort the shell. The shell starts even with broken modules; errors appear in context.

**Liquidprompt caveat:** Until liquidprompt is nix-packaged (evtctl task #47), its vendored file check remains as an inline guard in init.bash. Once nix-managed, the guard becomes unconditional.

### Rejected alternatives

**`programs.bash` as the primary shell-init framework.** Generates `.bash_profile`, `.profile`, and `.bashrc` — re-implementing the three-file sourcing model that `init.bash` was designed to replace. Would require cramming the app module system into `initExtra` as opaque nix strings. Cannot support the `Alias`/reveal mechanism (`shellAliases` produces plain aliases). Other `programs.*` modules (direnv, bat, firefox, etc.) are used freely — this rejection is specific to HM managing bash startup files. See [Why a single entry point](#why-a-single-entry-point).

**Generated `init.bash` from nix.** Would make the structure declarative but would obscure debugging — instead of reading one bash file, you'd read a nix expression to understand what bash gets generated. Violates the core promise of UC-I0: the user reads `init.bash` and knows exactly what runs. Revisit if: the number of hook-producing integrations grows beyond a handful, ordering constraints become nontrivial, or manual hook wiring creates duplication across hosts.

**Generalized auto-discovery for hooks.** The current `OrderByDependencies` mechanism discovers, detects, and orders all app modules. Since only 2 modules have hooks and their order is fixed, a general-purpose ordering system is unnecessary overhead. Explicit hook ordering in `init.bash` is simpler, more visible, and more reliable than dependency resolution.

**Keeping the detection layer.** `detect.bash` and `IsApp`/`IsCmd` gate module loading on tool availability. Under declarative provisioning, runtime detection is not a design goal — nix guarantees packages are on PATH, and the test suite validates presence at build time. Liquidprompt is the sole remaining user of `detect.bash`, and only because it's vendored rather than nix-packaged.

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

`home.sessionVariables` and `home.sessionPath` in `home.nix` replace bash app modules for pure environment setup. These flow into the shell via `hm-session-vars.sh`, sourced by the home-manager app module (symlink). Target: `settings/env.bash` PATH additions and variable declarations move here, with `hm-session-vars.sh` sourced directly from `init.bash`.

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

## Operational Properties

### Cross-host consistency

`shared.nix` guarantees identical packages and `programs.*` config across all hosts. Context-specific packages (VPN tools on linux, chromium on crostini) are clearly separated in context `home.nix` files.

The bash init system is host-agnostic — same `init.bash`, same app modules, same settings. Platform adaptation goes through `context/init.bash` (currently unused but available). The `hm-session-vars.sh` sourcing path checks both standalone (`~/.nix-profile/...`) and NixOS (`/etc/profiles/per-user/$USER/...`) locations.

**Confidence bound:** Structurally verified by `shared.nix` and context separation. Runtime-verified on Crostini. NixOS runtime behavior is inferred from code, not tested from this host.

### Recovery

Home-manager maintains generations. `home-manager generations` lists available rollbacks. `home-manager activate <path>` restores a previous generation.

If `init.bash` changes break shell startup, recovery is: open a terminal, the broken init runs but the shell still starts (failure isolation), fix the file, `source ~/.bashrc reload`.

If nix changes break `home-manager switch`, the previous generation's packages and config remain on PATH until explicitly changed.

### Performance

Shell startup: ~500ms. Dominant contributor: keychain eval (~250ms, 50%). Non-interactive login without keychain/liquidprompt: ~57ms. Liquidprompt: ~1ms.

The startup budget is acceptable for interactive terminal use. If it becomes a concern, keychain could move to a lazy/deferred pattern (start agent on first SSH use rather than every login). This is an optional optimization, not a current priority.

The `Alias`/reveal wrapper adds no measurable overhead to command invocation.

## Configuration Validation

The `tesht` test suite serves as the living specification of the configured environment. Tests define what aliases, functions, env vars, and shell settings must exist. Changes to the configuration start with a test assertion (red), then implementation (green).

Two test layers:
- **Static tests** (non-interactive): nix file parsing, symlinks, package declarations, module structure
- **Runtime tests** (interactive login shell): aliases exist, functions exist, vi mode on, umask correct, PROMPT_COMMAND ordering

Tests do not duplicate nix's guarantees. Nix handles package presence, derivation correctness, and generated file content. Tests handle the bash-layer contract: after startup, the expected runtime state exists.

## Resolved Questions

- On NixOS, home-manager runs as a NixOS module. Does `update-env` skip its home-manager phase? **Yes.** `platform()` detects NixOS via `/etc/NIXOS` (with host-specific context support via `$HOSTNAME`) and gates Phase 3 (Nix + home-manager install) to non-NixOS platforms only.
