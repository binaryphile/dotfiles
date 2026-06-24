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
  # Z-suffixed UTC ISO-8601 matches production claude-code transcript format.
  # Tests that need an explicit timestamp pass arg 4 in the same shape.
  local id=$1 input=$2 output=$3
  local ts=${4:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}
  local cacheRead=${5:-0} cacheCreation=${6:-0}
  printf '{"timestamp":"%s","message":{"id":"%s","usage":{"input_tokens":%d,"output_tokens":%d,"cache_read_input_tokens":%d,"cache_creation_input_tokens":%d}}}' \
    "$ts" "$id" "$input" "$output" "$cacheRead" "$cacheCreation"
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
  day=$(date -d '3 hours ago' +%Y-%m-%d)
  local got
  got=$(cat "$StateDir/sessions/${day}-mysession.tokens")
  # Weighted (input 1x + output 5x): msg1 = 100 + 250 = 350; msg2 = 200 + 400 = 600.
  # Total = 950; msg1 deduplicated.
  tesht.AssertGot "$got" "950"
}

test_StopWeightsCacheTokens() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir

  local transcript="$dir/session.jsonl"
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  # input=10 output=5 cache_read=10000 cache_creation=1000
  # Weighted: 10*1 + 5*5 + 10000*0.1 + 1000*1.25 = 10 + 25 + 1000 + 1250 = 2285
  # Trailing sentinel absorbs the script's head -n -1 truncation.
  makeTranscript "$transcript" \
    "$(makeMsg m1 10 5 "$now" 10000 1000)" \
    "$(makeMsg tail 0 0 "$now")"

  runStop "sess" "$transcript"

  local day
  day=$(date -d '3 hours ago' +%Y-%m-%d)
  local got
  got=$(cat "$StateDir/sessions/${day}-sess.tokens")
  tesht.AssertGot "$got" "2285"
}

test_StopFiltersMessagesBeforeBudgetDayCutoff() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir

  local transcript="$dir/session.jsonl"
  local twoDaysAgo now
  twoDaysAgo=$(date -u -d '2 days ago' +%Y-%m-%dT%H:%M:%SZ)
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  # Old message (excluded) + new message (included). Trailing sentinel
  # absorbs the head -n -1 truncation (the script's defense against
  # partially-flushed transcript tail lines).
  makeTranscript "$transcript" \
    "$(makeMsg old 1000 500 "$twoDaysAgo")" \
    "$(makeMsg new 100 50 "$now")" \
    "$(makeMsg tail 0 0 "$now")"

  runStop "sess" "$transcript"

  local day
  day=$(date -d '3 hours ago' +%Y-%m-%d)
  local got
  got=$(cat "$StateDir/sessions/${day}-sess.tokens")
  # Only "new" counted: 100*1 + 50*5 = 350.
  tesht.AssertGot "$got" "350"
}

test_StopSplitsAtSleepGapKeepsPostGapOnly() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir

  local transcript="$dir/session.jsonl"
  local preGap postGap now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  postGap=$(date -u -d '2 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
  preGap=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
  # pre (input 100 + output 50): weighted 350 -- last night's tail
  # post (input 200 + output 80): weighted 600 -- this morning's wake
  # Gap = 28 min between pre and post; with threshold=5min, splits at the gap.
  # Only "post" survives.
  makeTranscript "$transcript" \
    "$(makeMsg pre 100 50 "$preGap")" \
    "$(makeMsg post 200 80 "$postGap")" \
    "$(makeMsg tail 0 0 "$now")"

  export CLAUDE_BUDGET_SLEEP_GAP_MIN=5
  runStop "sess" "$transcript"

  local day
  day=$(date -d '3 hours ago' +%Y-%m-%d)
  local got
  got=$(cat "$StateDir/sessions/${day}-sess.tokens")
  tesht.AssertGot "$got" "600"
}

