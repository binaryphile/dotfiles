#!/usr/bin/env bash

# Tests for scripts/update-env-audit — compliance audit script for
# update-env stage-1 convergence.
#
# Output-state-based: assertions on captured stdout + exit code of the
# script invoked as a subprocess. No mocks; uses tesht.MktempDir for
# isolated synthetic homes / repos / flake.locks.
#
# Assertion discipline: every grep is wrapped in `|| true` (or has its
# rc masked) before being passed to tesht.AssertGot. Otherwise tesht's
# strict-mode subshell kills the test on grep's non-zero rc.

Script=$HOME/dotfiles/scripts/update-env-audit

# fixture helper: create an update-env stub with the given task.Ln
# declarations. Each declaration is one "<src> <link>" string.
makeUpdateEnvStub() {
  local out=$1; shift
  {
    echo '#!/usr/bin/env bash'
    echo '# stub for testing'
    if (( $# > 0 )); then
      echo "each task.Ln <<'END'"
      printf '  %s\n' "$@"
      echo 'END'
    fi
  } > "$out"
}

# fixture helper: minimal flake.lock with a given nixpkgs rev.
makeFlakeLock() {
  local out=$1 rev=$2
  cat > "$out" <<EOF
{
  "nodes": {
    "nixpkgs": {
      "locked": {
        "rev": "$rev"
      }
    }
  }
}
EOF
}

# fixture helper: init a git repo with optional core.hooksPath value.
makeGitRepo() {
  local dir=$1 hooksPath=${2:-}
  mkdir -p "$dir"
  git -C "$dir" init -q
  [[ -n $hooksPath ]] && git -C "$dir" config core.hooksPath "$hooksPath"
  return 0
}

# countMatches -- count lines matching a regex in $OutputT.
# Safe under set -e: wraps grep's non-match-returns-1 with || true.
countMatches() {
  grep -c "$1" <<<"$OutputT" || true
}

# countMatchesFixed -- count lines containing a literal substring.
countMatchesFixed() {
  grep -cF "$1" <<<"$OutputT" || true
}

# runAudit -- invoke the script with overridden paths.
# Args: home dir, [flags...].
# Sets globals OutputT, RcT.
runAudit() {
  local home=$1; shift
  OutputT=$(
    HOME=$home \
      UPDATE_ENV_AUDIT_SOURCE=$home/update-env \
      UPDATE_ENV_AUDIT_DOTFILES=$home/dotfiles \
      UPDATE_ENV_AUDIT_PROJECTS=$home/projects \
      UPDATE_ENV_AUDIT_CLAUDE_MD=$home/.claude/CLAUDE.md \
      UPDATE_ENV_AUDIT_ERA_FLAKE_LOCK=$home/projects/era/flake.lock \
      "$Script" "$@" 2>&1
  ) && RcT=$? || RcT=$?
  return 0
}

# --- Phase-1 symlinks ---

test_phase1Symlinks_all_present() {
  local Dir; tesht.MktempDir Dir || return 128
  mkdir -p "$Dir/dotfiles"
  for f in .bashrc .profile .bash_profile .shellcheckrc config local ssh .netrc; do
    ln -s "$Dir/target" "$Dir/$f"
  done
  ln -s "$Dir/target" "$Dir/dotfiles/context"
  touch "$Dir/target"
  makeUpdateEnvStub "$Dir/update-env"

  runAudit "$Dir"

  local okN missingN
  okN=$(countMatches '^\[OK\] phase1Symlinks')
  missingN=$(countMatches '^\[MISSING\] phase1Symlinks')
  tesht.AssertGot "$okN" "9"
  tesht.AssertGot "$missingN" "0"
}

test_phase1Symlinks_one_missing() {
  local Dir; tesht.MktempDir Dir || return 128
  mkdir -p "$Dir/dotfiles"
  for f in .profile .bash_profile .shellcheckrc config local ssh .netrc; do
    ln -s "$Dir/target" "$Dir/$f"
  done
  ln -s "$Dir/target" "$Dir/dotfiles/context"
  touch "$Dir/target"
  makeUpdateEnvStub "$Dir/update-env"

  runAudit "$Dir"

  tesht.AssertGot "$RcT" "1"
  local got
  got=$(countMatchesFixed "[MISSING] phase1Symlinks: $Dir/.bashrc")
  tesht.AssertGot "$got" "1"
}

# --- Bin symlinks: broken-link detection ---

test_binSymlinksBroken_clean() {
  local Dir; tesht.MktempDir Dir || return 128
  mkdir -p "$Dir/.local/bin" "$Dir/srcdir"
  touch "$Dir/srcdir/foo"
  ln -s "$Dir/srcdir/foo" "$Dir/.local/bin/foo"
  makeUpdateEnvStub "$Dir/update-env" "$Dir/srcdir/foo $Dir/.local/bin/foo"

  runAudit "$Dir"

  local brokenN okN
  brokenN=$(countMatches '^\[BROKEN\]')
  okN=$(countMatchesFixed "[OK] binSymlinksBroken: $Dir/.local/bin/foo")
  tesht.AssertGot "$brokenN" "0"
  tesht.AssertGot "$okN" "1"
}

test_binSymlinksBroken_dangling() {
  local Dir; tesht.MktempDir Dir || return 128
  mkdir -p "$Dir/.local/bin"
  ln -s "$Dir/nonexistent" "$Dir/.local/bin/foo"
  makeUpdateEnvStub "$Dir/update-env" "$Dir/nonexistent $Dir/.local/bin/foo"

  runAudit "$Dir"

  tesht.AssertGot "$RcT" "1"
  local got
  got=$(countMatchesFixed "[BROKEN] binSymlinksBroken: $Dir/.local/bin/foo -> $Dir/nonexistent")
  tesht.AssertGot "$got" "1"
}

# --- Bin symlinks: target equality ---

test_binSymlinksTargets_match() {
  local Dir; tesht.MktempDir Dir || return 128
  mkdir -p "$Dir/.local/bin" "$Dir/srcdir"
  touch "$Dir/srcdir/foo"
  ln -s "$Dir/srcdir/foo" "$Dir/.local/bin/foo"
  makeUpdateEnvStub "$Dir/update-env" "$Dir/srcdir/foo $Dir/.local/bin/foo"

  runAudit "$Dir"

  local driftN okN
  driftN=$(countMatches '^\[DRIFT\] binSymlinksTargets')
  okN=$(countMatchesFixed "[OK] binSymlinksTargets: $Dir/.local/bin/foo")
  tesht.AssertGot "$driftN" "0"
  tesht.AssertGot "$okN" "1"
}

test_binSymlinksTargets_drift() {
  local Dir; tesht.MktempDir Dir || return 128
  mkdir -p "$Dir/.local/bin" "$Dir/srcdir" "$Dir/other"
  touch "$Dir/srcdir/foo" "$Dir/other/foo"
  ln -s "$Dir/other/foo" "$Dir/.local/bin/foo"
  makeUpdateEnvStub "$Dir/update-env" "$Dir/srcdir/foo $Dir/.local/bin/foo"

  runAudit "$Dir"

  tesht.AssertGot "$RcT" "1"
  local got
  got=$(countMatchesFixed "[DRIFT] binSymlinksTargets: $Dir/.local/bin/foo: expected $Dir/srcdir/foo, got $Dir/other/foo")
  tesht.AssertGot "$got" "1"
}

# --- Retired binaries ---

test_retiredBinaries_absent() {
  local Dir; tesht.MktempDir Dir || return 128
  mkdir -p "$Dir/.local/bin" "$Dir/.claude/commands" "$Dir/dotfiles"
  makeUpdateEnvStub "$Dir/update-env"

  runAudit "$Dir"

  local got
  got=$(countMatches '^\[RESIDUAL\]')
  tesht.AssertGot "$got" "0"
}

test_retiredBinaries_present() {
  local Dir; tesht.MktempDir Dir || return 128
  mkdir -p "$Dir/.local/bin" "$Dir/.claude/commands" "$Dir/dotfiles"
  touch "$Dir/.local/bin/mk"
  makeUpdateEnvStub "$Dir/update-env"

  runAudit "$Dir"

  tesht.AssertGot "$RcT" "1"
  local got
  got=$(countMatchesFixed "[RESIDUAL] retiredBinaries: $Dir/.local/bin/mk")
  tesht.AssertGot "$got" "1"
}

# --- git hooksPath ---

test_gitHooksPath_consistent() {
  local Dir; tesht.MktempDir Dir || return 128
  makeUpdateEnvStub "$Dir/update-env"
  makeGitRepo "$Dir/dotfiles" .githooks
  makeGitRepo "$Dir/projects/jeeves" .githooks
  makeGitRepo "$Dir/projects/finances" .githooks

  runAudit "$Dir"

  local got
  got=$(countMatches '^\[DRIFT\] gitHooksPath')
  tesht.AssertGot "$got" "0"
}

test_gitHooksPath_unset() {
  local Dir; tesht.MktempDir Dir || return 128
  makeUpdateEnvStub "$Dir/update-env"
  makeGitRepo "$Dir/dotfiles" .githooks
  makeGitRepo "$Dir/projects/jeeves"          # no hooksPath
  makeGitRepo "$Dir/projects/finances" .githooks

  runAudit "$Dir"

  tesht.AssertGot "$RcT" "1"
  local got
  got=$(countMatchesFixed "[DRIFT] gitHooksPath: $Dir/projects/jeeves: expected .githooks, got (unset)")
  tesht.AssertGot "$got" "1"
}

# --- CLAUDE.md markers ---

test_claudeMdMarkers_all_present() {
  local Dir; tesht.MktempDir Dir || return 128
  makeUpdateEnvStub "$Dir/update-env"
  mkdir -p "$Dir/.claude"
  cat > "$Dir/.claude/CLAUDE.md" <<EOF
# CLAUDE.md
@~/projects/era/docs/era.md
@~/projects/tesht/docs/tesht.md
@~/projects/tandem-protocol/README.md
EOF

  runAudit "$Dir"

  local got
  got=$(countMatches '^\[MISSING\] claudeMdMarkers')
  tesht.AssertGot "$got" "0"
}

test_claudeMdMarkers_one_missing() {
  local Dir; tesht.MktempDir Dir || return 128
  makeUpdateEnvStub "$Dir/update-env"
  mkdir -p "$Dir/.claude"
  cat > "$Dir/.claude/CLAUDE.md" <<EOF
# CLAUDE.md
@~/projects/era/docs/era.md
@~/projects/tandem-protocol/README.md
EOF

  runAudit "$Dir"

  tesht.AssertGot "$RcT" "1"
  local got
  got=$(countMatchesFixed "[MISSING] claudeMdMarkers: @~/projects/tesht/docs/tesht.md")
  tesht.AssertGot "$got" "1"
}

# --- flake.lock canonical-rev pinning ---

test_flakeLockCanonical_aligned() {
  local Dir; tesht.MktempDir Dir || return 128
  makeUpdateEnvStub "$Dir/update-env"
  mkdir -p "$Dir/projects/era" "$Dir/projects/jeeves"
  local rev=deadbeefcafebabe1234567890abcdefdeadbeef
  makeFlakeLock "$Dir/projects/era/flake.lock" $rev
  makeFlakeLock "$Dir/projects/jeeves/flake.lock" $rev

  runAudit "$Dir"

  local got
  got=$(countMatches '^\[DRIFT\] flakeLockCanonical')
  tesht.AssertGot "$got" "0"
}

test_flakeLockCanonical_drift() {
  local Dir; tesht.MktempDir Dir || return 128
  makeUpdateEnvStub "$Dir/update-env"
  mkdir -p "$Dir/projects/era" "$Dir/projects/jeeves"
  local canonical=deadbeefcafebabe1234567890abcdefdeadbeef
  local stale=affffffffffffffffffffffffffffffffffffff0
  makeFlakeLock "$Dir/projects/era/flake.lock" $canonical
  makeFlakeLock "$Dir/projects/jeeves/flake.lock" $stale

  runAudit "$Dir"

  tesht.AssertGot "$RcT" "1"
  local got
  got=$(countMatchesFixed "[DRIFT] flakeLockCanonical: $Dir/projects/jeeves/flake.lock")
  tesht.AssertGot "$got" "1"
}

# --- Renderers ---

test_renderJson_shape() {
  local Dir; tesht.MktempDir Dir || return 128
  makeUpdateEnvStub "$Dir/update-env"

  runAudit "$Dir" --json

  # Envelope: {schemaVersion, toolVersion, findings: [...]} where each
  # finding has {status, category, detail}.
  local got
  got=$(jq -e '
    type == "object"
    and has("schemaVersion") and (.schemaVersion == 1)
    and has("toolVersion")
    and has("findings")
    and (.findings | type == "array" and (length > 0))
    and (.findings | all(.[]; has("status") and has("category") and has("detail")))
  ' <<<"$OutputT" >/dev/null && echo yes || echo no)
  tesht.AssertGot "$got" "yes"
}

test_renderText_shape() {
  local Dir; tesht.MktempDir Dir || return 128
  makeUpdateEnvStub "$Dir/update-env"

  runAudit "$Dir"

  # Every non-empty line must match [STATUS] <category>: <detail>.
  local malformed
  malformed=$(awk 'NF && !/^\[(OK|MISSING|BROKEN|RESIDUAL|DRIFT)\] [a-zA-Z0-9]+: /' <<<"$OutputT" | wc -l)
  tesht.AssertGot "$malformed" "0"
}

# --- Unaudited declarations (coverage boundary surface) ---

test_unauditedDeclarations_static_only() {
  local Dir; tesht.MktempDir Dir || return 128
  # update-env stub with only literal declarations -- no $ expansion needed.
  makeUpdateEnvStub "$Dir/update-env" "/abs/src /abs/dst"

  runAudit "$Dir"

  local got
  got=$(countMatches '^\[UNAUDITED\]')
  tesht.AssertGot "$got" "0"
}

test_unauditedDeclarations_present() {
  local Dir; tesht.MktempDir Dir || return 128
  # update-env stub with both a literal and a variable-expanded declaration.
  cat > "$Dir/update-env" <<'STUB'
#!/usr/bin/env bash
each task.Ln <<'END'
  /abs/literal/src           /abs/literal/dst
  contexts/"$Platform"       ~/dotfiles/context
END
STUB

  runAudit "$Dir"

  # Should emit exactly one UNAUDITED finding (the $Platform line).
  local got
  got=$(countMatches '^\[UNAUDITED\] taskLnDeclarations')
  tesht.AssertGot "$got" "1"
}

test_unauditedDeclarations_do_not_fail_rc() {
  local Dir; tesht.MktempDir Dir || return 128
  # Clean fixture except for one UNAUDITED declaration.
  mkdir -p "$Dir/dotfiles" "$Dir/.local/bin" "$Dir/.claude/commands" "$Dir/projects/era"
  for f in .bashrc .profile .bash_profile .shellcheckrc config local ssh .netrc; do
    ln -s "$Dir/t" "$Dir/$f"
  done
  ln -s "$Dir/t" "$Dir/dotfiles/context"
  touch "$Dir/t"
  cat > "$Dir/update-env" <<'STUB'
#!/usr/bin/env bash
each task.Ln <<'END'
  contexts/"$Platform"       ~/dotfiles/context
END
STUB
  cat > "$Dir/.claude/CLAUDE.md" <<EOF
@~/projects/era/docs/era.md
@~/projects/tesht/docs/tesht.md
@~/projects/tandem-protocol/README.md
EOF
  makeGitRepo "$Dir/dotfiles" .githooks
  makeGitRepo "$Dir/projects/jeeves" .githooks
  makeGitRepo "$Dir/projects/finances" .githooks
  makeFlakeLock "$Dir/projects/era/flake.lock" deadbeefcafebabe

  runAudit "$Dir"

  # UNAUDITED present + everything else OK -> rc=0 (UNAUDITED is advisory).
  tesht.AssertGot "$RcT" "0"
  local unauditedN
  unauditedN=$(countMatches '^\[UNAUDITED\] taskLnDeclarations')
  tesht.AssertGot "$unauditedN" "1"
}

# --- Historical drift fixtures (the two findings that motivated the cycle) ---

test_historicalDrift_sync_shellcheckrc_broken() {
  local Dir; tesht.MktempDir Dir || return 128
  # Simulate the original BROKEN sync-shellcheckrc finding:
  # update-env declares a task.Ln to a script that was retired; stage-1
  # ran before the retirement, creating the link; cleanup didn't happen.
  mkdir -p "$Dir/.local/bin" "$Dir/dotfiles/scripts"
  # The retired script is GONE (matches post-727b09c reality).
  # The dangling link is present (legacy stage-1 output).
  ln -s "$Dir/dotfiles/scripts/sync-shellcheckrc" "$Dir/.local/bin/sync-shellcheckrc"
  makeUpdateEnvStub "$Dir/update-env" \
    "$Dir/dotfiles/scripts/sync-shellcheckrc $Dir/.local/bin/sync-shellcheckrc"

  runAudit "$Dir"

  tesht.AssertGot "$RcT" "1"
  local got
  got=$(countMatchesFixed "[BROKEN] binSymlinksBroken: $Dir/.local/bin/sync-shellcheckrc")
  tesht.AssertGot "$got" "1"
}

test_historicalDrift_scaffold_target_drift() {
  local Dir; tesht.MktempDir Dir || return 128
  # Simulate the original DRIFT scaffold finding:
  # update-env declares the link at $Dir/dotfiles/scripts/scaffold; the
  # operator's actual link points at $Dir/projects/share/scaffold/scaffold.
  # Both source files exist (so no BROKEN); they're different files.
  mkdir -p "$Dir/.local/bin" "$Dir/dotfiles/scripts" "$Dir/projects/share/scaffold"
  touch "$Dir/dotfiles/scripts/scaffold"
  touch "$Dir/projects/share/scaffold/scaffold"
  ln -s "$Dir/projects/share/scaffold/scaffold" "$Dir/.local/bin/scaffold"
  makeUpdateEnvStub "$Dir/update-env" \
    "$Dir/dotfiles/scripts/scaffold $Dir/.local/bin/scaffold"

  runAudit "$Dir"

  tesht.AssertGot "$RcT" "1"
  local got
  got=$(countMatchesFixed "[DRIFT] binSymlinksTargets: $Dir/.local/bin/scaffold: expected $Dir/dotfiles/scripts/scaffold, got $Dir/projects/share/scaffold/scaffold")
  tesht.AssertGot "$got" "1"
}

# --- main rc semantics ---

test_main_exit0_when_clean() {
  local Dir; tesht.MktempDir Dir || return 128

  # All categories clean.
  mkdir -p "$Dir/dotfiles" "$Dir/.local/bin" "$Dir/.claude/commands" "$Dir/projects/era"
  for f in .bashrc .profile .bash_profile .shellcheckrc config local ssh .netrc; do
    ln -s "$Dir/t" "$Dir/$f"
  done
  ln -s "$Dir/t" "$Dir/dotfiles/context"
  touch "$Dir/t"
  makeUpdateEnvStub "$Dir/update-env"
  cat > "$Dir/.claude/CLAUDE.md" <<EOF
@~/projects/era/docs/era.md
@~/projects/tesht/docs/tesht.md
@~/projects/tandem-protocol/README.md
EOF
  makeGitRepo "$Dir/dotfiles" .githooks
  makeGitRepo "$Dir/projects/jeeves" .githooks
  makeGitRepo "$Dir/projects/finances" .githooks
  makeFlakeLock "$Dir/projects/era/flake.lock" deadbeefcafebabe

  runAudit "$Dir"

  tesht.AssertGot "$RcT" "0"
}

test_main_exit1_when_drift() {
  local Dir; tesht.MktempDir Dir || return 128

  # Otherwise clean, plus one RESIDUAL.
  mkdir -p "$Dir/dotfiles" "$Dir/.local/bin" "$Dir/.claude/commands" "$Dir/projects/era"
  for f in .bashrc .profile .bash_profile .shellcheckrc config local ssh .netrc; do
    ln -s "$Dir/t" "$Dir/$f"
  done
  ln -s "$Dir/t" "$Dir/dotfiles/context"
  touch "$Dir/t"
  touch "$Dir/.local/bin/mk"   # RETIRED binary still present
  makeUpdateEnvStub "$Dir/update-env"
  cat > "$Dir/.claude/CLAUDE.md" <<EOF
@~/projects/era/docs/era.md
@~/projects/tesht/docs/tesht.md
@~/projects/tandem-protocol/README.md
EOF
  makeGitRepo "$Dir/dotfiles" .githooks
  makeGitRepo "$Dir/projects/jeeves" .githooks
  makeGitRepo "$Dir/projects/finances" .githooks
  makeFlakeLock "$Dir/projects/era/flake.lock" deadbeefcafebabe

  runAudit "$Dir"

  tesht.AssertGot "$RcT" "1"
}
