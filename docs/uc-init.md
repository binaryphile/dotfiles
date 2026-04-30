# Use Cases -- Bash Init System

Companion to [use-cases.md](use-cases.md). Documents the init.bash features that support UC-1 through UC-6. See [design.md](design.md) for the nix/bash boundary, target architecture, and rejected alternatives.

## Actors

### Ted

User across all machines. Interacts with the shell environment daily.

### Maintainer (Ted or Claude)

Modifies init config: adds app modules, changes settings, updates integrations.

## Classification

- **Use case** -- user-goal or subfunction with actor, trigger, scenario
- **Supporting UC** -- internal mechanism that enables other UCs (maintainer-facing)
- **Appendix** -- command catalog or reference material
- **Design constraint** -- invariants enforced by the system

---

## Shell Initialization

### UC-I0: Predictable Shell Init

- **Actor:** Ted
- **Goal:** Understand and control shell initialization without learning an opaque sourcing taxonomy
- **Scope:** All hosts
- **Level:** User goal
- **Trigger:** Ted needs to know what runs when a shell starts, or needs to change startup behavior
- **Preconditions:** None
- **Stakeholders:**
  - Ted -- predictable behavior, no hidden rules, debuggable without guessing which file ran
- **Main Success Scenario:**
  1. Ted opens `init.bash` -- one file
  2. Mode detection is explicit: `ShellIsLogin`, `ShellIsInteractive`, `Reload`
  3. Every sourcing decision is a readable conditional in the code
  4. Ted knows exactly what runs for any shell mode without consulting external documentation
- **Extensions:**
  - 1a. Ted needs to change what runs on login -> edit the `ShellIsLogin` conditional in init.bash
  - 1b. Ted needs to add interactive-only behavior -> edit the `ShellIsInteractive` conditional
  - 1c. Ted needs to debug unexpected behavior -> read init.bash top to bottom; no hidden sourcing rules to discover
- **Postconditions:**
  - **Success:** Shell initialization is fully comprehensible from one file. No need to understand the interaction of `.profile` vs `.bash_profile` vs `.bashrc`, login vs non-login, interactive vs non-interactive, local vs remote, bash vs sh
  - **Failure:** N/A -- the model is inherently simpler than what it replaces
- **Design rationale:** The conventional three-file model (`.profile`, `.bash_profile`, `.bashrc`) hides complexity behind an opaque sourcing taxonomy that even experienced engineers cannot reliably state. `init.bash` replaces it with explicit control: one file, readable conditionals, no hidden file-selection rules.
- **Technology:** init.bash symlinked as .bashrc, .bash_profile, .profile

---

### UC-I1: Shell Startup

- **Actor:** Ted
- **Goal:** Consistent, fully configured shell on any host
- **Scope:** All hosts
- **Level:** User goal
- **Trigger:** Ted opens a terminal or SSH session
- **Preconditions:** init.bash symlinked as .bashrc, .bash_profile, .profile
- **Stakeholders:**
  - Ted -- productive immediately, same experience on every machine
  - Claude -- consistent tool availability across sessions
- **Main Success Scenario:**
  1. Ted opens a terminal
  2. Environment is configured: PATH, EDITOR, PAGER, CFGDIR, SECRETS (UC-I5)
  3. Platform-specific setup applied if applicable (UC-I3)
  4. App integrations activated: prompt, direnv, SSH agent, aliases (UC-I4)
  5. Interactive behavior enabled: vi mode, history, reveal-wrapped commands (UC-I6, UC-I7)
  6. Shell is ready for use
- **Extensions:**
  - 1a. Non-interactive shell (e.g., script) -> only env vars and base settings apply; no prompt, aliases, or interactive config
  - 1b. SSH session -> same as terminal (init.bash is .bash_profile)
  - 4a. Tool not installed -> its integration skipped, shell still starts
- **Postconditions:**
  - **Success:** Consistent environment regardless of host -- PATH, editor, prompt, agent, direnv, all workflow commands available
  - **Failure:** Partial init; broken component doesn't prevent shell startup
