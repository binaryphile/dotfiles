# Handoff: Bootstrap Trust Chain + CLI + Panel Overlay

Session date: 2026-04-18

## What was done this session

### 1. installNix fix (commit 056a416 bug)

`installNix` called `install --no-confirm --init none` but `--init` is a
flag on the `linux` subcommand, not on `install`. Error: `unexpected
argument '--init' found`.

Fix: platform-aware invocation:
- Linux: `install linux --no-confirm --init none`
- macOS: `install --no-confirm` (default planner handles launchd)

Tests: case1 updated, case6 added (macOS path). Mock curl writes a script
that captures "$@" to argvfile; test reads argvfile and asserts content.
Tests real code path; only inter-system boundary mocked per Khorikov.

### 2. CLI: --help and -c/--credential

`--help` was broken (`Usage_` undefined). No way to run just the credential
section without the full stage 1 pipeline.

Added:
- `usageText` function with all flags documented
- `-c`/`--credential` flag for credential-only mode
- `credentialPreflight` -- fails fast on non-Crostini, checks age,
  ~/dotfiles, and $CrostiniDir/hostname
- `credentialStage` -- extracted credential section into callable function

Tests:
- `test_usageText`: pure function test
- `test_credentialPreflight`: 3 cases (non-crostini reject, crostini
  accept, crostini without hostname reject)
