#!/usr/bin/env bash
# Tests for bash/lib/op-run-integrity.bash.
#
# OpRunIntegrityCheck is a Controller (Khorikov classical school):
# orchestrates a source-content probe and a PATH-resolution probe and
# routes detective signals to stderr. Tests assert observable stderr
# only; no mocks except the inter-system filesystem boundary (via
# tesht.MktempDir) and the PATH env-var seam.

source "$PWD/bash/lib/op-run-integrity.bash"

# seedRoot populates a tempdir with the minimum hashed-artifact set:
# scripts/op-run, op-run/projects.bash, one op-run/machines/<host>.allow,
# plus a deterministic op-run/checksums covering all three.
#
# Args: <root>. Writes files; leaves the canonical checksums in
# <root>/op-run/checksums.
seedRoot() {
  local root=$1
  mkdir -p "$root/scripts" "$root/op-run/machines"
  printf '#!/usr/bin/env bash\necho launcher\n' > "$root/scripts/op-run"
  printf '# registry\nProjectPath=()\n' > "$root/op-run/projects.bash"
  printf '# host allowlist\nAllowedVaults=()\n' > "$root/op-run/machines/test.allow"
  (
    cd "$root"
    sha256sum scripts/op-run op-run/projects.bash op-run/machines/test.allow \
      | LC_ALL=C sort -k 2 > op-run/checksums
  )
}

# capStderr runs `cmd` with provided env overrides and captures stderr.
# Pattern: `local out; capStderr out DotfilesRoot=$root OpRunIntegrityCheck`
# (out param style avoids subshell-swallowed fatals; matches op-run.bash).
capStderr() {
  local -n OUT=$1
  shift
  # Run in a subshell so PATH/DotfilesRoot mutations don't leak.
  OUT=$( ( "$@" ) 2>&1 >/dev/null ) || true
}

## happy path -- silent

test_OpRunIntegrityCheck_happy_path_silent() {
  local Dir; tesht.MktempDir Dir || return 128
  seedRoot "$Dir"

  # Hide any installed op-run; we are testing source-content probe only.
  local stderr
  stderr=$( PATH=/usr/bin:/bin DotfilesRoot="$Dir" OpRunIntegrityCheck 2>&1 1>/dev/null )

  tesht.AssertGot "$stderr" ""
}

## source-content probe -- mismatch warns

test_OpRunIntegrityCheck_source_mismatch_warns() {
  local Dir; tesht.MktempDir Dir || return 128
  seedRoot "$Dir"

  # Corrupt the first hash byte so sha256sum --check fails.
  sed -i '1s/^./0/' "$Dir/op-run/checksums"

  local stderr
  stderr=$( PATH=/usr/bin:/bin DotfilesRoot="$Dir" OpRunIntegrityCheck 2>&1 1>/dev/null )

  [[ $stderr == *"op-run integrity: hash mismatch"* ]] \
    || { echo "expected 'hash mismatch' in stderr, got: $stderr"; return 1; }
}

## source-content probe -- missing checksums skips silently

test_OpRunIntegrityCheck_missing_checksums_silent() {
  local Dir; tesht.MktempDir Dir || return 128
  seedRoot "$Dir"
  rm "$Dir/op-run/checksums"

  local stderr
  stderr=$( PATH=/usr/bin:/bin DotfilesRoot="$Dir" OpRunIntegrityCheck 2>&1 1>/dev/null )

  tesht.AssertGot "$stderr" ""
}

## PATH-resolution probe -- shadowed binary warns

test_OpRunIntegrityCheck_path_shadow_warns() {
  local Dir; tesht.MktempDir Dir || return 128
  seedRoot "$Dir"

  local shadowDir=$Dir/shadow
  mkdir -p "$shadowDir"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$shadowDir/op-run"
  chmod +x "$shadowDir/op-run"

  local stderr
  stderr=$( PATH="$shadowDir" DotfilesRoot="$Dir" OpRunIntegrityCheck 2>&1 1>/dev/null )

  [[ $stderr == *"installed op-run is not under /nix/store"* ]] \
    || { echo "expected PATH-shadow warning in stderr, got: $stderr"; return 1; }
}

## PATH-resolution probe -- op-run not on PATH skips silently

test_OpRunIntegrityCheck_op_run_absent_silent() {
  local Dir; tesht.MktempDir Dir || return 128
  seedRoot "$Dir"

  local stderr
  stderr=$( PATH=/usr/bin:/bin DotfilesRoot="$Dir" OpRunIntegrityCheck 2>&1 1>/dev/null )

  tesht.AssertGot "$stderr" ""
}

## bootstrap -- neither DotfilesRoot nor Root set skips silently

test_OpRunIntegrityCheck_bootstrap_silent() {
  local stderr
  stderr=$( PATH=/usr/bin:/bin bash -c \
              "unset DotfilesRoot Root; source $PWD/bash/lib/op-run-integrity.bash; OpRunIntegrityCheck" 2>&1 1>/dev/null )

  tesht.AssertGot "$stderr" ""
}

## both probes fail -- both warnings appear

test_OpRunIntegrityCheck_both_probes_warn() {
  local Dir; tesht.MktempDir Dir || return 128
  seedRoot "$Dir"
  sed -i '1s/^./0/' "$Dir/op-run/checksums"

  local shadowDir=$Dir/shadow
  mkdir -p "$shadowDir"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$shadowDir/op-run"
  chmod +x "$shadowDir/op-run"

  local stderr
  stderr=$( PATH="$shadowDir" DotfilesRoot="$Dir" OpRunIntegrityCheck 2>&1 1>/dev/null )

  [[ $stderr == *"hash mismatch"* ]] \
    || { echo "expected source-mismatch warning, got: $stderr"; return 1; }
  [[ $stderr == *"installed op-run is not under /nix/store"* ]] \
    || { echo "expected PATH-shadow warning, got: $stderr"; return 1; }
}

## manifest equality across regenerator and pre-commit hook

test_manifest_equality_regenerator_vs_hook() {
  # Both scripts hardcode the same glob pattern in a `declare -a Manifest=(...)`
  # array. Extract the Manifest block from each, normalize, and compare.
  extractManifest() {
    awk '/^declare -a Manifest=\(/,/^\)/' "$1" \
      | sed -e 's/^declare -a Manifest=(//' -e 's/^)$//' \
      | grep -v '^[[:space:]]*$' \
      | grep -v '^[[:space:]]*#' \
      | awk '{$1=$1;print}'
  }

  local regenManifest hookManifest
  regenManifest=$(extractManifest scripts/op-run-checksum-update)
  hookManifest=$(extractManifest githooks/pre-commit)

  tesht.AssertGot "$regenManifest" "$hookManifest"
}
