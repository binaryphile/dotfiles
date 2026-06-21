#!/usr/bin/env bash
# Tests for claude-agent-identity SessionStart hook.
#
# Khorikov-aligned (classical school): integration tests on the controller
# (the script's `main`), output-based assertions on captured CLAUDE_ENV_FILE
# contents + PATH-stubbed evtctl calls. Mock only at the inter-system
# boundary (evtctl POSTs to era-serve); hostname / role / USER are all
# internal helpers exercised through the public interface.

IFS=$'\n'
set -o noglob

# shellcheck disable=SC2128
Script=$(dirname $TESHT_TEST_FILE)/claude-agent-identity

# waitForAsync_ polls a file's existence for up to ~1s. The hook backgrounds
# the evtctl publish, so the test needs to wait for the captured args file
# to appear before asserting on its contents.
waitForAsync_() {
  local path_=$1 i
  for (( i = 0; i < 10; i++ )); do
    [[ -f "$path_" ]] && return 0
    sleep 0.1
  done
  return 1
}

# fixture sets up an isolated $HOME (under tesht.MktempDir) and a
# PATH-stubbed evtctl that captures payload to a file. Out-params via
# nameref: home (HOME root), stub (PATH stub dir), calls (capture file).
fixture() {
  local -n homeRef=$2 stubRef=$3 callsRef=$4
  local dir_=$1
  homeRef=$dir_/home
  stubRef=$dir_/stubs
  callsRef=$dir_/evtctl.calls
  mkdir -p $homeRef $stubRef $homeRef/.claude

  cat >$stubRef/evtctl <<EOF
#!/usr/bin/env bash
# Capture only the payload arg (\$2) for 'interaction' calls so tests assert
# directly on the /session-start string; fall back to full args otherwise.
if [[ \$1 == interaction ]]; then
  printf '%s\n' "\$2" >> $callsRef
else
  printf '%s\n' "\$*" >> $callsRef
fi
EOF
  chmod +x $stubRef/evtctl
}

# assertContains fails the test when haystack does not contain needle.
# Used in place of tesht.Softly's free-form heredoc since tesht.Log alone
# does not flip the test fail-flag.
assertContains() {
  local haystack_=$1 needle_=$2
  if [[ "$haystack_" != *"$needle_"* ]]; then
    tesht.Log "expected payload to contain '$needle_', got: $haystack_"
    return 1
  fi
}

# composeInput builds a SessionStart-shaped JSON string in the named var.
# Avoids the embedded-quote string-concat shape that SC2089/SC2090 warns on.
composeInput() {
  local -n outRef=$1
  local source_=${2-startup} sessionId_=${3-sid} model_=${4-sonnet} version_=${5-4.6} cwd_=${6-}
  printf -v outRef \
    '{"source":"%s","session_id":"%s","model":"%s","version":"%s","cwd":"%s"}' \
    "$source_" "$sessionId_" "$model_" "$version_" "$cwd_"
}

test_defaultIdentity_noRoleNoCrostini() {
  ## arrange
  local dir home stub calls envFile input
  local wantExport_ gotExport_ gotAgent_ host_
  tesht.MktempDir dir
  fixture $dir home stub calls
  envFile=$dir/env
  composeInput input startup sid-1 sonnet 4.6 $home

  ## act
  HOME=$home USER=testuser CLAUDE_ENV_FILE=$envFile PATH=$stub:$PATH \
    $Script <<<$input

  waitForAsync_ $calls || { tesht.Log 'evtctl was never invoked'; return 1; }

  ## assert
  host_=$(hostname)
  printf -v wantExport_ 'export EVTCTL_AGENT=%q' "testuser@$host_"
  gotExport_=$(< $envFile)
  tesht.AssertGot "$gotExport_" "$wantExport_"
  gotAgent_=$(grep -oE 'agent=testuser@[^ ]+' $calls | head -1)
  tesht.AssertGot "$gotAgent_" "agent=testuser@$host_"
}

