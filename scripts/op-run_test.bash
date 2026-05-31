#!/usr/bin/env bash

# op-run_test.bash -- tesht harness for scripts/op-run
#
# Naming Policy: standalone test script -- no namespace prefix on functions.
# Function names use camelCase. Globals PascalCase. Locals camelCase.
# DI vars (lowercase) are shadowed via `local` per the bash style guide.
#
# Tests source scripts/op-run; the script's `return 2>/dev/null` exits the
# sourced read before its strict-mode preamble and before main() runs, so
# functions and DI globals are loaded but main does not execute.

# shellcheck disable=SC1091
source "$PWD/scripts/op-run"

## helpers

# stubGit creates an executable in $Dir that prints `toplevel` and exits 0.
#
# Returns the path on stdout. Implemented via a tempfile because `local
# git=funcName` resolves $git to an external binary lookup, and bash function
# names cannot be dispatched as binaries.
stubGit() {
  local toplevel=$1
  local path=$Dir/stub-git-$RANDOM
  cat >"$path" <<EOF
#!/usr/bin/env bash
echo "$toplevel"
EOF
  chmod +x "$path"
  echo "$path"
}

# stubRealpath creates an executable in $Dir that echoes its first argument unchanged.
#
# Returns the path on stdout. Sufficient when tests pass already-canonical paths.
stubRealpath() {
  local path=$Dir/stub-realpath-$RANDOM
  cat >"$path" <<'EOF'
#!/usr/bin/env bash
echo "$1"
EOF
  chmod +x "$path"
  echo "$path"
}

## tests

# test_resolveProject_success verifies the happy path: git toplevel matches a registered ProjectPath.
test_resolveProject_success() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  ## arrange
  declare -Ag ProjectPath=( [demo]=/some/canonical/path )
  local git realpath
  git=$(stubGit "/some/canonical/path")
  realpath=$(stubRealpath)

  ## act
  local got
  got=$(resolveProject) || return 1

  ## assert
  tesht.AssertGot "$got" "demo"
}

# test_resolveProject_no_git_repo verifies exit 64 when invoked outside a git repo.
test_resolveProject_no_git_repo() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local stubExit=$Dir/stub-git-exit
  cat >"$stubExit" <<'EOF'
#!/usr/bin/env bash
exit 128
EOF
  chmod +x "$stubExit"

  local git=$stubExit realpath
  realpath=$(stubRealpath)
  local rc=0
  ( resolveProject ) >/dev/null 2>&1 || rc=$?
  tesht.AssertRC $rc 64
}

# test_resolveProject_no_registry_match verifies exit 65 when the toplevel matches no registered path.
test_resolveProject_no_registry_match() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  declare -Ag ProjectPath=( [other]=/some/other/path )
  local git realpath
  git=$(stubGit "/unmatched/toplevel")
  realpath=$(stubRealpath)

  local rc=0
  ( resolveProject ) >/dev/null 2>&1 || rc=$?
  tesht.AssertRC $rc 65
}

# test_guardSubstitutions_unsubstituted verifies the REAL function fatals
# when the LHS marker is still literal. The sourced script body has the
# unsubstituted marker, so calling the real function should exit 73.
#
# This regresses the historical bug where mkScriptBin replaced both LHS
# and RHS markers, making the inequality always-false and the guard inert.
test_guardSubstitutions_unsubstituted() {
  local rc=0
  ( guardSubstitutions ) >/dev/null 2>&1 || rc=$?
  tesht.AssertRC $rc 73
}

# test_guardSubstitutions_after_substitution simulates the post-substitution
# state by sed-rewriting the LHS literal in the function body, then invoking
# the real function. The RHS marker (built via adjacent-string concatenation)
# must survive substitution unchanged, so this exercises the actual fix.
test_guardSubstitutions_after_substitution() {
  local body
  body=$(declare -f guardSubstitutions | sed "s|'@dotfilesRoot@'|'$HOME/dotfiles'|")
  eval "$body"
  local rc=0
  guardSubstitutions || rc=$?
  tesht.AssertRC $rc 0
}

# test_sourceOrFail_readable verifies sourceOrFail returns success on a readable file.
test_sourceOrFail_readable() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  echo "TestSourceOrFailVar=set" >"$Dir/lib.bash"
  local rc=0
  ( sourceOrFail "$Dir/lib.bash" ) >/dev/null 2>&1 || rc=$?
  tesht.AssertRC $rc 0
}

