# Handoff: Bootstrap Trust Chain + CLI + Panel Overlay + 1Password

Session date: 2026-04-18

## What was done this session

### installNix fix
`install --no-confirm --init none` -> `install linux --no-confirm --init none`
on Linux, `install --no-confirm` on macOS. `--init` is a subcommand flag.

### CLI: --help and -c/--credential
- `usageText()` for `--help` (was broken: `Usage_` undefined)
- `-c`/`--credential` for credential-only runs
- `credentialPreflight` validates platform, hostname content, dotfiles dir
- `credentialStage` extracted as callable function

### Panel nix overlay (tmux-with-panel)
Panel nix-packaged as tmux dependency in linux-base.nix. Fixes status bar
when tmux server starts before `~/.local/bin` on PATH. `$Here` resolved
via `@here@` substitution (nix) or `BASH_SOURCE` fallback (source).

### 1Password SSH key restore
- `restore_from_op` tier in `sshKeyAction` replaces age-to-repo tiers
- `sshKeyRestoreFromOp` retrieves auth key via `op read`
- `_1password-cli` added to `shared.nix`
- Age-to-repo code removed: `sshKeyEncryptToRepo`, `sshKeyDecryptAndInstall`,
  `withCleanupTrap`, `cleanupSshStage`, `validateSecretsArchive`, age/tar DI
- `restoreSecrets` simplified to two tiers (local -> cache)
- Epilogue messages updated for 1Password browser extension workflow

### Signing key preflight
- `signingKeyPreflight` (pure): warns when .pub sidecar untracked or key
  missing from 1Password
- `runSigningKeyPreflight` (controller): classifies state, calls pure fn
- Wired into `credentialStage` and `stage1`
- Security model P1 closed

### Flake config rename
`homeConfigurations.penguin` -> `.crostini`. Compat alias added.

### Doc sync
All docs updated to reflect age removal, 1Password workflow, panel
packaging, implementation status.

## Outstanding

### Remaining
1. **Declarative nix.conf ownership** (P2) -- split by platform
2. **Signed tag/release for bootstrap** (P3) -- verify repo before exec

### Housekeeping
1. Register auth + signing keys on Codeberg and Bitbucket
2. Re-enable GitHub branch protection
3. Run stage 2 (`update-env -2`)
4. Remove deprecated `penguin` flake compat alias after confirming no
   downstream consumers

## Test results

92/92 pass. `home-manager build` succeeds.

## Testing

```bash
tesht update-env_test.bash test_each test_keepIf test_map test_stream \
  test_verifySha256 test_nixInstallerAsset test_installNix \
  test_verifyNixFlakes test_signingKeyAction test_restoreSigningKey \
  test_installKey test_pubFingerprint test_crostiniHostname \
  test_authPreflight test_restoreSecretsTierSelection \
  test_withSecret test_withSecretMissingFile test_usageText \
  test_credentialPreflight test_cliHelp test_cliCredential \
  test_sshKeyAction test_signingKeyPreflight test_panelHermetic
```

## Context for next agent

- Follow docs-first, red/green TDD per Khorikov.
- Read CLAUDE.md for project conventions.
- Panel is nix-packaged (store copy). Edits require `home-manager switch`.
- `update-env -c` runs credentials without full stage 1.
- tmux overlay is `tmux-with-panel` in linux-base.nix.
- Flake config is `crostini` (compat alias `penguin` exists temporarily).
- SSH auth key restored from 1Password via `op read`. Age tiers removed.
- `restoreSecrets` is local -> cache only. No age-from-repo.
- Signing key preflight warns on untracked sidecar or missing 1Password item.
- `op` requires interactive auth in a separate terminal -- Claude Code
  shell has no TTY for password prompts.