test_StopKeepsAllMessagesWhenNoSleepGap() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir

  local transcript="$dir/session.jsonl"
  local ts1 ts2 now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  ts2=$(date -u -d '2 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
  ts1=$(date -u -d '4 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
  # Two messages 2 minutes apart; threshold 5min => no split.
  # m1 weighted 350, m2 weighted 600 -- both counted.
  makeTranscript "$transcript" \
    "$(makeMsg m1 100 50 "$ts1")" \
    "$(makeMsg m2 200 80 "$ts2")" \
    "$(makeMsg tail 0 0 "$now")"

  export CLAUDE_BUDGET_SLEEP_GAP_MIN=5
  runStop "sess" "$transcript"

  local day
  day=$(date -d '3 hours ago' +%Y-%m-%d)
  local got
  got=$(cat "$StateDir/sessions/${day}-sess.tokens")
  tesht.AssertGot "$got" "950"
}

test_StopUsesLastSleepGapWhenMultiple() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir

  local transcript="$dir/session.jsonl"
  local t1 t2 t3 now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  t3=$(date -u -d '2 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
  t2=$(date -u -d '20 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
  t1=$(date -u -d '40 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
  # Three clusters separated by 18min + 18min gaps; threshold=5min.
  # Two gaps qualify; last gap is between t2 and t3.
  # Only t3 + tail kept. t3 weighted = 300*1 + 100*5 = 800. tail=0.
  makeTranscript "$transcript" \
    "$(makeMsg m1 100 50 "$t1")" \
    "$(makeMsg m2 200 80 "$t2")" \
    "$(makeMsg m3 300 100 "$t3")" \
    "$(makeMsg tail 0 0 "$now")"

  export CLAUDE_BUDGET_SLEEP_GAP_MIN=5
  runStop "sess" "$transcript"

  local day
  day=$(date -d '3 hours ago' +%Y-%m-%d)
  local got
  got=$(cat "$StateDir/sessions/${day}-sess.tokens")
  tesht.AssertGot "$got" "800"
}

test_StopDuplicateMsgIdAcrossSleepGap() {
  # When the same msg_id appears both pre-gap and post-gap (re-emitted across
  # a session resume / retry), the pre-gap copy is dropped by the slice and
  # only the post-gap copy survives unique_by. This is the intended ordering
  # — unique_by(.id) AFTER [cut:] preserves today's accounting.
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir

  local transcript="$dir/session.jsonl"
  local preGap postGap now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  postGap=$(date -u -d '2 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
  preGap=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
  # Same msg_id 'X' pre-gap (huge usage) and post-gap (small usage).
  # Gap = 28 min; threshold=5min splits. Pre-gap X dropped by slice.
  # Post-gap X counted: 50*1 + 25*5 = 175.
  makeTranscript "$transcript" \
    "$(makeMsg X 1000 500 "$preGap")" \
    "$(makeMsg X 50 25 "$postGap")" \
    "$(makeMsg tail 0 0 "$now")"

  export CLAUDE_BUDGET_SLEEP_GAP_MIN=5
  runStop "sess" "$transcript"

  local day
  day=$(date -d '3 hours ago' +%Y-%m-%d)
  local got
  got=$(cat "$StateDir/sessions/${day}-sess.tokens")
  tesht.AssertGot "$got" "175"
}

test_StopSleepGapAtExactThresholdQualifies() {
  # Edge case: a gap EXACTLY equal to the threshold should qualify (the
  # comparison is `>=`, not `>`). Operator may set the threshold to a
  # round number expecting boundary inclusion.
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir

  local transcript="$dir/session.jsonl"
  local preGap postGap now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  postGap=$(date -u -d '1 minute ago' +%Y-%m-%dT%H:%M:%SZ)
  # Gap = exactly 5 minutes. With threshold=5, the gap qualifies via `>=`.
  preGap=$(date -u -d '6 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
  # pre (1000 + 500) dropped; post (200 + 80 -> 600) survives.
  makeTranscript "$transcript" \
    "$(makeMsg pre 1000 500 "$preGap")" \
    "$(makeMsg post 200 80 "$postGap")" \
    "$(makeMsg tail 0 0 "$now")"

  export CLAUDE_BUDGET_SLEEP_GAP_MIN=5
  runStop "sess" "$transcript"

  local day
  day=$(date -d '3 hours ago' +%Y-%m-%d)
  local got
  got=$(cat "$StateDir/sessions/${day}-sess.tokens")
  tesht.AssertGot "$got" "600"
}

test_StopDayStartHourEnvOverride() {
  # Operator-policy: CLAUDE_BUDGET_DAY_START_HOUR shifts the day-start cutoff
  # away from the default 03:00. With override=0 (midnight), a message timestamped
  # in the post-midnight pre-3am window is INCLUDED (it would have been excluded
  # under the 03:00 default if the test ran in a window straddling the boundary).
  # Simpler proof: override=0 + a message at today's epoch start (anywhere after
  # midnight local) ought to be counted, and the day-key reflects the override.
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir

  local transcript="$dir/session.jsonl"
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  makeTranscript "$transcript" \
    "$(makeMsg m1 100 50 "$now")" \
    "$(makeMsg tail 0 0 "$now")"

  # With override=0, day-key = `date -d '0 hours ago'` = local date right now.
  export CLAUDE_BUDGET_DAY_START_HOUR=0
  runStop "sess" "$transcript"

  local day
  day=$(date -d '0 hours ago' +%Y-%m-%d)
  local got
  got=$(cat "$StateDir/sessions/${day}-sess.tokens")
  # m1 only (input 100 + output 50, weighted 350). Tail is 0.
  tesht.AssertGot "$got" "350"
}

test_StopSleepGapThresholdEnvOverride() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir

  local transcript="$dir/session.jsonl"
  local preGap postGap now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  postGap=$(date -u -d '2 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
  preGap=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
  # 28-min gap. With default threshold (120min) gap doesn't qualify -> keep all.
  # m1 weighted 350, m2 weighted 600, tail 0 -> total 950.
  makeTranscript "$transcript" \
    "$(makeMsg pre 100 50 "$preGap")" \
    "$(makeMsg post 200 80 "$postGap")" \
    "$(makeMsg tail 0 0 "$now")"

  # Explicitly unset the threshold env var so default applies.
  unset CLAUDE_BUDGET_SLEEP_GAP_MIN
  runStop "sess" "$transcript"

  local day
  day=$(date -d '3 hours ago' +%Y-%m-%d)
  local got
  got=$(cat "$StateDir/sessions/${day}-sess.tokens")
  tesht.AssertGot "$got" "950"
}

test_StopSkipsMessagesWithoutTimestamp() {
  # Older transcript versions (or malformed entries) lacking .timestamp
  # are excluded entirely rather than silently counted under today.
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir

  local transcript="$dir/session.jsonl"
  printf '%s\n' '{"message":{"id":"notime","usage":{"input_tokens":100,"output_tokens":50}}}' >> "$transcript"

  runStop "sess" "$transcript"

  local day
  day=$(date -d '3 hours ago' +%Y-%m-%d)
  tesht.AssertRC "$(ls "$StateDir/sessions/${day}-sess.tokens" 2>/dev/null; echo $?)" "2"
}

test_StopSkipsMissingTranscript() {
  tesht.MktempDir StateDir

  runStop "mysession" "/nonexistent/path.jsonl"

  local day
  day=$(date -d '3 hours ago' +%Y-%m-%d)
  tesht.AssertRC "$(ls "$StateDir/sessions/${day}-mysession.tokens" 2>/dev/null; echo $?)" "2"
}

test_StopSkipsMalformedJSONL() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir

  local transcript="$dir/session.jsonl"
  # Only one line: a truncated/malformed entry. head -n -1 strips it -> 0 tokens -> no file.
  printf '{"message":{"id":"m1","usage":{"input_tokens":100' > "$transcript"

  runStop "mysession" "$transcript"

  local day
  day=$(date -d '3 hours ago' +%Y-%m-%d)
  tesht.AssertRC "$(ls "$StateDir/sessions/${day}-mysession.tokens" 2>/dev/null; echo $?)" "2"
}

test_SessionStartWarnsAt25Pct() {
  tesht.MktempDir StateDir
  local dir; tesht.MktempDir dir
  ConfigFile="$dir/config.json"

  local day
  day=$(date -d '3 hours ago' +%Y-%m-%d)

  # 760k used of 1000k -> 24% remaining -> crosses 25% threshold -> 25%-action text fires
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
  day=$(date -d '3 hours ago' +%Y-%m-%d)

  # 500k used of 1000k -> 50% remaining -> no threshold crossed
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
  day=$(date -d '3 hours ago' +%Y-%m-%d)

  # 910k of 1000k -> 9% remaining -> 25% already warned -> 10%-action fires
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
  day=$(date -d '3 hours ago' +%Y-%m-%d)

  # 960k of 1000k -> 4% remaining -> enforce_at_pct=5 -> block
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
  day=$(date -d '3 hours ago' +%Y-%m-%d)

  # 760k of 1000k -> 24% remaining -> both concurrent calls race to emit 25% warning
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

  local recent_file="$sessions_dir/$(date -d '3 hours ago' +%Y-%m-%d)-recent.tokens"
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
  day=$(date -d '3 hours ago' +%Y-%m-%d)

  # 3 sessions, 800k total -> 20% remaining -> crosses 25%
  writeConfig 1000000
  writeTokenFile "$day" "sessA" 300000
  writeTokenFile "$day" "sessB" 300000
  writeTokenFile "$day" "sessC" 200000

  local got
  got=$(runSessionStart)
  [[ $got == *"3 sessions today"* ]] || { echo "expected '3 sessions today' in: $got"; return 1; }
}