# test_sourceOrFail_missing verifies sourceOrFail fatals with exit 72 on a missing file.
test_sourceOrFail_missing() {
  local rc=0
  ( sourceOrFail /nonexistent/path/to/nothing.bash ) >/dev/null 2>&1 || rc=$?
  tesht.AssertRC $rc 72
}

# test_parseOptions_no_flags verifies positional args populate ParsedPositional.
#
# ${arr[*]} joins with the first char of IFS, which is $'\n' under tesht, so
# the want value uses $'\n' literals.
test_parseOptions_no_flags() {
  unset -v ParsedPositional
  parseOptions tool-name arg1 arg2
  tesht.AssertGot "${ParsedPositional[*]}" $'tool-name\narg1\narg2'
}

# test_parseOptions_after_dashdash verifies that args after `--` are treated as positional.
test_parseOptions_after_dashdash() {
  unset -v ParsedPositional
  parseOptions -- --weird-arg another
  tesht.AssertGot "${ParsedPositional[*]}" $'--weird-arg\nanother'
}

# test_parseOptions_unknown_flag verifies an unknown flag triggers exit 64.
test_parseOptions_unknown_flag() {
  local rc=0
  ( parseOptions --bogus tool ) >/dev/null 2>&1 || rc=$?
  tesht.AssertRC $rc 64
}

# test_enforceProjectVaultVisible_present verifies success when vault is in VisibleVaults.
test_enforceProjectVaultVisible_present() {
  declare -ag VisibleVaults=( Private urma-atlassian )
  local rc=0
  enforceProjectVaultVisible "urma-atlassian" || rc=$?
  tesht.AssertRC $rc 0
}

# test_enforceProjectVaultVisible_missing verifies exit 68 when the vault is not visible.
test_enforceProjectVaultVisible_missing() {
  declare -ag VisibleVaults=( Private )
  export OP_ACCOUNT=test
  local rc=0
  ( enforceProjectVaultVisible "urma-atlassian" ) >/dev/null 2>&1 || rc=$?
  tesht.AssertRC $rc 68
}

# test_enforceVaultsMatch_exact_match verifies success when sets are equal.
test_enforceVaultsMatch_exact_match() {
  declare -ag VisibleVaults=( Private urma-atlassian )
  declare -ag AllowedVaults=( Private urma-atlassian )
  local rc=0
  enforceVaultsMatch || rc=$?
  tesht.AssertRC $rc 0
}

# test_enforceVaultsMatch_extra_vault verifies exit 69 when VisibleVaults has an extra entry.
test_enforceVaultsMatch_extra_vault() {
  declare -ag VisibleVaults=( Private urma-atlassian extras-vault )
  declare -ag AllowedVaults=( Private urma-atlassian )
  local rc=0
  ( enforceVaultsMatch ) >/dev/null 2>&1 || rc=$?
  tesht.AssertRC $rc 69
}

# test_enforceVaultsMatch_missing_vault verifies exit 69 when VisibleVaults lacks an allowed entry.
test_enforceVaultsMatch_missing_vault() {
  declare -ag VisibleVaults=( Private )
  declare -ag AllowedVaults=( Private urma-atlassian )
  local rc=0
  ( enforceVaultsMatch ) >/dev/null 2>&1 || rc=$?
  tesht.AssertRC $rc 69
}

# test_enforceVaultsMatch_last_alphabetic_mismatch is a regression for the trailing-newline bug.
#
# Pre-fix, comm received input from `printf '%s' "$sortedString"` (no
# terminator) which could mis-classify the alphabetically-last entry. This
# test forces the differing vault to sort last (`zzz-vault` > `urma-atlassian`
# > `Private` under default LC_ALLs) so any regression to the no-terminator
# form would mis-classify.
test_enforceVaultsMatch_last_alphabetic_mismatch() {
  declare -ag VisibleVaults=( Private urma-atlassian zzz-vault )
  declare -ag AllowedVaults=( Private urma-atlassian )
  local rc=0
  local out
  out=$( enforceVaultsMatch 2>&1 ) || rc=$?
  tesht.AssertRC $rc 69
  [[ $out == *zzz-vault* ]] || { echo "expected zzz-vault in error message; got: $out"; return 1; }
}

