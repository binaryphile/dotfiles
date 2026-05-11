# Use Cases -- dotfiles

## Context

This repo is a fleet configuration management system for Ted's user environment. It targets a heterogeneous fleet -- NixOS workstations, disposable Crostini VMs on commodity Chromebooks, standalone linux systems, and macOS. System-level config and Sway live in nixos-config; this repo owns everything from the user session down. The repo is private on GitHub. Branch protection on `main` requires signed commits and disallows force-push.

Ted moves between machines freely. Any machine is replaceable. Goal: run one command, be productive on any host.

See [uc-init.md](uc-init.md) for use cases covering the bash init system's features.

## Actors

### Ted

Senior software engineer. Uses the terminal as primary interface -- CLI-first, not GUI. Operates across a heterogeneous fleet of NixOS workstations and disposable Crostini VMs. Expects the same tools, aliases, and workflows on every machine. Constraints: Chromebooks are wiped or replaced without notice; corporate resources require VPN; no admin access to ChromeOS host.

### Claude

Ted's AI agent (Claude Code). Modifies packages, configs, dotfiles, and docs. Has filesystem and git access but cannot apply nix changes (Ted must run `home-manager switch` or `update-env`). Constraints: no persistent state across sessions beyond CLAUDE.md, Era memory, and project docs; must re-orient on each launch (UC-6).

## Actor-Goal List

| Actor | Goal | UC | Level |
|-------|------|----|-------|
| Ted | Write, build, test, and version-control code on any host | UC-1 | User goal |
| Ted | Have browsers, messaging, media, and productivity apps available | UC-2 | Subfunction |
| Ted | Navigate, search, and organize files efficiently | UC-3 | Subfunction |
| Ted | Complete, consistent environment on a new or rebuilt machine | UC-4 | User goal |
| Ted | Replace the shared SSH key across all machines and registries | UC-4a | Subfunction |
| Ted | Add, update, or remove a work credential | UC-4b | Subfunction |
| Ted | Restore credential access after a failure | UC-4c | Subfunction |
| Ted | Revoke a retired machine's access to work credentials | UC-4d | Subfunction |
| Ted | Enroll a new machine for scoped work credential access | UC-4e | Subfunction |
| Claude | Deliver a validated change to packages, dotfiles, or configs | UC-5 | User goal |
| Claude | Resume work with full context | UC-6 | Subfunction |
| Ted | Reach work resources via corporate VPN | UC-7 | User goal |
| Ted | Open VPN-only URLs in ChromeOS host Chrome | UC-8 | User goal |
| Ted | Get phone push notifications from desktop tools | UC-9 | User goal |
| Ted | See ambient system/service health in tmux status bar | UC-10 | User goal |
| Ted | Use a tool that requires work credentials | UC-11 | Subfunction |
| Ted | Update all development environments to a newer package revision | UC-12 | User goal |

---

## Use Cases

### UC-1: Software Development

- **Primary Actor:** Ted
- **Goal:** Write, build, test, and version-control code on any host
- **Scope:** Dotfiles environment (shell, tools, configs)
- **Level:** User goal
- **Trigger:** Ted starts work on a project
- **Preconditions:** Terminal, editor, git available; VPN connected for work repos
- **Stakeholders:**
  - Ted -- productive, consistent across machines
  - Claude -- needs the same tools (git, ripgrep, fd)
  - Collaborators -- Ted can contribute without environment issues
- **Main Success Scenario:**
  1. Ted connects to VPN (if accessing work resources)
  2. Ted opens a terminal
  3. Ted clones or navigates to a project
  4. direnv loads the project's dev environment automatically
  5. Ted edits code
  6. Ted builds and tests
  7. Ted commits and pushes
