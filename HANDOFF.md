# Handoff

Session date: 2026-04-18

## What was done

installNix fix, CLI --help and -c/--credential, panel nix overlay
(tmux-with-panel), 1Password SSH key restore (replacing age-to-repo),
signing key preflight, declarative nix.conf, platform DI, 1Password
naming centralization, stage1TaskGroups refactor, dead code removal,
security model alignment, flake config rename, Codeberg signing key
correction.

24 commits. update-env 1939 -> 1748 lines (-191). 98 tests, 26
functions. Adversarial review: 2/5 -> 3/5 -> 3/5 -> 3/5 -> 4/5.

## Outstanding

### P2
1. **Signing key preflight enforcement** -- warning-only. Adequate for
   personal repo. Upgrade if security model claims stronger guarantee.

### P3
1. **Signed tag/release for bootstrap** -- verify repo before exec.

### Housekeeping
1. Run stage 2 from a TTY terminal: `~/dotfiles/update-env -2`
2. Authenticate `gh`: `gh auth login`
3. Remove deprecated `penguin` flake compat alias from flake.nix

## Testing

```bash
tesht update-env_test.bash test_each test_keepIf test_map test_stream \
  test_verifySha256 test_nixInstallerAsset test_installNix \
  test_verifyNixFlakes test_signingKeyAction test_restoreSigningKey \
  test_installKey test_pubFingerprint test_crostiniHostname \
  test_authPreflight test_restoreSecretsTierSelection \
  test_withSecret test_withSecretMissingFile \
  test_credentialPreflight test_cliHelp test_cliCredential \
  test_sshKeyAction test_signingKeyPreflight test_stage1TaskGroups \
  test_opNamingNoLiterals test_panelHermetic test_nixConfContent
```

## Context for next agent

- Docs-first, red/green TDD per Khorikov. Read the guide at
  binaryphile.com. Delete trivials, refactor Q4s, no intra-system mocks.
- Read CLAUDE.md for project conventions.
- Panel is nix-packaged (store copy). Edits require `home-manager switch`.
- `update-env -c` runs credentials without full stage 1.
- tmux overlay is `tmux-with-panel` in linux-base.nix.
- Flake config is `crostini` (compat alias `penguin` exists temporarily).
- SSH auth key restored from 1Password via `op read`. Age tiers removed.
- `restoreSecrets` is local -> cache only. No age-from-repo.
- 1Password naming: `opAuthKeyItem`, `opSigningKeyItem`, `OpVault`.
  Canonical doc: secrets-lifecycle.md "1Password Naming Convention".
- `op` requires interactive auth in a separate terminal.
- `detectPlatform` is the implementation; `$platform` is the DI variable.
- `stage1TaskGroups` is the pure routing decision; `stage1` dispatches on it.
- Codeberg does not support SSH signing verification. GitHub only.
