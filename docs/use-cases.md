# Use Cases -- dotfiles

## Context

This repo is a fleet configuration management system for Ted's user environment. It targets a heterogeneous fleet -- NixOS workstations and disposable Crostini VMs on commodity Chromebooks. System-level config and Sway live in nixos-config; this repo owns everything from the user session down.

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
| Ted | Replace SSH key across machines and registries | UC-4a | Subfunction |
| Ted | Add, update, or remove a secret | UC-4b | Subfunction |
| Ted | Recover from credential failure | UC-4c | Subfunction |
| Ted | Remove retired machine's credentials | UC-4d | Subfunction |
| Claude | Deliver a validated change to packages, dotfiles, or configs | UC-5 | User goal |
| Claude | Resume work with full context | UC-6 | Subfunction |
| Ted | Reach work resources via corporate VPN | UC-7 | User goal |
| Ted | Open VPN-only URLs in ChromeOS host Chrome | UC-8 | User goal |
| Ted | Get phone push notifications from desktop tools | UC-9 | User goal |
| Ted | See ambient system/service health in tmux status bar | UC-10 | User goal |

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
- **Technology:** neovim, Claude Code, direnv, Nix devShells, git, stgit, gh, tmux, jira-cli-go, dig, scc, pandoc

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
- **Trigger:** New Chromebook, powerwashed Crostini, rebuilt container, or new NixOS host
- **Preconditions:** Network connected. Crostini: ChromeOS file sharing enabled. Crostini first run: hostname required. NixOS: SSH keys pre-existing.
- **Stakeholders:**
  - Ted -- minimal manual steps; same tools and identity on every machine
  - Future Ted -- works without remembering steps; idempotent re-runs fix drift
  - Security -- private keys in 1Password, not in repo; signed commits with force-push disabled; downloaded binaries hash-verified; TOFU host-key model. See [security.md](security.md)
  - UC-1 (development) -- depends on git (with SSH identity), editor, tmux, dev tool repos
  - UC-7 (VPN) -- depends on SSH keys registered with providers and VPN client installed
- **Main Success Scenario:**
  1. Ted runs the deployment command with a hostname (first run) or without (subsequent). Only interaction required: hostname and 1Password auth (or passphrases if restoring from cache).
  2. System installs package manager, VPN client, and all packages. Dev tools, editor, shell config available after this step. VPN is usable.
  3. System restores SSH auth key from local, mount cache, or 1Password (or generates new). Loads into agent, validates provider auth.
  4. System restores signing key from local or 1Password (or generates new).
  5. System restores secrets from local, mount cache, or 1Password.
  6. System clones dev tool and project repos, prints remaining manual steps
- **Extensions:**
  - 1a. Crostini first run, no hostname -> fail with instructions
  - 1b. Crostini, ChromeOS shared storage not mounted -> fail with instructions
  - 2a. Package lock held -> waits; resume at step 2
  - 3a. Auth key exists locally, matches repo `.pub` -> accept; resume at step 4
  - 3b. Mount cache valid -> restore auth key without passphrase; resume at step 4
  - 3c. No TTY -> skip credentials; HTTPS clones still work; separate success
  - 3d. No auth key locally or in cache, `op` available -> retrieve from 1Password; resume at step 4
  - 3e. No auth key anywhere -> generate; store in 1Password manually; resume at step 4
  - 3f. Auth key mismatches repo `.pub` -> collision error; fail
  - 3g. Agent load fails -> warn "key not in agent"; preflight skips registry checks
  - 4a. Signing key exists locally -> accept; resume at step 5
  - 4b. Signing key in 1Password -> restore; resume at step 5
  - 4c. Signing key missing everywhere -> generate, prompt to store in 1Password and register on GitHub/Codeberg; resume at step 5
  - 5a. NixOS host -> skip credential restore; resume at step 6
  - 6a. Repo has uncommitted local changes -> stash, update, restore; resume at step 6
  - 6b. Provider auth fails -> reports per provider; private repos skipped; separate success
  - 6c. VPN-dependent repo unreachable -> fails fast; resume at next repo
  - *a. Any step fails partway -> re-run converges (idempotent)
