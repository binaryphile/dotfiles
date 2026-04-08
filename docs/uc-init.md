# Use Cases — Bash Init System

Companion to [use-cases.md](use-cases.md). Documents the init.bash features that support UC-1 through UC-6.

## Actors

### Ted

User across all machines. Interacts with the shell environment daily.

### Maintainer (Ted or Claude)

Modifies init config: adds app modules, changes settings, updates integrations.

## Classification

- **Use case** — user-goal or subfunction with actor, trigger, scenario
- **Supporting UC** — internal mechanism that enables other UCs (maintainer-facing)
- **Appendix** — command catalog or reference material
- **Design constraint** — invariants enforced by the system

---

## Shell Initialization

### UC-I1: Shell Startup

- **Actor:** Ted
- **Goal:** Consistent, fully configured shell on any host
- **Scope:** All hosts
- **Level:** User goal
- **Trigger:** Ted opens a terminal or SSH session
- **Preconditions:** init.bash symlinked as .bashrc, .bash_profile, .profile
- **Stakeholders:**
  - Ted — productive immediately, same experience on every machine
  - Claude — consistent tool availability across sessions
- **Main Success Scenario:**
  1. Ted opens a terminal
  2. Environment is configured: PATH, EDITOR, PAGER, CFGDIR, SECRETS (UC-I5)
  3. Platform-specific setup applied if applicable (UC-I3)
  4. App integrations activated: prompt, direnv, SSH agent, aliases (UC-I4)
  5. Interactive behavior enabled: vi mode, history, reveal-wrapped commands (UC-I6, UC-I7)
  6. Shell is ready for use
- **Extensions:**
  - 1a. Non-interactive shell (e.g., script) → only env vars and base settings apply; no prompt, aliases, or interactive config
  - 1b. SSH session → same as terminal (init.bash is .bash_profile)
  - 4a. Tool not installed → app module skipped (detect.bash or IsCmd fails)
- **Postconditions:**
  - **Success:** Consistent environment regardless of host — PATH, editor, prompt, agent, direnv, all workflow commands available
  - **Failure:** Partial init; broken app module or missing dependency
