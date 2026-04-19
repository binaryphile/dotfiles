# Handoff

Session date: 2026-04-18

## What was done

installNix fix, CLI --help and -c/--credential, panel nix overlay
(tmux-with-panel), 1Password SSH key restore (replacing age-to-repo),
signing key preflight, declarative nix.conf, platform DI, 1Password
naming centralization, dead code removal (-380 lines), security model
alignment (curl|eval removed, Lix cache trust removed), flake config
rename (penguin -> crostini).

18 commits. update-env 1939 -> 1763 lines. 92 tests, 24 functions.
Four adversarial review rounds (2/5, 3/5, 3/5, 3/5).

## Outstanding

### P2
1. **writeNixConfTask platform guard** -- safe by stage1 control flow
   (NixOS never reaches it), but not self-guarding. Add internal
   platform check or a controller test proving NixOS exclusion.
2. **1Password naming regression tripwire** -- centralized in code
   (opAuthKeyItem/opSigningKeyItem/OpVault) and docs, but no grep-based
   test preventing future hardcoded literals from re-entering.
3. **Signing key preflight enforcement** -- warning-only. Adequate for
   personal repo (P2 per reviewer). Upgrade to enforcement if the
   security model ever claims a stronger guarantee.
4. **Stage1 platform/task-selection controller test** -- highest-value
   missing test per reviewer. Assert NixOS skips nix/hm/nix.conf,
   Crostini runs expected credential path, rerun is idempotent.

### P3
1. **Signed tag/release for bootstrap** -- verify repo before exec.

### Housekeeping
1. Register auth + signing keys on Codeberg and Bitbucket
2. Re-enable GitHub branch protection
3. Run stage 2 (`update-env -2`)
4. Remove deprecated `penguin` flake compat alias

## Test results

92/92 pass. `home-manager build` succeeds.

## Testing

```bash
tesht update-env_test.bash test_each test_keepIf test_map test_stream \
  test_verifySha256 test_nixInstallerAsset test_installNix \
  test_verifyNixFlakes test_signingKeyAction test_restoreSigningKey \
  test_installKey test_pubFingerprint test_crostiniHostname \
  test_authPreflight test_restoreSecretsTierSelection \
  test_withSecret test_withSecretMissingFile \
  test_credentialPreflight test_cliHelp test_cliCredential \
  test_sshKeyAction test_signingKeyPreflight test_panelHermetic \
  test_nixConfContent
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