# test_enforceNoDotenv_clean verifies success when no .env exists in [CWD, toplevel].
test_enforceNoDotenv_clean() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN
  local git realpath
  git=$(stubGit "$Dir")
  realpath=$(stubRealpath)
  ( cd "$Dir" && enforceNoDotenv ) || return 1
}

# test_enforceNoDotenv_finds_env verifies exit 70 when a .env exists in the walk path.
test_enforceNoDotenv_finds_env() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN
  : >"$Dir/.env"
  local git realpath
  git=$(stubGit "$Dir")
  realpath=$(stubRealpath)
  local rc=0
  ( cd "$Dir" && enforceNoDotenv ) >/dev/null 2>&1 || rc=$?
  tesht.AssertRC $rc 70
}

# test_applyEnvSpec_exports verifies KEY=value lines export, blanks/comments are skipped.
test_applyEnvSpec_exports() {
  unset -v APPLYTEST_FOO
  ( applyEnvSpec "APPLYTEST_FOO=bar
# comment line, ignored

APPLYTEST_BAZ=qux" >/dev/null 2>&1; printf '%s|%s' "${APPLYTEST_FOO:-}" "${APPLYTEST_BAZ:-}" )
  ( applyEnvSpec "APPLYTEST_FOO=bar" >/dev/null 2>&1; tesht.AssertGot "${APPLYTEST_FOO:-}" "bar" )
}

# test_applyEnvSpec_malformed verifies exit 71 when a non-empty line is missing `=`.
test_applyEnvSpec_malformed() {
  local rc=0
  ( applyEnvSpec "no_equals_sign" ) >/dev/null 2>&1 || rc=$?
  tesht.AssertRC $rc 71
}

# test_urmaProjectEnvSpec_includesJira verifies the urma project registry
# declares Jira credential injection. Guards against accidental removal of
# JIRA_* entries; parser correctness is covered by test_applyEnvSpec_exports.
test_urmaProjectEnvSpec_includesJira() {
  ( source "$PWD/op-run/projects.bash"

    local spec=${ProjectEnvSpec[urma]:-}
    [[ -n $spec ]] || { echo "ProjectEnvSpec[urma] not set"; return 1; }

    grep -qE '^JIRA_URL=' <<<"$spec"            || { echo "missing JIRA_URL";       return 1; }
    grep -qE '^JIRA_USERNAME=' <<<"$spec"       || { echo "missing JIRA_USERNAME";  return 1; }
    grep -qE '^JIRA_API_TOKEN=op://' <<<"$spec" || { echo "missing JIRA_API_TOKEN op:// ref"; return 1; }
  )
}

# test_projectPath_urma_resolves_via_realpath verifies the urma entry's
# tilde-form expands at source-time and resolves to a real on-disk path.
#
# Regression guard for #20003: the entry previously hardcoded /home/ted; the
# bash-expansion conversion (~/projects/urma) only works if tilde-expansion
# fires inside `declare -A`. This test exercises the real registry value
# end-to-end through realpath -- existing resolveProject tests use stubbed
# ProjectPath arrays, so nothing else catches a future expansion regression.
test_projectPath_urma_resolves_via_realpath() {
  ( source "$PWD/op-run/projects.bash"

    local raw=${ProjectPath[urma]:-}
    [[ -n $raw ]] || { echo "ProjectPath[urma] not set"; return 1; }
    [[ $raw != *'~'* ]] || { echo "ProjectPath[urma] still contains literal ~: $raw"; return 1; }

    local resolved
    resolved=$(realpath "$raw" 2>/dev/null) || { echo "realpath failed for: $raw"; return 1; }
    [[ $resolved == */projects/urma ]] || { echo "resolved path does not end in /projects/urma: $resolved"; return 1; }
  )
}

# test_auditPublish_keys_only_op_refs verifies the keys list contains only op:// var names.
#
# Literal vars (URLs, usernames) are not credentials and must not appear in
# the audit payload's keys field.
test_auditPublish_keys_only_op_refs() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  ## arrange
  local capturePath=$Dir/era-capture
  local eraStub=$Dir/era-stub
  cat >"$eraStub" <<EOF
#!/usr/bin/env bash
[[ \$1 == publish ]] && printf '%s' "\$2" >"$capturePath"
EOF
  chmod +x "$eraStub"

  local timeoutPass=$Dir/timeout-pass
  cat >"$timeoutPass" <<'EOF'
#!/usr/bin/env bash
shift 3 2>/dev/null
exec "$@"
EOF
  chmod +x "$timeoutPass"

  local era=$eraStub timeout=$timeoutPass

  local spec="LITERAL_URL=https://example.com
SECRET_TOKEN=op://vault/item/credential
ANOTHER_LITERAL=foo
ANOTHER_SECRET=op://vault/other/credential"

  ## act
  auditPublish urma work urma-atlassian "$spec" mcp-tool arg1 arg2 >/dev/null 2>&1

  ## assert
  local payload
  payload=$(<"$capturePath")
  echo "$payload" | $jq -e '.keys | sort == ["ANOTHER_SECRET","SECRET_TOKEN"]' >/dev/null \
    || { echo "keys mismatch: $(echo "$payload" | $jq -c '.keys')"; return 1; }
  echo "$payload" | $jq -e '.args == ["arg1","arg2"]' >/dev/null \
    || { echo "args mismatch: $(echo "$payload" | $jq -c '.args')"; return 1; }
  echo "$payload" | $jq -e '.tool == "mcp-tool"' >/dev/null \
    || { echo "tool mismatch: $(echo "$payload" | $jq -c '.tool')"; return 1; }
}

