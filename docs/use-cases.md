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

**Credential model (UC-4 family):** documented in the canonical doc set in ~/projects/jeeves/security/.

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

Architecture and operational procedures documented in the canonical doc set in ~/projects/jeeves/security/.

---

### UC-4b: Manage Work Credentials

- **Primary Actor:** Ted
- **Goal:** Add, update, or remove a work credential so project tools can access it
- **Trigger:** New service credential needed, token rotated, credential retired
- **Postcondition:** Credential available to enrolled machines that need it

Operational procedures documented in the canonical doc set in ~/projects/jeeves/security/.

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
  2. Browser opens a SAML auth page (host Chrome on Crostini via the saml-host-browser shim; container browser otherwise)
  3. Ted completes SSO authentication
  4. System captures the auth token and establishes the tunnel
  5. Tunnel stays up. Under gpoc the foreground retry loop exits on Ctrl-C; under pangp the daemon (`gpd.service`) keeps the tunnel until `vpn down`.
  6. Ted reaches corporate resources (git servers, internal services)
- **Extensions:**
  - 1a. VPN command not available -> re-run deployment (UC-4); resume at step 1
  - 1b. Active client is broken upstream (e.g., gpoc against post-CVE-2026-0257 Prisma Access) -> switch via UC-7a; resume at step 1
  - 2a. Browser doesn't open -> check URL scheme handler (see [docs/vpn.md](vpn.md)); resume at step 1
  - 2b. (pangp/Crostini) SAML form opens in a terminal vim or in-container firefox instead of host Chrome -> `text/html` mime isn't pinned to `saml-host-browser.desktop`; re-run deployment; resume at step 1
  - 3a. SAML times out -> re-authenticate; resume at step 1
  - 4a. Auth callback not dispatched -> URL scheme handler misconfigured (see [docs/vpn.md](vpn.md)); resume at step 1
  - 4b. (pangp/Crostini) `/tmp/gpcallback.log` shows `gpclient::launch_gui Failed to feed auth data to the CLI` -> system `/usr/share/applications/gpgui.desktop` is still claiming the callback scheme over `gp.desktop`; re-run `update-env`'s system-desktop task; resume at step 1
  - 4e. (pangp/Crostini) SAML form opened without the green "VPN auth via pangp" banner -> `vpn-connect` dispatched to gpoc instead of pangp; usually `gpd.service` inactive after a Crostini host-shutdown event (older install predating the activation hook's `systemctl enable`). Run `sudo systemctl enable gpd.service`, then `vpn down && vpn-mode pangp && vpn up`; resume at step 1
  - 4c. PanGPS rejects PanGPA with `Connected by non-PanGPA. Close socket.` -> daemon and agent live in different directories; co-locate both at `/opt/paloaltonetworks/globalprotect/` (see [docs/vpn.md: PanGPS co-location workaround](vpn.md)); resume at step 1
  - 4d. PanGPS log shows `Failed to connect to portal` while the shell can reach the same host -> daemon stuck after long uptime (sleep/wake/network swap cycles); `sudo systemctl restart gpd`; resume at step 1 (see [docs/vpn.md: PanGPS Failed to connect to portal with network reachable](vpn.md))
  - 5a. Reconnect loop hammers a dead gateway -> Ctrl-C, diagnose; fail
- **Minimal Guarantee:** No tunnel; previous network state intact
- **Success Guarantee:** VPN tunnel up. gpoc mode preserves split-tunnel routing; pangp pushes full-tunnel via `gpd0` (all traffic via Prisma Access), with internal DNS handling split-horizon hostnames.
- **Technology:** Two GlobalProtect clients coexist (yuezk gpoc and proprietary pangp); `vpn-connect` reads UC-7a's selected mode and dispatches to the right one. SAML on Crostini in pangp mode uses the `saml-host-browser` shim to route the local `saml.html` through the existing `darkhttpd` (proxy-pac-server) to ChromeOS host Chrome via `garcon-url-handler`; the shim also injects a "via pangp" banner into the SAML form so silent gpoc-vs-pangp dispatch failures (banner absent = gpoc) are visible at auth time. Callback comes back through `gp.desktop`. See [design.md: VPN](design.md#vpn-uc-7) and [docs/vpn.md](vpn.md).

---

### UC-7a: Switch the Active VPN Client

- **Primary Actor:** Ted
- **Secondary Actors:** systemd (the toggle target)
- **Goal:** Flip between the OSS gpoc and the proprietary pangp without uninstalling either, so when one client is broken upstream the other can take over
- **Scope:** Local client selection on a Linux host with both clients installed
- **Level:** User goal
- **Trigger:** Active client fails persistently (e.g., gpoc returns HTTP 512 since the CVE-2026-0257 Prisma Access cookie-mint hardening on 2026-05-08; pangp still works), or the broken upstream lands a fix and Ted wants to switch back
- **Preconditions:** Both clients installed (UC-4 deployed pangp via the nix derivation; gpoc separately via apt or upstream flake input)
- **Stakeholders:**
  - Ted -- pick which client owns the tun device with one short command; preserve the other for when it stops being broken; never collide (two daemons grabbing the same tun)
  - UC-7 -- depends on this for the dispatch-by-mode behavior of `vpn-connect`
- **Main Success Scenario:**
  1. Ted runs the toggle command with the target client name
  2. System stops the currently-active client's services and kills any in-flight tunnel from that client
  3. System starts the target client's services (or leaves them stopped if the target client runs on-demand)
  4. Subsequent `vpn-connect` invocations dispatch to the new active client
- **Extensions:**
  - 1a. Toggle command not available -> re-run deployment (UC-4); resume at step 1
  - 2a. Currently-active client refuses to stop cleanly -> abort with the underlying systemctl error visible; do NOT start the target client (preserves single-active invariant); fail
  - 4a. New active client also broken -> flip back via this UC; resume at step 1 with the original target
- **Minimal Guarantee:** The toggle is atomic from the user's perspective -- either succeeds and the target is active, or fails with neither in a partial state
- **Success Guarantee:** Exactly one VPN client's services are running; widgets (panel, sway probes) detect the tun device the active client owns without needing to know which client it is
- **Technology:** `vpn-mode` script reading `systemctl is-active gpd.service` as the implicit state; `gpd.service` running = pangp mode, stopped = gpoc mode (gpoc launches on-demand via `vpn-connect`, no persistent service). `gpd.service` is enabled-at-boot via the pangp activation hook, so the post-reboot default is always pangp; `vpn-mode gpoc` is session-scoped and does not survive reboot. See [design.md: VPN](design.md#vpn-uc-7) and [docs/vpn.md](vpn.md).

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
  - 3a. VPN-gated widgets (dm1, stash, nexus, gitlab) hidden when neither tun0 (gpoc) nor gpd0 (pangp) is in state UP; remotemanager is public and always probed; resume at step 4
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
| VPN-gated | dm1, stash, nexus, gitlab | Hidden when neither tun0 (gpoc) nor gpd0 (pangp) is in state UP |
| Threshold (>=90%) | cpu, mem, disk | Appear in white when threshold crossed |
| SSH connections | ssh | Hidden when no inbound connections |
| Battery | bat | Hidden above 10%; warning [10,5%) shows "H:MM" in partial color; critical [5,0%] shows "N% bat" in white |
| Always shown (non-widget) | clock (click for date), hostname | Follow hardware group |
| Desktop-only (not in panel) | backlight, vol, temp, tray, fw | Handled by waybar on NixOS |

**State coloring** (mirrors waybar.css): on = hidden (health) or white (always-shown); light gray = partial; dark gray = off; amber = unknown.

**Reachability signal**: TCP/443 ping (`pingHost`) is the only operative reachability probe. The SSH probe (`sshHost`) is disabled for all widgets in `WidgetNoSsh` (= all widgets currently) -- was triggering 1Password SSH-agent prompts on every poll. The `combine` rule `ssh=skip + ping=ok = on` keeps state-display semantics intact: ping success drives "on" directly. See [design.md: Status widgets](design.md#status-widgets-uc-10) for the implementation detail.

---

### UC-11: Use a Credentialed Tool

- **Primary Actor:** Ted
- **Goal:** Tools that need work credentials start successfully
- **Trigger:** Ted starts a tool that requires credentials (e.g., Claude Code with MCP servers)
- **Postcondition:** Tool running with declared credentials in its process environment; launcher integrity verified at shell init
- **Stakeholders:**
  - Ted -- credentialed tools start without per-invocation friction
  - Ted (security-conscious) -- modifications to the launcher, project registry, or machine allowlist are surfaced at interactive-shell init; a launcher resolved outside `/nix/store/` is also surfaced
- **Extensions:**
  - *Shell init detects launcher / registry / allowlist hash drift:* `OpRunIntegrityCheck` (sourced from `bash/lib/op-run-integrity.bash`, called from the interactive branch of `bash/init.bash`) runs `sha256sum --check op-run/checksums` and emits a single warning to stderr naming the offending path(s). Shell startup is not blocked.
  - *Shell init detects a launcher not resolved from the nix store:* If `command -v op-run` resolves to a path NOT under `/nix/store/`, `OpRunIntegrityCheck` emits a warning. Shell startup is not blocked.
  - *Operator edits a hashed file (launcher, registry, allowlist):* `.githooks/pre-commit` refuses the commit unless `op-run/checksums` is staged with hashes matching the staged source content. Operator runs `scripts/op-run-checksum-update && git add op-run/checksums` to update. Bypass: `git commit --no-verify`.
  - *Audit fallback log grows past size cap:* When the file at `${XDG_STATE_HOME:-~/.local/state}/op-run/audit.log` exceeds `AuditLogMaxBytes` (default 1 MiB), the next fallback write rotates it to `audit.log.1` (overwriting any prior rotation) and the new `audit.log` opens with a `{"event":"rotated","at":"<ISO8601>","prev_size":<bytes>}` marker. `AuditLogMaxBytes=0` disables the cap (debugging escape hatch). Disk use bounded at ~2x the cap. Rotation failures never block a launch; the function returns 0 on any failure path.

Architecture documented in `~/projects/jeeves/security/` (`security.md`, `threat-model.md`, `secrets-lifecycle.md`).

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
  3. Ted runs `update-env -2` on any machine
  4. System updates all development environment lock files to the new revision, commits each change, and pushes to the project's remote repository
  5. Other machines pull the canonical revision on their next `update-env` run without conflict
- **Extensions:**
  - 1a. *Canonical lock file absent:* Era project not cloned. Fail.
  - 4a. *A development environment's lock file is not git-tracked:* System skips that environment. Resume at next environment.
  - 4b. *Push to remote fails (SSH unavailable for Codeberg or Bitbucket remotes):* System records commit locally; push deferred to next machine with remote access. Non-fatal.
- **Minimal Guarantee:** Canonical lock file updated; local development environments pinned; no environment partially updated.
- **Success Guarantee:** All managed development environments share the new package revision; canonical revision committed and pushed to all reachable remote repositories so other machines converge without conflict.
- **Technology:** `./mk bump-nixpkgs` (updates era/flake.lock), `update-env -2` (pins all managed flake.lock files, commits, and pushes to remotes). See [design.md Deployment step 10](design.md#deployment-uc-4).

---

### UC-13: Stay Within Daily Token Budget

- **Primary Actor:** Ted
- **Secondary Actors:** Claude Code (hook infrastructure), claude-budget script
- **Goal:** Ted receives timely warnings when daily token usage approaches his self-imposed budget, enabling him to reduce parallel sessions before exhausting the Enterprise quota
- **Scope:** Dotfiles environment (Claude Code hook system)
- **Level:** User goal
- **Trigger:** Automatic -- fires at each Claude Code session start and after each response (Stop hook)
- **Preconditions:** UC-4 completed; `~/.config/claude-budget/config.json` exists with a `daily_tokens` value
- **Stakeholders:**
  - Ted -- warned early enough to reduce parallel sessions and preserve remaining quota
  - Enterprise quota -- not silently exhausted by unattended agents
- **Main Success Scenario:**
  1. Ted starts a Claude Code session (or Claude completes a response)
  2. System computes total tokens used today across all sessions
  3. System computes percent remaining against Ted's configured daily budget
  4. If percent remaining has crossed a warning threshold (25%, 10%, 5%, or 1%) for the first time today, system injects a warning into Claude's session context
  5. Ted reads the warning, sees token count and active session count, and decides to close idle sessions
  6. Each threshold fires at most once per budget day (2am reset); subsequent sessions in the same day see no duplicate warnings for already-fired thresholds
- **Extensions:**
  - 1a. *Config absent:* System exits silently; no warnings emitted
  - 3a. *Two sessions cross the same threshold simultaneously:* `flock` ensures exactly one warning is emitted; the other session sees the threshold already recorded and stays silent
  - 4a. *Token files from old sessions accumulate:* `SessionEnd` hook prunes files older than 7 days automatically
- **Minimal Guarantee:** System exits cleanly; no warning emitted if any precondition is unmet
- **Success Guarantee:** Ted is warned at each of the four thresholds (exactly once each per budget day), with token count and active session count visible, giving enough time to act before exhaustion

---

### UC-14: Guard Against Accidental Binary Commits

- **Primary Actor:** Ted
- **Secondary Actors:** git, pre-commit hook, global gitignore
- **Goal:** Block accidental binary commits across every repo Ted works in without leaving any settings or hook artifact in any individual repo's tracked content
- **Scope:** Dotfiles git configuration (global)
- **Level:** User goal
- **Trigger:** Automatic -- fires on every `git commit` in any repo that does not set a local `core.hooksPath`
- **Preconditions:** UC-4 completed (home-manager-deployed `~/.gitconfig` with `[core] hooksPath = ~/dotfiles/.githooks`); `~/dotfiles/.githooks/pre-commit` is executable
- **Stakeholders:**
  - Ted -- protected from committing build artifacts (Go binaries with no extension, ELF objects, archives, databases, ML model files) to personal or shared repos
  - Shared repos (dal, pepin, cloud-services, urma) -- the guard's existence leaves no trace in their tracked files or `.git/config`; coworkers never see it
  - Coworkers on shared repos -- no behavior change visible to them
- **Main Success Scenario:**
  1. Ted runs `git commit` in any repo
  2. Pre-commit hook reads `git diff --cached --numstat --no-renames` against the staged tree
  3. Hook flags every entry git classifies as binary (numstat emits `- -` for binary content)
  4. If any binary entry is detected, hook prints the file list + remediation options on stderr and exits 1; the commit aborts
  5. If no binary entry, hook exits 0; commit proceeds normally
- **Extensions:**
  - 2a. *Repo sets local `core.hooksPath`*: the local chain takes precedence; the global guard is inactive in that repo (era's `.githooks/` is the canonical example)
  - 3a. *Operator intentionally commits binary (test fixture, image, signed artifact)*: bypass with `git commit --no-verify`
  - 3b. *Binary belongs to a recurring class*: add the path glob to per-repo `.gitignore` (project-local) or `~/dotfiles/gitignore_global` (all repos) and re-stage
  - 5a. *Hook script missing or non-executable*: git falls back to no hook; commits succeed without inspection (fail-open by design -- a broken guard must not block work)
- **Minimal Guarantee:** Shared-repo tracked content unchanged by the guard; existing commits unaffected
- **Success Guarantee:** Future `git commit` in any non-overridden repo refuses staged binary files; bypass via `--no-verify` remains available; coworkers on shared repos see no evidence of the guard
- **Technology:** `~/dotfiles/.githooks/pre-commit` (bash + `git diff --cached --numstat`); wired in via `[core] hooksPath` in `~/dotfiles/gitconfig`. Complemented by `~/dotfiles/gitignore_global` binary-extensions block (compiled objects, archives, databases, ML model artifacts) that filters typical binaries before the hook ever runs. See [design.md: Git Commit Binary Guard](design.md#git-commit-binary-guard-uc-14).

---

### UC-15: Audit update-env Stage-1 Convergence

- **Primary Actor:** Ted (operator)
- **Secondary Actors:** `update-env-audit` script, filesystem, git, jq
- **Goal:** Mechanically verify that update-env stage-1 has converged the operator's home environment to its declared state, without relying on ad-hoc manual inspection
- **Scope:** Dotfiles environment (Ted's home; managed bin symlinks, git config, CLAUDE.md imports, flake.lock pins)
- **Level:** User goal (supports UC-4 by exposing UC-4's convergence as inspectable state)
- **Trigger:** Ted suspects drift (broken symlink observed, env behavior inconsistent across machines) or wants a periodic compliance check
- **Preconditions:** UC-4 completed (stage 1 has run at least once); `~/dotfiles/scripts/update-env-audit` on PATH or invocable by full path
- **Stakeholders:**
  - Ted -- needs to distinguish "stage-1 ran but didn't converge" from "stage-1 hasn't run recently"; needs the report to be machine-readable for downstream automation
  - Future cycles -- need a deterministic baseline for "is my environment broken?" without manual re-audit
- **Main Success Scenario:**
  1. Ted runs `update-env-audit` (text) or `update-env-audit --json` (machine)
  2. The script runs each of the v1 check categories (Phase-1 symlinks present, bin symlinks not dangling, bin symlinks pointing where update-env declares, retired binaries absent, git `hooksPath` consistent on managed repos, CLAUDE.md import markers present, flake.lock nixpkgs revs aligned with era canonical)
  3. Each check pushes findings of class OK / MISSING / BROKEN / RESIDUAL / DRIFT into an accumulator
  4. The accumulator is rendered as one line per finding (text mode) or as a JSON array of `{status, category, detail}` objects (`--json` mode)
  5. The script exits 0 if every finding is OK, 1 if any non-OK finding exists
- **Extensions:**
  - 2a. *update-env adds a new symlink not yet in v1 check list*: audit silently misses it; remediation is filing the v2 follow-up (deferred categories) or adding to the v1 source-of-truth parse if the new symlink falls into a v1 category
  - 4a. *Operator wants only one category*: deferred to a future flag (`--category <name>`); v1 runs all categories
  - 5a. *Operator wants the audit to fix drift, not just report it*: deferred via `--fix` flag (out of scope per #18166 task body)
- **Minimal Guarantee:** When invoked with no arguments, prints a finding report to stdout and exits with rc=0 or rc=1 reflecting overall compliance; never silently exits 0 on detected drift
- **Success Guarantee:** Operator distinguishes converged-and-clean from drifted-with-detail without manual re-audit; the drift detail is precise enough to drive remediation (path, expected vs actual, etc.)
- **Technology:** `~/dotfiles/scripts/update-env-audit` (bash; standalone, no mk.bash framework). Tested via `~/dotfiles/scripts/update-env-audit_test.bash` (tesht; controller-integration with real-filesystem fixtures via `tesht.MktempDir`). See [design.md: update-env-audit](design.md#update-env-audit-uc-15).

---

### UC-16: Auto-Attribute Claude Sessions for Mux-Identity

- **Primary Actor:** Ted (operator)
- **Secondary Actors:** Claude Code (SessionStart hook infrastructure), `claude-agent-identity` script, evtctl
- **Goal:** Every event published by a Claude Code session carries `metadata.agent = <role>@<host>` attribution without the operator or agent having to remember to `export EVTCTL_AGENT` at session start
- **Scope:** Dotfiles environment (Claude Code hook system + evtctl mux-identity contract)
- **Level:** User goal
- **Trigger:** Automatic -- fires at each Claude Code session start (source = startup, resume, or compact)
- **Preconditions:** UC-4 completed; evtctl on PATH; `~/.local/bin/claude-agent-identity` deployed via `update-env`; `~/dotfiles/claude/settings.json` registers the hook in `hooks.SessionStart`
- **Stakeholders:**
  - Ted -- sees stable per-session attribution in audit queries (`era query <stream> --json | jq '.[].metadata.agent'`); the operator-authored decision-share metric (icarus roadmap Phase B leading indicator #7) stays readable
  - Audit consumers -- can join events to sessions reliably via `metadata.agent` without unattributed gaps
  - Claude agents -- relieved of the operator-discipline export at session start; the identity flows automatically
- **Main Success Scenario:**
  1. Claude Code launches a new session (or resumes / compacts)
  2. Claude Code invokes the SessionStart hook chain; `claude-agent-identity` runs synchronously
  3. The hook resolves identity: `host` from `~/crostini/hostname` (Crostini-aware) or system `hostname` builtin; `role` from `~/.claude/agent-role` if present; composes `agent = claude-${role}@${host}` when role set, else `${USER}@${host}`
  4. The hook appends `export EVTCTL_AGENT="$agent"` to `$CLAUDE_ENV_FILE` (Claude Code's documented mechanism for hook-persisted env vars across subsequent Bash tool invocations)
  5. The hook forks a backgrounded `evtctl interaction "/session-start source=$source session_id=$id model=$m version=$v agent=$agent started_at=$ts"` and exits 0
  6. Every subsequent Bash tool invocation in the session has `EVTCTL_AGENT` exported; every event published by `evtctl` carries `metadata.agent = $agent`
- **Extensions:**
  - 3a. *Role marker absent:* `agent` defaults to `${USER}@${host}` (e.g., `ted@calliope`); attribution surfaces under the operator-prefix in metric computation
  - 3b. *Crostini hostname file absent (non-Crostini host):* falls back to system `hostname` builtin
  - 4a. *`$CLAUDE_ENV_FILE` unset (script invoked outside hook context, e.g., direct CLI for testing):* hook exits 0 silently without writing; no error
  - 5a. *evtctl unreachable (era-serve down):* background publish errors are swallowed (`>/dev/null 2>&1`); session startup is unaffected
  - 5b. *Hook stdin JSON malformed or fields absent (upstream schema change):* fields default to `unknown`; `/session-start` event still publishes with at least `agent` and `started_at`
- **Minimal Guarantee:** Session startup is never blocked by the hook (sync work bounded to a local file append; all network I/O backgrounded); `EVTCTL_AGENT` is set for every subsequent Bash tool invocation when `$CLAUDE_ENV_FILE` is provided by Claude Code
- **Success Guarantee:** Every event published by `evtctl` (task / contract / complete / interaction / claim / done / inbox) during the session carries `metadata.agent = <role>@<host>`; the `/session-start` audit event lands on the session's project stream within a few seconds
- **Technology:** `~/dotfiles/claude/claude-agent-identity` (bash; reads stdin JSON via `jq`, resolves hostname + role marker, writes export to `$CLAUDE_ENV_FILE`, forks `evtctl interaction`); registered in `~/dotfiles/claude/settings.json` `hooks.SessionStart`; deployed to `~/.local/bin/claude-agent-identity` by `update-env` (symlink). Tested via `~/dotfiles/claude/claude-agent-identity_test.bash` (tesht; controller-integration with PATH-stubbed `evtctl` + `tesht.MktempDir` fixtures for `$HOME` / `$CLAUDE_ENV_FILE`). See [design.md: Claude Agent Identity Hook (UC-16)](design.md#claude-agent-identity-hook-uc-16).

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
| UC-7 Connect to Corporate VPN | Working | Dual-client: gpoc Rust rewrite (apt on Crostini; flake input on NixOS/standalone) + proprietary pangp (nix-managed via PanGPLinux tarball). `vpn-mode` toggles; `gpd.service` enabled-at-boot so post-reboot default is pangp. gpoc broken upstream by CVE-2026-0257; pangp current default. SAML callback + dual-client banner injection validated end-to-end on Crostini |
| UC-8 Access VPN from Host Browser | Working | tinyproxy + PAC, Crostini-specific |
| UC-9 Phone Notifications | Working | notify-send wrapper bridges to ntfy.sh |
| UC-10 Tmux Status Bar Widgets | Working | shared panel.tmux.conf; session-created hook for per-session loading on NixOS |
| UC-11 Use a Credentialed Tool | v1 + v2 implemented (mcp-atlassian: Bitbucket + Confluence + Jira) | Bash launcher op-run wrapping `op run`; project registry in dotfiles (path-keyed); machine allowlist per host. Launcher hash check at shell init + pre-commit drift gate (`op-run/checksums` + `OpRunIntegrityCheck`). Audit-log fallback size-cap rotation (`AuditLogMaxBytes`, default 1 MiB). Architecture in canonical doc set at `~/projects/jeeves/security/`. |
| UC-12 Update Development Package Revision | Working | bump-nixpkgs + update-env -2 |
| UC-13 Stay Within Daily Token Budget | Implemented | claude-budget hook script; warns at 25/10/5/1% remaining; blocking permanently disabled |
| UC-14 Guard Against Accidental Binary Commits | Working | Global pre-commit hook + binary-extension gitignore active (deployed via home-manager); no per-repo settings; bypass via `--no-verify` or local `core.hooksPath` |
| UC-15 Audit update-env Stage-1 Convergence | v1 implemented (7 check categories) | `~/dotfiles/scripts/update-env-audit` — text + `--json` output; `OK/MISSING/BROKEN/RESIDUAL/DRIFT` taxonomy; tesht coverage via real-filesystem fixtures; v2 deferred (per-project shellcheckrc, MCP, slash commands, memory redirects, agent.toml, nix-wrapper, systemd services, op-run/checksums, project-clones-present) |
| UC-16 Auto-Attribute Claude Sessions for Mux-Identity | Implemented | `claude-agent-identity` SessionStart hook writes `EVTCTL_AGENT` to `$CLAUDE_ENV_FILE`; backgrounds `/session-start` interaction event publish; Crostini-aware hostname + optional role marker (`~/.claude/agent-role`); mechanizes the mux-identity export discipline (era `docs/evtctl.md` §"Mux identity contract") |
