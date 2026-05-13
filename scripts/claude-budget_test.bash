#!/usr/bin/env bash

Script=$HOME/dotfiles/scripts/claude-budget

sourceHelpers() {
  __CLAUDE_BUDGET_TESTING=1 source "$Script"
}

# --- helpers ---

makeTranscript() {
  local path=$1; shift
  # Each arg is a JSON object (one per line)
  local obj
  for obj; do
    printf '%s\n' "$obj" >> "$path"
  done
}

makeMsg() {
  local id=$1 input=$2 output=$3
  printf '{"message":{"id":"%s","usage":{"input_tokens":%d,"output_tokens":%d}}}' \
    "$id" "$input" "$output"
}

runStop() {
  local session_id=$1 transcript=$2
  printf '{"hook_event_name":"Stop","session_id":"%s","transcript_path":"%s","cwd":"/tmp"}' \
    "$session_id" "$transcript" \
    | CLAUDE_BUDGET_STATE="$StateDir" "$Script"
}

runSessionStart() {
  printf '{"hook_event_name":"SessionStart","session_id":"s","transcript_path":"/dev/null","cwd":"/tmp"}' \
    | CLAUDE_BUDGET_STATE="$StateDir" CLAUDE_BUDGET_CONFIG="$ConfigFile" "$Script"
}

runUserPromptSubmit() {
  local sid=${1:-s}
  printf '{"hook_event_name":"UserPromptSubmit","session_id":"%s","transcript_path":"/dev/null","cwd":"/tmp"}' \
    "$sid" \
    | CLAUDE_BUDGET_STATE="$StateDir" CLAUDE_BUDGET_CONFIG="$ConfigFile" "$Script"
}

runSessionEnd() {
  printf '{"hook_event_name":"SessionEnd","session_id":"s","transcript_path":"/dev/null","cwd":"/tmp"}' \
    | CLAUDE_BUDGET_STATE="$StateDir" "$Script"
}

writeConfig() {
  local daily=$1 enforce=${2:-0}
  printf '{"daily_tokens":%d,"enforce_at_pct":%d}\n' "$daily" "$enforce" > "$ConfigFile"
}

writeTokenFile() {
  local day=$1 session=$2 tokens=$3
  mkdir -p "$StateDir/sessions"
  printf '%d\n' "$tokens" > "$StateDir/sessions/${day}-${session}.tokens"
}

# --- tests ---

test_StopWritesSessionTokens() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir

  local transcript="$dir/session.jsonl"
  makeTranscript "$transcript" \
    "$(makeMsg msg1 100 50)" \
    "$(makeMsg msg2 200 80)" \
    "$(makeMsg msg1 100 50)"   # duplicate of msg1

  runStop "mysession" "$transcript"

  local day
  day=$(date -d '2 hours ago' +%Y-%m-%d)
  local got
  got=$(cat "$StateDir/sessions/${day}-mysession.tokens")
  tesht.AssertGot "$got" "430"   # 150 + 280, msg1 deduplicated
}

test_StopSkipsMissingTranscript() {
  tesht.MktempDir StateDir

  runStop "mysession" "/nonexistent/path.jsonl"

  local day
  day=$(date -d '2 hours ago' +%Y-%m-%d)
  tesht.AssertRC "$(ls "$StateDir/sessions/${day}-mysession.tokens" 2>/dev/null; echo $?)" "2"
}

test_StopSkipsMalformedJSONL() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir

  local transcript="$dir/session.jsonl"
  # Only one line: a truncated/malformed entry. head -n -1 strips it → 0 tokens → no file.
  printf '{"message":{"id":"m1","usage":{"input_tokens":100' > "$transcript"

  runStop "mysession" "$transcript"

  local day
  day=$(date -d '2 hours ago' +%Y-%m-%d)
  tesht.AssertRC "$(ls "$StateDir/sessions/${day}-mysession.tokens" 2>/dev/null; echo $?)" "2"
}

test_SessionStartWarnsAt25Pct() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir
  ConfigFile="$dir/config.json"

  local day
  day=$(date -d '2 hours ago' +%Y-%m-%d)

  # 760k used of 1000k → 24% remaining → crosses 25% threshold → 25%-action text fires
  writeConfig 1000000
  writeTokenFile "$day" "sess1" 500000
  writeTokenFile "$day" "sess2" 260000

  local got
  got=$(runSessionStart)

  [[ $got == *"Consider closing idle parallel sessions."* ]] || { echo "expected 25% action in: $got"; return 1; }
  [[ $got == *"2 sessions today"* ]] || { echo "expected '2 sessions today' in: $got"; return 1; }
}