- **Extensions:**
  - 1a. VPN not connected -> connect via UC-7; resume at step 1
  - 1b. VPN tools not installed -> add to home.nix (UC-5); resume at step 1
  - 3a. Git not available -> add to home.nix (UC-5); resume at step 3
  - 4a. Editor not installed -> add to home.nix (UC-5); resume at step 5
  - 4b. No .envrc -> project doesn't use direnv; manual `nix develop`; resume at step 5
  - 6a. Toolchain missing -> add a dev environment to that project; resume at step 6
  - 6b. Can't reach work git server -> check VPN connection (UC-7); resume at step 7
  - 6c. Hostname won't resolve -> use dig to diagnose DNS; resume at step 7
  - 6d. Need to create PR or manage repo -> use gh CLI; resume at step 7
- **Minimal Guarantee:** Existing environment unchanged; failed tool installs don't break working config
- **Success Guarantee:** Ted can clone, edit, build, test, and push on any host
- **Technology:** neovim, Claude Code, direnv, Nix devShells, git, stgit, gh, tmux, jira-cli-go, dig, scc, pandoc, shellcheck

---

### UC-2: Application Access

- **Primary Actor:** Ted
- **Goal:** Browsers, messaging, media, and productivity apps available on any host
- **Scope:** Dotfiles environment (home-manager package set)
- **Level:** Subfunction (supports UC-1, UC-4)
- **Trigger:** Ted launches an app after deployment (UC-4)
- **Preconditions:** Home-manager configured; UC-4 completed
- **Stakeholders:**
  - Ted -- apps available immediately after setup
  - Future Ted on a new Chromebook -- all apps come with the environment
- **Main Success Scenario:**
  1. Ted launches an app
  2. App starts with declarative config applied
  3. App functions correctly
- **Extensions:**
  - 1a. App not installed -> add to home.nix (UC-5); resume at step 1
  - 1b. App installed imperatively -> promote to home.nix (UC-5); resume at step 1
  - 2a. Firefox policies not applied -> ensure Nix Firefox is running, not an apt-installed one; resume at step 2
  - 3a. App misbehaves -> check config or system-level deps; fail
  - 3b. Wrong version or broken build -> pin version or find alternative; resume at step 1
- **Minimal Guarantee:** Other apps unaffected by a single app's failure
- **Success Guarantee:** All expected apps declaratively installed and working
- **Technology:** Firefox (declarative policies: DuckDuckGo, uBlock Origin, Privacy Badger, Vimium), Obsidian, signal-desktop, bottom, highlight, wl-clipboard, cliphist, asciinema. notify-send is wrapped to also push to ntfy.sh (UC-9).

---

### UC-3: File Management

- **Primary Actor:** Ted
- **Goal:** Navigate, search, and organize files efficiently
- **Scope:** Dotfiles environment (CLI tools and configs)
- **Level:** Subfunction (supports UC-1)
- **Trigger:** Ted needs to find, move, or manage files during development
- **Preconditions:** Filesystem accessible; UC-4 completed
- **Stakeholders:**
  - Ted -- fast operations from terminal
  - Project repos -- files must be findable for development (UC-1)
- **Main Success Scenario:**
  1. Ted opens ranger or a search tool
  2. Ted locates the target file by name or content
  3. Ted performs the file operation
- **Extensions:**
  - 1a. File manager not installed -> add via UC-5; resume at step 1
  - 2a. Search tools missing -> add via UC-5; resume at step 2
  - 3a. Archive format unsupported -> add support via UC-5; resume at step 3
- **Minimal Guarantee:** Basic `ls`/`cp`/`mv` always work (coreutils)
- **Success Guarantee:** Ted finds, organizes, and transfers files without friction
- **Technology:** ranger, silver-searcher (ag), tree, ncdu, zip, rsync

---

### UC-4: Deploy User Environment

- **Primary Actor:** Ted
- **Goal:** Working development environment on a new or rebuilt machine
- **Scope:** User environment (all hosts)
- **Level:** User goal
- **Trigger:** New Chromebook, powerwashed Crostini, rebuilt container, new NixOS host, standalone linux, or macOS machine
- **Preconditions:** Network connected. Machine enrolled with work credential account (UC-4e).
- **Stakeholders:**
  - Ted -- minimal manual steps; same tools and identity on every machine
  - Ted (returning after rebuild) -- works without remembering steps; idempotent re-runs fix drift
  - Ted (security-conscious) -- vault visibility bounded per machine; per-project access verified at tool startup; TOFU host-key model
