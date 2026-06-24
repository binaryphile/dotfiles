# claude-budget

`claude-budget` warns you when your day's Claude Code token usage approaches a self-imposed limit. It exists for one situation: you're running parallel sessions on the Enterprise plan, the quota resets every two weeks, and there's no built-in way to see how close you are to exhausting it. By the time you notice, every session stops working at once. The tool hooks Claude Code's lifecycle events and warns you with enough lead time to wind down voluntarily.

## How it works

After each response, Claude Code writes the conversation to a JSONL file under `~/.claude/projects/`. The Stop hook reads that file, applies three filters, and records the per-session total to `~/.local/state/claude-budget/sessions/{day}-{session_id}.tokens`:

1. **Day-scope filter.** Only messages whose `.timestamp` falls within the current budget day (03:00 to 03:00 local) are counted. Without this filter, a long-lived session that spans multiple calendar days re-counts prior-day messages into today's bucket every time the Stop hook fires. Claude Code transcripts are append-only within a session — `/compact` or `/clear` may shrink them but the daily ledger should still represent today's work, not cumulative-since-session-start.

2. **Sleep-aware attribution.** Within today's filtered window, the hook walks messages in timestamp order and finds the most-recent idle gap of `CLAUDE_BUDGET_SLEEP_GAP_MIN` minutes (default 120). Messages BEFORE that gap are dropped — they belong to the prior day's work-block that ran past the day-start cutoff before the operator slept; the post-gap block is today's true operator-intent work. Sessions with no gap exceeding the threshold count entirely (single contiguous work-block). The day-start cutoff alone catches late-night tails as "today"; this second filter corrects that.

   The 120-minute default is **operator policy, not algorithmic truth**. The algorithm doesn't discover "sleep" — it discovers "most recent long idle gap." False positives (2.5h lunch break treated as a sleep boundary) and false negatives (90-min nap not counted as wake) both exist. Re-tune via env if your work patterns differ.

3. **Cache-aware weighted sum.** The per-message token formula is `input*1 + output*5 + cache_creation*1.25 + cache_read*0.1`, mapping to Anthropic's prompt-caching multipliers ([verified against the official pricing docs](https://platform.claude.com/docs/en/about-claude/pricing) 2026-06-24): cache_read = 0.1x base input, cache_creation_5m = 1.25x base input, cache_creation_1h = 2x base input. The `output*5` weight reflects the input-to-output ratio for the current Opus / Sonnet / Haiku generations (e.g. Opus 4.7: input $5/MTok, output $25/MTok). These multipliers are **universal across Claude models**; only the per-model BASE price varies. The weighted formula tracks model-agnostic input-equivalent units; re-tune `daily_tokens` cap to match your model's base input price ($5/MTok for Opus 4.7 → 1M weighted ≈ $5 of input-equivalent spend). The 1-hour cache tier (2x) isn't distinguished in this formula — both 5m and 1h cache_creation count at 1.25x, which under-counts 1h-cache-heavy workloads.

Messages without a `.timestamp` field are excluded entirely (older transcript versions or malformed entries).

The budget day resets at the hour set by `CLAUDE_BUDGET_DAY_START_HOUR` (default 3, i.e. 03:00 local). The 03:00 default is heuristic for "operator's working day has wound down by then"; late-night-burners can shift later (e.g. 04) and morning-people can pull it earlier (e.g. 00).

**Known accounting-loss modes**:

1. **Pre-rollover tail loss** (timestamp-filter exclusion). Pre-gap tokens are NOT retro-written to yesterday's file (already closed at the day-start rollover). If work continued AFTER yesterday's last Stop and BEFORE the day-start rollover, that work is lost — the timestamp-filter excludes anything before today's cutoff. Example with default `CLAUDE_BUDGET_DAY_START_HOUR=3`: 23:00 yesterday Stop → continuous work 23:00–02:30 today (no Stop) → sleep → 09:00 wake. Yesterday's file was written at 23:00 (missing 23:00–02:30). Today's cutoff is 03:00, so the 02:30 messages are filtered out entirely (not by sleep-split — the timestamp-filter alone). Net: 3.5 hours of work unrecorded.