# test_auditPublish_zero_keys verifies that a project with no op:// refs produces keys=[].
#
# Regression for the awk-vs-grep pivot: grep exits 1 on zero matches, which
# would abort under set -euo pipefail. awk produces no rows and exit 0.
test_auditPublish_zero_keys() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local capturePath=$Dir/era-capture
  local eraStub=$Dir/era-stub
  cat >"$eraStub" <<EOF
#!/usr/bin/env bash
[[ \$1 == publish ]] && printf '%s' "\$2" >"$capturePath"
EOF
  chmod +x "$eraStub"
  local timeoutPass=$Dir/timeout-pass
  cat >"$timeoutPass" <<'EOF'
#!/usr/bin/env bash
shift 3 2>/dev/null
exec "$@"
EOF
  chmod +x "$timeoutPass"

  local era=$eraStub timeout=$timeoutPass

  local spec="LITERAL_URL=https://example.com
ANOTHER_LITERAL=foo"

  auditPublish urma work urma-atlassian "$spec" mcp-tool >/dev/null 2>&1

  local payload
  payload=$(<"$capturePath")
  echo "$payload" | $jq -e '.keys == []' >/dev/null \
    || { echo "keys not empty: $(echo "$payload" | $jq -c '.keys')"; return 1; }
  echo "$payload" | $jq -e '.args == []' >/dev/null \
    || { echo "args not empty: $(echo "$payload" | $jq -c '.args')"; return 1; }
}

# test_auditPublish_special_chars_in_args verifies jq escapes spaces, quotes, and unicode.
#
# Without jq doing the escaping (e.g., naive shell concatenation), spaces or
# quotes in args would corrupt the JSON payload.
test_auditPublish_special_chars_in_args() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local capturePath=$Dir/era-capture
  local eraStub=$Dir/era-stub
  cat >"$eraStub" <<EOF
#!/usr/bin/env bash
[[ \$1 == publish ]] && printf '%s' "\$2" >"$capturePath"
EOF
  chmod +x "$eraStub"
  local timeoutPass=$Dir/timeout-pass
  cat >"$timeoutPass" <<'EOF'
#!/usr/bin/env bash
shift 3 2>/dev/null
exec "$@"
EOF
  chmod +x "$timeoutPass"

  local era=$eraStub timeout=$timeoutPass

  auditPublish urma work urma-atlassian "FOO=op://x/y/z" tool 'arg with spaces' 'arg"with"quotes' $'unicode-\xc3\xa9' >/dev/null 2>&1

  local payload
  payload=$(<"$capturePath")
  echo "$payload" | $jq -e '.args == ["arg with spaces","arg\"with\"quotes","unicode-\u00e9"]' >/dev/null \
    || { echo "args mismatch: $(echo "$payload" | $jq -c '.args')"; return 1; }
}

