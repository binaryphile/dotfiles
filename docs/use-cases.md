# Use Cases — dotfiles

## Context

This repo is Ted's shared user environment. It works on all hosts — NixOS and commodity Crostini VMs. System config and Sway live in nixos-config.

Ted moves between Chromebooks freely. They're disposable. Goal: run one command, be productive.

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
  4. Ted edits code
  5. Ted builds and tests
  6. Ted commits and pushes
- **Extensions:**
  - 1a. VPN not connected → authenticate and connect (UC-5)
  - 1b. VPN tools not installed → add to home.nix (UC-5)
  - 3a. Git not available → add to home.nix (UC-5)
  - 4a. Editor not installed → add to home.nix (UC-5)
  - 5a. Toolchain missing → add a dev environment to that project
  - 6a. Can't reach work git server → check VPN connection
  - 6b. Hostname won't resolve → use dig to diagnose DNS
  - 6c. Need to create PR or manage repo → use gh CLI
- **Postconditions:**
  - **Success:** Ted can clone, edit, build, test, and push on any host
  - **Failure:** Key tools missing; Ted must install before proceeding
- **Technology:** neovim, Claude Code, Nix devShells, dig (DNS diagnostics)

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
- **Postconditions:**
  - **Success:** All expected apps declaratively installed and working
  - **Failure:** App needs manual install or has unresolved issues
- **Technology:** Firefox, Chromium, Signal, Obsidian, mpv, GlobalProtect

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
- **Technology:** ranger, fd, ripgrep, fzf, zip, p7zip

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
- **Extensions:**
  - 1a. NixOS host → `update-env` must skip inapplicable phases (Nix install, apt); needs updates for NixOS support
  - 2a. A phase fails → script reports which; diagnose
  - 2b. Package fails to build → nixpkgs compatibility issue
- **Postconditions:**
  - **Success:** Git, neovim, tmux, shell, SSH keys, dev tools, packages, and dotfile symlinks all in place
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

## Status

| Use Case | Status | Blocker? |
|----------|--------|----------|
| UC-1 Software Development | Working | VPN working for work repos |
| UC-2 Application Access | Working | gp-saml-gui + openconnect replaces globalprotect-openconnect |
| UC-3 File Management | Working | |
| UC-4 Environment Deployment | Partial | Needs NixOS support in update-env |
| UC-5 Make a Config Change | Working | |
| UC-6 Start a New Session | Not started | No CLAUDE.md yet |