- `test_cliHelp`: CLI boundary test, runs real entrypoint
- `test_cliCredentialRejectsNonCrostini`: CLI boundary test (skips on
  crostini host since platform() can't be overridden externally)
- `credentialStage` controller test omitted per Khorikov -- trivial
  controller verified by inspection

### 3. Panel nix overlay (tmux-with-panel)

Panel was a live symlink at `~/.local/bin/panel` but tmux couldn't find it
when the server started before `hm-session-vars.sh` sourced `~/.local/bin`
onto PATH. Also `$Here` was never set (latent bug), and probe-lib.bash was
hardcoded to `$HOME/dotfiles/scripts/`.

Fix:
- `scripts/panel`: dual-mode `$Here` resolution. `@here@` marker is
  substituted by nix at build time; when running from source, the literal
  survives and BASH_SOURCE fallback activates. The `'@''here''@'` in the
  comparison is bash string concatenation to avoid substituteInPlace
  self-replacement.
- `linux-base.nix`: `panel-lib` (probe-lib.bash + load-sparkline),
  `panel` via `mkScriptBin` with runtime deps, `tmux-with-panel` overlay.
  Runtime deps: bash, coreutils, curl, gawk, gnugrep, iproute2, jq,
  openssh, procps, systemd.
- `shared.nix`: tmux removed (linux gets tmux-with-panel, macOS gets
  plain tmux from its context)
- `crostini/home.nix`: `home.file.".local/bin/panel"` removed

### 4. Flake config rename

`homeConfigurations.penguin` -> `homeConfigurations.crostini`. Updated in
flake.nix, update-env (2 occurrences), docs/design.md, CLAUDE.md. Remaining
`penguin` references in lib.bash and tests are correct -- they describe the
Crostini container's OS-level $HOSTNAME used by platform() for detection.

### Adversarial review history

Round 1 (2/5): identified P0s on live-exec wrapper, silent credential skip,
incomplete installer test. All addressed.

Round 2 (3/5): identified P1s on missing hostname preflight, missing CLI
boundary tests, incomplete panel runtime deps. All addressed.

Round 3 (3/5): remaining P1s and P2s below.

## Outstanding items from round 3 review

### P1 -- must fix before considering this work complete

1. **Hostname preflight validates existence only, not content.**
   `credentialPreflight` checks `[[ -f $CrostiniDir/hostname ]]` but does
   not validate the file is readable, non-empty, single-line, or matches
   the hostname charset (`[a-z0-9][a-z0-9-]*`). An empty or malformed
   hostname file passes preflight, then credential functions fail mid-stage
   after side effects. Fix: call `lib.MachineHostname` and
   `lib.ValidateHostname` in the preflight, which already implement the
   full validation. Test: add cases for empty file, malformed content.

2. **Flake config rename has no compatibility alias.**
   `homeConfigurations.penguin` was renamed to `.crostini` without a
   temporary alias. Downstream consumers: `~/nixos-config/flake.nix`
   references dotfiles via a `flake = false` path input (imports
   `contexts/linux/home.nix` directly, does NOT reference
   homeConfigurations). No CI. No known external scripts. But a one-line
   alias is cheap insurance:
   ```nix
   homeConfigurations.penguin = self.homeConfigurations.crostini;
   ```
   Add it, mark deprecated, remove in a future session.

### P2 -- should fix soon

3. **CLI `-c` has no positive-path boundary test.** The reject path is
   tested (non-crostini -> exit 2). The happy path (crostini -> dispatches
   credentialPreflight + credentialStage) is unverified at the CLI boundary.
   Can't test on crostini host since platform() can't be overridden
   externally. Fix: make platform detection injectable for tests (e.g.,
   `DOTFILES_PLATFORM` env var override when `DOTFILES_TEST=1`), then add
   a boundary test that sets it to crostini with mocked credential
   functions.

4. **Panel packaging lacks hermetic runtime test.** The runtime dep audit
   was manual. A stripped-PATH test would prove completeness:
   ```bash
   env -i PATH=/nix/store/.../panel/bin HOME=$HOME \
     panel vpn 2>&1  # should not fail with "command not found"
   ```
   Interactive-only deps (xdg-open, vpn) are intentionally excluded but
   untested code paths remain.

5. **`--help` uses `exit` not `exit 0`.** Currently works because
   `usageText` returns success, but fragile. Change to `exit 0`.

6. **tmux package selection is spread across layers.** shared.nix has no
   tmux, linux-base.nix has tmux-with-panel, macos/home.nix has plain tmux.
   Functional but diffuse. Consider a single selection point if more
   platforms are added.

## What remains from prior sessions

### P1 (from security model backlog)
1. **Signing key registration preflight** -- detect unregistered signing
   key before first push to protected branch.

### P2
2. **Declarative nix.conf ownership** -- split by platform.

### P3
3. **Signed tag/release for bootstrap** -- verify repo content before
   executing update-env on fresh machine.

### Housekeeping
4. Register signing key on Codeberg
5. Re-enable GitHub branch protection
6. Stage 2 not yet run -- run `update-env -c` to generate SSH key, then
   `update-env -2`
7. Commit and push this session's changes (this commit)

## Test results

59/59 pass. `home-manager build --flake ~/dotfiles#crostini` succeeds.
All nix and bash files parse clean.

## Testing

```bash
tesht update-env_test.bash test_each test_keepIf test_map test_verifySha256 \
  test_nixInstallerAsset test_installNix test_verifyNixFlakes \
  test_signingKeyAction test_restoreSigningKey test_installKey \
  test_pubFingerprint test_crostiniHostname test_authPreflight \
  test_restoreSecretsTierSelection test_ageRoundTrip test_withSecretMissingFile \
  test_usageText test_credentialPreflight test_cliHelp \
  test_cliCredentialRejectsNonCrostini
```

## Context for next agent

- Follow docs-first, red/green TDD per Khorikov (see binaryphile.com).
- Read CLAUDE.md for project conventions (ASCII only, bash style,
  nix/bash boundary).
- Read docs/security.md for threat model and controls.
- Bash style: IFS=$'\n' + noglob, `_` suffix for IFS-contaminated
  variables, UPPERCASE namerefs.
- DI pattern: lowercase globals in the DI block, overridden by `local`
  in tests.
- tesht: data-driven subtests with associative arrays, mock names in
  case arrays.
- Panel is now nix-packaged (store copy), not a live symlink. Edits
  require `home-manager switch`.
- `update-env -c` runs credentials without full stage 1.
- The tmux overlay is `tmux-with-panel` in linux-base.nix.
- Flake config is `crostini` (was `penguin`).
- Outstanding P1s above should be addressed before other work.