- **Main Success Scenario:**
  1. Ted runs `update-env`
  2. System provisions a working shell environment (packages, configs, symlinks)
  3. Ted unlocks work credential account
  4. System validates SSH auth to each registry
  5. System clones project repos and reports remaining manual steps
  6. System converges all development environments to a common package revision
- **Extensions:**
  - 2a. *NixOS host:* System skips package manager install (already managed by NixOS). Resume step 3.
  - 3a. *Work credential account not enrolled:* Machine has not completed UC-4e. Fail (credential goals not met).
  - 3b. *Credential account unavailable:* Credential setup skipped; HTTPS clones still work; credential-dependent repos skipped. Fail (credential goals not met).
  - 4a. *Provider auth fails:* Reports per provider; private repos skipped. Fail (partial deployment).
  - 5a. *VPN-dependent repo unreachable:* Skips that repo. Resume at next repo.
- **Minimal Guarantee:** Machine usable for HTTPS-only work even if credential setup fails.
- **Success Guarantee:** Shell, git, editor, tmux, dev tools, project repos, packages, dotfile symlinks in place; SSH auth working; Obsidian CSS snippets synced to all active project vaults; Era memory server binary built and service running; remaining manual steps documented.
- **Technology:** update-env (bash), 1Password, home-manager, Nix. See [design.md Deployment](design.md#deployment-uc-4).

**Credential model (UC-4 family):** documented in the 1Password-stored canonical doc set.

---

### UC-4a: Rotate SSH Keys

- **Primary Actor:** Ted
- **Goal:** Replace the shared SSH auth key across all machines and registries (signing key rotation is a separate operation -- update `dotfiles/ssh/id_ed25519_signing.pub` and redeploy)
- **Scope:** Work credential account + Git registry settings
- **Level:** Subfunction (supports UC-4)
- **Trigger:** Suspected compromise, scheduled rotation, or key algorithm upgrade
- **Preconditions:** Work credential account unlocked; SSH key in the shared SSH vault
- **Stakeholders:**
  - Ted -- continued access to all Git registries after rotation
  - Ted (security-conscious) -- old key invalidated promptly; exposure window minimized
- **Main Success Scenario:**
  1. Ted generates a new SSH key in the credential manager
  2. Ted registers new public key with registries
  3. Ted deregisters old public key from registries
  4. Ted verifies SSH auth to all registries from any enrolled machine
- **Extensions:**
  - 2a. *Registry unreachable:* That registry deferred. Resume step 2 for remaining registries.
  - 4a. *Auth fails on a machine:* Resume step 4.
- **Minimal Guarantee:** Old key retained until explicitly deleted. No key lost.
- **Success Guarantee:** New key active, registered with all registries, old key deregistered. All enrolled machines use the new key.

---

### UC-4e: Enroll a Machine for Work Credentials

- **Primary Actor:** Ted
- **Goal:** A new or rebuilt machine can access work credentials
- **Trigger:** New machine provisioned, or existing machine rebuilt/reimaged
- **Postcondition:** Machine authorized; SSH agent serving keys; programmatic access available

Architecture and operational procedures documented in the 1Password-stored canonical doc set.

---

### UC-4b: Manage Work Credentials

- **Primary Actor:** Ted
- **Goal:** Add, update, or remove a work credential so project tools can access it
- **Trigger:** New service credential needed, token rotated, credential retired
- **Postcondition:** Credential available to enrolled machines that need it

Operational procedures documented in the 1Password-stored canonical doc set.

---

### UC-4c: Recover from Credential Failure

- **Primary Actor:** Ted
- **Goal:** Restore credential access after a failure
- **Scope:** Work credential account + tool configuration
- **Level:** Subfunction (supports UC-4)
- **Trigger:** Tool reports a credential error, or SSH auth fails
- **Preconditions:** Work credential account exists with credentials
- **Stakeholders:**
  - Ted -- restore access to services and registries
  - Ted (security-conscious) -- recovery must not widen access scope; compliance invariant must hold after recovery
- **Main Success Scenario:**
  1. Ted observes a credential error from a tool or SSH failure
  2. Ted identifies the cause from the error message
  3. Ted resolves the cause
  4. Ted verifies the tool works
  5. Ted verifies vault scope is unchanged (UC-11 compliance check passes)
- **Extensions:**
  - 2a. *Account locked:* Resume step 3.
  - 2b. *Account not running:* Resume step 3.
  - 2c. *Enrollment incomplete (UC-4e):* Fail (cannot recover without enrollment).
  - 2d. *Credential missing from vault (UC-4b):* Resume step 3.
  - 2e. *Account locked out:* Out of scope (account provider recovery).
  - 5a. *Vault scope changed during recovery:* Fail (scope violation).
- **Minimal Guarantee:** No credentials destroyed. Compliance invariant not bypassed.
- **Success Guarantee:** Credentials accessible; tools work; vault scope unchanged.

---

### UC-4d: Decommission a Machine

- **Primary Actor:** Ted
- **Goal:** Retired machine can no longer access work credentials
- **Scope:** Work credential account
- **Level:** Subfunction (supports UC-4)
- **Trigger:** Machine retired, repurposed, or hostname changed
- **Preconditions:** Machine is no longer in use (or hostname reassigned)
- **Stakeholders:**
  - Ted -- no stale device authorizations
  - Ted (security-conscious) -- retired machine cannot access any vault; shared SSH key unaffected (registries still accessible from other enrolled machines)
- **Main Success Scenario:**
  1. Ted deauthorizes the machine in the work credential account
  2. Ted removes any machine-specific config from dotfiles repo (if present)
- **Extensions:**
  - 1a. *Machine already wiped:* Device still authorized remotely. Resume step 1.
  - 1b. *Suspected compromise:* Credential rotation also required (UC-4a, UC-4b). Resume step 2.
- **Minimal Guarantee:** Account admin changes are explicit; no silent deauthorization.
- **Success Guarantee:** Retired machine cannot access any work credentials. Shared SSH key unaffected.

---

### UC-5: Make a Configuration Change

- **Primary Actor:** Claude
- **Goal:** Deliver a validated change to packages, dotfiles, or configs
- **Scope:** Dotfiles repo
- **Level:** User goal
- **Trigger:** Ted requests a change, or Claude spots a gap
- **Preconditions:** Claude Code running, repo accessible
- **Stakeholders:**
  - Ted -- environment evolves without debugging
  - All hosts -- a change here affects every machine
- **Main Success Scenario:**
  1. Ted describes a need, or Claude spots a gap
  2. Claude reads the relevant files
  3. Claude writes the change
  4. Claude validates the change (nix-instantiate, home-manager build, tesht)
  5. Ted applies the change
  6. Ted confirms it works
  7. Claude commits
- **Extensions:**
  - 1a. Ambiguous request -> Claude asks first; resume at step 1
  - 1b. Change belongs in nixos-config -> Claude flags it; fail (out of scope)
  - 3a. Change affects all hosts -> Claude considers NixOS and Crostini; resume at step 4
  - 4a. Validation fails -> Claude fixes and re-validates; resume at step 4
  - 5a. Apply fails -> Claude diagnoses; resume at step 3
  - 6a. Change misbehaves -> Claude investigates; resume at step 3
  - 7a. Pre-commit hook blocks commit (credential in settings.json) -> Claude removes inline credentials, uses op-run pattern; resume at step 7
- **Minimal Guarantee:** Previous environment intact; broken change not committed; credentials never committed to git
- **Success Guarantee:** Change applied, working, committed, docs updated

---

### UC-6: Start a New Session

- **Primary Actor:** Claude
- **Goal:** Resume work with full context
- **Scope:** Dotfiles repo
- **Level:** Subfunction (supports UC-5)
- **Trigger:** Ted launches Claude Code in this repo
- **Preconditions:** CLAUDE.md exists
- **Stakeholders:**
  - Ted -- no re-explaining
  - Claude -- useful immediately
- **Main Success Scenario:**
  1. Ted launches Claude Code
  2. Claude reads CLAUDE.md (base config always available after stage 1)
  3. Claude searches Era memory for relevant context (if era available -- requires stage 2)
  4. Claude reads use-cases.md and design.md
  5. Claude is ready to act
- **Extensions:**
  - 2a. CLAUDE.md missing -> Claude explores and reconstructs; resume at step 3
  - 3a. Era not available (stage 2 not run) -> skip; Claude relies on docs and filesystem; resume at step 4
  - 3b. Memory stale -> Claude trusts current state, updates memory; resume at step 4
  - 3c. No relevant memory -> Claude explores and builds context; resume at step 4
  - 4a. Docs outdated -> Claude updates docs; resume at step 5
  - 5a. Ted expects Claude to know something -> Claude checks docs first; resume at step 5
- **Minimal Guarantee:** Claude reads CLAUDE.md and has basic orientation
- **Success Guarantee:** Claude acts without Ted re-explaining

---

### UC-7: Connect to Corporate VPN

- **Primary Actor:** Ted
- **Secondary Actors:** SAML IdP, GlobalProtect gateway
- **Goal:** Reach work resources (git, build artifacts, internal services) from any host
- **Scope:** VPN access to corporate network
- **Level:** User goal
- **Trigger:** Ted needs to access a host behind the corporate VPN
- **Preconditions:** Network connected; VPN credentials valid; SSO active in the default browser
- **Stakeholders:**
  - Ted -- tunnel up with a single command, no manual cookie copying
  - UC-1 -- depends on this for any task that touches a corporate repo or service
  - UC-8 -- depends on this; VPN must be up before host-browser proxy access works
- **Main Success Scenario:**
  1. Ted runs the VPN connect command
  2. Browser opens a SAML auth page
  3. Ted completes SSO authentication
  4. System captures the auth token and establishes the tunnel
  5. Tunnel stays up with automatic reconnect; Ctrl-C exits
  6. Ted reaches corporate resources (git servers, internal services)
- **Extensions:**
  - 1a. VPN command not available -> re-run deployment (UC-4); resume at step 1
  - 2a. Browser doesn't open -> check URL scheme handler (see [docs/vpn.md](vpn.md)); resume at step 1
  - 3a. SAML times out -> re-authenticate; resume at step 1
  - 4a. Auth callback not dispatched -> URL scheme handler misconfigured (see [docs/vpn.md](vpn.md)); resume at step 1
  - 5a. Reconnect loop hammers a dead gateway -> Ctrl-C, diagnose; fail
- **Minimal Guarantee:** No tunnel; previous network state intact
- **Success Guarantee:** VPN tunnel up with split-tunnel routing for corporate subnets, internal hostnames resolved, normal traffic stays on LAN
- **Technology:** globalprotect-openconnect (gpoc), vpn-slice, vpn-connect wrapper. gpoc sourced per platform: apt on Crostini, flake input on NixOS (via nixos-config) and standalone linux (via dotfiles). See [design.md: VPN](design.md#vpn-uc-7) and [docs/vpn.md](vpn.md) for the detailed flow.

---

### UC-8: Access VPN Resources from Host Browser

- **Primary Actor:** Ted
- **Secondary Actors:** ChromeOS Chrome, tinyproxy, darkhttpd
- **Goal:** Open VPN-only URLs in ChromeOS host Chrome, not just in-container browsers
- **Scope:** Crostini proxy stack (tinyproxy + PAC)
- **Level:** User goal
- **Trigger:** Ted clicks a `stash.digi.com` link from an email, chat, or another browser tab
- **Preconditions:** UC-7 satisfied -- VPN tunnel up in the container; ChromeOS Chrome configured with the PAC URL
- **Stakeholders:**
  - Ted -- seamless link clicking from host Chrome without copying URLs into a separate browser
  - Normal browsing -- must NOT pay any container-hop cost; only VPN-bound hosts traverse the proxy
- **Main Success Scenario:**
  1. Ted clicks a corporate URL in host Chrome
  2. Chrome consults the PAC file and matches a VPN host
  3. Chrome routes the request through the in-container proxy
  4. tinyproxy forwards via tun0 over the VPN
  5. Page loads in host Chrome
- **Extensions:**
  - 1a. Host Chrome PAC not configured -> set ChromeOS Network -> Proxy -> Automatic configuration to `http://127.0.0.1:8120/proxy.pac` (UC-4 step 5 prints reminders); resume at step 1
  - 2a. Host not in PAC list -> Chrome connects directly (correct, expected); separate success
  - 2b. New `*.digi.com` host -> already matched by `dnsDomainIs`; no PAC change needed
  - 2c. New non-digi VPN host -> add to PAC's `vpnHosts` array in `contexts/crostini/home.nix`, re-activate; resume at step 1
  - 4a. Proxy unreachable -> check `systemctl --user status tinyproxy proxy-pac-server`; fail
  - 4b. VPN tunnel down -> see UC-7; resume at step 1
- **Minimal Guarantee:** Non-VPN URLs always work (PAC returns DIRECT); proxy failure doesn't break normal browsing
- **Success Guarantee:** VPN-bound URLs work in host Chrome with no per-click setup; non-VPN URLs unaffected
- **Technology:** `tinyproxy` (forward HTTP proxy in container), `darkhttpd` (serves the PAC file over HTTP), Chrome's PAC mechanism. Crostini-specific. See [design.md: Browser VPN access](design.md#browser-vpn-access-uc-8).

---

### UC-9: Phone Notifications from Desktop Tools

- **Primary Actor:** Ted
- **Secondary Actors:** ntfy.sh, notification daemon
- **Goal:** Get push notifications on the phone when desktop tools fire local notifications, without each tool needing to know about the phone
- **Scope:** notify-send wrapper (Nix-managed script)
- **Level:** User goal
- **Trigger:** Ted triggers an action that calls `notify-send` (e.g., calendar reminder fires, build completes)
- **Preconditions:** ntfy app installed on phone; phone subscribed to a private topic; topic name available (via 1Password or config)
- **Stakeholders:**
  - Ted -- reliable phone reminders for time-sensitive events even when away from the laptop
  - Calendar reminders (khal-notify) -- depends on this for phone delivery
  - Future tools -- get phone push for free without modification
- **Main Success Scenario:**
  1. Ted's action triggers a `notify-send` call (e.g., calendar reminder fires)
  2. System forwards to libnotify; local notification appears
  3. System POSTs the notification to ntfy.sh in the background
  4. A push notification appears on Ted's phone
- **Extensions:**
  - 1a. Tool doesn't use `notify-send` -> wrap it or have it call notify-send; resume at step 1
  - 2a. Local notification daemon missing -> desktop popup fails; resume at step 3
  - 3a. ntfy topic unavailable -> phone push skipped silently; separate success (local only)
  - 3b. Network unreachable -> push is fire-and-forget; local notification unaffected; separate success (local only)
  - 4a. Phone not subscribed -> notification lost; fail (phone delivery)
- **Minimal Guarantee:** Local notification always works; phone push failure never blocks the caller
- **Success Guarantee:** Both local popup and phone push, with no blocking on the network call
- **Technology:** ntfy.sh (third-party push service); a `notify-send` wrapper script (`scripts/notify-send`) installed via Nix that shadows libnotify's `notify-send` and tees the notification to `https://ntfy.sh/<topic>`. See [design.md: Phone notification bridge](design.md#phone-notification-bridge-uc-9).

---

### UC-10: Tmux Status Bar Widgets

Mirrors nixos-config UC-1a/UC-1b for headless sessions -- Crostini and SSH into NixOS. Widget contracts match waybar so the user gets the same ambient experience on either platform.

- **Primary Actor:** Ted
- **Secondary Actors:** probe-lib.bash (shared probes), external service APIs
- **Goal:** See ambient system and service health at a glance from any tmux session
- **Scope:** panel script + probe-lib.bash
- **Level:** User goal
- **Trigger:** Ted opens a tmux session
- **Preconditions:** tmux 3.2+ (for `display-popup`); panel nix-packaged as a tmux dependency (available on tmux's PATH regardless of session environment)
- **Stakeholders:**
  - Ted -- same ambient awareness as NixOS waybar, "quiet by default, loud when something needs attention"
  - UC-7 -- VPN status always shown; VPN-gated widgets hidden when tunnel is down
  - nixos-config UC-1a/UC-1b -- sibling use cases; behavioral changes must be mirrored
- **Main Success Scenario:**
  1. Ted opens a tmux session
  2. panel loads and renders the status bar (1 or 2 rows based on terminal width)
  3. Health widgets are hidden -- bar is quiet, showing only always-visible anchors (vpn, era, load)
  4. Ted glances at the bar and sees no health widgets -- everything is healthy
  5. A service degrades; the health widget appears automatically on the next refresh
  6. Ted clicks a segment; a relevant inspector pops up
- **Extensions:**
  - 1a. Not in tmux -> start tmux; resume at step 1
  - 2a. Terminal resized -> panel layout adjusts within 5s or immediately via client-resized hook; resume at step 3
  - 3a. VPN-gated widgets (dm1, stash, nexus, gitlab) hidden when tun0 is down; remotemanager is public and always probed; resume at step 4
  - 3b. Threshold widgets (cpu, mem, disk) hidden below 90% usage; resume at step 4
  - 5a. VPN comes up after session start -> VPN-gated widgets appear on next tick (<=5s); resume at step 4
  - 6a. Inspector tool not installed -> click handler falls back to basic status echo; separate success
- **Minimal Guarantee:** tmux session works normally; broken probes produce empty segments, not errors
- **Success Guarantee:** Bar is quiet when healthy, surfaces degraded/down services automatically, matches waybar contract
- **Sibling implementation:** On NixOS+Sway, waybar renders the same widgets; on headless sessions, tmux panel substitutes. Both renderers can be active on the same machine. Implementations are independent rendering wrappers around shared probe-lib.bash. See [design.md: Status widgets](design.md#status-widgets-uc-10).

**Widget visibility contract** (must match nixos-config UC-1a/UC-1b):

| Category | Widgets | Visibility rule |
|----------|---------|-----------------|
| Always shown | vpn, era, load | Visible in white; vpn and era are interactive (click to toggle); load shows sparkline |
| Hidden when healthy | dm1, stash, nexus, gitlab, remotemanager, codeberg, bitbucket, teams, ntfy | Appear only for partial (light gray), off (dark gray), or unknown (amber) |
| VPN-gated | dm1, stash, nexus, gitlab | Hidden when tun0 is down |
| Threshold (>=90%) | cpu, mem, disk | Appear in white when threshold crossed |
| SSH connections | ssh | Hidden when no inbound connections |
| Battery | bat | Hidden above 10%; warning [10,5%) shows "H:MM" in partial color; critical [5,0%] shows "N% bat" in white |
| Always shown (non-widget) | clock (click for date), hostname | Follow hardware group |
| Desktop-only (not in panel) | backlight, vol, temp, tray, fw | Handled by waybar on NixOS |

**State coloring** (mirrors waybar.css): on = hidden (health) or white (always-shown); light gray = partial; dark gray = off; amber = unknown.

---

### UC-11: Use a Credentialed Tool

- **Primary Actor:** Ted
- **Goal:** Tools that need work credentials start successfully
- **Trigger:** Ted starts a tool that requires credentials (e.g., Claude Code with MCP servers)
- **Postcondition:** Tool running with declared credentials in its process environment

Architecture, threat model, and operational procedures documented in the 1Password-stored canonical doc set (security.md, threat-model.md, secrets-lifecycle.md).

---

### UC-12: Update Development Package Revision

- **Primary Actor:** Ted
- **Goal:** All development environments updated to a newer package revision
- **Scope:** Dotfiles environment (all hosts)
- **Level:** User goal
- **Trigger:** Ted decides to update to a newer package baseline (security fixes, new tools, drift correction)
- **Preconditions:** UC-4 completed; era project cloned and canonical lock file present
- **Stakeholders:**
  - Ted -- newer packages available on all machines with a single operation
  - Ted (security-conscious) -- all environments share the same revision; no machine silently lags behind
- **Main Success Scenario:**
  1. Ted updates the canonical package revision
  2. System records the new revision in the canonical lock file
  3. Ted propagates the update across all machines
  4. System updates all development environment lock files to the new revision
- **Extensions:**
  - 1a. *Canonical lock file absent:* Era project not cloned. Fail.
  - 4a. *A development environment's lock file is not git-tracked:* System skips that environment. Resume at next environment.
  - 4b. *Propagation fails on one environment:* System reports the failure. Fail.
- **Minimal Guarantee:** Canonical lock file updated; no environment partially updated.
- **Success Guarantee:** All managed development environments share the new package revision.
- **Technology:** `./mk bump-nixpkgs` (updates era/flake.lock), `update-env -2` (propagates to all managed flake.lock files). See [design.md Deployment step 10](design.md#deployment-uc-4).

---

## Status

| Use Case | Status | Notes |
|----------|--------|-------|
| UC-1 Software Development | Working | |
| UC-2 Application Access | Working | Firefox policies, signal-desktop, Obsidian |
| UC-3 File Management | Working | |
| UC-4 Environment Deployment | Working | Two-stage: stage 1 = working shell (VPN deferred), stage 2 = full config. homeConfigurations: crostini, debian, desktop, macos |
| UC-4a Rotate SSH Key | Implemented | 1Password vault-only rotation; not yet exercised end-to-end |
| UC-4b Manage Work Credentials | Implemented | 1Password vault management; op-run launcher delivered for UC-11 v1 (mcp-atlassian) |
| UC-4c Recover from Credential Failure | Implemented | 1Password unlock + agent restart; not yet validated |
| UC-4d Decommission a Machine | Implemented | 1Password device deauthorization; not yet exercised |
| UC-4e Enroll Machine for Work Credentials | Not started | New UC for scoped device enrollment |
| UC-5 Make a Config Change | Working | |
| UC-6 Start a New Session | Working | |
| UC-7 Connect to Corporate VPN | Working | gpoc Rust rewrite; Crostini via apt, NixOS via nixos-config flake input, standalone linux via dotfiles flake input; SAML callback validated end-to-end on Crostini |
| UC-8 Access VPN from Host Browser | Working | tinyproxy + PAC, Crostini-specific |
| UC-9 Phone Notifications | Working | notify-send wrapper bridges to ntfy.sh |
| UC-10 Tmux Status Bar Widgets | Working | shared panel.tmux.conf; session-created hook for per-session loading on NixOS |
| UC-11 Use a Credentialed Tool | v1 implemented (mcp-atlassian: Bitbucket + Confluence + Jira) | Bash launcher op-run wrapping `op run`; project registry in dotfiles (path-keyed); machine allowlist per host. v2 deferrals: tamper-evident launcher hash, audit-log rotation, generalized failure-mode probing. |
| UC-12 Update Development Package Revision | Working | bump-nixpkgs + update-env -2; urma excluded (git-excluded flake.nix) |
