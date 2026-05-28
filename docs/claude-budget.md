# claude-budget

`claude-budget` warns you when your day's Claude Code token usage approaches a self-imposed limit. It exists for one situation: you're running parallel sessions on the Enterprise plan, the quota resets every two weeks, and there's no built-in way to see how close you are to exhausting it. By the time you notice, every session stops working at once. The tool hooks Claude Code's lifecycle events and warns you with enough lead time to wind down voluntarily.

## How it works

After each response, Claude Code writes the conversation to a JSONL file under `~/.claude/projects/`. The Stop hook reads that file, sums `input_tokens + output_tokens` per message (deduped by message ID), and records the per-session total to `~/.local/state/claude-budget/sessions/{day}-{session_id}.tokens`. This matches what `/usage` shows you with cache tokens excluded. Enterprise quota accounting may differ slightly (it weights cache reads), but for relative pacing this is accurate enough.

The budget day resets at 2am, not midnight. That handles the late-night session that crosses midnight without charging twice for one work block.

## Configuration

One file, two knobs at `~/.config/claude-budget/config.json`:

```json
{"daily_tokens": 1000000, "enforce_at_pct": 0}
```

`daily_tokens` is the self-imposed ceiling. A typical heavy day runs 1.0-1.3M tokens; the observed peak (the day the quota actually ran out) was 3.1M. Setting `daily_tokens` to 1M means the 25% warning fires at 750k used -- mid-heavy-day, well before things get tight. The 3.1M peak was the anomaly that motivated this tool; don't use it as the ceiling or warnings arrive too late.

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
DAY=$(date -d '2 hours ago' +%Y-%m-%d)
echo 800000 > "$CBSTATE/sessions/${DAY}-fake.tokens"

printf '{"hook_event_name":"SessionStart","session_id":"test","transcript_path":"/dev/null","cwd":"/tmp"}' \
  | CLAUDE_BUDGET_STATE="$CBSTATE" claude-budget
# expect: [Claude Budget] 20% remaining ... Consider closing idle parallel sessions.
```

The full tesht suite lives at `scripts/claude-budget_test.bash`; run with `tesht -f scripts/claude-budget_test.bash` from the dotfiles repo root.

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