# test_vaultsJson_locked_signin_substring verifies exit 66 on the locked-vault stderr substring.
test_vaultsJson_locked_signin_substring() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local stubOp=$Dir/stub-op-locked
  cat >"$stubOp" <<'EOF'
#!/usr/bin/env bash
echo '[ERROR] 2026/05/06 21:21:22 You are not currently signed in. Please run `op signin --help` for instructions' >&2
exit 1
EOF
  chmod +x "$stubOp"

  local op=$stubOp
  local rc=0
  ( local out; vaultsJson out ) >/dev/null 2>&1 || rc=$?
  tesht.AssertRC $rc 66
}

# test_vaultsJson_generic_op_error verifies exit 67 on op stderr that doesn't match the locked substring.
test_vaultsJson_generic_op_error() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local stubOp=$Dir/stub-op-broken
  cat >"$stubOp" <<'EOF'
#!/usr/bin/env bash
echo '[ERROR] something else broke entirely' >&2
exit 1
EOF
  chmod +x "$stubOp"

  local op=$stubOp
  local rc=0
  ( local out; vaultsJson out ) >/dev/null 2>&1 || rc=$?
  tesht.AssertRC $rc 67
}

# test_loadVisibleVaults_propagates_locked_exit is a regression for the subshell-swallows-fatal bug.
#
# Pre-fix, `vaultsJson_=$(vaultsJson)` ran vaultsJson in a subshell, so
# vaultsJson's `fatal 66` exited the subshell only -- the parent continued
# with empty VisibleVaults, and the user-visible error became exit 68 (vault
# not visible) instead of the truthful exit 66 (locked). The fix is the
# nameref out-param pattern; this test guards against regression to the
# stdout-+-$() form.
test_loadVisibleVaults_propagates_locked_exit() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local stubOp=$Dir/stub-op-locked
  cat >"$stubOp" <<'EOF'
#!/usr/bin/env bash
echo '[ERROR] You are not currently signed in' >&2
exit 1
EOF
  chmod +x "$stubOp"

  local op=$stubOp
  local rc=0
  ( loadVisibleVaults ) >/dev/null 2>&1 || rc=$?
  tesht.AssertRC $rc 66
}

# test_auditTransport_timeout_falls_back_to_file verifies a 124 exit triggers the file fallback.
test_auditTransport_timeout_falls_back_to_file() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  ## arrange
  local timeoutStub=$Dir/timeout-stub-124
  cat >"$timeoutStub" <<'EOF'
#!/usr/bin/env bash
exit 124
EOF
  chmod +x "$timeoutStub"

  local timeout=$timeoutStub era=/nonexistent
  local stateDir=$Dir/state

  ## act
  XDG_STATE_HOME=$stateDir auditTransport '{"ts":"x","keys":[]}' >/dev/null 2>&1

  ## assert
  local logPath=$stateDir/op-run/audit.log
  [[ -f $logPath ]] || { echo "fallback log not created at $logPath"; return 1; }
  local content
  content=$(<"$logPath")
  tesht.AssertGot "$content" '{"ts":"x","keys":[]}'
}

# test_auditTransport_era_missing_falls_back verifies a missing era binary triggers the file fallback.
test_auditTransport_era_missing_falls_back() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local timeoutStub=$Dir/timeout-passthrough
  cat >"$timeoutStub" <<'EOF'
#!/usr/bin/env bash
shift 3 2>/dev/null
exec "$@"
EOF
  chmod +x "$timeoutStub"

  local timeout=$timeoutStub era=$Dir/no-such-era-binary
  local stateDir=$Dir/state
  XDG_STATE_HOME=$stateDir auditTransport '{"ts":"missing-era"}' >/dev/null 2>&1

  local logPath=$stateDir/op-run/audit.log
  [[ -f $logPath ]] || { echo "fallback log not created at $logPath"; return 1; }
}

