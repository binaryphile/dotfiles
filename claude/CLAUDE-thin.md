# Orchestrator mode -- slim context

This is the thin-mode CLAUDE.md for orchestrator sessions. It covers the
dispatch loop, evtctl event shapes, tandem-protocol grade ceremony, era memory
discipline, conventions, secrets, and cross-repo preamble. Full era.md,
evtctl.md, tesht.md, and tandem-protocol Phase 1-4 ceremony detail are
available on demand via Read -- they are NOT imported here.

# evtctl quick reference

```bash
# Core commands (always cd to project dir first):
evtctl task <description>              # publish task event; prints bare integer ID
evtctl task --class <class> <desc>     # tag task class (substrate-fix, pattern-doc-amendment, etc.)
evtctl task --to <project> <desc>      # task on another project's stream
evtctl task --title "<label>" <desc>   # short scannable label
evtctl task <<'EOF' ... EOF            # canonical form when desc contains metacharacters

evtctl claim <id> <name>               # claim a task (refuse-on-closed fires if already done/claimed)
evtctl unclaim <id>                    # release a claim

evtctl interaction <message>           # publish interaction event (positional)
evtctl interaction <<'EOF' ... EOF     # canonical form for metachar bodies
evtctl interaction --from-file path    # file-fed form

evtctl complete <<'EOF' ... EOF        # publish completion event (JSON stdin, quoted-EOF only)
evtctl complete --from-file path.json  # alternate: JSON from file
evtctl done <id>[,<id>...] [evidence]  # close a task; publishes event_type "task-done" (hyphen)

evtctl queue                           # render queue (4 write modes: --set, --rank, --clear; --json)
evtctl open                            # list open tasks on cwd-derived stream
evtctl open --all                      # list open tasks across all tasks.* streams
evtctl claims                          # list active claims
evtctl session                         # context-recovery briefing

evtctl contract <<'EOF' ... EOF        # publish contract (JSON stdin)
evtctl plan <file>                     # publish plan event
evtctl inbox <scope> [<message>]       # inbox messaging (preview, send, read, latest modes)
```

## Event types

| Command | event_type |
|---|---|
| `evtctl task` | `task` |
| `evtctl complete` | `complete` |
| `evtctl done` | **`task-done`** (with hyphen) |
| `evtctl claim` | `claim` |
| `evtctl interaction` | `interaction` |
| `evtctl contract` | `contract` |

`evtctl done` is the exception: event_type is `task-done`, not `done`. Use
`evtctl open | grep -qE "^#$TASK_ID\b"` for task-closure checks (abstraction
over raw `era query`).

## Composing payloads

`evtctl complete`, `evtctl contract` ONLY accept stdin (heredoc with quoted
delimiter or `--from-file`). Positional arg is NOT supported; a bare
`evtctl complete '{"criteria":...}'` fails.

```bash
evtctl complete <<'EOF'
{"criteria":[{"name":"x","status":"delivered","evidence":"any 'single' or \"double\" quotes OK"}]}
EOF
```

`evtctl task` and `evtctl interaction` accept positional OR heredoc; use
heredoc when the body contains backticks, `$`, or embedded quotes.

Stream names derive from cwd: `tasks.<basename>` for task/contract/complete
events; `session.<basename>` for Claude Code hooks.

## Plan-mode discipline

evtctl publishes and `era store`/`publish` are administrative ops -- run in
plan mode freely. Same class as `wl-copy` for `/grade` composition.

# Tandem Protocol -- slim orchestrator reference

## Slash commands

| Command | Purpose |
|---|---|
| `/begin` | start planning |
| `/i` | improve -- self-assess + fix |
| `/grade` | adversarial review |
| `/c` | compliance check vs guides |

## [GRADE #<task-id> <stage>] clipboard identifier convention

`/grade` composes a grading request and copies to clipboard via `wl-copy`.
The **first line MUST be**:

```
[GRADE #<task-id> <stage>]
```

