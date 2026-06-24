# claude-budget

`claude-budget` warns you when your day's Claude Code token usage approaches a self-imposed limit. It exists for one situation: you're running parallel sessions on the Enterprise plan, the quota resets every two weeks, and there's no built-in way to see how close you are to exhausting it. By the time you notice, every session stops working at once. The tool hooks Claude Code's lifecycle events and warns you with enough lead time to wind down voluntarily.

## How it works

After each response, Claude Code writes the conversation to a JSONL file under `~/.claude/projects/`. The Stop hook reads that file, applies three filters, and records the per-session total to `~/.local/state/claude-budget/sessions/{day}-{session_id}.tokens`:

1. **Day-scope filter.** Only messages whose `.timestamp` falls within the current budget day (03:00 to 03:00 local) are counted. Without this filter, a long-lived session that spans multiple calendar days re-counts prior-day messages into today's bucket every time the Stop hook fires. Claude Code transcripts are append-only within a session — `/compact` or `/clear` may shrink them but the daily ledger should still represent today's work, not cumulative-since-session-start.

2. **Sleep-aware attribution.** Within today's filtered window, the hook walks messages in timestamp order and finds the most-recent idle gap of `CLAUDE_BUDGET_SLEEP_GAP_MIN` minutes (default 120). Messages BEFORE that gap are dropped — they belong to the prior day's work-block that ran past the 03:00 cutoff before the operator slept; the post-gap block is today's true operator-intent work. Sessions with no gap exceeding the threshold count entirely (single contiguous work-block). The 03:00 cutoff alone catches late-night tails as "today"; this second filter corrects that.

3. **Cache-aware weighted sum.** The per-message token formula is `input*1 + output*5 + cache_creation*1.25 + cache_read*0.1`, approximating Anthropic's billing shape on input-equivalent units (output ~5x base; cache_creation ~1.25x; cache_read ~0.1x). The weights are an operator policy choice — re-tune them (and `daily_tokens`) if rate-card pricing changes. The previous formula was `input + output` only, which ignored cache reads entirely and under-represented usage in cache-heavy long-running sessions where cache reads dominate. Messages without a `.timestamp` field are excluded (older transcript versions or malformed entries).

The budget day resets at 3am, not midnight. That handles the late-night session that crosses midnight without charging twice for one work block. Note: pre-gap tokens are intentionally NOT retro-written to yesterday's file (already closed at rollover); they're lost from accounting under the assumption that yesterday's last Stop already approximately captured them.

## Configuration

One file, two knobs at `~/.config/claude-budget/config.json`:

```json
{"daily_tokens": 1000000, "enforce_at_pct": 0}
```

`daily_tokens` is the self-imposed ceiling. Pre-2026-06-23 the formula was raw `input + output`; post-fix the formula is weighted billable-equivalent. Existing caps set under the old formula are no longer directly comparable — re-tune by observing 5-10 days of post-fix data and setting the cap to roughly P90 of daily usage. A typical heavy day under the old formula ran 1.0-1.3M raw tokens; under the new formula the same workload reads higher because cache reads now count (heavily-cached long sessions can read 1.5-2x as much). Set `daily_tokens` such that the 25% warning fires mid-heavy-day, well before things get tight.

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