- **Minimal Guarantee:** Best-effort rollback on failure; idempotent re-run converges.
- **Minimal Manual Steps** (printed inline by update-env with copyable URLs):
  - Register SSH auth key with each registry (URLs printed in output):
    - https://github.com/settings/keys (Authentication Key)
    - https://codeberg.org/user/settings/keys (Authentication Key)
    - https://bitbucket.org/account/settings/ssh-keys/
    - https://stash.digi.com/plugins/servlet/ssh/account/keys (VPN required)
  - Register SSH signing key on platforms that verify commit signatures:
    - https://github.com/settings/keys (Signing Key)
    - https://codeberg.org/user/settings/keys (Signing Key)
  - Store signing key in 1Password (if newly generated)
  - Crostini: configure ChromeOS Chrome proxy (per-network, one-time; instructions printed in output):
    - ChromeOS Settings > Network > connection > Proxy > Automatic proxy configuration
    - URL: `http://127.0.0.1:8120/proxy.pac`
- **Success Guarantee:** Shell, git, editor, tmux, VPN, dev tools, packages, dotfile symlinks in place; SSH auth and signing keys restored; commits signed; user informed of remaining manual steps
- **Technology:** update-env, 1Password CLI (`op`), ssh-keygen, home-manager (flake), Nix. See [design.md Deployment](design.md#deployment-uc-4), [design.md SSH Key Bootstrap](design.md#ssh-key-bootstrap-uc-4), and [security.md](security.md).

---

### UC-4a: Rotate SSH Keys

- **Primary Actor:** Ted
- **Goal:** Replace current SSH keys (auth and/or signing) with new ones across machines and registries
- **Scope:** 1Password + dotfiles repo (.pub sidecars) + Git registry settings
- **Level:** Subfunction (supports UC-4)
- **Trigger:** Suspected compromise, scheduled rotation, or key algorithm upgrade
- **Preconditions:** Current keys exist in 1Password or locally. Old `.pub` sidecars in repo.
- **Stakeholders:**
  - Ted -- continued access to all Git registries after rotation; continued commit verification
  - Security -- old keys deregistered; new keys stored in 1Password, not in repo. See [security.md](security.md)
- **Main Success Scenario:**
  1. Ted verifies current keys are in 1Password (if not, stores them now)
  2. Ted deletes local keys and cache
  3. Ted runs `update-env` -- generates new keys
  4. Ted stores new keys in 1Password
  5. Ted commits new `.pub` sidecars (not private keys) and pushes
  6. Ted registers auth key with all registries, signing key with GitHub and Codeberg; deregisters old keys
- **Extensions:**
  - 1a. Key not in 1Password and only copy is local -> store in 1Password before deleting
  - 3a. `op` available -> new keys stored in 1Password automatically
  - 3b. `op` not available -> Ted stores manually; `update-env` prints reminder
  - 5a. Signing key only rotation -> auth key and registrations unchanged
  - 6a. Registry unreachable (VPN down) -> defer; re-run preflight later
- **Minimal Guarantee:** Old keys backed up in 1Password before deletion; no key lost
- **Success Guarantee:** New key in 1Password, `.pub` in repo, registered with all registries, old key deregistered
- **Procedure:** [secrets-lifecycle.md Key rotation](secrets-lifecycle.md#key-rotation)

---

### UC-4b: Manage Secrets

- **Primary Actor:** Ted
- **Goal:** Add, update, or remove a secret and propagate to 1Password
- **Scope:** `~/secrets/` directory + 1Password vault
- **Level:** Subfunction (supports UC-4, UC-7, UC-9)
- **Trigger:** New service credential, changed token, retired secret
- **Preconditions:** `~/secrets/` exists; 1Password account accessible
- **Stakeholders:**
  - Ted -- secrets available on all machines after 1Password sync
  - Security -- secrets in 1Password vault, not in repo. See [security.md](security.md)
- **Main Success Scenario:**
  1. Ted adds/edits/removes file in `~/secrets/`
  2. Ted stores updated secrets in 1Password (via `op` CLI or app)
  3. On Crostini: re-run `update-env` to refresh mount cache from `~/secrets/`
- **Extensions:**
  - 1a. Filename invalid (dotfile, spaces, paths) -> encrypt-secrets warns and excludes
  - 2a. `op` not available -> store manually via 1Password app
  - 3a. On another machine -> retrieve from 1Password on next `update-env`
- **Minimal Guarantee:** Local secrets unchanged on failure
- **Success Guarantee:** Secrets in 1Password; other machines can retrieve on next `update-env`
- **Procedure:** [secrets-lifecycle.md Add, update, remove](secrets-lifecycle.md#add-update-remove)

---

### UC-4c: Recover from Credential Failure

- **Primary Actor:** Ted
- **Goal:** Restore working SSH key or secrets after a failure (fingerprint mismatch, collision, missing key, corrupt cache)
- **Scope:** 1Password + local filesystem + mount cache
- **Level:** Subfunction (supports UC-4)
- **Trigger:** `update-env` reports an error during credential restore
- **Preconditions:** At least one copy of the credential exists (local, cache, or 1Password)
- **Stakeholders:**
  - Ted -- restore access to Git registries and secrets
  - Security -- recovery should not bypass trust model. See [security.md](security.md)
- **Main Success Scenario:**
  1. Ted identifies the failure type from `update-env` output
  2. Ted follows the matching recovery procedure
  3. Ted re-runs `update-env` to verify
- **Extensions:**
  - 1a. Key in 1Password but not local -> retrieve via `op` or manually
  - 1b. Fingerprint mismatch -> determine authoritative key (1Password is source of truth), fix local
  - 1c. Collision (local key != repo `.pub`) -> compare against 1Password; keep the matching one
  - 1d. Corrupt cache -> clear cache, restore from 1Password
  - 1e. Key not in 1Password, not local, not in cache -> irrecoverable; regenerate (UC-4a)
- **Minimal Guarantee:** No data destroyed without explicit operator action; cache checked before clearing
- **Success Guarantee:** Credentials restored; `update-env` completes without errors
- **Procedure:** [secrets-lifecycle.md Recovery Procedures](secrets-lifecycle.md#recovery-procedures)

---

### UC-4d: Decommission a Machine

- **Primary Actor:** Ted
- **Goal:** Remove a retired machine's key material from repo, 1Password, and registries
- **Scope:** 1Password + dotfiles repo + Git registry settings + mount cache
- **Level:** Subfunction (supports UC-4)
- **Trigger:** Machine retired, repurposed, or hostname changed
- **Preconditions:** Machine is no longer in use (or hostname reassigned)
- **Stakeholders:**
  - Ted -- clean repo and vault, no stale keys
  - Security -- old key deregistered from registries; removed from 1Password
- **Main Success Scenario:**
  1. Ted removes `.pub` sidecar from repo
  2. Ted removes SSH key and secrets from 1Password (or archives)
  3. Ted clears mount cache (if Crostini)
  4. Ted deregisters old `.pub` from registries
  5. Ted commits and pushes
- **Minimal Guarantee:** Repo unchanged on failure (git rm is reversible before commit)
- **Success Guarantee:** No credentials for the retired hostname remain in repo, 1Password, cache, or registries
- **Procedure:** [secrets-lifecycle.md Cleanup and decommission](secrets-lifecycle.md#cleanup-and-decommission)

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
- **Minimal Guarantee:** Previous environment intact; broken change not committed
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
- **Technology:** globalprotect-openconnect (gpoc), vpn-slice, vpn-connect wrapper. See [design.md: VPN](design.md#vpn-uc-7) and [docs/vpn.md](vpn.md) for the detailed flow.

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
- **Preconditions:** ntfy app installed on phone; phone subscribed to a private topic; topic name in `~/secrets/ntfy-topic`
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
  - 3a. `~/secrets/ntfy-topic` missing -> phone push skipped silently; separate success (local only)
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
- **Preconditions:** tmux 3.2+ (for `display-popup`), `panel` script on PATH
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