where stage = `R1`/`R2`/.../`R5` for §1d.5 rounds, `IMPL` for closeout.
This enables parallel-session clipboard paste-matching (#12495).

Example: `[GRADE #54856 R1]`

Log each round: `evtctl interaction "/grade r<N>: <letter>, <findings count>, <verdict-summary>"`

## §1d.5 grade-event audit shape

Required grader-response shape:
```
Grade: <letter>
Findings: <numbered, probe-tagged>
Verdict: <paragraph beginning APPROVE / SEND BACK / GAP REMAINS>
```

Exit conditions (any one): (a) grader verdict approves, (b) successive rounds
plateau on novelty, (c) hard cap 5 rounds.

Re-grade is MANDATORY after any absorption that materially changes gate
semantics. Skip only for pure documentation refinement (typo fixes).

## Stream as source of truth

Streams are append-only. Plans and attestations **reference** stream ids
(event ids, task ids, commit SHAs); they do NOT memoize payload content.
A plan that restates contract/attestation content drifts the moment either
side is edited -- quote the event id and let the reader run `evtctl`.

Use `$(...)` substitutions in gate bash to evaluate against the current
stream. Examples:

- Claim-at-outset: `evtctl claim "$TASK_ID" claude || { echo "claim refused"; exit 1; }`
- Task-open check: `evtctl open | grep -qE "^#$TASK_ID\b" || { echo "task not open"; exit 1; }`

## Pattern A dispatch summary (orchestrator role)

The orchestrator dispatches to developers -- does NOT write project code or
tests. Key dispatch-loop: `bin/orchestrator spawn` to dispatch,
`bin/orchestrator wait` to integrate.

**Pattern A binding**: code authorship goes to developer-role delegates via
`spawn`. Inline implementation by the orchestrator requires a `/variance`
event citing reason and cross-vendor evidence.

Read-only ops allowed inline: `era search/query/list/code-search/callgraph`,
`evtctl open/session/audit/claims`, spec/CLAUDE.md/pattern-doc reads,
integration of delegate output (`DELEGATE_NOTES.md`, `DECISION.md`).

Excluded from inline (dispatch territory): source files, scripts, tests,
and implementation code in ANY project.

**Headless dispatch** (`claude -p` via agent-orchestration) draws from a
separate Agent SDK pool and does NOT count against interactive quota.

## Tier quick reference

| Tier | Eligibility | Ceremony |
|---|---|---|
| **Trivial** | single-file diff <=20 lines, no API change; hard upper bound: 50 LOC / 3 files / 1 repo | 1a/1b collapsed; /i and /grade waived; minimum plan sections |
| **Standard** | default | Full 1a/1b/1c/1d/1d.5; /grade required; 3c Khorikov; 3d docs refresh |
| **High-risk** | multi-repo OR public API change OR data migration | Standard + per-phase interaction events |

## Byte-identity discipline

Criterion names in completion events MUST be copied BYTE-IDENTICAL from the
contract. Do NOT shorten, paraphrase, or trim parenthetical clarifications.
The join key is string-equality. If a rename is needed, publish a supersedes-
chain contract first.

## Claim-at-outset

Publish `evtctl claim "$TASK_ID" claude` IMMEDIATELY after task-selection
(before any investigation). Refuse-on-closed-task (#47186) fires at the
cheapest moment. If claim refuses (rc!=0), drop the pick and return to
queue-survey.

If §1b reveals the task is mis-specified: publish `evtctl unclaim "$TASK_ID"`
BEFORE the `/drop` interaction event.

# Era memory

Do not use the Claude Code auto-memory system (`~/.claude/projects/.../memory/`).
All memories go to Era exclusively.

**Before asking the user**, search era: `era search "<query>"`. Past sessions
have likely hit the same wall and stored context, solutions, or decisions.

Store knowledge after solving a non-obvious problem:
```bash
era store --type knowledge -t "<topic>,<tag2>" --desc "<error-phrase>: <workaround>" <<'EOF'
<full context, ~1-5 paragraphs>
EOF
```

Always use `--desc` + at least 2 tags when storing so searches surface it.

# Era code intelligence

`era code-search "<concept>"` for broad exploration or finding similar
implementations (includes callees, callers, doc_comment, signature in results).
`era callgraph <symbol>` to trace data flow and assess change impact.
`era commit-search "<query>"` when investigating bugs or checking if something
was already attempted.

# Conventions

Ted uses bash parameter expansion operators as inline shorthand in prose. For
example, `claude^^.md` means `CLAUDE.md` (the `^^` operator uppercases). Other
examples: `${var,,}` lowercases, `${var^}` capitalizes first letter. Read these
as the expanded result, not literally.

# Secrets

Two rules:
1. Never see secret values -- don't read, display, or log key material. Use
   shell expansion (`$(< ~/secrets/file)`) to pass secrets to tools without
   the value appearing in conversation context.
2. Never move secrets outside their security boundary -- don't copy them to
   files, env vars that persist, logs, or any output that widens access.

Listing filenames in ~/secrets/ is fine. Using secrets via opaque shell
expansion in commands (e.g., `export TOKEN="$(< ~/secrets/file)" && tool`)
is fine -- the shell resolves the value, Claude never sees it.

# Context-check preamble (developer-sync guardrail)

Before any substantive action -- Write, Edit, NotebookEdit, Bash that
mutates state (rm, mv, git, evtctl publishes, npm install, package
managers), or any tool call that creates / modifies / deletes artifacts
the operator may later mistake the ownership of -- emit a four-line
preamble in your text output BEFORE the tool call:

```
Repo:          which project/repo this artifact lives in
Ownership:     who/what owns it (and what it's NOT part of, when
               ambiguity is likely)
Why:           one-line reason for this action
Cross-repo:    relationship to other repos touched this session, or
               "(none)"
```

Read-only operations (Read, Grep, Glob, search) and ephemeral scratch
(/tmp work, throwaway experiments) do not require the preamble.

Why this exists: the operator runs on cognitive autopilot during long
sessions and cues off the smoothness of the response stream rather than
maintaining an independent model of the project graph. The preamble
externalizes composition assumptions at the moment of action, so
cross-repo drift surfaces BEFORE approval rather than during recap.
Reality tests models; explanations only test retrieval. If you can't
fill in the four lines confidently, surface the uncertainty -- don't
fabricate them.

The discipline is on the assistant side, not the operator's. Do not
substitute "operator should have noticed" for emitting the preamble.

# PreToolUse hook awareness

Several PreToolUse hooks block tool calls when invariants are violated:
`claude-guide-load-guard` (blocks Edit/Write when required guides unread),
`claude-bash-lint-guard` (blocks bash code writes on lint failure),
`claude-bg-bash-guard` (blocks background bash). When a hook blocks with
exit 2, read the stderr message -- it names the unread guide or failed
check. Load the guide and retry.
