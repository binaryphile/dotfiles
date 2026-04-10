# Use Cases — dotfiles

## Context

This repo is Ted's shared user environment. It works on all hosts — NixOS and commodity Crostini VMs. System config and Sway live in nixos-config.

Ted moves between Chromebooks freely. They're disposable. Goal: run one command, be productive.

See [uc-init.md](uc-init.md) for use cases covering the bash init system's features.

## Actors

### Ted

User across all machines. Development, browsing, communication, media.

### Claude

Ted's agent. Changes packages, configs, and dotfiles. Maintains project docs across sessions.

---

## Use Cases

### UC-1: Software Development

- **Actor:** Ted
- **Goal:** Write, build, test, and version-control code on any host
- **Scope:** All hosts
- **Level:** User goal
- **Trigger:** Ted starts work on a project
- **Preconditions:** Terminal, editor, git available; VPN connected for work repos
- **Stakeholders:**
  - Ted — productive, consistent across machines
  - Claude — needs the same tools (git, ripgrep, fd)
  - Collaborators — Ted can contribute without environment issues
- **Main Success Scenario:**
  1. Ted connects to VPN (if accessing work resources)
  2. Ted opens a terminal
  3. Ted clones or navigates to a project
  4. direnv loads the project's dev environment automatically
  5. Ted edits code
  6. Ted builds and tests
  7. Ted commits and pushes
- **Extensions:**
  - 1a. VPN not connected → connect via UC-7
  - 1b. VPN tools not installed → add to home.nix (UC-5)
  - 3a. Git not available → add to home.nix (UC-5)
  - 4a. Editor not installed → add to home.nix (UC-5)
  - 4a. No .envrc → project doesn't use direnv; manual `nix develop` or system tools
  - 6a. Toolchain missing → add a dev environment to that project
  - 6a. Can't reach work git server → check VPN connection (UC-7)
  - 6b. Hostname won't resolve → use dig to diagnose DNS
  - 6c. Need to create PR or manage repo → use gh CLI
- **Postconditions:**
  - **Success:** Ted can clone, edit, build, test, and push on any host
  - **Failure:** Key tools missing; Ted must install before proceeding
- **Technology:** neovim, Claude Code, direnv, Nix devShells, git, stgit, gh, tmux, jira-cli-go, dig, scc, pandoc

---

### UC-2: Application Access

- **Actor:** Ted
- **Goal:** Browsers, messaging, media, and productivity apps available on any host
- **Scope:** All hosts
- **Level:** User goal
- **Trigger:** Ted needs an app that should be declaratively installed
- **Preconditions:** Home-manager configured
- **Stakeholders:**
  - Ted — apps available immediately after setup
  - Future Ted on a new Chromebook — all apps come with the environment
- **Main Success Scenario:**
  1. Ted launches an app
  2. It works
- **Extensions:**
  - 1a. Not installed → add to home.nix (UC-5)
  - 1b. Installed imperatively → promote to home.nix (UC-5)
  - 2a. Misbehaves → check config or system-level deps
  - 2b. Wrong version or broken build → pin version or find alternative
  - 2c. Firefox policies not applied → ensure Nix Firefox is running, not an apt-installed one
- **Postconditions:**
  - **Success:** All expected apps declaratively installed and working
  - **Failure:** App needs manual install or has unresolved issues
- **Technology:** Firefox (declarative policies: DuckDuckGo, uBlock Origin, Privacy Badger, Vimium), Obsidian, signal-desktop, btop, highlight, wl-clipboard, cliphist, asciinema. notify-send is wrapped to also push to ntfy.sh (UC-9).

---

### UC-3: File Management

- **Actor:** Ted
- **Goal:** Navigate, search, and organize files efficiently
- **Scope:** All hosts
- **Level:** User goal
- **Trigger:** Ted needs to find, move, or manage files
- **Preconditions:** Filesystem accessible, tools available
- **Stakeholders:**
  - Ted — fast operations from terminal
  - Project repos — files must be findable for development (UC-1)