- **Technology:** init.bash

---

### UC-I2: Live Reload

- **Actor:** Ted
- **Goal:** Apply config changes without opening a new terminal
- **Scope:** All hosts
- **Level:** Subfunction
- **Trigger:** Ted runs `source ~/.bashrc reload`
- **Stakeholders:**
  - Ted -- fast iteration when editing dotfiles
- **Main Success Scenario:**
  1. Ted runs `source ~/.bashrc reload`
  2. All shell config is re-sourced: hooks, aliases, functions, settings
  3. Shell prints "reloaded"
  4. Changes are active immediately
- **Extensions:**
  - 2a. Nix-managed session vars may not refresh (guard prevents re-sourcing) -> open new terminal for nix var changes
- **Postconditions:**
  - **Success:** Config changes take effect immediately
  - **Failure:** Nix var changes require new terminal
- **Technology:** init.bash

---

### UC-I3: Context-Specific Init (Supporting UC)

- **Actor:** Ted / Maintainer
- **Goal:** Platform-specific shell setup
- **Scope:** Per-platform
- **Level:** Subfunction
- **Trigger:** Shell startup (UC-I1)
- **Main Success Scenario:**
  1. Shell startup detects active platform context
  2. Platform-specific shell setup runs if configured
- **Extensions:**
  - 1a. No platform-specific setup configured -> no-op
- **Postconditions:**
  - **Success:** Platform-specific behavior active
  - **Failure:** N/A -- no platform config is a valid state
- **Technology:** context symlink, context/init.bash

---

### UC-I4: App Module System (Supporting UC)

- **Actor:** Maintainer (Ted or Claude)
- **Goal:** Add a tool integration that automatically participates in shell startup
- **Scope:** All hosts
- **Level:** Subfunction
- **Trigger:** New tool needs shell integration (env vars, hooks, aliases, or functions)
- **Preconditions:** Tool installed (nix package or system)
- **Stakeholders:**
  - Maintainer -- integration is discoverable and follows a consistent pattern
  - Ted -- new tool works on next shell startup without manual sourcing
- **Main Success Scenario:**
  1. Maintainer decides the concern: hook (startup behavior) or commands (aliases/functions)
  2. For hooks: adds sourcing to init.bash in the correct position
  3. For commands: creates `bash/apps/<tool>/cmds.bash`
  4. Installs the package via nix
  5. On next shell startup, the integration is active
- **Extensions:**
  - 2a. Hook is order-sensitive -> maintainer places it after dependencies in init.bash
  - 3a. Tool needs both hooks and commands -> adds hook line AND creates cmds.bash
  - 4a. Tool has a `programs.*` module -> use that for declarative config
- **Postconditions:**
  - **Success:** Tool integration loads automatically on every shell startup
  - **Failure:** Missing hook file or cmds.bash -> silently skipped, shell still starts