test_SessionStartNoWarnUnderThreshold() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir
  ConfigFile="$dir/config.json"

  local day
  day=$(date -d '2 hours ago' +%Y-%m-%d)

  # 500k used of 1000k → 50% remaining → no threshold crossed
  writeConfig 1000000
  writeTokenFile "$day" "sess1" 500000

  local got
  got=$(runSessionStart)
  tesht.AssertGot "$got" ""
}

test_UserPromptSubmitWarnsOnNewThreshold() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir
  ConfigFile="$dir/config.json"

  local day
  day=$(date -d '2 hours ago' +%Y-%m-%d)

  # 910k of 1000k → 9% remaining → 25% already warned → 10%-action fires
  writeConfig 1000000
  writeTokenFile "$day" "sess1" 910000

  # Pre-mark 25% as already warned so 10% fires next
  mkdir -p "$StateDir/warned"
  printf '25\n' > "$StateDir/warned/${day}"

  local got1
  got1=$(runUserPromptSubmit)
  [[ $got1 == *"Close all but one session."* ]] || { echo "expected 10% action in first call: $got1"; return 1; }

  local got2
  got2=$(runUserPromptSubmit)
  tesht.AssertGot "$got2" ""
}

test_UserPromptSubmitBlocksAtEnforceThreshold() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir
  ConfigFile="$dir/config.json"

  local day
  day=$(date -d '2 hours ago' +%Y-%m-%d)

  # 960k of 1000k → 4% remaining → enforce_at_pct=5 → block
  writeConfig 1000000 5
  writeTokenFile "$day" "sess1" 960000

  local got
  got=$(runUserPromptSubmit)
  [[ $got == *'"decision":"block"'* ]] || { echo "expected block decision in: $got"; return 1; }
}

test_WarningFlockedNoDuplicate() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir
  ConfigFile="$dir/config.json"

  local day
  day=$(date -d '2 hours ago' +%Y-%m-%d)

  # 760k of 1000k → 24% remaining → both concurrent calls race to emit 25% warning
  writeConfig 1000000
  writeTokenFile "$day" "sess1" 760000

  # Race two UserPromptSubmit instances; flock ensures exactly one threshold written
  runUserPromptSubmit "s1" > /dev/null &
  runUserPromptSubmit "s2" > /dev/null &
  wait

  local warned_lines
  warned_lines=$(wc -l < "$StateDir/warned/${day}" 2>/dev/null || echo 0)
  # Exactly one threshold (25) should be recorded
  tesht.AssertGot "$warned_lines" "1"
}

test_SessionEndPrunesOldFiles() {
  tesht.MktempDir StateDir

  local sessions_dir="$StateDir/sessions"
  mkdir -p "$sessions_dir"

  local old_file="$sessions_dir/2020-01-01-old.tokens"
  printf '100\n' > "$old_file"
  touch -d '9 days ago' "$old_file"

  local recent_file="$sessions_dir/$(date -d '2 hours ago' +%Y-%m-%d)-recent.tokens"
  printf '200\n' > "$recent_file"

  runSessionEnd

  [[ ! -f $old_file ]] || { echo "old file still exists: $old_file"; return 1; }
  [[ -f $recent_file ]] || { echo "recent file was deleted: $recent_file"; return 1; }
}

test_MissingConfigIsNoop() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir
  ConfigFile="$dir/no-such-config.json"

  local got
  got=$(runSessionStart)
  tesht.AssertGot "$got" ""
}

test_UnknownEventIsNoop() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir
  ConfigFile="$dir/config.json"
  writeConfig 1000000

  local got
  got=$(printf '{"hook_event_name":"PreCompact","session_id":"s","cwd":"/tmp"}' \
    | CLAUDE_BUDGET_STATE="$StateDir" CLAUDE_BUDGET_CONFIG="$ConfigFile" "$Script")
  tesht.AssertGot "$got" ""
}

test_SessionStartWarnsWithSessionCount() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir
  ConfigFile="$dir/config.json"

  local day
  day=$(date -d '2 hours ago' +%Y-%m-%d)

  # 3 sessions, 800k total → 20% remaining → crosses 25%
  writeConfig 1000000
  writeTokenFile "$day" "sessA" 300000
  writeTokenFile "$day" "sessB" 300000
  writeTokenFile "$day" "sessC" 200000

  local got
  got=$(runSessionStart)
  [[ $got == *"3 sessions today"* ]] || { echo "expected '3 sessions today' in: $got"; return 1; }
}