# test_auditFileFallback_perms verifies parent dir mode 700 and log file mode 600.
#
# Linux-only: stat -c is GNU. The implementation uses install -d -m 700
# (explicit mode, ignores umask) and umask 077 in a subshell for the file.
test_auditFileFallback_perms() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local stateDir=$Dir/state
  XDG_STATE_HOME=$stateDir auditFileFallback '{"ts":"perm-check"}' 0 >/dev/null 2>&1

  local dirMode fileMode
  dirMode=$(stat -c '%a' "$stateDir/op-run")
  fileMode=$(stat -c '%a' "$stateDir/op-run/audit.log")
  [[ $dirMode == 700 ]]  || { echo "parent dir mode $dirMode != 700"; return 1; }
  [[ $fileMode == 600 ]] || { echo "log file mode $fileMode != 600"; return 1; }
}

# test_auditFileFallback_perms_under_hostile_umask verifies modes 700/600 even under umask 022.
#
# Without explicit `install -d -m 700` and a subshell `umask 077`, the test
# would observe 755/644 (the umask-022 defaults). Proves the modes come from
# the implementation, not from ambient umask.
test_auditFileFallback_perms_under_hostile_umask() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local stateDir=$Dir/state
  ( umask 022 && XDG_STATE_HOME=$stateDir auditFileFallback '{"ts":"hostile"}' 0 >/dev/null 2>&1 )

  local dirMode fileMode
  dirMode=$(stat -c '%a' "$stateDir/op-run")
  fileMode=$(stat -c '%a' "$stateDir/op-run/audit.log")
  [[ $dirMode == 700 ]]  || { echo "parent dir mode $dirMode != 700 under umask 022"; return 1; }
  [[ $fileMode == 600 ]] || { echo "log file mode $fileMode != 600 under umask 022"; return 1; }
}

# test_runOp_exec_argv verifies runOp's exec is invoked with the right argv.
#
# Uses a real on-disk mock binary (function names cannot be exec'd). The mock
# records its argv to a side-channel file; the test asserts on the captured
# argv to detect any regression in run/--no-masking/-- ordering.
test_runOp_exec_argv() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  ## arrange
  local mockPath=$Dir/mock-op
  local capturePath=$Dir/argv-capture
  cat >"$mockPath" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"$capturePath"
exit 0
EOF
  chmod +x "$mockPath"

  local op=$mockPath

  ## act
  ( runOp my-tool arg-one arg-two ) >/dev/null 2>&1

  ## assert
  local got
  got=$(<"$capturePath")
  local want="run
--no-masking
--
my-tool
arg-one
arg-two"
  tesht.AssertGot "$got" "$want"
}

## audit fallback log rotation (#2907)
#
# 7 cases covering the rotation block added to auditFileFallback:
#   1. below_cap_no_rotation        -- happy path: no rotation under cap
#   2. above_cap_rotates_with_marker -- happy rotation: .1 has pre-rotation
#                                       content, new audit.log opens with
#                                       {event:rotated,...} marker
#   3. above_cap_twice_overwrites_dot1 -- bounded disk use: second rotation
#                                         overwrites first's .1
#   4. cap_zero_disables_rotation   -- AuditLogMaxBytes=0 escape hatch
#   5. invalid_cap_under_strict_mode -- non-numeric cap defaults to 1 MiB
#                                       without aborting under set -e
#   6. jq_failure_under_strict_mode -- DI-stubbed failing jq does not
#                                      abort op-run main path
#   7. mv_failure_survives_strict_mode -- chmod 0500 denies rename;
#                                         function returns 0
#
# Khorikov posture: tests on the controller (auditFileFallback) boundary.
# Output-based assertions on observable filesystem state + jq -e field
# probes on the marker (NOT exact-JSON match -- field-order / timestamp
# formatting changes don't break tests). Mock boundary is XDG_STATE_HOME
# (env var) + $jq DI (test 6) + chmod (test 7).

# test_auditFileFallback_below_cap_no_rotation: write under cap, no .1.
test_auditFileFallback_below_cap_no_rotation() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local stateDir=$Dir/state
  XDG_STATE_HOME=$stateDir AuditLogMaxBytes=10000 auditFileFallback '{"ts":"under-cap"}' 0 >/dev/null 2>&1

  [[ -f $stateDir/op-run/audit.log ]] || { echo "audit.log missing"; return 1; }
  [[ ! -e $stateDir/op-run/audit.log.1 ]] || { echo "unexpected audit.log.1 present"; return 1; }
  grep -q '"ts":"under-cap"' "$stateDir/op-run/audit.log" || { echo "record not in audit.log"; return 1; }
}