2. **Post-rollover-pre-sleep loss** (sleep-split discard). Work that fell INSIDE today's window (after the day-start cutoff) but BEFORE the operator slept and woke is dropped by the sleep-split filter — attributed conceptually to yesterday's perceived day even though it falls in today's clock-day. Example with default cutoff at 03:00: continuous work crosses 03:00 (say 02:30–03:20), then sleep, then wake. The 03:00–03:20 segment is past today's cutoff so the timestamp-filter keeps it, then the sleep-split drops it (because it's before the most-recent long gap). This loss is intentional under the sleep-aware attribution model: those minutes belong to operator's "yesterday" mental day.

Both modes are accepted limits until retro-write to yesterday's file is implemented (companion task to #19784 cap re-tune).

**Day-start hour constraints**: `CLAUDE_BUDGET_DAY_START_HOUR` accepts integer hours 0–23 only. Fractional hours (`3.5` or `03:30`) are not supported — the cutoff is constructed as `${hour}:00` literal. Invalid values (non-integer, negative, > 23) fall back to the default 3 with a stderr warning.

## Configuration

One file, two knobs at `~/.config/claude-budget/config.json`:

```json
{"daily_tokens": 1000000, "enforce_at_pct": 0}
```

`daily_tokens` is the self-imposed ceiling, denominated in **input-equivalent weighted tokens** (per the formula in §How it works). A typical heavy day under the old `input + output` formula ran 1.0-1.3M; under the post-2026-06-23 weighted formula the same workload reads higher because cache reads now count (heavily-cached long sessions can read 2-4x as much). Re-tune `daily_tokens` by observing 5-10 days of post-fix data and setting the cap to roughly P90 of daily usage.

Two env vars tune the day-attribution heuristics; both are operator policy, not algorithmic truth:

- `CLAUDE_BUDGET_DAY_START_HOUR` (default 3) — the hour at which the budget day rolls over. Late-night-burners may want 4 or 5; morning-people may want 0 or 1.
- `CLAUDE_BUDGET_SLEEP_GAP_MIN` (default 120) — the minimum idle minutes that count as a sleep boundary within today's window. Long-lunch operators may want higher (180+) to avoid false-positive splits; nap-takers may want lower.

`enforce_at_pct: 0` means warn-only. Set it to a non-zero value (say `1`) and any `UserPromptSubmit` at or below that percentage remaining gets blocked with `{"decision":"block","reason":"..."}` -- Claude Code refuses to send the prompt. That's the guardrail against autonomous agents quietly draining the last 50k tokens overnight.

If the config file is absent or `daily_tokens` is 0, the tool is a silent no-op.

## What you'll see

At each new threshold crossing -- 25%, 10%, 5%, 1% remaining -- a one-line message appears at the next `SessionStart` or `UserPromptSubmit`:

```
[Claude Budget] 9% remaining (910k/1000k tokens, 3 sessions today). Close all but one session.
```

Each threshold fires exactly once per budget day across all sessions, enforced by `flock` against `~/.local/state/claude-budget/warned/{day}`. The action text escalates:

- 25% remaining: Consider closing idle parallel sessions.
- 10% remaining: Close all but one session.
- 5% remaining: Finish current work only.
- 1% remaining: Stop after this prompt.

The session count in the warning is the number of session token files written today. The usual cause of unexpected burn is forgetting a parallel agent is still alive, so the count is what tells you to go look.

## Limitations

The tool can only see tokens already written to JSONL, which happens after each response completes. Tokens currently being generated -- the response in flight right now -- aren't counted until it finishes. Your true usage is always slightly higher than what claude-budget reports, especially with multiple parallel sessions.

Warnings appear in Claude's context, not yours directly. They arrive in the next prompt Claude sees and Claude relays them to you. If Claude is mid-tool-use when the threshold crosses, you see the warning when control returns.

## State directory

Three pieces of state under `~/.local/state/claude-budget/`:

- `sessions/{day}-{session_id}.tokens` -- per-session token count; auto-pruned on `SessionEnd` after 7 days.
- `warned/{day}` -- newline-separated list of thresholds that fired today.
- `warned/{day}.lock` -- flock target for the parallel-session race.

Nothing here is precious. Deleting the state dir loses today's session-count accuracy but gives a fresh slate.

## Testing

To verify hooks are firing without waiting for natural usage, point `CLAUDE_BUDGET_STATE` at a temp dir, write a fake token file, and trigger a hook:

```bash
CBSTATE=/tmp/cb-test
mkdir -p "$CBSTATE/sessions"
DAY=$(date -d '3 hours ago' +%Y-%m-%d)
echo 800000 > "$CBSTATE/sessions/${DAY}-fake.tokens"

printf '{"hook_event_name":"SessionStart","session_id":"test","transcript_path":"/dev/null","cwd":"/tmp"}' \
  | CLAUDE_BUDGET_STATE="$CBSTATE" claude-budget
# expect: [Claude Budget] 20% remaining ... Consider closing idle parallel sessions.
```

The full tesht suite lives at `scripts/claude-budget_test.bash`; run with `tesht scripts/claude-budget_test.bash` from the dotfiles repo root.

## Hook wiring

The four hooks live in `~/dotfiles/claude/settings.json`:

- `Stop` (async): parse the current session's JSONL, write the token count.
- `SessionEnd` (async): prune token files older than 7 days.
- `SessionStart` (sync): check thresholds, inject warning if crossed.
- `UserPromptSubmit` (sync): same check plus the enforcement block.

Sync hooks pause Claude Code briefly so its stdout can be injected into the session context. Async hooks fire and forget.

## See also

- `docs/use-cases.md` UC-13 -- behavioral contract in Cockburn format.
- `docs/design.md` "Claude Code Budget (UC-13)" -- architecture, threshold tracking, JSONL resilience.
- `scripts/claude-budget` -- the script itself, ~150 lines of bash.
- `scripts/claude-budget_test.bash` -- tesht integration tests.