- **Main Success Scenario:**
  1. Ted navigates to a directory
  2. Ted searches by name or content
  3. Ted moves, copies, renames, or deletes
  4. Ted archives or extracts
- **Extensions:**
  - 1a. File manager not installed → add via UC-5
  - 2a. Search tools missing → add via UC-5
  - 4a. Archive format unsupported → add support via UC-5
- **Postconditions:**
  - **Success:** Ted finds, organizes, and transfers files without friction
  - **Failure:** Basic `ls`/`cp`/`mv` work but search is tedious
- **Technology:** ranger, silver-searcher (ag), tree, ncdu, zip, rsync

---

### UC-4: User Environment Deployment

- **Actor:** Ted
- **Goal:** Complete, consistent environment on a new or rebuilt machine in one step
- **Scope:** All hosts
- **Level:** User goal
- **Trigger:** New Chromebook, rebuilt Crostini, or new host
- **Preconditions:** Network connected
- **Stakeholders:**
  - Ted — minimal steps, reproducible
  - Future Ted — works without remembering steps
- **Main Success Scenario:**
  1. Ted runs `update-env`
  2. Ted is productive immediately
  3. update-env prints any platform-specific manual steps that cannot be automated (e.g., ChromeOS proxy setup for UC-8 on Crostini)
- **Extensions:**
  - 1a. NixOS host → `update-env` skips apt and nix/home-manager phases (system-managed)
  - 1b. New machine → create a machine-specific context with per-machine config (e.g., btop network interface)
  - 2a. A phase fails → script reports which; diagnose
  - 2b. Package fails to build → nixpkgs compatibility issue
  - 3a. Manual step missed → re-run update-env to see the reminders again, or check use-cases.md
- **Postconditions:**
  - **Success:** Git, neovim, tmux, shell, SSH keys, dev tools, packages, and dotfile symlinks all in place; user has been told about any remaining manual steps
  - **Failure:** Partial deployment; re-run after fixing

---

### UC-5: Make a Configuration Change

- **Actor:** Claude
- **Goal:** Deliver a validated change to packages, dotfiles, or configs
- **Scope:** This repo
- **Level:** User goal
- **Trigger:** Ted requests a change, or Claude spots a gap
- **Preconditions:** Claude Code running, repo accessible
- **Stakeholders:**
  - Ted — environment evolves without debugging
  - All hosts — a change here affects every machine
- **Main Success Scenario:**
  1. Ted describes a need, or Claude spots a gap
  2. Claude reads the relevant files
  3. Claude writes the change
  4. Claude verifies the change builds or parses correctly
  5. Ted applies
  6. Ted confirms it works
  7. Claude commits
- **Extensions:**
  - 1a. Ambiguous → Claude asks first
  - 1b. Belongs in nixos-config → Claude flags it
  - 3a. Affects all hosts → Claude considers NixOS and Crostini
  - 4a. Validation fails → Claude fixes and re-verifies
  - 5a. Apply fails → Claude diagnoses
  - 6a. Misbehaves → Claude investigates
- **Postconditions:**
  - **Success:** Applied, working, committed
  - **Failure:** Previous environment intact; broken change not committed

---

### UC-6: Start a New Session

- **Actor:** Claude
- **Goal:** Resume work with full context
- **Scope:** This repo
- **Level:** Subfunction
- **Trigger:** Ted launches Claude Code here
- **Preconditions:** CLAUDE.md exists
- **Stakeholders:**
  - Ted — no re-explaining
  - Claude — useful immediately
- **Main Success Scenario:**
  1. Ted launches Claude Code
  2. Claude reads CLAUDE.md
  3. Claude reads memories
  4. Claude reads use-cases.md and design.md
  5. Claude is ready
- **Extensions:**
  - 2a. CLAUDE.md missing → Claude explores and reconstructs
  - 3a. Memory stale → Claude trusts current state, updates
  - 3b. No memory → Claude explores and builds context
  - 4a. Docs outdated → Claude updates
  - 5a. Ted expects Claude to know something → Claude checks docs first