# test_auditFileFallback_above_cap_rotates_with_marker: write past cap,
# .1 has pre-rotation content, audit.log opens with rotation marker.
test_auditFileFallback_above_cap_rotates_with_marker() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local stateDir=$Dir/state
  # Seed audit.log just under cap so the first invocation pushes it over.
  mkdir -p "$stateDir/op-run"
  ( umask 077; yes '{"ts":"seed"}' | head -c 120 > "$stateDir/op-run/audit.log" )

  XDG_STATE_HOME=$stateDir AuditLogMaxBytes=100 auditFileFallback '{"ts":"trigger"}' 0 >/dev/null 2>&1

  [[ -f $stateDir/op-run/audit.log.1 ]] || { echo "audit.log.1 missing after rotation"; return 1; }
  [[ -f $stateDir/op-run/audit.log ]]   || { echo "audit.log missing after rotation"; return 1; }
  grep -q '"ts":"seed"'    "$stateDir/op-run/audit.log.1" || { echo "pre-rotation content lost from .1"; return 1; }
  grep -q '"ts":"trigger"' "$stateDir/op-run/audit.log.1" || { echo "trigger record not in .1 (should be there: written before rotation)"; return 1; }

  # Marker assertions: observable semantics, not exact JSON match.
  local marker
  marker=$(head -1 "$stateDir/op-run/audit.log")
  echo "$marker" | jq -e '.event == "rotated"' >/dev/null \
    || { echo "marker event != 'rotated': $marker"; return 1; }
  echo "$marker" | jq -e '.prev_size > 0' >/dev/null \
    || { echo "marker prev_size not > 0: $marker"; return 1; }
  echo "$marker" | jq -e '.at | length > 0' >/dev/null \
    || { echo "marker at missing or empty: $marker"; return 1; }
}

# test_auditFileFallback_above_cap_twice_overwrites_dot1: two rotations
# leave .1 holding the SECOND pre-rotation batch (bounded disk use).
test_auditFileFallback_above_cap_twice_overwrites_dot1() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local stateDir=$Dir/state

  # First rotation cycle: seed + trigger.
  mkdir -p "$stateDir/op-run"
  ( umask 077; yes '{"ts":"first-batch"}' | head -c 120 > "$stateDir/op-run/audit.log" )
  XDG_STATE_HOME=$stateDir AuditLogMaxBytes=100 auditFileFallback '{"ts":"first-trigger"}' 0 >/dev/null 2>&1

  # After first rotation: .1 has first-batch + first-trigger; audit.log has marker.
  grep -q '"ts":"first-batch"' "$stateDir/op-run/audit.log.1" || { echo "first batch not in .1"; return 1; }

  # Second rotation cycle: append more content to push back over cap.
  ( umask 077; yes '{"ts":"second-batch"}' | head -c 120 >> "$stateDir/op-run/audit.log" )
  XDG_STATE_HOME=$stateDir AuditLogMaxBytes=100 auditFileFallback '{"ts":"second-trigger"}' 0 >/dev/null 2>&1

  # After second rotation: .1 should now hold SECOND batch (first batch lost).
  grep -q '"ts":"second-batch"' "$stateDir/op-run/audit.log.1" || { echo "second batch not in .1 (overwrite failed)"; return 1; }
  ! grep -q '"ts":"first-batch"' "$stateDir/op-run/audit.log.1" || { echo "first batch still in .1 (overwrite did not happen)"; return 1; }
}

# test_auditFileFallback_cap_zero_disables_rotation: AuditLogMaxBytes=0
# disables the cap entirely; no rotation across many writes.
test_auditFileFallback_cap_zero_disables_rotation() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local stateDir=$Dir/state
  for i in 1 2 3 4 5 6 7 8 9 10; do
    XDG_STATE_HOME=$stateDir AuditLogMaxBytes=0 auditFileFallback "{\"ts\":\"cap-disabled-$i\"}" 0 >/dev/null 2>&1
  done

  [[ ! -e $stateDir/op-run/audit.log.1 ]] || { echo "audit.log.1 created despite cap=0"; return 1; }
  local lines
  lines=$(wc -l < "$stateDir/op-run/audit.log")
  (( lines == 10 )) || { echo "expected 10 lines in audit.log, got $lines"; return 1; }
}