test_roleMarker_present() {
  ## arrange
  local dir home stub calls envFile input
  local wantExport_ gotExport_ gotAgent_ host_
  tesht.MktempDir dir
  fixture $dir home stub calls
  envFile=$dir/env
  printf 'tandem\n' >$home/.claude/agent-role
  composeInput input startup sid-2 sonnet 4.6 $home

  ## act
  HOME=$home USER=testuser CLAUDE_ENV_FILE=$envFile PATH=$stub:$PATH \
    $Script <<<$input

  waitForAsync_ $calls || { tesht.Log 'evtctl was never invoked'; return 1; }

  ## assert
  host_=$(hostname)
  printf -v wantExport_ 'export EVTCTL_AGENT=%q' "claude-tandem@$host_"
  gotExport_=$(< $envFile)
  tesht.AssertGot "$gotExport_" "$wantExport_"
  gotAgent_=$(grep -oE 'agent=claude-tandem@[^ ]+' $calls | head -1)
  tesht.AssertGot "$gotAgent_" "agent=claude-tandem@$host_"
}

test_crostiniHostname_overridesSystem() {
  ## arrange
  local dir home stub calls envFile input wantExport_ gotExport_
  tesht.MktempDir dir
  fixture $dir home stub calls
  envFile=$dir/env
  mkdir -p $home/crostini
  printf 'mock-crostini-host\n' >$home/crostini/hostname
  composeInput input startup sid-3 sonnet 4.6 $home

  ## act
  HOME=$home USER=testuser CLAUDE_ENV_FILE=$envFile PATH=$stub:$PATH \
    $Script <<<$input

  waitForAsync_ $calls || { tesht.Log 'evtctl was never invoked'; return 1; }

  ## assert: identity uses ~/crostini/hostname, NOT $(hostname)
  printf -v wantExport_ 'export EVTCTL_AGENT=%q' 'testuser@mock-crostini-host'
  gotExport_=$(< $envFile)
  tesht.AssertGot "$gotExport_" "$wantExport_"
}

test_envFileUnset_silentExit() {
  ## arrange
  local dir home stub calls input agentCount_
  tesht.MktempDir dir
  fixture $dir home stub calls
  composeInput input startup sid-4 sonnet 4.6 $home

  ## act: NO CLAUDE_ENV_FILE in env
  local rc=0
  HOME=$home USER=testuser PATH=$stub:$PATH \
    env -u CLAUDE_ENV_FILE $Script <<<$input || rc=$?

  waitForAsync_ $calls || { tesht.Log 'evtctl was never invoked'; return 1; }

  ## assert: exited cleanly, evtctl still called (audit event still publishes)
  tesht.AssertRC $rc 0
  agentCount_=$(grep -c agent= $calls)
  tesht.AssertGot "$agentCount_" 1
}

test_eventPayload_carriesAllFields() {
  ## arrange
  local dir home stub calls envFile input payload_
  tesht.MktempDir dir
  fixture $dir home stub calls
  envFile=$dir/env
  composeInput input resume abc-123 opus 4.7 $home

  ## act
  HOME=$home USER=testuser CLAUDE_ENV_FILE=$envFile PATH=$stub:$PATH \
    $Script <<<$input

  waitForAsync_ $calls || { tesht.Log 'evtctl was never invoked'; return 1; }

  ## assert: every field from stdin lands in the /session-start payload
  payload_=$(< $calls)
  assertContains "$payload_" /session-start     || return 1
  assertContains "$payload_" source=resume      || return 1
  assertContains "$payload_" session_id=abc-123 || return 1
  assertContains "$payload_" model=opus         || return 1
  assertContains "$payload_" version=4.7        || return 1
  assertContains "$payload_" agent=testuser@    || return 1
  assertContains "$payload_" started_at=        || return 1
}

test_emptyStdin_defaultsToUnknown() {
  ## arrange
  local dir home stub calls envFile payload_
  tesht.MktempDir dir
  fixture $dir home stub calls
  envFile=$dir/env

  ## act: empty stdin
  HOME=$home USER=testuser CLAUDE_ENV_FILE=$envFile PATH=$stub:$PATH \
    $Script </dev/null

  waitForAsync_ $calls || { tesht.Log 'evtctl was never invoked'; return 1; }

  ## assert: agent still resolves (USER@host); other fields default to "unknown"
  payload_=$(< $calls)
  assertContains "$payload_" source=unknown     || return 1
  assertContains "$payload_" session_id=unknown || return 1
  assertContains "$payload_" agent=testuser@    || return 1
}