- **Postconditions:**
  - **Success:** Claude acts without Ted re-explaining
  - **Failure:** Claude asks targeted questions, not "what is this project?"

---

### UC-7: Connect to Corporate VPN

- **Actor:** Ted
- **Goal:** Reach work resources (git, build artifacts, internal services) from any host
- **Scope:** Linux + Crostini hosts
- **Level:** User goal
- **Trigger:** Ted needs to access a host that lives behind the corporate VPN
- **Preconditions:** Network connected; VPN credentials valid; SAML SSO active in the default browser
- **Stakeholders:**
  - Ted — wants tunnel up with a single command, no manual cookie copying
  - UC-1 — depends on this for any task that touches a corporate repo or service
  - UC-8 — depends on this; VPN must be up before host-browser proxy access works
- **Main Success Scenario:**
  1. Ted runs `vpn-connect` in a terminal
  2. The default browser opens a SAML auth page
  3. Browser auto-completes (Ted is already signed in via SSO)
  4. Tunnel comes up; reconnect-loop keeps it alive until Ctrl-C
  5. Ted reaches `stash.digi.com`, `gitlab.drm.ninja`, etc. via in-container shells
- **Extensions:**
  - 1a. `vpn-connect` not on PATH → re-run `home-manager switch`; `vpn-connect` is a Nix-managed wrapper
  - 2a. Browser doesn't open → check `xdg-open` and the registered URL scheme handler (see [docs/vpn.md](vpn.md))
  - 3a. SAML times out or fails → re-authenticate to the IdP, re-run
  - 4a. Pipeline exits silently after browser shows "authenticated" → URL scheme handler isn't dispatching back to the in-container helper; on Crostini, verify the `gpgui.desktop` symlink in `~/.local/share/applications/` exists (see [docs/vpn.md](vpn.md))
  - 4b. Reconnect loop hammers a dead gateway → Ctrl-C, diagnose
- **Postconditions:**
  - **Success:** `tun0` interface up, split-tunnel routes installed for the configured hosts only, normal traffic stays on LAN
  - **Failure:** No tunnel; previous network state intact
- **Technology:** yuezk's globalprotect-openconnect (gpoc) Rust rewrite — `gpauth` for SAML, `gpclient` for the openconnect-driven tunnel — wrapped by `scripts/vpn-connect`. Split-horizon DNS via `vpn-slice`. See [design.md § VPN](design.md#vpn--uc-7) and [docs/vpn.md](vpn.md) for the detailed flow.

---

### UC-8: Access VPN Resources from Host Browser

- **Actor:** Ted
- **Goal:** Open VPN-only URLs (stash, gitlab, internal Jira, etc.) in ChromeOS host Chrome, not just in-container browsers
- **Scope:** Crostini host
- **Level:** User goal
- **Trigger:** Ted clicks a `stash.digi.com` link from an email, chat, or another browser tab
- **Preconditions:** UC-7 satisfied — VPN tunnel up in the container; ChromeOS Chrome configured with the PAC URL
- **Stakeholders:**
  - Ted — wants seamless link clicking from host Chrome without copying URLs into a separate browser
  - Normal browsing — must NOT pay any container-hop cost; only VPN-bound hosts traverse the proxy
- **Main Success Scenario:**
  1. Ted clicks a corporate URL in host Chrome
  2. Chrome consults the PAC file; matches a VPN host; routes through the in-container proxy
  3. The in-container proxy forwards via tun0 over the VPN
  4. Page loads in host Chrome
- **Extensions:**
  - 1a. Host Chrome PAC not configured → set ChromeOS Network → Proxy → Automatic configuration to `http://127.0.0.1:8120/proxy.pac`. `update-env` prints these instructions on Crostini after each run as a reminder (UC-4 step 3).
  - 2a. Host doesn't match → URL is not in the VPN host list → Chrome connects directly (correct, expected)
  - 2b. Host should match but PAC list is stale → edit `contexts/crostini/home.nix` to add the host, re-activate
  - 3a. Proxy unreachable → check `systemctl --user status tinyproxy proxy-pac-server`
  - 3b. VPN tunnel down → see UC-7
