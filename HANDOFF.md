# Handoff: Bootstrap Trust Chain Hardening

Session date: 2026-04-18

## What was done

Replaced the `curl | sh` Lix installer with a hash-verified Determinate Nix
installer. This was the top P1 item from the security model's controls backlog.

### Changes (commit 056a416)

**update-env:**
- `nixInstallerAsset` -- pure decision function: maps OS/arch to binary name + SHA-256 hash. Supports x86_64-linux, aarch64-linux, aarch64-darwin.
- `installNix` -- controller: downloads pinned binary (v3.17.3), verifies hash via `verifySha256`, executes with `install --no-confirm --init none`. Platform auto-detected via injectable `uname_s`/`uname_m`.
- `verifySha256` -- shared hash verification function, extracted per rule-of-three. Used by installNix, aptInstallGpoc, task.bash bootstrap.
- `verifyNixFlakes` -- post-install postcondition check. Two-stage: verifies nix is runnable, then verifies flakes are enabled. Called before home-manager.
- Portable `sha256sum` -- macOS wrapper using `shasum -a 256`.
- Hash verification added to gpoc `.deb` download and task.bash bootstrap fetch.
- DI block expanded: `curl`, `sha256sum`, `nix`, `uname_s`, `uname_m` all injectable.
- Bare `curl` calls converted to `$curl` DI.

**update-env_test.bash:**
- `test_verifySha256` -- 2 cases, uses real sha256sum (thin wrapper, not mocked)
- `test_nixInstallerAsset` -- 4 cases (3 platforms + unsupported), pure decision, no mocks
- `test_installNix` -- 5 cases (happy path with argv check, download failure, hash mismatch, installer nonzero exit, unsupported platform). Data-driven: mock names and expected rc in case arrays.
- `test_verifyNixFlakes` -- 3 cases (working, not runnable, no flakes). Data-driven.
- 52 tests total, all passing.

**docs/design.md:** Step 3 updated with Determinate installer, platform coverage, install mode rationale (`--init none` + chown = single-user).

**docs/security.md:** `curl | sh` control marked "Narrowed" (not "Done" -- repo-compromise trust root remains). task.bash hash verification similarly marked. gpoc listed as hash-verified.

### Design decisions

- **Determinate over official Nix:** Enables flakes by default, avoiding NIX_CONFIG chicken-and-egg. Versioned binary releases with checksums.
- **`--init none` + chownRTask:** Effectively single-user, same as old Lix pattern. No systemd service.
- **No x86_64-darwin:** Dropped by Determinate in v3.13.0 (Intel Mac usage <0.01%).
- **Khorikov structure:** `nixInstallerAsset` is quadrant 1 (pure decision). `installNix` is quadrant 3 (controller). `verifySha256` called real inside controller (intra-system, not mocked). Only inter-system boundaries mocked (curl, sha256sum, nix).

### Adversarial review scores (self-graded after improvements)

Original review scored 2.4/5. All P0s addressed:
- P0.1: Install mode audited, documented
- P0.2: OS/arch detection added
- P0.3: macOS support (portable sha256sum, bare `install` auto-detects)
- P1.1: Post-install verification
- P1.5: Tests strengthened (argv, nonzero exit, platform selection)
- P1.6: mktemp -d failure handling
- P2.3: Sentinel path confirmed valid
- P2.4: gpoc hash verification added
- All pinned hashes verified by direct download

## What remains

### P1 (from security model backlog)
1. **Signing key registration preflight** -- detect unregistered signing key before first push to protected branch. Prevents push rejection on protected branches.

### P2
2. **Declarative nix.conf ownership** -- split by platform (NixOS vs Crostini). Currently nix.conf is unmanaged.

### P3
3. **Signed tag/release for bootstrap** -- verify repo content before executing update-env on fresh machine. Addresses the remaining repo-compromise trust root.

### Housekeeping
4. **Register signing key on Codeberg** -- currently only on GitHub.
5. **Re-enable GitHub branch protection** -- turned off during this session for development. Turn back on (Settings > Branches > require signed commits, disallow force-push on main).

## Testing

Run all tests:
```bash
tesht update-env_test.bash test_each test_keepIf test_map test_verifySha256 test_nixInstallerAsset test_installNix test_verifyNixFlakes test_signingKeyAction test_restoreSigningKey test_installKey test_pubFingerprint test_crostiniHostname test_authPreflight test_restoreSecretsTierSelection test_ageRoundTrip test_withSecretMissingFile
```

## Context for next agent

- Follow docs-first, red/green TDD per Khorikov (see www.binaryphile.com for guide).
- Read CLAUDE.md for project conventions (ASCII only, bash style, nix/bash boundary).
- Read docs/security.md for threat model and controls.
- Bash style: IFS=$'\n' + noglob, `_` suffix for IFS-contaminated variables, UPPERCASE namerefs.
- DI pattern: lowercase globals in the DI block, overridden by `local` in tests.
- tesht: data-driven subtests with associative arrays, mock names in case arrays.
