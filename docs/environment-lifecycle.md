# Environment Lifecycle

How the dotfiles environment moves through bootstrap, maintenance, and multi-machine sync. Companion to [use-cases.md](use-cases.md) (UC-4, UC-5) and [design.md](design.md) (Deployment).

## Phases

### Bootstrap

A bare machine reaches productive state via `update-env`. For the detailed step-by-step, see [design.md Deployment](design.md#deployment-uc-4).

- **Stage 1** (`update-env -1 <hostname>`) -- system setup, packages, credential restore. After this: working shell, VPN, SSH identity.
- **Stage 2** (`update-env -2`) -- project repos, dev tool clones, neovim. After this: full development environment.

`update-env` is idempotent. First run does everything; re-runs converge. Hostname is required on first Crostini run, optional thereafter. Bare `update-env` runs both stages; `-1`/`-2` flags run individual stages; `-c`/`--credential` runs only credential setup (SSH key, signing key, secrets, agent, auth preflight) for completing identity after an interrupted or non-interactive stage 1.

### Maintenance

Once bootstrapped, the environment evolves through three mechanisms:

**Configuration changes** (UC-5): docs first, then implementation. See [Development Workflow](#development-workflow).

**Drift correction:** re-running `update-env` or `home-manager switch` converges any machine to current state. `tesht` validates the shell environment matches expectations. Failures indicate drift -- fix the config to satisfy the assertions, don't rewrite tests.

**Package updates:**
- Shared packages: `nix flake update` in dotfiles, then rebuild
- Dev tools (task.bash, mk.bash, tesht): `nix flake update <name>` in dotfiles, then rebuild
- NixOS: `nix flake update dotfiles` in nixos-config, then `nixos-rebuild switch`

### Multi-machine sync

Changes propagate across the fleet through git:

```
dotfiles repo (GitHub)
        |
        +--- NixOS workstation
        |      nix flake update dotfiles && sudo nixos-rebuild switch
        |
        +--- Crostini VM
        |      update-env (or home-manager switch)
        |
        +--- Other Linux / macOS
               update-env (or home-manager switch)
```

**What syncs automatically:** packages, program config, session variables, PATH, dotfile symlinks, shell init, Claude Code config.

**What requires manual action per machine:** registry key registration (UC-4a), VPN auth (UC-7), secrets not yet in 1Password.

## Development Workflow

Per CLAUDE.md: docs first, then implementation.

### Adding a new tool

1. Decide where it belongs (see [design.md Nix/bash boundary](design.md#nixbash-boundary))
2. Update docs (use-cases.md if it changes a UC, design.md for component details)
3. Write test in `tesht` (red)
4. Implement
5. Validate: `nix-instantiate --parse`, `home-manager build`, `tesht` (green)
6. Apply and confirm
7. Commit

### Adding a new secret

1. Create the file in `~/secrets/` (see [secrets-lifecycle.md](secrets-lifecycle.md#add-update-remove))
2. Store in 1Password
3. Update the Known Secrets table in secrets-lifecycle.md
4. Add the consumer code
5. Test with and without the secret (graceful degradation)

### Changing credential handling

1. Review [security.md](security.md) for trust boundaries and constraints
2. Update security.md if trust model changes
3. Update secrets-lifecycle.md procedures
4. Update use-cases.md (UC-4a through UC-4d) if workflows change
5. Implement and test

## Operational Properties

**Idempotency:** `update-env` and `home-manager switch` both converge. Running them twice produces the same result. When in doubt, re-run.

**Failure isolation:** a broken `cmds.bash` module does not prevent hooks from running. A failed repo clone does not block other clones. A missing secret degrades the feature, not the environment.

**Rollback:** `home-manager generations` lists available rollbacks. `home-manager activate <path>` restores a previous generation. Git provides rollback for dotfile content.

**Observability:** `update-env` prints progress via `section` calls. Auth preflight reports per-provider status. `tesht` validates the full shell contract.

## Implementation Status

| Use Case | Status | Notes |
|----------|--------|-------|
| UC-1 Software Development | Working | |
| UC-2 Application Access | Working | Firefox policies, signal-desktop, Obsidian |
| UC-3 File Management | Working | |
| UC-4 Environment Deployment | Working | Two-stage + credential-only (`-c`). SSH keys restored from 1Password via `op`. Signing key preflight warns on incomplete registration. |
| UC-4a Rotate SSH Key | Partial | Manual procedure works. `op` retrieves auth and signing keys. 1Password storage after generation is manual. |
| UC-4b Manage Secrets | Partial | Local secrets work. 1Password as backup store is manual -- no `op` automation for secrets (multiple files, no standard schema). |
| UC-4c Recover from Credential Failure | Working | Local, cache, and 1Password recovery paths all functional. |
| UC-4d Decommission a Machine | Partial | Repo and cache cleanup works. 1Password cleanup is manual. |
| UC-5 Make a Config Change | Working | |
| UC-6 Start a New Session | Working | |
| UC-7 Connect to Corporate VPN | Working | gpoc Rust rewrite; Crostini via apt, NixOS via flake input |
| UC-8 Access VPN from Host Browser | Working | tinyproxy + PAC, Crostini-specific |
| UC-9 Phone Notifications | Working | notify-send wrapper bridges to ntfy.sh |
| UC-10 Tmux Status Bar Widgets | Working | shared panel.tmux.conf; session-created hook for per-session loading on NixOS |
