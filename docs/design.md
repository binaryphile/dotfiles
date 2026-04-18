# Dotfiles Design

How this repo satisfies [use-cases.md](use-cases.md). Each **use case (UC-N)** is a user-facing goal documented there; section headings here reference them parenthetically.

Ted's shared user environment. Works on all hosts. NixOS system and Sway design: `~/nixos-config/design.md`.

## Principles

1. **One environment, all hosts.** Same config on NixOS and Crostini. Platform differences handled by `contexts/`.
2. **Symlinks over copies.** Configs live here. Home directory gets symlinks. See [Why symlinks, not immutable copies](#why-symlinks-not-immutable-copies) under Deployment.
3. **Single-file bash init.** One entry point replaces `.bashrc`, `.bash_profile`, `.profile`. Explicit mode detection, no hidden sourcing rules. See [Why a single entry point](#why-a-single-entry-point).
4. **Idempotent deployment.** `update-env` works on fresh or existing machines. Converges to desired state.
5. **Nix for packages, dotfiles for config.** `home.nix` says what to install. Dotfiles say how to configure.
6. **Nix owns declarative config. Bash owns shell-evaluated behavior.** Decision test: can this be expressed as static data or generated config without bash evaluating shell state? If yes -> nix. If no -> bash. See [Nix/bash boundary](#nixbash-boundary).

## What this repo owns

- `shared.nix` -- cross-platform packages, programs, session variables; imported everywhere
- `contexts/linux-base.nix` -- Linux+Crostini shared layer: notify-send wrapper, calendar/khal-notify, dotfile symlinks
- `contexts/<platform>/home.nix` -- platform-specific packages and overrides
- Bash -- custom app-based init system
- Git -- identity, aliases, global ignore (now home-manager-managed via `home.file`)
- Tmux, SSH, Ranger, Liquidprompt -- platform-aware via `contexts/`, deployed via home-manager
- Claude Code -- settings managed via `home.file`
- VPN access -- gpoc Rust rewrite, vpn-slice, vpn-connect wrapper (both platforms); plus Crostini-only browser proxy stack
- Phone notifications -- `notify-send` wrapper bridging to ntfy.sh
- Neovim -- separate `dot_vim` repo

## Structure

```
shared.nix                      # Shared packages, programs, config (imported by all contexts)
home.nix                        # Symlink to active context's home.nix
flake.nix, flake.lock           # Crostini HM configs, lockfile-pinned bash tools, multi-system dev shell
bash-tools.nix                  # Bash dev tool derivations (flake sources or fetchFromGitHub fallback)
update-env                      # Idempotent deployment script (installs nix, bootstraps shell)
claude/                         # Claude Code config: settings.json + CLAUDE.md (base, stage 1) + CLAUDE-era.md (era/guides, stage 2)
bash/
  init.bash                     # Entry point -> .bashrc, .bash_profile, .profile
  apps/                         # Per-app modules (env, init, cmds, deps)
  settings/                     # Base, login, interactive, env, cmds
  lib/                          # Init system internals
contexts/
  mkScriptBin.nix               # Shared helper: build wrapped script binaries with store-path substitutions
  linux-base.nix                # Linux+Crostini shared layer (imports shared.nix); calendar, notify-send wrapper, dotfile symlinks
  linux/home.nix                # NixOS-specific (imports linux-base.nix); gpoc, vpn-connect via flake input
  crostini/home.nix             # Crostini-specific (imports linux-base.nix); vpn-connect (apt gpoc), tinyproxy + PAC for UC-8
  macos/home.nix                # macOS-specific (imports shared.nix directly; skips the linux-base layer)
gitconfig, gitignore_global     # Git (SSH commit signing enabled on linux)
tmux.conf                       # Context-dependent symlink
ssh/config, ssh/authorized_keys  # Tracked; HM-managed client config (symlinked via linux-base.nix)
ssh/*.pub                        # Per-machine public key sidecars (fingerprint validation only; no private keys or encrypted material in repo)
ranger/                         # File manager
liquidprompt/                   # Prompt theme
scripts/                        # Setup utilities (notify-send, vpn-connect, khal-notify, encrypt-secrets, with-secret, lib.bash, load-sparkline)
docs/                           # use-cases.md, design.md, security.md, secrets-lifecycle.md, environment-lifecycle.md, vpn.md, uc-init.md
```

## Component Design

### Deployment (UC-4)

`update-env` takes a bare machine to fully configured. Lives in `~/dotfiles/update-env`, deployed to `~/.local/bin/`. Two stages:

**Stage 1** (critical path -- working shell with identity):

1. System setup. Crostini: verifies ChromeOS shared storage is mounted, then accepts optional hostname argument (`update-env -1 <hostname>`), written to `$CrostiniDir/hostname` for machine identity. First run without hostname is fatal. Creates `$CrostiniDir` only when backing storage exists. All platforms: apt-get upgrade (crostini/debian only).
2. Clone dotfiles via HTTPS, install bootstrap symlinks (`.bash_profile`, `.bashrc`, `.profile` -> `bash/init.bash`; `~/dotfiles/context` -> active context). Remaining symlinks managed by home-manager via `linux-base.nix`.
3. Install Nix + home-manager + gpoc (crostini/debian/linux/macos -- skipped on NixOS). Installs gpoc `.deb` from yuezk's GitHub releases (Crostini only -- avoids the upstream flake's multi-minute Rust build). Then uses `nix run ~/dotfiles#home-manager -- switch --flake ~/dotfiles#penguin` to apply the full home-manager config via the lockfile-pinned HM CLI exposed from the dotfiles flake. VPN wrapper (`vpn-connect`) included; depends on the apt-installed `gpclient`. Core dev tools (task.bash, mk.bash, tesht) nix-packaged in `bash-tools.nix` with sources pinned as `flake = false` inputs in `flake.nix`; available after home-manager switch. Env vars `TASK_BASH_LIB` and `MK_BASH_LIB` set to nix store paths for automation scripts. No `--impure` needed. No persistent `home-manager` installation -- it runs transiently via `nix run`. Installs `age` (used by `scripts/encrypt-secrets` for local secrets backup -- not for repo storage; see [Security Model](#security-model)).
4. Credential restore (Crostini only, requires hostname): `restoreSshKey` restores SSH key from local or mount cache; if neither exists, prompts Ted to retrieve from 1Password (see [Security Model](#security-model)). `restoreSecrets` restores secrets bundle from cache or 1Password. `loadSshKey` loads key into agent via keychain with `SSH_ASKPASS_REQUIRE=never` (the nix openssh derivation has a compiled-in askpass path that doesn't exist; without this override, `ssh-add` inside keychain's nested `$()` falls back to the broken askpass instead of prompting on `/dev/tty`). `authPreflight` checks that the key is loaded in the agent, then tests SSH auth to each provider -- distinguishes "key not in agent" from "key not registered" from "unreachable." After this step, `git push` and SSH clones work. Skipped if no hostname is set (re-run with hostname to fix).

**Stage 2** (projects, dev tool repos):

5. Re-run home-manager (idempotent convergence -- no-op if stage 1 already applied the same config).
6. Platform-specific setup (crostini only)
7. Clone dev tool repos for development (task.bash, fp.bash, mk.bash, tesht). Symlinked to `~/.local/bin/` for interactive use and executable overrides. Tools themselves already available via nix (step 3).
8. Clone and link project repos (jeeves, sofdevsim-2026, blog, tandem-protocol, era)
9. Work projects (VPN-dependent, graceful failure via `try` + `ConnectTimeout`)
10. Neovim plugins, daily notes

Bare `update-env` runs both stages sequentially. `-1`/`-2` flags run individual stages. Hostname positional argument accepted only with `-1` (`update-env -1 calderon`); rejected otherwise.

**Deployment terminology:**

- **Stage** -- top-level division. Stage 1 = critical path (working shell with identity). Stage 2 = projects, VPN.
- **Step** -- a numbered item within a stage (1-10 above). Referenced as "step 7" or "steps 8-10".
- **Phase** -- legacy label in `update-env` box comments (PHASE 1-7). Numbering does not map 1:1 to steps. Docs use "step" for the canonical sequence.
- **Section** -- progress marker emitted by `section <name>` calls in `update-env`; typically sub-step granularity (e.g. one `section` per repo clone within a step).

All public repo clones use HTTPS fetch with SSH push URLs (idempotent remote migration on every run). Private repos use SSH with `try` wrappers. `task.GitUpdate` uses `git pull --rebase --autostash` so repos with uncommitted local changes are updated without losing work.

Idempotent. Platform detection: macos -> crostini -> nixos/$HOSTNAME -> debian -> linux. For post-deployment maintenance, multi-machine sync, and development workflow, see [environment-lifecycle.md](environment-lifecycle.md).

**What belongs in update-env vs. home-manager:** The split is governed by one structural constraint and two categories:

*Structural constraint:* anything home-manager needs in order to run must be managed by `update-env`, because it must exist before `home-manager switch` executes. This is a hard dependency, not a preference.

| Owner | What | Count | Why |
|-------|------|-------|-----|
| `update-env` (bootstrap) | `.bash_profile`, `.bashrc`, `.profile` -> `bash/init.bash`; `context` -> active platform | 4 symlinks | Must exist before nix/HM runs. Shell init is a prerequisite for everything else. |
| `home-manager` (`bash-tools.nix`) | task.bash, mk.bash (libs) + mk, tesht (executables) | 3 derivations | Bash dev tools pinned as `flake = false` inputs in `flake.nix`. Libraries to nix store (dependency-only); executables on PATH. Env vars `TASK_BASH_LIB`, `MK_BASH_LIB` inject store paths for automation scripts. Bump with `nix flake update <name>`. NixOS path (via shared.nix fallback) uses `fetchFromGitHub` with pinned hashes until nixos-config consumes flake outputs. |
| `update-env` (external) | Dev tool and project repos (steps 7-10) cloned and linked to `~/.local/bin`; `update-env` itself; `era-mcp.service`; neovim config; SSH keys; credential files; crostini mounts; scaffold-managed nix-wrapper + .envrc per project | ~30 symlinks + installs | External repos, credentials, and platform mounts that live outside the dotfiles tree. HM can only manage files whose source is inside the nix evaluation -- cloned repos and secrets are not. Dev tool clones override nix executables via PATH for active development. |
| `home-manager` (`home.file`) | gitconfig, gitignore_global, tmux.conf, liquidprompt (2), ssh (2), ranger (3) | 10 symlinks (`linux-base.nix`) | Static dotfile configs consumed by programs. No bootstrap dependency. Benefit from HM's atomic generation switching and rollback. |
| `home-manager` (`home.file`) | Claude settings + base CLAUDE.md (Conventions, Secrets) | 2 copies (`claude.nix`) | `force: true` copies -- Claude Code may overwrite these, so HM restores them on switch. Stage-1-safe only; no era/evtctl/guide dependencies. |
| `update-env` (stage 2) | Claude era config (CLAUDE-era.md) + per-project memory redirects | ~15 files | Era-dependent Claude Code config: memory redirects point projects to era, CLAUDE-era.md adds era/evtctl/guide instructions. Requires era to be built and running. |
| `home-manager` (`home.file`) | panel, vpn, digi-security-watch scripts; proxy PAC; gpgui desktop entry | 3 symlinks + 1 generated + 1 symlink (`crostini/home.nix`) | Crostini-only scripts, generated config, and gpoc URL scheme handler. |
| `home-manager` (`programs.*`) | direnv, bat, firefox, khal, vdirsyncer | 5 modules | Declarative program config via HM modules -- not `home.file` but the same dependency tree. |

*Decision test for new files:* (1) Is it needed before HM runs? -> `update-env`. (2) Does its source live outside `~/dotfiles`? -> `update-env`. (3) Otherwise -> `home.file` with `mkOutOfStoreSymlink` for edit-in-place, or a `programs.*` module if one exists.

The `home.file` blocks use `mkOutOfStoreSymlink` to preserve edit-in-place semantics -- symlinks point at the live source files in `~/dotfiles/`, not into the nix store, so editing the source is immediately visible without `home-manager switch`.

#### Why symlinks, not immutable copies

The NixOS model copies config files into the read-only nix store, making them immune to runtime mutation. This is valuable when the consumer of a config is a program that might silently overwrite it. But the files managed here -- bash modules, tmux.conf, gitconfig, ssh config, ranger, liquidprompt -- are files the user writes and controls. No program writes back to them; the drift risk is zero. Symlinks give instant feedback: edit the source file, the change is live. Immutable copies would require a rebuild/deploy step for every edit, adding friction without solving a real problem. The `home.file` blocks that do exist (Claude config, gpgui desktop entry, proxy PAC) use `force: true` or are generated -- cases where immutability or atomic replacement actually matters. If a file were ever at risk of being silently modified by a program, the right move would be to promote it to a `home.file` block rather than building a parallel copy mechanism.

**Post-install messages** -- `sshKeyEpilogue` prints registry SSH key URLs inline (copyable from terminal) when a key is generated. `postInstallMessages` prints Crostini-specific setup (PAC URL and ChromeOS proxy instructions) inline. All URLs are printed directly so Ted can copy them without opening a file. Platform-gated by `case $(platform) in crostini ) ... ;; esac` so other hosts don't see Crostini-specific reminders.

All project repos -- including private repos like jeeves -- are cloned by update-env. Private repos use `try` so failures are non-fatal. All `*CloneAndLinkTask` functions default the branch to `main`.

On NixOS, `~/nixos-config/flake.nix` imports `home.nix` via flake input. Dotfile symlinks still deployed by `update-env`.

### Bash Init (UC-1)

#### Why a single entry point

The conventional bash init model splits startup across `.profile`, `.bash_profile`, and `.bashrc`. Which file runs depends on an interaction of login vs non-login, interactive vs non-interactive, bash vs sh, local vs remote -- a sourcing taxonomy complex enough that even experienced engineers cannot reliably state the full rules. The result is shell behavior that is difficult to predict, debug, or control.

`init.bash` replaces all three files with a single entry point. Mode detection is explicit (`ShellIsLogin`, `ShellIsInteractive`, `Reload`) and every sourcing decision is visible in the code. No hidden file-selection rules, no "bash checks for .bash_profile first but falls back to .profile unless..." -- the user reads one file and knows exactly what runs when.

This design does not use `programs.bash` (home-manager's bash module). However, other `programs.*` modules and `home.sessionVariables`/`home.sessionPath` are used freely -- principle 3 only prohibits HM managing bash startup files.

#### Architecture

`bash/init.bash` is symlinked to `.bashrc`, `.bash_profile`, `.profile`. Supports `source ~/.bashrc reload` for live reloading.

Init flow:
1. Resolve repo root via symlink
2. Source `lib/initutil.bash` (shell detection, Alias/reveal, `SplitSpace`/`Globbing`)
3. Login or reload -> source `hm-session-vars.sh` directly (if/elif fallback for portability)
4. Source `context/init.bash` (platform-specific, if present)
5. Hooks: explicit order -- keychain (login), liquidprompt (interactive), direnv (interactive)
6. Source `settings/base.bash`, `settings/cmds.bash`
7. Commands: auto-discover `apps/*/cmds.bash` (interactive, order-independent)
8. Interactive -> source `settings/interactive.bash`
9. Interactive login or reload -> source `settings/login.bash`

App modules are directories under `bash/apps/<app>/` with:
- `init.bash` -- startup hook (sourced explicitly in init.bash in defined order)
- `cmds.bash` -- aliases and functions (auto-discovered, interactive only)

Current app modules:
- `direnv` -- PROMPT_COMMAND hook (appends after liquidprompt)
- `git` -- 44 shell aliases + workflow functions (europe, wolf, venice, etc.)
- `keychain` -- SSH agent via keychain eval (id_ed25519, login hook). Uses `SSH_ASKPASS_REQUIRE=never` to prevent nix openssh's broken compiled-in askpass fallback.
- `mnencode` -- randword function
- `pandoc` -- shannon (markdown reformatter) function
- `stg` -- 30+ stgit aliases + workflow functions

Liquidprompt is nix-packaged and sourced via `command -v liquidprompt` (not an app module). The `liquidprompt/` directory contains only config (`liquidpromptrc`) and theme overrides (`liquid.theme`), deployed to `~/.config/` by home-manager.

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

**Hooks** (order-sensitive, rare) are sourced explicitly in `init.bash` in a defined order. Currently: liquidprompt -> direnv -> keychain. Order matters because direnv's PROMPT_COMMAND hook must append after liquidprompt's. Adding a hook means adding a line to `init.bash` -- explicit, visible, no discovery mechanism needed.

**Commands** (order-independent, common) are auto-discovered from `bash/apps/*/cmds.bash`. Currently: git, stg, mnencode, pandoc. Order doesn't matter -- aliases and functions are independent. Adding commands means dropping a `cmds.bash` file in a new directory.

**Session variables** are sourced directly from `hm-session-vars.sh` in `init.bash` (login only), replacing the current indirect path through the home-manager app module symlink. Both `~/.nix-profile/...` and `/etc/profiles/per-user/$USER/...` paths are checked for NixOS/standalone portability.

**Session environment** is managed entirely by nix via `home.sessionVariables` and `home.sessionPath` in `shared.nix`. These flow into the shell through `hm-session-vars.sh`, sourced directly by `init.bash` on login.

**Failure isolation:** In the target architecture, hook sourcing and command sourcing are separate passes -- a syntax error in a `cmds.bash` file does not prevent hooks from running. In both current and target architectures, `TestAndSource` silently skips missing files, and `source` failures in one module do not abort the shell. The shell starts even with broken modules; errors appear in context.

**Liquidprompt:** Now nix-packaged (`shared.nix`). `init.bash` sources it via `command -v liquidprompt` with a guard so the shell starts cleanly if the package is missing (e.g., before first `home-manager switch`). Temp, RAM, and battery indicators are disabled in `liquidpromptrc` -- the status bar (waybar/panel) monitors these instead.

### Rejected alternatives

**`programs.bash` as the primary shell-init framework.** Generates `.bash_profile`, `.profile`, and `.bashrc` -- re-implementing the three-file sourcing model that `init.bash` was designed to replace. Would require cramming the app module system into `initExtra` as opaque nix strings. Cannot support the `Alias`/reveal mechanism (`shellAliases` produces plain aliases). Other `programs.*` modules (direnv, bat, firefox, etc.) are used freely -- this rejection is specific to HM managing bash startup files. See [Why a single entry point](#why-a-single-entry-point).

**Generated `init.bash` from nix.** Would make the structure declarative but would obscure debugging -- instead of reading one bash file, you'd read a nix expression to understand what bash gets generated. Violates the core promise of UC-I0: the user reads `init.bash` and knows exactly what runs. Revisit if: the number of hook-producing integrations grows beyond a handful, ordering constraints become nontrivial, or manual hook wiring creates duplication across hosts.

**Generalized auto-discovery for hooks.** The previous `OrderByDependencies` mechanism discovered, detected, and ordered all app modules. Since only 2 modules have hooks and their order is fixed, a general-purpose ordering system was unnecessary overhead. Explicit hook ordering in `init.bash` is simpler, more visible, and more reliable than dependency resolution.

**Keeping the detection layer.** `detect.bash` and `IsApp`/`IsCmd` gated module loading on tool availability. Under declarative provisioning, runtime detection is not a design goal -- nix guarantees packages are on PATH, and the test suite validates presence at build time. Liquidprompt was the sole user of `detect.bash`; its availability guard is now inline in `init.bash`.

### Contexts (cross-cutting)

`contexts/` holds platform overrides plus a shared Linux+Crostini intermediate layer. A `context` symlink at repo root points to the active platform.

Each platform context can override `home.nix`, `gitconfig`, `tmux.conf`, and other configs. Top-level files like `gitconfig` and `home.nix` are symlinks to their context version.

The home-manager import chain:
- `contexts/macos/home.nix` -> `shared.nix`
- `contexts/linux/home.nix` -> `linux-base.nix` -> `shared.nix`
- `contexts/crostini/home.nix` -> `linux-base.nix` -> `shared.nix`

`linux-base.nix` exists because Linux and Crostini share substantial config that doesn't apply to macOS: notify-send-bridge (depends on libnotify), calendar/khal-notify systemd units, and the dotfile symlink set. Before this layer was extracted, both `linux/home.nix` and `crostini/home.nix` had ~80 lines of duplicated config that drifted over time.

gpoc/vpn-connect don't live in `linux-base.nix` because the gpoc source differs per platform: Crostini uses gpoc installed via apt (avoiding the multi-minute Rust build from the upstream flake), NixOS uses a proper flake input from `nixos-config/flake.nix` (pure). Each platform builds a `vpn-connect` wrapper via `mkScriptBin` in its own context (`crostini/home.nix` and `linux/home.nix` respectively). On Crostini, `gpclient` is referenced at `/usr/bin/gpclient`.

Machine-specific contexts (e.g., `calumny`) symlink most files to their platform context (e.g., `../nixos/home.nix`) and add machine-specific config. This keeps platform config shared while allowing per-machine overrides.

### Packages (UC-1, UC-2, UC-3)

Declared in `home.nix`. See the file for the current list. By category:

**Dev tools (UC-1):** git, neovim, tmux, stgit, gh, claude-code, jira-cli-go, scc, pandoc, diff-so-fancy, silver-searcher (ag), highlight, asciinema, asciinema-agg

**System/CLI (UC-3):** bottom, htop, ncdu, jq, tree, rsync, coreutils, dig, zip, mnemonicode

**Wayland (UC-2):** wl-clipboard, cliphist, libnotify

**Apps (UC-2):** Firefox (via `programs.firefox`), Obsidian, signal-desktop

**VPN (UC-7):** gpoc (yuezk Rust rewrite), vpn-slice, vpn-connect wrapper. On Crostini, gpoc comes from apt (avoiding the Rust build); on NixOS, via a proper flake input in `nixos-config/flake.nix` passed through `extraSpecialArgs`. Both platforms use `mkScriptBin` to wrap `scripts/vpn-connect`. Plus the Crostini-only browser-VPN-access stack: tinyproxy + darkhttpd (UC-8).

**Notifications (UC-9):** notify-send wrapper that bridges desktop notifications to ntfy.sh phone push. Drops in transparently as `notify-send` for any caller.

**Calendar (UC-1):** khal, vdirsyncer (linux and crostini -- systemd integration via `linux-base.nix`)

**File management (UC-3):** ranger

### Programs managed by home-manager modules

Some tools use `programs.*` instead of `home.packages` for declarative config:

- `programs.direnv` -- direnv + nix-direnv for `use flake` support. Bash integration disabled (custom hook in `bash/apps/direnv/init.bash`).
- `programs.bat` -- default style via config file, no shell alias needed.
- `programs.firefox` -- declarative search engine and extension policies.
- `programs.khal`, `programs.vdirsyncer` -- calendar sync (linux and crostini).

### Session environment managed by nix

`home.sessionVariables` and `home.sessionPath` in `shared.nix` provide EDITOR, PAGER, CFGDIR, SECRETS, XDG_CONFIG_HOME, and PATH additions. These flow into the shell via `hm-session-vars.sh`, sourced directly by `init.bash` on login (if/elif fallback for NixOS/standalone portability).

### Firefox (UC-2)

Managed via `programs.firefox` (home-manager module), not `home.packages`. This enables declarative profile and search engine configuration.

- Default search engine: DuckDuckGo (via `policies.SearchEngines.Default`)
- Extensions auto-installed via `policies.ExtensionSettings` with `force_installed`: uBlock Origin, Privacy Badger, Vimium
- All extensions enabled in private browsing (`private_browsing = true`)
- Uses policies instead of per-profile config -- policies apply to all profiles regardless of profile path, which varies per machine
- Works on both NixOS (home-manager as NixOS module) and Debian/Crostini (standalone home-manager) -- policies are baked into the wrapped Firefox package at build time

### Security Model

See [security.md](security.md) for the full security model: threat actors, trust boundaries, confidentiality and integrity models, accepted risks, and controls.

**Key constraints for this section:** this repo is public. No encrypted secret material may be committed. Private keys and secrets are backed up to 1Password, not to the repo. The mount cache stores plaintext on ChromeOS-host-visible storage (accepted tradeoff). Fingerprint validation against repo `.pub` is self-consistency, not authenticity. All commits are SSH-signed; force-push is disallowed on `main`.

### SSH Key Bootstrap (UC-4)

Per-machine SSH keys identified by hostname. Public key sidecars committed to the repo for validation:

```
ssh/
  id_ed25519_calumny.pub      # plaintext public key (for fingerprint validation)
```

Private keys are stored in 1Password, not in the repo. See [Security Model](#security-model).

**Restore priority** (stage 1 step 4):
1. **Local** -- `~/.ssh/id_ed25519` exists and `.pub` fingerprint matches repo `.pub` -> accept
2. **Mount cache** -- `$CrostiniDir/ssh/<hostname>/id_ed25519` with `.pub` fingerprint matching repo `.pub` -> restore, no passphrase needed
3. **1Password** -- retrieve private key via `op` CLI (or manually from app) -> install to `~/.ssh/id_ed25519`
4. **Generate** -- no key exists anywhere -> generate new passphrase-protected key, store in 1Password, commit `.pub` sidecar to repo

**Trust model:** private key is trusted to match `.pub` if the pair was produced together by `ssh-keygen`. Fingerprint validation against the repo `.pub` is a self-consistency check, not an authenticity guarantee (see [Security Model](#security-model)). Manual `.pub` replacement is unsupported.

**Hostname as machine identity:** admin-assigned, stored in `$CrostiniDir/hostname` on Crostini, `$HOSTNAME` on NixOS. `penguin` (Crostini default) is rejected. Collision guard: repo `.pub` fingerprint vs local `.pub` fingerprint -- mismatch = collision error. Hostname validated with `[a-z0-9][a-z0-9-]*`.

**Host key trust: TOFU.** `StrictHostKeyChecking=accept-new` for first contact on fresh machines. Prevents interactive prompts during bootstrap while rejecting changed host keys on subsequent connections.

**Auth preflight** (stage 1 step 4): guards registry checks with a fingerprint-specific agent test -- gets the `.pub` fingerprint via `ssh-keygen -lf`, then checks `ssh-add -l` for that fingerprint. If the specific key is not in the agent (empty agent, wrong key loaded, or unreadable `.pub`), reports "key not in agent" and skips registry checks. This prevents the misleading "key not registered" diagnostic that `BatchMode=yes` SSH failures would otherwise produce (the failure looks identical whether the key was rejected by the registry or never offered). When the key is confirmed in the agent, tests SSH auth to GitHub, Codeberg, Bitbucket using `BatchMode=yes`, `IdentitiesOnly=yes`, explicit identity file. Distinguishes "not registered" from "unreachable." VPN-gated stash tested only when `tun0` is up.

**Decision logic** (`sshKeyAction` in `update-env`): pure function mapping filesystem state to exactly one action. Code is authoritative; this table is a reading aid.

| State | Action | Notes |
|-------|--------|-------|
| local exists, localFp == repoFp | `present` | strongest match |
| local exists, localFp != repoFp | `collision` | error: two keys for same hostname |
| no local, cache exists, cacheFp matches | `restore_from_cache` | fast path (no passphrase) |
| no local, `op` available | `restore_from_op` | retrieve from 1Password |
| no local, no cache, no `op`, tty | `generate` | new key; store in 1Password manually |
| any path needing tty but no tty | `missing_noninteractive` | pre-provision required |

`SshKeyStatus` values (set by restore, read by `sshKeyEpilogue`): `present`, `restored`, `generated`, `collision`, `missing_noninteractive`.

Operator workflows (bootstrap, rotation, recovery, decommission): [secrets-lifecycle.md](secrets-lifecycle.md).

### Secrets Management (UC-4)

Per-machine secrets stored in `~/secrets/`. Backed up to 1Password -- not to the repo. See [Security Model](#security-model).

**Filename policy:** `lib.ValidSecretName` -- alphanumeric start, then `[a-zA-Z0-9._-]*`. No dotfiles, no paths, no spaces. Shared between `scripts/encrypt-secrets` (producer) and `restoreSecrets` (consumer) via `scripts/lib.bash`.

**Restore priority:**
1. **Local** -- `~/secrets/` has non-dot files -> accept (no restore needed)
2. **Mount cache** -- `$CrostiniDir/secrets/<hostname>/` with freshness check via `.bundle-hash` -> restore
3. **1Password** -- retrieve via `op` CLI or manually from app -> populate `~/secrets/`

**Restore behavior:** restore only runs when `~/secrets/` is empty (Tier 1 short-circuits if any non-dot files exist). Files are moved into `~/secrets/` additively; restore never overwrites existing secrets.

**Archive validation** (`validateSecretsArchive`): when restoring from a bundle (cache or export), pre-extraction validation in two passes:
1. **Name pass** -- `tar tf`: accepts root (`.`/`./`), rejects non-root directories (`*/`), validates remaining names via `lib.ValidSecretName`.
2. **Type pass** -- `tar tvf`: accepts regular files (`-`) and root directory (`d` only for `.`/`./`). Rejects symlinks, hardlinks, devices, fifos. Requires at least one regular file.

Fails closed: corrupt or non-tar input rejected before extraction. Post-extraction `find -not -type f` remains as defense-in-depth.

**Scripts:**
- `scripts/encrypt-secrets` -- bundles `~/secrets/` (valid non-dot files only) into age-encrypted tarball for local backup or 1Password export. Warns about excluded dotfiles. Sources `scripts/lib.bash`.
- `scripts/with-secret` -- injects file-based secret as env var into child process only. Last-resort shim for tools requiring env vars.
- `scripts/lib.bash` -- shared helpers (`lib.MachineHostname`, `lib.ValidateHostname`, `lib.ValidSecretName`, `lib.Glob`). Sourced by both `update-env` and `encrypt-secrets`.

Operator workflows (add/update/remove, rotation, recovery): [secrets-lifecycle.md](secrets-lifecycle.md).

### VPN (UC-7)

GlobalProtect VPN with SAML SSO via yuezk's Rust rewrite of `globalprotect-openconnect` (gpoc). nixpkgs ships only an old C++/Qt 1.4.9 build that drags in qtwebengine. gpoc is sourced differently per platform:
- **Crostini:** installed via apt by `update-env` stage 1 (`aptInstallGpocTask` downloads the `.deb` from yuezk's GitHub releases and installs with `dpkg`). The upstream flake's Rust compilation takes several minutes and has no binary cache. `crostini/home.nix` references `/usr/bin/gpclient` directly.
- **NixOS:** proper flake input `globalprotect-openconnect` in `nixos-config/flake.nix`, passed to home-manager via `extraSpecialArgs` as `gpoc` (pure evaluation)

Components:
- `gpauth` -- performs SAML auth via the user's default browser, captures the cookie
- `gpclient connect` -- drives openconnect (linked in via FFI) to bring up the GP tunnel
- `vpn-slice` -- passed as `--script` to gpclient/openconnect for split-tunnel routing and split-horizon DNS

Entry point: `vpn-connect` -- a Nix-managed wrapper script built via `mkScriptBin` on both platforms (`contexts/linux/home.nix` and `contexts/crostini/home.nix`). The derivation substitutes `@vpn-slice@` and `@gpclient@` with absolute store paths because those binaries are invoked under `sudo`, which strips PATH. `gpoc` is also added to the wrapper's runtime PATH for the unsudo'd `gpauth` invocation. On NixOS, `waybar.nix` builds an identical derivation for its systemd service (nix deduplicates the store path).

The script reconnects in a loop on disconnect; Ctrl-C exits cleanly.

#### SAML callback flow

The callback path is non-obvious and the source of past failures. Full step-by-step description lives in [docs/vpn.md](vpn.md). Summary:

1. `gpauth` opens a one-shot HTTP server to serve the SAML form HTML
2. `gpauth` opens a separate raw TCP listener on another port and writes that port to `/tmp/gpcallback.port`
3. Browser does SAML, the IdP returns a `globalprotectcallback://<base64>` URL
4. The OS dispatches that URL scheme to `gpclient launch-gui %u` via the registered `.desktop` handler
5. `gpclient launch-gui` reads the port file, opens a TCP socket to localhost, writes the auth data
6. `gpauth` accepts, reads the cookie, prints to stdout (piped to `gpclient connect --cookie-on-stdin`)

The URL scheme handler is registered via home-manager's `xdg.desktopEntries.gpgui` plus `xdg.mimeApps`, both in `contexts/crostini/home.nix`.

#### Crostini garcon discovery gotcha

home-manager's `xdg.desktopEntries` installs to `~/.nix-profile/share/applications/`. **Garcon (the ChromeOS<->container bridge) only scans `~/.local/share/applications/`** for desktop files when propagating MIME registrations to the host, not arbitrary `XDG_DATA_DIRS` entries. Without an extra symlink into the standard XDG dir, host ChromeOS Chrome never learns about the `globalprotectcallback://` handler, the SAML callback URL is silently dropped, and `gpauth` hangs forever on `accept()`.

The fix: a `home.file.".local/share/applications/gpgui.desktop".source` symlink (via `mkOutOfStoreSymlink`) into `~/.nix-profile/share/applications/gpgui.desktop`, defined in `crostini/home.nix`.

#### Split-tunnel routing

vpn-slice receives two categories of routing arguments:

1. **CIDR ranges** (`10.0.0.0/8`, `172.26.0.0/16`) -- route all corporate internal and VPN infrastructure traffic through the tunnel. Eliminates per-host discovery for routing.
2. **Positional hostnames** -- vpn-slice resolves these via the VPN's DNS server and writes `/etc/hosts` entries, providing split-horizon DNS. Two subcategories:
   - **Split-horizon hosts** (`stash.digi.com`, `nexus.digi.com`) -- internal `*.digi.com` services where public DNS returns a different IP (e.g., stash -> Atlassian `198.51.192.159`) or NXDOMAIN. The `/etc/hosts` entry overrides the system resolver to use the internal IP. Routing is already handled by the `10.0.0.0/8` CIDR.
   - **AWS-hosted services** (`dm1.devdevicecloud.com`, `gitlab.drm.ninja`, `3.16.193.243`) -- resolve identically from public and VPN DNS, but traffic must traverse the tunnel so the server sees the VPN source IP. vpn-slice adds both routes and `/etc/hosts` entries.

`remotemanager.digi.com` is a public Digi site accessed externally -- it is intentionally excluded from the tunnel.

Note: `--domains-vpn-dns` was evaluated but does not write `/etc/hosts` entries, only affecting vpn-slice's own internal DNS queries. Positional hostnames remain necessary for split-horizon DNS.

The PAC file in `contexts/crostini/home.nix` uses `dnsDomainIs(host, ".digi.com")` to auto-match internal `*.digi.com` hosts (with early `DIRECT` exclusions for public digi sites like `remotemanager.digi.com`), plus an explicit list of the AWS-hosted services. New `*.digi.com` hosts auto-proxy via the PAC but still need adding as positional hostnames in vpn-connect for the `/etc/hosts` entry.

Notes:
- `--gateway "US East"` pre-selects the gateway, avoids interactive prompt
- `--browser xdg-open` so the browser choice respects ChromeOS's Sommelier routing on Crostini and `xdg-mime` defaults elsewhere
- yuezk's flake is unpinned; v2.4.4 tag fails to build, main works. Pin to a specific commit when upstream stabilizes

### Browser VPN access (UC-8)

ChromeOS host Chrome lives outside the Crostini container and cannot reach `tun0` directly. To let Ted click VPN-only URLs from host Chrome (instead of falling back to terminal tools or in-container Firefox), `contexts/crostini/home.nix` declares two systemd user services and a PAC file:

- **`tinyproxy`** (forward HTTP proxy) listens on the container's `127.0.0.1:8118`. Garcon's container->host localhost forwarding makes that port reachable from ChromeOS Chrome. tinyproxy itself has no special VPN knowledge -- it just forwards requests, which traverse the container's tun0 because that's the container's network namespace.
- **`darkhttpd`** (single-binary static file server) serves a PAC file from `~/.local/share/proxy-pac/proxy.pac` on `127.0.0.1:8120`. Used as a "PAC URL" host so Chrome can fetch the script.
- **`proxy.pac`** is generated by `pkgs.writeText` inside `contexts/crostini/home.nix`. Public digi sites (`remotemanager.digi.com`, `www.digi.com`, `digi.com`) are excluded early as `DIRECT`. Remaining `*.digi.com` hosts are proxied (auto-matching any new internal service), plus an explicit list of AWS-hosted VPN services. Everything else returns `DIRECT`.

Ted manually points ChromeOS Network -> Proxy -> Automatic configuration at `http://127.0.0.1:8120/proxy.pac`. After that, Chrome consults the PAC per-request:
- Non-VPN URL -> `DIRECT` -> Chrome connects without involving the container, no overhead
- VPN URL -> `PROXY 127.0.0.1:8118` -> Chrome sends to tinyproxy -> tinyproxy forwards via tun0

This is **crostini-specific** because no other host needs it: regular Linux/NixOS desktops route VPN traffic locally and reach VPN hosts directly. Lives in `contexts/crostini/home.nix` (not `linux-base.nix`) so other Linux machines don't pick up the config.

The PAC file uses `dnsDomainIs` for `*.digi.com` (auto-matching new internal services), with early `DIRECT` returns for public digi sites (`remotemanager.digi.com`, `www.digi.com`, `digi.com`), plus an explicit list for AWS-hosted services. Adding a new internal `*.digi.com` service requires adding it as a positional hostname in vpn-connect (for `/etc/hosts`) but needs no PAC change; adding a new external VPN-routed host requires updating both the vpn-slice positional args and the PAC's `vpnHosts` array; adding a new public `*.digi.com` site requires adding it to the PAC's exclusion list.

### Phone notification bridge (UC-9)

`scripts/notify-send` is a wrapper script that:
1. Forwards all arguments to the real libnotify `notify-send` (synchronously) for the local desktop popup
2. Parses `--urgency`, the trailing positional summary, and the optional body
3. If `~/secrets/ntfy-topic` exists and is readable, POSTs the notification to `https://ntfy.sh/<topic>` in a backgrounded subshell with `disown` so the calling tool doesn't block on the network

The wrapper is built via `mkScriptBin` in `linux-base.nix`. The `@notify-send@` placeholder is substituted at build time with the absolute store path to libnotify's `notify-send`, so the wrapper does not recurse into itself when invoked through PATH. `curl` and `coreutils` are added to the wrapper's runtime PATH.

Critical-urgency notifications get `Priority: high` on ntfy (loud notification on the phone); others get `Priority: default`. All messages get `Tags: bell` for the icon.

Tools that already call `notify-send` get phone push for free with no source changes -- `khal-notify` is the current consumer; future tools just call `notify-send` and inherit the bridge.

The wrapper shadows libnotify's `notify-send` because it's installed via a derivation named `notify-send` whose `bin/notify-send` ends up in the user's nix profile alongside libnotify's. Nix profile coalescing prefers the wrapper because it's installed via `home.packages` in `linux-base.nix` while libnotify is only present as a transitive dep of the wrapper itself (not directly in `home.packages`).

### Status widgets (UC-10)

Headless sessions (Crostini, SSH into NixOS without a desktop) don't have waybar, so the tmux status bar substitutes for it. Implementation lives in four files:

- **`scripts/probe-lib.bash`** -- shared probe library, sourced by both this repo's panel script AND nixos-config's waybar widget renderer. Caller sets `$State` to its own cache directory before sourcing. The same code path runs on both platforms -- drift in probe semantics is impossible at this layer. Defines:
  - Probe functions: `isStale`, `refresh`, `readState`, `pingHost`, `sshHost`, `combine`, `vpnUp`, `bitbucketApiProbe`, `codebergApiProbe`, `digiApiProbe`, `probeReachability`, `probePing`.
  - Widget metadata tables: `WidgetHost`, `WidgetVpnGated`, `WidgetApiFn`, `WidgetNoSsh` -- single source of truth for host names, VPN gating, API probe selection, and SSH probe skipping. Accessors `widgetHost`, `widgetVpnGated`, `probeWidget` let callers look up by widget key instead of repeating host strings. `WidgetNoSsh` marks hosts (dm1, nexus, remotemanager) that skip SSH probes -- `probeReachability` checks this table and skips `sshHost` for those entries, and `combine` treats `ssh=skip` + `ping=ok` as "on".
  - Injectable command globals: `Timeout`, `Ssh`, `Curl`, `Jq`, `Ip` -- each defaults to the real binary (`${Var:-binary}`) but can be overridden before sourcing or via bash dynamic scope in tests. This is the only test seam; the library has no other test hooks.

- **`scripts/panel`** -- tmux status bar renderer. Sources `probe-lib.bash`, sets `$State=$XDG_RUNTIME_DIR/panel`, and exposes `panel <module>` (returns a tmux-formatted segment with `#[fg=...]` color codes), `panel click <module>` (mouse handler), `panel poll` (synchronous warmup), and `panel layout` (dynamic status bar height). Health monitor widgets use `segment` (hidden when on) and service toggles use `alwaysSegment` (always visible). Supporting functions: `cachedHealthState`/`cachedPingState` (read cached state without new probes -- used by `healthSep` and `layoutCmd`), `healthSep` (dynamic separator, visible only when health widgets are), `hostnameCmd` (`~/crostini/hostname` on Crostini, system hostname elsewhere), `canLoadCmd` (checks `tmux show-env` for SSH without desktop).

- **`contexts/panel.tmux.conf`** -- shared panel config sourced via `session-created` hook (never during initial config parse -- session-scoped `set` silently fails before session creation). Options use `set` without `-g` so sessions independently have panel or not. `bind-key` is the exception (inherently global); guarded by `show-option` on `@panel-right`. Two sourcing paths: Crostini replaces Linux's conditional hook with unconditional; Linux's hook runs `panel can-load` (checks `tmux show-env` for `SSH_CONNECTION` set and `WAYLAND_DISPLAY` absent). Limitation: `tmux attach` doesn't re-evaluate. For full isolation: `tmux -L ssh new`.

- **`contexts/crostini/tmux.conf`** -- sources linux/tmux.conf for the base, then replaces Linux's conditional `session-created` hook with an unconditional one (Crostini is always headless).

**Probe cadences** (set in `probe-lib.bash`):
- SSH probe (`sshHost`): every 600s. `ssh -T git@<host>`; rc 0/1 or "shell request failed" both count as ok.
- TCP/443 ping (`pingHost`): every 30s. Uses `bash`'s `/dev/tcp/<host>/443` rather than ICMP because most vendor sites block ICMP.
- Vendor status API (`bitbucketApiProbe`, `codebergApiProbe`, `digiApiProbe`): every 30s. Atlassian Statuspage component `qmh4tj8h5kbn` (bitbucket), Codeberg Uptime Kuma monitor 7, and Digi Remote Manager status page (worst-of across all components) respectively. `digiApiProbe` is shared by dm1 and remotemanager widgets.

**State machine** (per `combine` in `probe-lib.bash`): the displayed class is the worst tier across (api, ssh, ping). `api=down` -> `off`. `api=degraded` -> `partial`. `ping=fail` -> `off`, AND `pingHost` invalidates the cached SSH success on failure so the widget can return to `on` only via a fresh successful SSH probe -- a partial recovery from a network blip lands in `partial`, not back in `on`. `ssh=ok && ping=ok` -> `on`. `ssh=skip && ping=ok` -> `on` (for hosts in `WidgetNoSsh`). `ping=ok` (without confirmed ssh) -> `partial`. Otherwise `unknown`.

**VPN gating**: `dm1`, `stash`, `gitlab`, `nexus` modules return early (empty string) when `tun0` is missing -- the segment vanishes from the bar entirely, since tmux's per-segment range tolerates empty content. `remotemanager` is public (not VPN-gated) and always probed.

**Widget order and separators:** Both waybar (nixos-config) and the tmux panel use the same canonical group order, separated by visual dividers (CSS borders in waybar, pipe characters in tmux):

1. **System** -- ssh, fw, vpn (waybar only; tmux has vpn only)
2. **Health** -- dm1, stash, gitlab, nexus, remotemanager, codeberg, bitbucket, teams, ntfy (external service reachability; VPN-gated widgets appear only when tunnel is up)
3. **Services** -- era (local infrastructure services managed by the user)
4. **Hardware** -- load, cpu, mem, disk, bat (local resource monitors; tmux omits backlight, vol, temp which are desktop-only; bat is present on Linux laptops)

Within each group, widgets cuddle with a single space between them. Empty widgets (VPN-gated when tunnel is down, threshold-gated below 90%, health monitors in `on` state) produce no output and no space -- the group contracts. The separator between vpn and the health group is dynamic (`healthSep`): it appears only when at least one health widget is visible, preventing empty `vpn | | era` artifacts. Other separators are always visible. A clock (`HH:MM`, click to show `MM/DD` for 2s) and hostname (reads `~/crostini/hostname` on Crostini, system hostname elsewhere) follow the hardware group with no separator. Changes to group membership or order must be mirrored in both renderers -- see nixos-config's `docs/design.md` Waybar section.

**Dynamic status bar height:** `panel layout` toggles between 1-line (`status on`) and 2-line (`status 2`) mode based on whether the window list + widget bar fits the terminal width. In 1-line mode, `status-right` renders the widget bar (via `#{E:#{@panel-right}}`); in 2-line mode, `status-format[1]` renders it and `status-right` is empty. Triggered by session-scoped tmux hooks (`client-resized`, `window-linked`, `window-unlinked`, `after-rename-window` -- set without `-g` so each session manages its own layout independently) and a silent `#(panel layout)` call embedded in `@panel-right` that runs every `status-interval` (5s). Width estimation: window list width (session name + tab names), widget bar width (dynamically counts actually-visible widgets via `cachedHealthState`/`cachedPingState` + separators + clock + hostname). Idempotent -- skips if already in the correct mode.

**Color palette** mirrors nixos-config's `home/sway/waybar.css`: light gray (`colour250`) = partial, dark gray (`colour244`) = off, amber (`colour130`) = unknown. Health widgets (all `segment`-based widgets except vpn and load) are **hidden when on** -- they signal by appearing, not by being always visible. cpu/mem/disk use white when above threshold, also signaling by appearing.

**cpu/mem/disk thresholding**: hidden below 90% (segment is empty), label + percentage in white (default text color) at 90%+. Implemented via `thresholdSegment`. Uses `df`, `/proc/meminfo`, and a delta against `/proc/stat` cached in `$State/cpu-stat`.

**Battery (`batModule`)**: hidden when charging, full, or above 10%. Warning [10,5%): "H:MM" in partial color (dimmer than clock, implies battery). Critical [5,0%]: "N% bat" in white (explicit label to distinguish from RAM/disk). Supports Crostini (`/sys/class/power_supply/battery/`) and standard Linux laptops (`/sys/class/power_supply/BAT0/`). Three sysfs interface fallbacks: `charge_now`/`current_now` (standard ACPI, most laptops), `charge_counter`/`current_now` (Crostini Android bridge), `energy_now`/`power_now` (energy-based laptops). Units cancel in all cases (uAh/uA = h, uWh/uW = h). Sysfs path injectable via `BatSysfs` for testing.

**Load sparkline**: 3-bar widget rendered left-to-right as 1m/5m/15m (matching `uptime`/`top` convention). Normalization formula:

```
idx = 1 + floor(load * 5 / (2 * nproc))
```

capped at 8. Bar 6 = 2 * nproc (the "2 processes waiting per CPU, time to be concerned" line). Bars 7-8 give headroom past that -- bar 8 saturates at ~2.8 * nproc. Below the concerned line the bar stays mostly empty; once you're past it, things are getting crazy and the bar fills up fast. `nproc` is invoked from bash and passed to awk via `-v nCpu`.

**State files** live at `$XDG_RUNTIME_DIR/panel/<widget>-{api,ssh,ping}` for the panel script and `/tmp/waybar-health/<widget>-{api,ssh,ping}` for nixos-config's waybar -- both use the same probe-lib code path but write to separate directories so the two consumers don't fight over each other's caches.

**Why text labels instead of icons**: ChromeOS Terminal is locked to a fixed font list (Cousine, Fira Code, JetBrains Mono, etc.) -- none of which include Nerd Font / Font Awesome glyphs. We tried installing alternative terminals (foot has no working clipboard under Sommelier; alacritty/kitty fail on the GL bridge) and rolled back. On NixOS SSH, the client terminal may have Nerd Font support, but text labels work universally across all clients without font assumptions. The widget contract is identical to waybar's; only the rendering glyphs differ. See git history for details.

**Drift risk**: this UC has a sibling implementation in `nixos-config/home/sway/waybar.nix` + `nixos-config/scripts/widget-status`. The probe code is shared (single source of truth in `probe-lib.bash`); the renderers are not. Widget group order, separator placement, visibility rules, and color mappings must be kept in sync between the two renderers. Cadences live in `probe-lib.bash` and are therefore actually shared. On NixOS, both renderers can be active on the same machine -- waybar on desktop sessions, panel on SSH sessions -- writing to separate state directories (`$XDG_RUNTIME_DIR/panel` vs `/tmp/waybar-health`). Both design docs (this file and `nixos-config/docs/design.md`) document the canonical group order -- update both when changing it.

### direnv (UC-1)

Automatically loads project-specific environments when entering a directory with `.envrc`. Works with Nix devShells via `use flake` in `.envrc`.

Managed via `programs.direnv` with `nix-direnv.enable = true` for cached `use flake` support. HM bash integration is disabled (`enableBashIntegration = false`) because the custom init uses its own PROMPT_COMMAND hook in `bash/apps/direnv/init.bash`. The custom hook appends (not prepends) to PROMPT_COMMAND so it runs after liquidprompt, which is declared as a dependency in `bash/apps/direnv/deps`.

### DNS Diagnostics (UC-1)

`dig` (from bind dnsutils) for hostname resolution troubleshooting, especially useful when debugging VPN split tunnel routing.

### GitHub CLI (UC-1)

`gh` for PR management, repo operations, and issue tracking from the terminal.

### Calendar (UC-1)

Work calendar synced from OWA via published ICS URL. Three components:

**vdirsyncer** syncs the ICS URL to `~/.calendars/work/` every 5 minutes (systemd timer). The ICS URL is a secret stored in `~/secrets/calendar-ics.url` -- vdirsyncer reads it at runtime via `url.fetch = ["command", "cat", ...]` so the URL never appears in committed config.

**khal** reads the local calendar and expands recurring events, handling rescheduled instances (`RECURRENCE-ID`), cancellations (`EXDATE`), and timezone conversion. CLI: `khal list today`.

**khal-notify** (`scripts/khal-notify`) runs every 5 minutes via systemd timer, checks for events starting in 60, 30, 10, or 5 minutes and sends desktop notifications via `notify-send`. Phone push happens transparently because the `notify-send` binary on PATH is the wrapper from UC-9 -- khal-notify itself has no ntfy code. The 5-minute notification uses critical urgency. A statefile (`~/.local/state/khal-notify/sent`) prevents duplicate notifications, cleaned daily.

Calendar config (`accounts.calendar`, `programs.khal`, `programs.vdirsyncer`, `services.vdirsyncer`) plus the custom khal-notify systemd unit live in `contexts/linux-base.nix`, imported by both `contexts/linux/home.nix` and `contexts/crostini/home.nix`. The khal-notify ExecStart uses `${config.home.homeDirectory}/dotfiles/scripts/khal-notify`, which works identically on both standalone home-manager (Crostini) and the NixOS home-manager module (linux). The systemd unit's `DBUS_SESSION_BUS_ADDRESS` uses systemd's `%U` specifier for the user UID instead of hardcoding `1000`.

### Relationship to nixos-config

```nix
dotfiles = {
  url = "path:/home/ted/dotfiles";
  flake = false;
};
globalprotect-openconnect = {
  url = "github:yuezk/GlobalProtect-openconnect";
};
```

NixOS imports `"${dotfiles}/contexts/linux/home.nix"` directly (the `home.nix` symlink chain doesn't resolve in the nix store) and layers Sway on top. The `globalprotect-openconnect` flake input provides gpoc as a pure flake reference; it's passed to home-manager via `extraSpecialArgs` as `gpoc` so `linux/home.nix` and `waybar.nix` can build the `vpn-connect` wrapper without `--impure`. Package changes happen here. The local path input means changes take effect on `nixos-rebuild switch` without pushing to GitHub first.

Now that dotfiles has its own `flake.nix` (for Crostini home-manager configs), nixos-config should eventually switch `dotfiles` from `flake = false` to `flake = true`, set `dotfiles.inputs.nixpkgs.follows = "nixpkgs"` and `dotfiles.inputs.home-manager.follows = "home-manager"`, and consume dotfiles outputs instead of raw file paths.

## Operational Properties

### Cross-host consistency

`shared.nix` guarantees identical packages and `programs.*` config across all hosts. VPN tools (gpoc, vpn-connect, vpn-slice) are on both NixOS and Crostini via platform-specific gpoc sourcing. Context-specific packages (browser proxy stack on Crostini, desktop apps on NixOS) are separated in context `home.nix` files.

The bash init system is host-agnostic -- same `init.bash`, same app modules, same settings. Platform adaptation goes through `context/init.bash` (currently unused but available). The `hm-session-vars.sh` sourcing path checks both standalone (`~/.nix-profile/...`) and NixOS (`/etc/profiles/per-user/$USER/...`) locations.

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

- On NixOS, home-manager runs as a NixOS module. Does `update-env` skip its home-manager step? **Yes.** `platform()` detects NixOS via `/etc/NIXOS` (with host-specific context support via `$HOSTNAME`) and gates step 3 (Nix + home-manager install) to non-NixOS platforms only.