- **Implementation:** init.bash → initutil.bash → env.bash → context/init.bash → apps.bash → base.bash → cmds.bash → interactive.bash → login.bash. IFS/globbing controlled during init (UC-I15). Cleanup removes helper functions/vars after init.
- **Technology:** init.bash, lib/initutil.bash, lib/apps.bash, settings/*

---

### UC-I2: Live Reload

- **Actor:** Ted
- **Goal:** Apply config changes without opening a new terminal
- **Scope:** All hosts
- **Level:** Subfunction
- **Trigger:** Ted runs `source ~/.bashrc reload`
- **Stakeholders:**
  - Ted — fast iteration when editing dotfiles
- **Main Success Scenario:**
  1. init.bash detects `$1 == reload`, sets Reload=1
  2. Re-sources env.bash (Reload triggers same path as login)
  3. Re-sources all app modules (env.bash re-sourced per app)
  4. Re-sources interactive and login settings
  5. Prints "reloaded"
- **Extensions:**
  - 2a. hm-session-vars guard (`__HM_SESS_VARS_SOURCED`) blocks re-sourcing → nix-managed env vars from previous generation persist until new terminal
- **Postconditions:**
  - **Success:** Config changes take effect immediately
  - **Failure:** Guard prevents nix var updates; open new terminal instead
- **Technology:** init.bash (Reload flag), ShellIsLogin override

---

### UC-I3: Context-Specific Init (Supporting UC)

- **Actor:** Ted / Maintainer
- **Goal:** Platform-specific shell setup
- **Scope:** Per-platform
- **Level:** Subfunction
- **Trigger:** Shell startup (UC-I1)
- **Main Success Scenario:**
  1. init.bash calls TestAndSource on context/init.bash
  2. Context-specific setup runs (if file exists)
- **Extensions:**
  - 1a. No context/init.bash → no-op
- **Postconditions:**
  - **Success:** Platform-specific behavior active
  - **Failure:** N/A — missing file is a valid no-op
- **Technology:** context symlink, TestAndSource

---

### UC-I4: App Module System (Supporting UC)

- **Actor:** Maintainer (Ted or Claude)
- **Goal:** Add a tool integration that automatically participates in shell startup
- **Scope:** All hosts
- **Level:** Subfunction
- **Trigger:** New tool needs shell integration (env vars, hooks, aliases, or functions)
- **Preconditions:** Tool installed (nix package or system)
- **Stakeholders:**
  - Maintainer — integration is discoverable and follows a consistent pattern
  - Ted — new tool works on next shell startup without manual sourcing
- **Main Success Scenario:**
  1. Maintainer creates `bash/apps/<tool>/`
  2. Adds files as needed: `env.bash` (vars), `detect.bash` (gate), `init.bash` (setup), `cmds.bash` (aliases/functions), `deps` (ordering)
  3. On next shell startup, module is discovered and activated
  4. If the tool is on PATH (or detect.bash passes), the module's files are sourced in the correct shell mode
  5. If deps declares prerequisites, they load first
- **Extensions:**
  - 2a. Tool not on PATH and no detect.bash → module is silently skipped
  - 2b. Dependency declared but not available → dependency skipped, module still loads
  - 3a. Module only needs env vars → only env.bash needed
  - 3b. Module only needs aliases → only cmds.bash needed
- **Postconditions:**
  - **Success:** Tool integration loads automatically, in correct order, on every shell startup
  - **Failure:** detect.bash rejects; module skipped with no side effects
- **Implementation:** apps.bash discovers dirs via ListDir, filters with IsApp (detect.bash or IsCmd), sorts with OrderByDependencies (reads deps files), sources env.bash on login, init.bash and cmds.bash always. Loaded array tracks state.
- **Technology:** lib/apps.bash, lib/initutil.bash (IsApp, OrderByDependencies, Filter, ListDir)

---

## Environment & Interactive Behavior

### UC-I5: Environment Setup

- **Actor:** Ted
- **Goal:** Correct PATH, editor, and environment on login
- **Scope:** All hosts
- **Level:** Subfunction
- **Trigger:** Login shell or reload
- **Main Success Scenario:**
  1. TestContainsAndPrepend adds .local/bin, .local/lib, /usr/local/bin to PATH (idempotent)
  2. TestCmdAndExport sets EDITOR to nvim (fallback vim) and PAGER to less
  3. TestAndExport sets CFGDIR (~/.config), SECRETS (~/secrets), XDG_CONFIG_HOME ($CFGDIR)
  4. home-manager/env.bash (symlink to hm-session-vars.sh) sources nix-generated session vars
  5. ENV_SET=1 exported to mark login complete
- **Extensions:**
  - 2a. Neither nvim nor vim on PATH → EDITOR unset
  - 4a. hm-session-vars guard already set → re-source skipped
- **Postconditions:**
  - **Success:** PATH, EDITOR, PAGER, config directories all set correctly
  - **Failure:** Missing editor; EDITOR unset
- **Technology:** settings/env.bash, bash/apps/home-manager/env.bash (symlink to hm-session-vars.sh)

---

### UC-I6: Interactive Shell

- **Actor:** Ted
- **Goal:** Productive interactive editing with history preservation
- **Scope:** All hosts
- **Level:** Subfunction
- **Trigger:** Interactive shell startup
- **Main Success Scenario:**
  1. Vi mode enabled (set -o vi)
  2. INPUTRC set to dotfiles/bash/inputrc
  3. History configured: append mode, erasedups, ignore patterns (l, ls, ll, ltr, ps, bg, fg, history), timestamps
  4. PROMPT_COMMAND appends eternal history logger (PID + user + command → ~/.bash_eternal_history)
  5. EXIT trap runs historymerge (dedup via sort + uniq, preserves order)
  6. Login → TestAndTouch ~/.hushlogin (suppress login messages)
  7. umask 022 set
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
  - 1a. Builtin or file command → shows full command with arguments
  - 1b. Unknown command type → no reveal output, runs normally
- **Postconditions:**
  - **Success:** Ted sees what the shortcut actually does — transparency and learning
  - **Failure:** N/A — worst case is no reveal output
- **Implementation:** `Alias` wrapper (initutil.bash) prepends `reveal $name;` to every alias. Workflow functions call `reveal "$FUNCNAME"` manually. reveal is type-aware: extracts alias definitions, shows function invocations, handles builtins and files.
- **Technology:** settings/cmds.bash (reveal), lib/initutil.bash (Alias)

---

## Tool Integrations

### UC-I8: Custom Prompt

- **Actor:** Ted
- **Goal:** Context-aware shell prompt
- **Scope:** All hosts
- **Level:** Subfunction
- **Trigger:** Shell startup (UC-I4 app loading)
- **Main Success Scenario:**
  1. detect.bash checks ShellIsInteractive AND vendored liquidprompt file exists
  2. init.bash sources ~/dotfiles/liquidprompt/liquidprompt
  3. Prompt is active, sets up PROMPT_COMMAND
- **Extensions:**
  - 1a. Non-interactive shell → detect fails, module skipped
  - 1b. Vendored file missing → detect fails, module skipped
- **Postconditions:**
  - **Success:** Informative prompt showing git status, hostname, etc.
  - **Failure:** Default bash prompt
- **Technology:** bash/apps/liquidprompt/, vendored liquidprompt/

---

### UC-I9: Direnv Integration

- **Actor:** Ted
- **Goal:** Project environments load automatically when entering a directory
- **Scope:** All hosts
- **Level:** Subfunction
- **Trigger:** Ted enters a directory with `.envrc`
- **Preconditions:** direnv installed (via `programs.direnv`); liquidprompt loaded (declared in `deps`)
- **Stakeholders:**
  - Ted — no manual `nix develop` or environment sourcing
  - Projects — `.envrc` with `use flake` is all that's needed
- **Main Success Scenario:**
  1. Shell starts; liquidprompt loads first (dependency ordering)
  2. direnv hook appends `_direnv_hook` to PROMPT_COMMAND (after liquidprompt)
  3. Ted enters a project directory with `.envrc`
  4. `_direnv_hook` fires on prompt, direnv evaluates `.envrc`
  5. nix-direnv caches the flake evaluation for fast subsequent loads
  6. Project tools are on PATH; project env vars are set
- **Extensions:**
  - 2a. PROMPT_COMMAND already contains `_direnv_hook` → not re-added (idempotent)
  - 3a. No `.envrc` → hook runs but does nothing
  - 4a. `.envrc` not allowed → direnv prompts to `direnv allow`
  - 5a. Cache stale (flake.lock changed) → nix-direnv re-evaluates and re-caches
- **Postconditions:**
  - **Success:** Project environment loaded transparently
  - **Failure:** `.envrc` evaluation error; direnv shows error, shell continues
- **Technology:** bash/apps/direnv/init.bash (custom hook), bash/apps/direnv/deps, programs.direnv (nix-direnv)

---

### UC-I10: SSH Agent

- **Actor:** Ted
- **Goal:** SSH key available without repeated passphrase entry
- **Scope:** All hosts
- **Level:** Subfunction
- **Trigger:** Login shell (env.bash sourcing)
- **Main Success Scenario:**
  1. keychain/env.bash runs `eval "$(keychain --eval --agents ssh id_ed25519)"`
  2. Keychain starts or reuses ssh-agent, loads id_ed25519
  3. SSH_AUTH_SOCK and SSH_AGENT_PID exported
- **Extensions:**
  - 1a. keychain not on PATH → IsApp fails (IsCmd keychain), module skipped
  - 1b. id_ed25519 not found → keychain prompts or errors
- **Postconditions:**
  - **Success:** SSH operations work without passphrase prompts
  - **Failure:** No agent; SSH prompts for passphrase each time
- **Technology:** bash/apps/keychain/, keychain package (shared.nix)

---

## Development Workflows

### UC-I11: Git Workflow

- **Actor:** Ted
- **Goal:** Fast git operations with named workflows
- **Scope:** All hosts
- **Level:** User goal
- **Trigger:** Ted works with git
- **Stakeholders:**
  - Ted — reduced keystrokes, consistent patterns
- **Main Success Scenario:**
  1. 44 shell aliases available for common git operations (ga., gad, gaf, gbD, gba, gbd, gbm, gbr, gc-, gc., gca, gcb, gch, gcl, gcm, gco, gdc, gdi, gfe, gin, glg, gln, glo, gls, gme, gmv, gpf, gps, gpu, gra, grb, grc, gre, grf, grh, gri, grm, grs, gsa, gsd, gsh, gss, gssh, gst)
  2. All aliases wrapped with reveal (shows underlying git command)
  3. 6 workflow functions available:
     - correct $branch — fetch + delete branches merged into $branch
     - europe $msg — interactive patch add + commit + push
     - pastel $branch — create branch + push + set upstream
     - flute — add all + amend + force push
     - venice $long $short [$base] — create feature branch from remote, rename locally
     - wolf $msg — add all + commit (with optional JIRA prefix) + push
- **Postconditions:**
  - **Success:** Git operations are fast and consistent
  - **Failure:** N/A — aliases are additive to normal git
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
     - minimak / qwerty — pop/push keyboard layout patches across dotfiles and vim
     - pretend $name [$target] — rename patch + update commit message
     - salt $name [$target] — insert new patch at a position in the stack (stashes dirty state)
- **Postconditions:**
  - **Success:** Patch stack operations are fast and consistent
  - **Failure:** N/A — aliases are additive to normal stgit
- **Technology:** bash/apps/stg/cmds.bash

---

## Command Reference

### UC-I13: Shell Convenience Commands (Appendix)

- **Actor:** Ted
- **Goal:** Fast access to common shell operations
- **Scope:** All hosts
- **Level:** User goal
- **Trigger:** Ted needs navigation, admin, or diagnostic shortcuts
- **Note:** Grouped as a command catalog — independent convenience commands, not a single workflow. All wrapped with reveal (UC-I7).
- **Main Success Scenario:**
  1. Ted types a short command
  2. reveal shows the underlying operation in yellow
  3. The operation runs

**Navigation/display:**
- l, ll, la, ltr — ls with cross-platform color (darwin -G, linux --color=auto), various detail levels
- path — display PATH entries one per line
- df — filtered (excludes squashfs, tmpfs)

**System/admin:**
- miracle $user — set ACLs on SSH_AUTH_SOCK for another user, then sudo to them with forwarded agent
- become $user — switch to user with login shell (sudo -Hu)
- runas $user $cmd — run command as user (sudo -u, login shell)
- ainst $pkg — apt update + apt install + apt autoremove

**Search/tools:**
- psaux $pattern — pgrep + ps for process search
- road $domain — dig +noall +answer shortcut for DNS lookup
- new cmd [$app] — open cmds.bash (or app-specific cmds.bash) in EDITOR

- **Technology:** settings/cmds.bash

---

### UC-I14: Text Utilities (Appendix)

- **Actor:** Ted
- **Goal:** Text processing for development workflows
- **Scope:** All hosts
- **Level:** Subfunction
- **Trigger:** Ted needs to format markdown or generate a name

- shannon $file — reformat markdown file in-place via pandoc (GFM, 92 columns, ATX headings, smart quotes on macOS)
- randword — generate a memorable word via openssl random bytes + mnencode, retry if word collides with an existing function name

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
| UC-I1 Shell Startup | Working |
| UC-I2 Live Reload | Working |
| UC-I3 Context Init | Working |
| UC-I4 App Modules | Working |
| UC-I5 Environment | Working |
| UC-I6 Interactive | Working |
| UC-I7 Reveal | Working |
| UC-I8 Prompt | Working — due for liquidprompt update |
| UC-I9 Direnv | Working |
| UC-I10 SSH Agent | Working — keychain needs to be installed |
| UC-I11 Git | Working |
| UC-I12 StGit | Working |
| UC-I13 Shell Cmds | Working |
| UC-I14 Text Utils | Working |
| UC-I15 Init Safety | Working |