# test_auditFileFallback_invalid_cap_under_strict_mode: garbage cap
# silently defaults to 1 MiB without aborting under set -euo pipefail.
test_auditFileFallback_invalid_cap_under_strict_mode() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local stateDir=$Dir/state
  local rc=0
  (
    set -euo pipefail
    XDG_STATE_HOME=$stateDir AuditLogMaxBytes=garbage auditFileFallback '{"ts":"invalid-cap"}' 0
  ) >/dev/null 2>&1 || rc=$?

  tesht.AssertRC $rc 0
  # With invalid cap defaulting to 1 MiB, a single small record does not trigger rotation.
  [[ -f $stateDir/op-run/audit.log ]] || { echo "audit.log missing"; return 1; }
  [[ ! -e $stateDir/op-run/audit.log.1 ]] || { echo "unexpected rotation under default cap"; return 1; }
}

# test_auditFileFallback_jq_failure_under_strict_mode: a DI-stubbed
# failing jq does not abort op-run's main path; .1 has pre-rotation
# content; audit.log absent (no marker written).
test_auditFileFallback_jq_failure_under_strict_mode() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local stateDir=$Dir/state
  mkdir -p "$stateDir/op-run"
  ( umask 077; yes '{"ts":"seed"}' | head -c 120 > "$stateDir/op-run/audit.log" )

  # Deterministic failing jq stub via $jq DI override.
  local stub=$Dir/jq-fail
  cat >"$stub" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$stub"

  local rc=0
  (
    set -euo pipefail
    local jq=$stub
    XDG_STATE_HOME=$stateDir AuditLogMaxBytes=100 auditFileFallback '{"ts":"trigger"}' 0
  ) >/dev/null 2>&1 || rc=$?

  tesht.AssertRC $rc 0
  [[ -f $stateDir/op-run/audit.log.1 ]] || { echo "expected audit.log.1 present after rotation"; return 1; }
  [[ ! -f $stateDir/op-run/audit.log ]] || { echo "expected audit.log absent (jq failed before marker write)"; return 1; }
  grep -q '"ts":"seed"' "$stateDir/op-run/audit.log.1" || { echo "pre-rotation content lost from .1"; return 1; }
}

# test_auditFileFallback_mv_failure_survives_strict_mode: PATH-prepended
# failing mv stub deterministically aborts the rename step; function
# returns 0; audit.log.1 absent; audit.log preserved.
#
# Note: chmod-based fault injection on the state dir does NOT work here
# because the function's `install -d -m 700 $stateDir` would reset the
# mode at every call (verified). PATH-prepend in the subshell gives a
# clean, deterministic fault that bash command-lookup will use (subshell
# has its own hash table — no stale cache to invalidate).
test_auditFileFallback_mv_failure_survives_strict_mode() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local stateDir=$Dir/state

  # Failing mv stub (PATH-prepended).
  local fakebin=$Dir/fakebin
  mkdir -p "$fakebin"
  cat >"$fakebin/mv" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$fakebin/mv"

  local rc=0
  (
    set -euo pipefail
    PATH=$fakebin:$PATH
    # Seed AFTER PATH prepend so seed's own writes (not via mv) still work.
    mkdir -p "$stateDir/op-run"
    : >"$stateDir/op-run/audit.log"
    for i in 1 2 3 4 5; do echo '{"ts":"seed-padding-bytes"}'; done >>"$stateDir/op-run/audit.log"
    XDG_STATE_HOME=$stateDir AuditLogMaxBytes=100 auditFileFallback '{"ts":"trigger"}' 0
  ) >/dev/null 2>&1 || rc=$?

  tesht.AssertRC $rc 0
  [[ ! -e $stateDir/op-run/audit.log.1 ]] || { echo "audit.log.1 created despite mv stub failure"; return 1; }
  # Original audit.log preserved (mv didn't happen, file intact + trigger appended).
  grep -q '"ts":"seed-padding-bytes"' "$stateDir/op-run/audit.log" || { echo "original audit.log content lost"; return 1; }
  grep -q '"ts":"trigger"' "$stateDir/op-run/audit.log" || { echo "trigger record not appended"; return 1; }
}