- **Postconditions:**
  - **Success:** VPN-bound URLs work in host Chrome with no per-click setup; non-VPN URLs are unaffected
  - **Failure:** Host Chrome cannot reach VPN URLs; Ted falls back to in-container Firefox or terminal tools
- **Technology:** `tinyproxy` (forward HTTP proxy in container), `darkhttpd` (serves the PAC file over HTTP), Chrome's PAC mechanism. Crostini-specific. See [design.md § Browser VPN access](design.md#browser-vpn-access--uc-8).

---

### UC-9: Phone Notifications from Desktop Tools

- **Actor:** Ted
- **Goal:** Get push notifications on the phone when desktop tools fire local notifications, without each tool needing to know about the phone
- **Scope:** Linux + Crostini hosts
- **Level:** User goal
- **Trigger:** A desktop tool calls `notify-send` (e.g., calendar reminder, build complete, alert)
- **Preconditions:** ntfy app installed on phone; phone subscribed to a private topic; topic name in `~/secrets/ntfy-topic`
- **Stakeholders:**
  - Ted — wants reliable phone reminders for time-sensitive events even when away from the laptop
  - Calendar reminders (UC-1's khal-notify integration) — depends on this for phone delivery
  - Future tools — get phone push for free without modification
- **Main Success Scenario:**
  1. A desktop tool fires a `notify-send` call
  2. The local desktop notification appears immediately
  3. A push notification appears on Ted's phone within a few seconds
- **Extensions:**
  - 1a. Tool doesn't use `notify-send` → wrap it or have it call notify-send too
  - 2a. Local notification doesn't appear → notification daemon issue, unrelated to phone push
  - 3a. Phone push doesn't arrive → check `~/secrets/ntfy-topic` exists and is readable; check phone is subscribed to the matching topic; check ntfy.sh is reachable
  - 3b. Network slow → push is fire-and-forget in the background; local notification is unaffected
- **Postconditions:**
  - **Success:** Both local popup and phone push, with no blocking on the network call
  - **Failure:** Local popup still works; phone push silently dropped
- **Technology:** ntfy.sh (third-party push service); a `notify-send` wrapper script (`scripts/notify-send`) installed via Nix that shadows libnotify's `notify-send` and tees the notification to `https://ntfy.sh/<topic>`. See [design.md § Phone notification bridge](design.md#phone-notification-bridge--uc-9).

---

### UC-10: Tmux Status Bar Widgets

This use case is the Crostini-side mirror of nixos-config UC-1a (Connect VPN) and UC-1b (Monitor and Adjust System State). The widget contracts described here are designed to match the waybar contracts in nixos-config so the user gets the same ambient experience on either platform. ChromeOS's locked-down shelf does not allow custom widgets the way waybar does on a real Linux desktop, so the tmux status bar substitutes here.

- **Actor:** Ted
- **Goal:** See ambient health for the same set of systems and services that the NixOS+Sway waybar shows — work VPN, work hosts behind that VPN, public dev forges, communication tools, the era memory store, system load, and resource exhaustion alerts — at a glance from any tmux pane on Crostini
- **Scope:** Crostini host
- **Level:** User goal
- **Trigger:** Ted runs a tmux session
- **Preconditions:** tmux 3.2+ (for `display-popup`), `panel` script on PATH, mouse support enabled
- **Stakeholders:**
  - Ted — wants the same ambient awareness as on NixOS, with the same "quiet by default, loud when something needs attention" contract
  - VPN ergonomics (UC-7) — VPN status is always shown; VPN-gated widgets are hidden when the tunnel is down
  - nixos-config UC-1a/UC-1b — sibling use cases on the other platform; this UC mirrors them
- **Widget visibility contract** (must match nixos-config UC-1a/UC-1b):
  - **Always shown**: vpn, teams, ntfy, bitbucket, codeberg, era, load
  - **Hidden when VPN down** (VPN-gated, mirrors nixos-config UC-1a): dm1, stash, nexus, gitlab — nothing to probe without `tun0`
  - **Hidden under 90% usage** (mirrors nixos-config UC-1b): cpu, mem, disk — appear in default text color (white) when threshold crossed, not styled as a warning
  - **Hidden when no inbound connections** (mirrors nixos-config UC-1b "SSH connection indicator: visible only when connections exist"): ssh — Crostini doesn't run sshd by default, so this widget is normally invisible
  - **Not present on Crostini at all**:
    - backlight, custom/vol, custom/bat, custom/temp — host-hardware widgets with no in-container equivalent
    - tray, clock — handled by the ChromeOS shelf
    - custom/fw — we don't run a firewall inside the Crostini container
- **State coloring** (mirrors waybar.css from nixos-config):
  - white = on, light gray = degraded/partial, dark gray = off, amber = unknown, red = critical
- **Main Success Scenario:**
  1. Ted opens a tmux session
  2. The status bar is two rows tall; row 0 has the standard tmux window list and hostname; row 1 has the panel widgets, all right-aligned
  3. Row 1 always shows: vpn, teams, bitbucket, codeberg, era, load — the widgets that are always meaningful
  3a. Widget order is the same as waybar on NixOS (left-to-right: infrastructure, VPN-gated hosts, public services, system monitors), minus widgets that have no Crostini equivalent
  4. Row 1 conditionally shows the VPN-gated widgets (dm1, stash, nexus, gitlab) only when `tun0` is up
  5. Row 1 conditionally shows cpu, mem, disk only when usage is at 90% or above
  6. Segments refresh every 5 seconds; expensive probes (curl, ssh) are cached for 30 seconds and refreshed asynchronously so the bar never stalls
  7. Ted clicks a segment; a relevant inspector pops up (btop for load/cpu/mem/disk drilldown, the URL for forge widgets, status info for vpn/era)
- **Extensions:**
  - 1a. Not in tmux → run `tmux` first; the bar lives in the status line
  - 4a. VPN comes up after tmux session started → next refresh tick (≤5s) the VPN-gated widgets appear
  - 5a. CPU spikes above 90% → cpu segment appears in white, vanishes again on the next tick once usage drops
  - 7a. Underlying inspector tool not installed → click handler falls back to a basic `ip -s addr` or status echo
- **Postconditions:**
  - **Success:** Ted's bar is quiet most of the time, surfaces information only when meaningful, and matches the waybar contract on the NixOS side
  - **Failure:** Bar is cluttered with always-visible "off" indicators OR misses important state changes
- **Sibling implementation:** This UC describes the same observable widget contract as nixos-config UC-1a (Connect VPN) and UC-1b (Monitor and Adjust System State). On NixOS+Sway, waybar renders the widgets; on Crostini, the tmux status bar substitutes for waybar. Behavioral changes must be mirrored across both UCs. The implementations are independent rendering wrappers around a shared probe library — see [design.md § Status widgets](design.md#status-widgets--uc-10) for how that works and which files are shared.

---

## Status

| Use Case | Status | Notes |
|----------|--------|-------|
| UC-1 Software Development | Working | |
| UC-2 Application Access | Working | Firefox policies, signal-desktop, Obsidian |
| UC-3 File Management | Working | |
| UC-4 Environment Deployment | Working | NixOS, Crostini, Debian, macOS platform detection |
| UC-5 Make a Config Change | Working | |
| UC-6 Start a New Session | Working | |
| UC-7 Connect to Corporate VPN | Working | gpoc Rust rewrite via upstream flake; SAML callback validated end-to-end on Crostini |
| UC-8 Access VPN from Host Browser | Working | tinyproxy + PAC, Crostini-specific |
| UC-9 Phone Notifications | Working | notify-send wrapper bridges to ntfy.sh |
| UC-10 Tmux Status Bar Widgets | Working | panel + crostini tmux.conf; vpn wrapper for shell-clean vpn-connect launches |
