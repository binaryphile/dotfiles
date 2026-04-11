# Dotfiles Design

How this repo satisfies [use-cases.md](use-cases.md).

Ted's shared user environment. Works on all hosts. NixOS system and Sway design: `~/nixos-config/design.md`.

## Principles

1. **One environment, all hosts.** Same config on NixOS and Crostini. Platform differences handled by `contexts/`.
2. **Symlinks over copies.** Configs live here. Home directory gets symlinks. See [Why symlinks, not immutable copies](#why-symlinks-not-immutable-copies) under Deployment.
3. **Single-file bash init.** One entry point replaces `.bashrc`, `.bash_profile`, `.profile`. Explicit mode detection, no hidden sourcing rules. See [Why a single entry point](#why-a-single-entry-point).
4. **Idempotent deployment.** `update-env` works on fresh or existing machines. Converges to desired state.
5. **Nix for packages, dotfiles for config.** `home.nix` says what to install. Dotfiles say how to configure.
6. **Nix owns declarative config. Bash owns shell-evaluated behavior.** Decision test: can this be expressed as static data or generated config without bash evaluating shell state? If yes → nix. If no → bash. See [Nix/bash boundary](#nixbash-boundary).

## What this repo owns

- `shared.nix` — cross-platform packages, programs, session variables; imported everywhere
- `contexts/linux-base.nix` — Linux+Crostini shared layer: notify-send wrapper, vpn-connect, gpoc, calendar/khal-notify, dotfile symlinks
- `contexts/<platform>/home.nix` — platform-specific packages and overrides
- Bash — custom app-based init system
- Git — identity, aliases, global ignore (now home-manager-managed via `home.file`)
- Tmux, SSH, Ranger, Liquidprompt — platform-aware via `contexts/`, deployed via home-manager
- Claude Code — settings managed via `home.file`
- VPN access — gpoc Rust rewrite, vpn-slice, plus crostini-only browser proxy stack
- Phone notifications — `notify-send` wrapper bridging to ntfy.sh
- Neovim — separate `dot_vim` repo

## Structure

```
shared.nix                      # Shared packages, programs, config (imported by all contexts)
home.nix                        # Symlink to active context's home.nix
flake.nix, flake.lock           # Dev-shell flake (mk, kcov, scc, jq, editor)
update-env                      # Idempotent deployment script (installs nix, bootstraps shell)
claude/                         # Claude Code config: settings.json + CLAUDE.md (managed by home.file)
bash/
  init.bash                     # Entry point → .bashrc, .bash_profile, .profile
  apps/                         # Per-app modules (env, init, cmds, deps)
  settings/                     # Base, login, interactive, env, cmds
  lib/                          # Init system internals
contexts/
  linux-base.nix                # Linux+Crostini shared layer (imports shared.nix); calendar, notify-send wrapper, vpn-connect, gpoc, dotfile symlinks
  linux/home.nix                # NixOS-specific (imports linux-base.nix)
  crostini/home.nix             # Crostini-specific (imports linux-base.nix); also tinyproxy + PAC for UC-8
  macos/home.nix                # macOS-specific (imports shared.nix directly; skips the linux-base layer)
gitconfig, gitignore_global     # Git
tmux.conf                       # Context-dependent symlink
ssh/                            # Client config
ranger/                         # File manager
liquidprompt/                   # Prompt theme
scripts/                        # Setup utilities (notify-send, vpn-connect, khal-notify)
docs/                           # use-cases.md, design.md, vpn.md, uc-init.md
```

## Component Design

### Deployment — UC-4

`update-env` takes a bare machine to fully configured. Lives in `~/dotfiles/update-env`, deployed to `~/.local/bin/`. Nine phases:

0. Git repo updates (conditional, subsequent runs)
1. System upgrades + SSH credentials (apt: crostini/debian only; credentials: crostini only)
2. Clone this repo, install **bootstrap-only** symlinks (`.bash_profile`, `.bashrc`, `.profile` → `bash/init.bash`; `~/dotfiles/context` → active context). The rest of the dotfile symlinks (gitconfig, tmux.conf, ssh, ranger, liquidprompt, etc.) are managed declaratively by home-manager via `linux-base.nix` once nix and HM are installed.
3. Install Nix + home-manager (crostini/debian/linux/macos only — skipped on NixOS, system-managed there)
4. Platform-specific setup (crostini only)
5. Clone and link dev tools (fp.bash, mk.bash, task.bash, tesht, jeeves, sofdevsim-2026, blog, tandem-protocol, era)
5b. Work projects (VPN-dependent, graceful failure): urma-next, pepin, cloud-services, accelerated-linux, urma-obsidian, share
6. Neovim plugins, daily notes
7. SSH key generation (crostini/linux only)

Idempotent. Platform detection: macos → crostini → nixos/$HOSTNAME → debian → linux.

**What belongs in update-env vs. home-manager:** The split is governed by one structural constraint and two categories:

*Structural constraint:* anything home-manager needs in order to run must be managed by `update-env`, because it must exist before `home-manager switch` executes. This is a hard dependency, not a preference.

| Owner | What | Count | Why |
|-------|------|-------|-----|
| `update-env` (bootstrap) | `.bash_profile`, `.bashrc`, `.profile` → `bash/init.bash`; `context` → active platform; `config.nix` → nixpkgs; `home.nix` → home-manager | 6 symlinks | Must exist before nix/HM runs. Shell init, nix config, and HM config are prerequisites for everything else. |
| `update-env` (external) | Dev tool and project repos (phases 5 + 5b) cloned and linked to `~/.local/bin` or `~/.local/lib`; `update-env` itself; `era-mcp.service`; neovim config; SSH keys; credential files; crostini mounts | ~30 symlinks + installs | External repos, credentials, and platform mounts that live outside the dotfiles tree. HM can only manage files whose source is inside the nix evaluation — cloned repos and secrets are not. |
| `home-manager` (`home.file`) | gitconfig, gitignore_global, tmux.conf, liquidprompt (2), ssh (2), ranger (3), gpgui desktop entry | 11 symlinks (`linux-base.nix`) | Static dotfile configs consumed by programs. No bootstrap dependency. Benefit from HM's atomic generation switching and rollback. |
| `home-manager` (`home.file`) | Claude settings + CLAUDE.md | 2 copies (`linux/home.nix`, `crostini/home.nix`, `macos/home.nix`) | `force: true` copies — Claude Code may overwrite these, so HM restores them on switch. |
| `home-manager` (`home.file`) | panel, vpn, digi-security-watch scripts; proxy PAC | 3 symlinks + 1 generated (`crostini/home.nix`) | Crostini-only scripts and generated config. |
| `home-manager` (`programs.*`) | direnv, bat, firefox, khal, vdirsyncer | 5 modules | Declarative program config via HM modules — not `home.file` but the same dependency tree. |

*Decision test for new files:* (1) Is it needed before HM runs? → `update-env`. (2) Does its source live outside `~/dotfiles`? → `update-env`. (3) Otherwise → `home.file` with `mkOutOfStoreSymlink` for edit-in-place, or a `programs.*` module if one exists.

The `home.file` blocks use `mkOutOfStoreSymlink` to preserve edit-in-place semantics — symlinks point at the live source files in `~/dotfiles/`, not into the nix store, so editing the source is immediately visible without `home-manager switch`.

**Why symlinks, not immutable copies:** The NixOS model copies config files into the read-only nix store, making them immune to runtime mutation. This is valuable when the consumer of a config is a program that might silently overwrite it. But the files managed here — bash modules, tmux.conf, gitconfig, ssh config, ranger, liquidprompt — are files the user writes and controls. No program writes back to them; the drift risk is zero. Symlinks give instant feedback: edit the source file, the change is live. Immutable copies would require a rebuild/deploy step for every edit, adding friction without solving a real problem. The `home.file` blocks that do exist (Claude config, gpgui desktop entry, proxy PAC) use `force: true` or are generated — cases where immutability or atomic replacement actually matters. If a file were ever at risk of being silently modified by a program, the right move would be to promote it to a `home.file` block rather than building a parallel copy mechanism.

**Post-install messages** (`postInstallMessages` function in `update-env`) write per-platform manual-setup instructions to a file under `~/.local/share/dotfiles/` (creating the file only if missing), then print a one-line reminder pointing at the file. Currently used on Crostini to document the ChromeOS Chrome PAC URL configuration for UC-8.

The "create file if missing" pattern lets the user delete the file to regenerate it after instructions change, while keeping every routine `update-env` run quiet — just a single line of output instead of a 20-line block. Platform-gated by `case $(platform) in crostini ) ... ;; esac` so other hosts don't see Crostini-specific reminders.

All project repos — including private repos like jeeves — are cloned by update-env. Private repos use `try` so failures are non-fatal. All `*CloneAndLinkTask` functions default the branch to `main`.

On NixOS, `~/nixos-config/flake.nix` imports `home.nix` via flake input. Dotfile symlinks still deployed by `update-env`.

### Bash Init — UC-1

#### Why a single entry point

The conventional bash init model splits startup across `.profile`, `.bash_profile`, and `.bashrc`. Which file runs depends on an interaction of login vs non-login, interactive vs non-interactive, bash vs sh, local vs remote — a sourcing taxonomy complex enough that even experienced engineers cannot reliably state the full rules. The result is shell behavior that is difficult to predict, debug, or control.

`init.bash` replaces all three files with a single entry point. Mode detection is explicit (`ShellIsLogin`, `ShellIsInteractive`, `Reload`) and every sourcing decision is visible in the code. No hidden file-selection rules, no "bash checks for .bash_profile first but falls back to .profile unless..." — the user reads one file and knows exactly what runs when.

This design does not use `programs.bash` (home-manager's bash module). However, other `programs.*` modules and `home.sessionVariables`/`home.sessionPath` are used freely — principle 3 only prohibits HM managing bash startup files.

#### Architecture

`bash/init.bash` is symlinked to `.bashrc`, `.bash_profile`, `.profile`. Supports `source ~/.bashrc reload` for live reloading.

Init flow:
1. Resolve repo root via symlink
2. Source `lib/initutil.bash` (shell detection, Alias/reveal, `SplitSpace`/`Globbing`)
3. Login or reload → source `hm-session-vars.sh` directly (if/elif fallback for portability)
4. Source `context/init.bash` (platform-specific, if present)
5. Hooks: explicit order — keychain (login), liquidprompt (interactive), direnv (interactive)
6. Source `settings/base.bash`, `settings/cmds.bash`
7. Commands: auto-discover `apps/*/cmds.bash` (interactive, order-independent)
8. Interactive → source `settings/interactive.bash`
9. Interactive login or reload → source `settings/login.bash`

App modules are directories under `bash/apps/<app>/` with:
- `init.bash` — startup hook (sourced explicitly in init.bash in defined order)
- `cmds.bash` — aliases and functions (auto-discovered, interactive only)

Current app modules:
- `direnv` — PROMPT_COMMAND hook (appends after liquidprompt)
- `git` — 44 shell aliases + workflow functions (europe, wolf, venice, etc.)
- `keychain` — SSH agent via keychain eval (id_ed25519, login hook)
- `mnencode` — randword function
- `pandoc` — shannon (markdown reformatter) function
- `stg` — 30+ stgit aliases + workflow functions

Liquidprompt is sourced directly from the vendored `liquidprompt/` directory (not an app module). Until nix-packaged (evtctl task #47), a file-existence guard gates its loading.

`bash/lib/initutil.bash` (~55 lines) provides: Alias/reveal wrapper, IsFile, TestAndSource, TestAndTouch, ShellIs* detection, SplitSpace/Globbing control, and function/variable cleanup tracking.

See [uc-init.md](uc-init.md) for full use case documentation of the init system.

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

### Design goals
- Predictable startup behavior from a single readable file
- Minimal order-sensitive code
- Declarative config in nix; shell-specific behavior isolated to bash
- A broken command script should not destabilize hook initialization
- Adding a new tool should require at most one decision (nix, hook, or commands) and one file

**Hooks** (order-sensitive, rare) are sourced explicitly in `init.bash` in a defined order. Currently: liquidprompt → direnv → keychain. Order matters because direnv's PROMPT_COMMAND hook must append after liquidprompt's. Adding a hook means adding a line to `init.bash` — explicit, visible, no discovery mechanism needed.

**Commands** (order-independent, common) are auto-discovered from `bash/apps/*/cmds.bash`. Currently: git, stg, mnencode, pandoc. Order doesn't matter — aliases and functions are independent. Adding commands means dropping a `cmds.bash` file in a new directory.

**Session variables** are sourced directly from `hm-session-vars.sh` in `init.bash` (login only), replacing the current indirect path through the home-manager app module symlink. Both `~/.nix-profile/...` and `/etc/profiles/per-user/$USER/...` paths are checked for NixOS/standalone portability.

**Session environment** is managed entirely by nix via `home.sessionVariables` and `home.sessionPath` in `shared.nix`. These flow into the shell through `hm-session-vars.sh`, sourced directly by `init.bash` on login.

**Failure isolation:** In the target architecture, hook sourcing and command sourcing are separate passes — a syntax error in a `cmds.bash` file does not prevent hooks from running. In both current and target architectures, `TestAndSource` silently skips missing files, and `source` failures in one module do not abort the shell. The shell starts even with broken modules; errors appear in context.

**Liquidprompt caveat:** Until liquidprompt is nix-packaged (evtctl task #47), its vendored file check remains as an inline guard in init.bash. Once nix-managed, the guard becomes unconditional.

### Rejected alternatives

**`programs.bash` as the primary shell-init framework.** Generates `.bash_profile`, `.profile`, and `.bashrc` — re-implementing the three-file sourcing model that `init.bash` was designed to replace. Would require cramming the app module system into `initExtra` as opaque nix strings. Cannot support the `Alias`/reveal mechanism (`shellAliases` produces plain aliases). Other `programs.*` modules (direnv, bat, firefox, etc.) are used freely — this rejection is specific to HM managing bash startup files. See [Why a single entry point](#why-a-single-entry-point).

**Generated `init.bash` from nix.** Would make the structure declarative but would obscure debugging — instead of reading one bash file, you'd read a nix expression to understand what bash gets generated. Violates the core promise of UC-I0: the user reads `init.bash` and knows exactly what runs. Revisit if: the number of hook-producing integrations grows beyond a handful, ordering constraints become nontrivial, or manual hook wiring creates duplication across hosts.

**Generalized auto-discovery for hooks.** The previous `OrderByDependencies` mechanism discovered, detected, and ordered all app modules. Since only 2 modules have hooks and their order is fixed, a general-purpose ordering system was unnecessary overhead. Explicit hook ordering in `init.bash` is simpler, more visible, and more reliable than dependency resolution.

**Keeping the detection layer.** `detect.bash` and `IsApp`/`IsCmd` gated module loading on tool availability. Under declarative provisioning, runtime detection is not a design goal — nix guarantees packages are on PATH, and the test suite validates presence at build time. Liquidprompt was the sole user of `detect.bash`; its availability guard is now inline in `init.bash`.

### Contexts — cross-cutting

`contexts/` holds platform overrides plus a shared Linux+Crostini intermediate layer. A `context` symlink at repo root points to the active platform.

Each platform context can override `home.nix`, `gitconfig`, `tmux.conf`, and other configs. Top-level files like `gitconfig` and `home.nix` are symlinks to their context version.

The home-manager import chain:
- `contexts/macos/home.nix` → `shared.nix`
- `contexts/linux/home.nix` → `linux-base.nix` → `shared.nix`
- `contexts/crostini/home.nix` → `linux-base.nix` → `shared.nix`

`linux-base.nix` exists because Linux and Crostini share substantial config that doesn't apply to macOS: notify-send-bridge (depends on libnotify), gpoc/vpn-connect (depends on systemd, openconnect, the URL scheme handler stack), calendar/khal-notify systemd units, and the dotfile symlink set. Before this layer was extracted, both `linux/home.nix` and `crostini/home.nix` had ~80 lines of duplicated config that drifted over time.

Machine-specific contexts (e.g., `calumny`) symlink most files to their platform context (e.g., `../nixos/home.nix`) and add machine-specific config. This keeps platform config shared while allowing per-machine overrides.

### Packages — UC-1, UC-2, UC-3

Declared in `home.nix`. See the file for the current list. By category:

**Dev tools (UC-1):** git, neovim, tmux, stgit, gh, claude-code, jira-cli-go, scc, pandoc, diff-so-fancy, silver-searcher (ag), highlight, asciinema, asciinema-agg

**System/CLI (UC-3):** bottom, htop, ncdu, jq, tree, rsync, coreutils, dig, zip, mnemonicode

**Wayland (UC-2):** wl-clipboard, cliphist, libnotify

**Apps (UC-2):** Firefox (via `programs.firefox`), Obsidian, signal-desktop

**VPN (UC-7):** gpoc (yuezk Rust rewrite, via upstream flake), vpn-slice. Plus the Crostini-only browser-VPN-access stack: tinyproxy + darkhttpd (UC-8).

**Notifications (UC-9):** notify-send wrapper that bridges desktop notifications to ntfy.sh phone push. Drops in transparently as `notify-send` for any caller.

**Calendar (UC-1):** khal, vdirsyncer (linux and crostini — systemd integration via `linux-base.nix`)

**File management (UC-3):** ranger

### Programs managed by home-manager modules

Some tools use `programs.*` instead of `home.packages` for declarative config:

- `programs.direnv` — direnv + nix-direnv for `use flake` support. Bash integration disabled (custom hook in `bash/apps/direnv/init.bash`).
- `programs.bat` — default style via config file, no shell alias needed.
- `programs.firefox` — declarative search engine and extension policies.
- `programs.khal`, `programs.vdirsyncer` — calendar sync (linux and crostini).

### Session environment managed by nix

`home.sessionVariables` and `home.sessionPath` in `shared.nix` provide EDITOR, PAGER, CFGDIR, SECRETS, XDG_CONFIG_HOME, and PATH additions. These flow into the shell via `hm-session-vars.sh`, sourced directly by `init.bash` on login (if/elif fallback for NixOS/standalone portability).

### Firefox — UC-2

Managed via `programs.firefox` (home-manager module), not `home.packages`. This enables declarative profile and search engine configuration.

- Default search engine: DuckDuckGo (via `policies.SearchEngines.Default`)
- Extensions auto-installed via `policies.ExtensionSettings` with `force_installed`: uBlock Origin, Privacy Badger, Vimium
- All extensions enabled in private browsing (`private_browsing = true`)
- Uses policies instead of per-profile config — policies apply to all profiles regardless of profile path, which varies per machine
- Works on both NixOS (home-manager as NixOS module) and Debian/Crostini (standalone home-manager) — policies are baked into the wrapped Firefox package at build time

### VPN — UC-7

GlobalProtect VPN with SAML SSO via yuezk's Rust rewrite of `globalprotect-openconnect` (gpoc). The Nix package comes from yuezk's upstream flake (`builtins.getFlake "github:yuezk/GlobalProtect-openconnect"`); nixpkgs ships only an old C++/Qt 1.4.9 build that drags in qtwebengine and was never made to work on Crostini.

Components:
- `gpauth` — performs SAML auth via the user's default browser, captures the cookie
- `gpclient connect` — drives openconnect (linked in via FFI) to bring up the GP tunnel
- `vpn-slice` — passed as `--script` to gpclient/openconnect for split-horizon DNS

Entry point: `vpn-connect` — a Nix-managed wrapper script defined in `contexts/linux-base.nix` via `mkScriptBin`. The derivation substitutes `@vpn-slice@` and `@gpclient@` with absolute store paths because those binaries are invoked under `sudo`, which strips PATH. `gpoc` is also added to the wrapper's runtime PATH for the unsudo'd `gpauth` invocation.

The script reconnects in a loop on disconnect; Ctrl-C exits cleanly.

#### SAML callback flow

The callback path is non-obvious and the source of past failures. Full step-by-step description lives in [docs/vpn.md](vpn.md). Summary:

1. `gpauth` opens a one-shot HTTP server to serve the SAML form HTML
2. `gpauth` opens a separate raw TCP listener on another port and writes that port to `/tmp/gpcallback.port`
3. Browser does SAML, the IdP returns a `globalprotectcallback://<base64>` URL
4. The OS dispatches that URL scheme to `gpclient launch-gui %u` via the registered `.desktop` handler
5. `gpclient launch-gui` reads the port file, opens a TCP socket to localhost, writes the auth data
6. `gpauth` accepts, reads the cookie, prints to stdout (piped to `gpclient connect --cookie-on-stdin`)

The URL scheme handler is registered via home-manager's `xdg.desktopEntries.gpgui` plus `xdg.mimeApps`, both in `contexts/linux-base.nix`.

#### Crostini garcon discovery gotcha

home-manager's `xdg.desktopEntries` installs to `~/.nix-profile/share/applications/`. **Garcon (the ChromeOS↔container bridge) only scans `~/.local/share/applications/`** for desktop files when propagating MIME registrations to the host, not arbitrary `XDG_DATA_DIRS` entries. Without an extra symlink into the standard XDG dir, host ChromeOS Chrome never learns about the `globalprotectcallback://` handler, the SAML callback URL is silently dropped, and `gpauth` hangs forever on `accept()`.

The fix: a `home.file.".local/share/applications/gpgui.desktop".source` symlink (via `mkOutOfStoreSymlink`) into `~/.nix-profile/share/applications/gpgui.desktop`, defined in `linux-base.nix`. This is harmless on non-Crostini Linux desktops where `~/.nix-profile/share/applications/` is already in `XDG_DATA_DIRS`.

Split-tunnel hosts: see the `vpn-slice` argument in `scripts/vpn-connect`. These are mirrored in `contexts/crostini/home.nix`'s PAC file for UC-8.

Notes:
- `--gateway "US East"` pre-selects the gateway, avoids interactive prompt
- `--browser xdg-open` so the browser choice respects ChromeOS's Sommelier routing on Crostini and `xdg-mime` defaults elsewhere
- yuezk's flake is unpinned; v2.4.4 tag fails to build, main works. Pin to a specific commit when upstream stabilizes

### Browser VPN access — UC-8

ChromeOS host Chrome lives outside the Crostini container and cannot reach `tun0` directly. To let Ted click VPN-only URLs from host Chrome (instead of falling back to terminal tools or in-container Firefox), `contexts/crostini/home.nix` declares two systemd user services and a PAC file:

- **`tinyproxy`** (forward HTTP proxy) listens on the container's `127.0.0.1:8118`. Garcon's container→host localhost forwarding makes that port reachable from ChromeOS Chrome. tinyproxy itself has no special VPN knowledge — it just forwards requests, which traverse the container's tun0 because that's the container's network namespace.
- **`darkhttpd`** (single-binary static file server) serves a PAC file from `~/.local/share/proxy-pac/proxy.pac` on `127.0.0.1:8120`. Used as a "PAC URL" host so Chrome can fetch the script.
- **`proxy.pac`** is generated by `pkgs.writeText` from a host list inside `contexts/crostini/home.nix`. Hosts matching the list (or any subdomain of them) return `PROXY 127.0.0.1:8118`; everything else returns `DIRECT`.

Ted manually points ChromeOS Network → Proxy → Automatic configuration at `http://127.0.0.1:8120/proxy.pac`. After that, Chrome consults the PAC per-request:
- Non-VPN URL → `DIRECT` → Chrome connects without involving the container, no overhead
- VPN URL → `PROXY 127.0.0.1:8118` → Chrome sends to tinyproxy → tinyproxy forwards via tun0

This is **crostini-specific** because no other host needs it: regular Linux/NixOS desktops route VPN traffic locally and reach VPN hosts directly. Lives in `contexts/crostini/home.nix` (not `linux-base.nix`) so other Linux machines don't pick up the config.

The PAC host list must be kept in sync with `vpn-connect`'s `vpn-slice` host list. Currently maintained manually in two places. A future improvement could read both from a single source-of-truth file.

### Phone notification bridge — UC-9

`scripts/notify-send` is a wrapper script that:
1. Forwards all arguments to the real libnotify `notify-send` (synchronously) for the local desktop popup
2. Parses `--urgency`, the trailing positional summary, and the optional body
3. If `~/secrets/ntfy-topic` exists and is readable, POSTs the notification to `https://ntfy.sh/<topic>` in a backgrounded subshell with `disown` so the calling tool doesn't block on the network

The wrapper is built via `mkScriptBin` in `linux-base.nix`. The `@notify-send@` placeholder is substituted at build time with the absolute store path to libnotify's `notify-send`, so the wrapper does not recurse into itself when invoked through PATH. `curl` and `coreutils` are added to the wrapper's runtime PATH.

Critical-urgency notifications get `Priority: high` on ntfy (loud notification on the phone); others get `Priority: default`. All messages get `Tags: bell` for the icon.

Tools that already call `notify-send` get phone push for free with no source changes — `khal-notify` is the current consumer; future tools just call `notify-send` and inherit the bridge.

The wrapper shadows libnotify's `notify-send` because it's installed via a derivation named `notify-send` whose `bin/notify-send` ends up in the user's nix profile alongside libnotify's. Nix profile coalescing prefers the wrapper because it's installed via `home.packages` in `linux-base.nix` while libnotify is only present as a transitive dep of the wrapper itself (not directly in `home.packages`).

### Status widgets — UC-10

Headless sessions (Crostini, SSH into NixOS without a desktop) don't have waybar, so the tmux status bar substitutes for it. Implementation lives in four files:

- **`scripts/probe-lib.bash`** — shared probe library, sourced by both this repo's panel script AND nixos-config's waybar widget renderer. Caller sets `$State` to its own cache directory before sourcing. The same code path runs on both platforms — drift in probe semantics is impossible at this layer. Defines:
  - Probe functions: `isStale`, `refresh`, `readState`, `pingHost`, `sshHost`, `combine`, `vpnUp`, `bitbucketApiProbe`, `codebergApiProbe`, `digiApiProbe`, `probeReachability`, `probePing`.
  - Widget metadata tables: `WidgetHost`, `WidgetVpnGated`, `WidgetApiFn`, `WidgetNoSsh` — single source of truth for host names, VPN gating, API probe selection, and SSH probe skipping. Accessors `widgetHost`, `widgetVpnGated`, `probeWidget` let callers look up by widget key instead of repeating host strings. `WidgetNoSsh` marks hosts (dm1, nexus, remotemanager) that skip SSH probes — `probeReachability` checks this table and skips `sshHost` for those entries, and `combine` treats `ssh=skip` + `ping=ok` as "on".
  - Injectable command globals: `Timeout`, `Ssh`, `Curl`, `Jq`, `Ip` — each defaults to the real binary (`${Var:-binary}`) but can be overridden before sourcing or via bash dynamic scope in tests. This is the only test seam; the library has no other test hooks.

- **`scripts/panel`** — tmux status bar renderer. Sources `probe-lib.bash`, sets `$State=$XDG_RUNTIME_DIR/panel`, and exposes `panel <module>` (returns a tmux-formatted segment with `#[fg=...]` color codes), `panel click <module>` (mouse handler), `panel poll` (synchronous warmup), and `panel layout` (dynamic status bar height). Health monitor widgets use `segment` (hidden when on) and service toggles use `alwaysSegment` (always visible). Supporting functions: `cachedHealthState`/`cachedPingState` (read cached state without new probes — used by `healthSep` and `layoutCmd`), `healthSep` (dynamic separator, visible only when health widgets are), `hostnameCmd` (`~/crostini/hostname` on Crostini, system hostname elsewhere), `canLoadCmd` (checks `tmux show-env` for SSH without desktop).

- **`contexts/panel.tmux.conf`** — shared panel config sourced via `session-created` hook (never during initial config parse — session-scoped `set` silently fails before session creation). Options use `set` without `-g` so sessions independently have panel or not. `bind-key` is the exception (inherently global); guarded by `show-option` on `@panel-right`. Two sourcing paths: Crostini replaces Linux's conditional hook with unconditional; Linux's hook runs `panel can-load` (checks `tmux show-env` for `SSH_CONNECTION` set and `WAYLAND_DISPLAY` absent). Limitation: `tmux attach` doesn't re-evaluate. For full isolation: `tmux -L ssh new`.

- **`contexts/crostini/tmux.conf`** — sources linux/tmux.conf for the base, then replaces Linux's conditional `session-created` hook with an unconditional one (Crostini is always headless).

**Probe cadences** (set in `probe-lib.bash`):
- SSH probe (`sshHost`): every 600s. `ssh -T git@<host>`; rc 0/1 or "shell request failed" both count as ok.
- TCP/443 ping (`pingHost`): every 30s. Uses `bash`'s `/dev/tcp/<host>/443` rather than ICMP because most vendor sites block ICMP.
- Vendor status API (`bitbucketApiProbe`, `codebergApiProbe`, `digiApiProbe`): every 30s. Atlassian Statuspage component `qmh4tj8h5kbn` (bitbucket), Codeberg Uptime Kuma monitor 7, and Digi Remote Manager status page (worst-of across all components) respectively. `digiApiProbe` is shared by dm1 and remotemanager widgets.

**State machine** (per `combine` in `probe-lib.bash`): the displayed class is the worst tier across (api, ssh, ping). `api=down` → `off`. `api=degraded` → `partial`. `ping=fail` → `off`, AND `pingHost` invalidates the cached SSH success on failure so the widget can return to `on` only via a fresh successful SSH probe — a partial recovery from a network blip lands in `partial`, not back in `on`. `ssh=ok ∧ ping=ok` → `on`. `ssh=skip ∧ ping=ok` → `on` (for hosts in `WidgetNoSsh`). `ping=ok` (without confirmed ssh) → `partial`. Otherwise `unknown`.

**VPN gating**: `dm1`, `stash`, `gitlab`, `nexus` modules return early (empty string) when `tun0` is missing — the segment vanishes from the bar entirely, since tmux's per-segment range tolerates empty content. `remotemanager` is public (not VPN-gated) and always probed.

**Widget order and separators:** Both waybar (nixos-config) and the tmux panel use the same canonical group order, separated by visual dividers (CSS borders in waybar, pipe characters in tmux):

1. **System** — ssh, fw, vpn (waybar only; tmux has vpn only)
2. **Health** — dm1, stash, gitlab, nexus, remotemanager, codeberg, bitbucket, teams, ntfy (external service reachability; VPN-gated widgets appear only when tunnel is up)
3. **Services** — era (local infrastructure services managed by the user)
4. **Hardware** — load, cpu, mem, disk, bat (local resource monitors; tmux omits backlight, vol, temp which are desktop-only; bat is present on Linux laptops)

Within each group, widgets cuddle with a single space between them. Empty widgets (VPN-gated when tunnel is down, threshold-gated below 90%, health monitors in `on` state) produce no output and no space — the group contracts. The separator between vpn and the health group is dynamic (`healthSep`): it appears only when at least one health widget is visible, preventing empty `vpn | | era` artifacts. Other separators are always visible. A clock (`MM/DD HH:MM`) and hostname (reads `~/crostini/hostname` on Crostini, system hostname elsewhere) follow the hardware group with no separator. Changes to group membership or order must be mirrored in both renderers — see nixos-config's `docs/design.md` Waybar section.

**Dynamic status bar height:** `panel layout` toggles between 1-line (`status on`) and 2-line (`status 2`) mode based on whether the window list + widget bar fits the terminal width. In 1-line mode, `status-right` renders the widget bar (via `#{E:#{@panel-right}}`); in 2-line mode, `status-format[1]` renders it and `status-right` is empty. Triggered by session-scoped tmux hooks (`client-resized`, `window-linked`, `window-unlinked`, `after-rename-window` — set without `-g` so each session manages its own layout independently) and a silent `#(panel layout)` call embedded in `@panel-right` that runs every `status-interval` (5s). Width estimation: window list width (session name + tab names), widget bar width (dynamically counts actually-visible widgets via `cachedHealthState`/`cachedPingState` + separators + clock + hostname). Idempotent — skips if already in the correct mode.

**Color palette** mirrors nixos-config's `home/sway/waybar.css`: light gray (`colour250`) = partial, dark gray (`colour244`) = off, amber (`colour130`) = unknown. Health widgets (all `segment`-based widgets except vpn and load) are **hidden when on** — they signal by appearing, not by being always visible. cpu/mem/disk use white when above threshold, also signaling by appearing.

**cpu/mem/disk thresholding**: hidden below 90% (segment is empty), label + percentage in white (default text color) at 90%+. Implemented via `thresholdSegment`. Uses `df`, `/proc/meminfo`, and a delta against `/proc/stat` cached in `$State/cpu-stat`.

**Battery (`batModule`)**: hidden when charging, full, or above 10%. Warning [10,5%): "H:MM" in partial color (dimmer than clock, implies battery). Critical [5,0%]: "N% bat" in white (explicit label to distinguish from RAM/disk). Supports Crostini (`/sys/class/power_supply/battery/`) and standard Linux laptops (`/sys/class/power_supply/BAT0/`). Three sysfs interface fallbacks: `charge_now`/`current_now` (standard ACPI, most laptops), `charge_counter`/`current_now` (Crostini Android bridge), `energy_now`/`power_now` (energy-based laptops). Units cancel in all cases (µAh/µA = h, µWh/µW = h). Sysfs path injectable via `BatSysfs` for testing.

**Load sparkline**: 3-bar widget rendered left-to-right as 1m/5m/15m (matching `uptime`/`top` convention). Normalization formula:

```
idx = 1 + floor(load * 5 / (2 * nproc))
```

capped at 8. Bar 6 = 2 × nproc (the "2 processes waiting per CPU, time to be concerned" line). Bars 7–8 give headroom past that — bar 8 saturates at ≈2.8 × nproc. Below the concerned line the bar stays mostly empty; once you're past it, things are getting crazy and the bar fills up fast. `nproc` is invoked from bash and passed to awk via `-v nCpu`.

**State files** live at `$XDG_RUNTIME_DIR/panel/<widget>-{api,ssh,ping}` for the panel script and `/tmp/waybar-health/<widget>-{api,ssh,ping}` for nixos-config's waybar — both use the same probe-lib code path but write to separate directories so the two consumers don't fight over each other's caches.

**Why text labels instead of icons**: ChromeOS Terminal is locked to a fixed font list (Cousine, Fira Code, JetBrains Mono, etc.) — none of which include Nerd Font / Font Awesome glyphs. We tried installing alternative terminals (foot has no working clipboard under Sommelier; alacritty/kitty fail on the GL bridge) and rolled back. On NixOS SSH, the client terminal may have Nerd Font support, but text labels work universally across all clients without font assumptions. The widget contract is identical to waybar's; only the rendering glyphs differ. See git history for details.

**Drift risk**: this UC has a sibling implementation in `nixos-config/home/sway/waybar.nix` + `nixos-config/scripts/widget-status`. The probe code is shared (single source of truth in `probe-lib.bash`); the renderers are not. Widget group order, separator placement, visibility rules, and color mappings must be kept in sync between the two renderers. Cadences live in `probe-lib.bash` and are therefore actually shared. On NixOS, both renderers can be active on the same machine — waybar on desktop sessions, panel on SSH sessions — writing to separate state directories (`$XDG_RUNTIME_DIR/panel` vs `/tmp/waybar-health`). Both design docs (this file and `nixos-config/docs/design.md`) document the canonical group order — update both when changing it.

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

**khal-notify** (`scripts/khal-notify`) runs every 5 minutes via systemd timer, checks for events starting in 60, 30, 10, or 5 minutes and sends desktop notifications via `notify-send`. Phone push happens transparently because the `notify-send` binary on PATH is the wrapper from UC-9 — khal-notify itself has no ntfy code. The 5-minute notification uses critical urgency. A statefile (`~/.local/state/khal-notify/sent`) prevents duplicate notifications, cleaned daily.

Calendar config (`accounts.calendar`, `programs.khal`, `programs.vdirsyncer`, `services.vdirsyncer`) plus the custom khal-notify systemd unit live in `contexts/linux-base.nix`, imported by both `contexts/linux/home.nix` and `contexts/crostini/home.nix`. The khal-notify ExecStart uses `${config.home.homeDirectory}/dotfiles/scripts/khal-notify`, which works identically on both standalone home-manager (Crostini) and the NixOS home-manager module (linux). The systemd unit's `DBUS_SESSION_BUS_ADDRESS` uses systemd's `%U` specifier for the user UID instead of hardcoding `1000`.

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