- **Technology:** init.bash (hooks), bash/apps/*/cmds.bash (commands)

---

## Environment & Interactive Behavior

### UC-I5: Environment Setup

- **Actor:** Ted
- **Goal:** Correct PATH, editor, and environment on login
- **Scope:** All hosts
- **Level:** Subfunction
- **Trigger:** Login shell or reload
- **Main Success Scenario:**
  1. Login shell starts
  2. PATH includes .local/bin, /usr/local/bin
  3. EDITOR set to nvim, PAGER to less
  4. CFGDIR, SECRETS, XDG_CONFIG_HOME set to expected values
  5. Nix-managed session variables available
- **Extensions:**
  - 5a. Nix session vars don't refresh on reload -> open new terminal for nix changes
  - 5b. home-manager not yet applied -> env vars missing until `home-manager switch`
- **Postconditions:**
  - **Success:** PATH, EDITOR, PAGER, config directories all set correctly
  - **Failure:** home-manager not applied; env vars missing
- **Technology:** shared.nix (home.sessionVariables, home.sessionPath), init.bash

---

### UC-I6: Interactive Shell

- **Actor:** Ted
- **Goal:** Productive interactive editing with history preservation
- **Scope:** All hosts
- **Level:** Subfunction
- **Trigger:** Interactive shell startup
- **Main Success Scenario:**
  1. Vi editing mode active
  2. History preserves commands across sessions with timestamps
  3. Eternal history log maintained (~/.bash_eternal_history)
  4. Duplicate history entries removed on shell exit
  5. Login messages suppressed
  6. umask set to 022
- **Postconditions:**
  - **Success:** Vi editing, persistent cross-session history, clean login
  - **Failure:** Partial config; most settings independent
- **Technology:** settings/interactive.bash, settings/login.bash, settings/base.bash

---

### UC-I7: Command Reveal (Supporting UC)

- **Actor:** Ted
- **Goal:** Know what an aliased or wrapped command actually executes
- **Scope:** All hosts
- **Level:** Subfunction
- **Trigger:** Ted runs any convenience command (alias or workflow function)
- **Main Success Scenario:**
  1. Ted types a short command (e.g., `gss`, `wolf "fix bug"`, `road example.com`)
  2. The underlying command appears in yellow on stderr (e.g., `git status -s`)
  3. The command executes normally
- **Extensions:**
  - 1a. Builtin or file command -> shows full command with arguments
  - 1b. Unknown command type -> no reveal output, runs normally
- **Postconditions:**
  - **Success:** Ted sees what the shortcut actually does -- transparency and learning
  - **Failure:** N/A -- worst case is no reveal output
- **Technology:** settings/cmds.bash, lib/initutil.bash

---

## Tool Integrations

### UC-I8: Custom Prompt

- **Actor:** Ted
- **Goal:** Context-aware shell prompt
- **Scope:** All hosts
- **Level:** Subfunction
- **Trigger:** Interactive shell startup
- **Main Success Scenario:**
  1. Shell starts in interactive mode
  2. Liquidprompt activates
  3. Prompt shows git status, hostname, working directory, etc.
- **Extensions:**
  - 1a. Non-interactive shell -> prompt not loaded
  - 1b. Liquidprompt not available -> default bash prompt
- **Postconditions:**
  - **Success:** Informative prompt showing git status, hostname, etc.
  - **Failure:** Default bash prompt
- **Technology:** liquidprompt/

---

### UC-I9: Direnv Integration

- **Actor:** Ted
- **Goal:** Project environments load automatically when entering a directory
- **Scope:** All hosts
- **Level:** Subfunction
- **Trigger:** Ted enters a directory with `.envrc`
- **Preconditions:** direnv installed; prompt loaded before direnv hook
- **Stakeholders:**
  - Ted -- no manual `nix develop` or environment sourcing
  - Projects -- `.envrc` with `use flake` is all that's needed
- **Main Success Scenario:**
  1. Ted enters a project directory with `.envrc`
  2. direnv evaluates `.envrc` automatically
  3. nix-direnv caches the flake evaluation for fast subsequent loads
  4. Project tools are on PATH; project env vars are set
- **Extensions:**
  - 1a. No `.envrc` -> nothing happens
  - 2a. `.envrc` not allowed -> direnv prompts to `direnv allow`
  - 3a. Cache stale (flake.lock changed) -> nix-direnv re-evaluates and re-caches
  - 2b. `.envrc` evaluation error -> direnv shows error, shell continues
- **Postconditions:**
  - **Success:** Project environment loaded transparently
  - **Failure:** direnv shows error; shell continues normally
- **Technology:** programs.direnv (nix-direnv), bash/apps/direnv/init.bash

---

### UC-I10: SSH Agent

- **Actor:** Ted
- **Goal:** SSH key available without repeated passphrase entry
- **Scope:** All hosts
- **Level:** Subfunction
- **Trigger:** Ted unlocks 1Password
- **Main Success Scenario:**
  1. 1Password SSH agent socket becomes available
  2. SSH config directs connections through the agent (`IdentityAgent`)
  3. SSH operations work without passphrase prompts
- **Extensions:**
  - 1a. 1Password not running -> SSH operations fail; start 1Password and unlock
  - 1b. 1Password locked -> agent socket exists but operations prompt for unlock
- **Postconditions:**
  - **Success:** SSH operations work without passphrase prompts
  - **Failure:** 1Password unavailable; SSH operations fail until unlocked
- **Technology:** 1Password SSH agent (`~/.1password/agent.sock`), `IdentityAgent` in ssh/config. Keychain retained as break-glass fallback (bash/apps/keychain/init.bash).

---

## Development Workflows

### UC-I11: Git Workflow

- **Actor:** Ted
- **Goal:** Fast git operations with named workflows
- **Scope:** All hosts
- **Level:** User goal
- **Trigger:** Ted works with git
- **Stakeholders:**
  - Ted -- reduced keystrokes, consistent patterns
- **Main Success Scenario:**
  1. 44 shell aliases available for common git operations (ga., gad, gaf, gbD, gba, gbd, gbm, gbr, gc-, gc., gca, gcb, gch, gcl, gcm, gco, gdc, gdi, gfe, gin, glg, gln, glo, gls, gme, gmv, gpf, gps, gpu, gra, grb, grc, gre, grf, grh, gri, grm, grs, gsa, gsd, gsh, gss, gssh, gst)
  2. All aliases wrapped with reveal (shows underlying git command)
  3. 6 workflow functions available:
     - correct $branch -- fetch + delete branches merged into $branch
     - europe $msg -- interactive patch add + commit + push
     - pastel $branch -- create branch + push + set upstream
     - flute -- add all + amend + force push
     - venice $long $short [$base] -- create feature branch from remote, rename locally
     - wolf $msg -- add all + commit (with optional JIRA prefix) + push
- **Postconditions:**
  - **Success:** Git operations are fast and consistent
  - **Failure:** N/A -- aliases are additive to normal git
- **Technology:** bash/apps/git/cmds.bash

---

### UC-I12: StGit Patch Management

- **Actor:** Ted
- **Goal:** Manage patch stacks with stgit
- **Scope:** All hosts
- **Level:** User goal
- **Trigger:** Ted works with stgit patch stacks
- **Main Success Scenario:**
  1. 30 aliases for stgit operations (stbcf, stcal, stcn, stcom, stdel, stedi, stflo, stgot, stini, stnew, stnme, stnwmw, stpic, stpoa, stpop, stpul, stpus, stpusa, stref, strefi, stren, strep, stser, stsho, stsin, stsqu, stunc, stuncn, stund, stundh)
  2. All aliases wrapped with reveal
  3. 4 workflow functions:
     - minimak / qwerty -- pop/push keyboard layout patches across dotfiles and vim
     - pretend $name [$target] -- rename patch + update commit message
     - salt $name [$target] -- insert new patch at a position in the stack (stashes dirty state)
- **Postconditions:**
  - **Success:** Patch stack operations are fast and consistent
  - **Failure:** N/A -- aliases are additive to normal stgit
- **Technology:** bash/apps/stg/cmds.bash

---

## Command Reference

### UC-I13: Shell Convenience Commands (Appendix)

- **Actor:** Ted
- **Goal:** Fast access to common shell operations
- **Scope:** All hosts
- **Level:** User goal
- **Trigger:** Ted needs navigation, admin, or diagnostic shortcuts
- **Note:** Grouped as a command catalog -- independent convenience commands, not a single workflow. All wrapped with reveal (UC-I7).
- **Main Success Scenario:**
  1. Ted types a short command
  2. reveal shows the underlying operation in yellow
  3. The operation runs

**Navigation/display:**
- l, ll, la, ltr -- ls with cross-platform color (darwin -G, linux --color=auto), various detail levels
- path -- display PATH entries one per line
- df -- filtered (excludes squashfs, tmpfs)

**System/admin:**
- miracle $user -- set ACLs on SSH_AUTH_SOCK for another user, then sudo to them with forwarded agent
- become $user -- switch to user with login shell (sudo -Hu)
- runas $user $cmd -- run command as user (sudo -u, login shell)
- ainst $pkg -- apt update + apt install + apt autoremove

**Search/tools:**
- psaux $pattern -- pgrep + ps for process search
- road $domain -- dig +noall +answer shortcut for DNS lookup
- new cmd [$app] -- open cmds.bash (or app-specific cmds.bash) in EDITOR

- **Postconditions:**
  - **Success:** Operation completes with reveal showing what ran
  - **Failure:** N/A -- aliases are additive to normal shell
- **Technology:** settings/cmds.bash

---

### UC-I14: Text Utilities (Appendix)

- **Actor:** Ted
- **Goal:** Text processing for development workflows
- **Scope:** All hosts
- **Level:** Subfunction
- **Trigger:** Ted needs to format markdown or generate a name

- shannon $file -- reformat markdown file in-place via pandoc (GFM, 92 columns, ATX headings, smart quotes on macOS)
- randword -- generate a memorable word via openssl random bytes + mnencode, retry if word collides with an existing function name

- **Postconditions:**
  - **Success:** Text processed as expected
  - **Failure:** Missing tool (pandoc, mnencode, openssl) -> command not found
- **Technology:** bash/apps/pandoc/cmds.bash, bash/apps/mnencode/cmds.bash

---

## Design Constraints

### UC-I15: Init Safety

The init system enforces two invariants:

**Safe string handling during init:** IFS is set to newline-only (`SplitSpace off`) and globbing is disabled during init. This prevents word splitting and glob expansion bugs in variable assignments and file paths. Temporarily restored per app module for file operations that need it.

**No namespace pollution:** All helper functions (tracked via `Functions` array, built by diffing compgen before/after initutil.bash) and init-time variables (tracked via `Vars` array) are unset after init completes. The user's shell inherits only the intended exports, aliases, and functions.

**Technology:** lib/initutil.bash (SplitSpace, Globbing, Functions, Vars arrays)

---

## Cross-Reference Matrix

P = primary support, S = secondary/indirect support

| Init UC | UC-1 Dev | UC-2 Apps | UC-3 Files | UC-4 Deploy | UC-5 Config | UC-6 Session |
|---------|:--------:|:---------:|:----------:|:-----------:|:-----------:|:------------:|
| I0 Predictable Init | P | | | P | P | |
| I1 Shell Startup | P | | | P | | P |
| I2 Live Reload | S | | | | P | |
| I3 Context Init | | | | P | S | |
| I4 App Modules | P | | | | P | |
| I5 Environment | P | | | P | | |
| I6 Interactive | P | | | | | |
| I7 Reveal | P | | | | | |
| I8 Prompt | P | | | | | |
| I9 Direnv | P | | | | | |
| I10 SSH Agent | P | | | S | | |
| I11 Git | P | | | | | |
| I12 StGit | P | | | | | |
| I13 Shell Cmds | P | | P | | | |
| I14 Text Utils | P | | | | | |
| I15 Init Safety | | | | P | P | |

---

## Status

| Use Case | Status |
|----------|--------|
| UC-I0 Predictable Init | Working |
| UC-I1 Shell Startup | Working |
| UC-I2 Live Reload | Working |
| UC-I3 Context Init | Working |
| UC-I4 App Modules | Working |
| UC-I5 Environment | Working |
| UC-I6 Interactive | Working |
| UC-I7 Reveal | Working |
| UC-I8 Prompt | Working -- due for liquidprompt update |
| UC-I9 Direnv | Working |
| UC-I10 SSH Agent | Working |
| UC-I11 Git | Working |
| UC-I12 StGit | Working |
| UC-I13 Shell Cmds | Working |
| UC-I14 Text Utils | Working |
| UC-I15 Init Safety | Working |
