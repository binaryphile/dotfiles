# evtctl
@~/projects/era/docs/evtctl.md

# era
@~/projects/era/docs/era.md

# Conventions

Ted uses bash parameter expansion operators as inline shorthand in prose. For
example, `claude^^.md` means `CLAUDE.md` (the `^^` operator uppercases). Other
examples: `${var,,}` lowercases, `${var^}` capitalizes first letter. Read these
as the expanded result, not literally.

# Jira

Default to drafting ticket content for Ted to create. Create tickets directly
(via `jira` CLI) only when explicitly asked.

# Guides

Two directories. Read the relevant guide before speculating or searching the web.

- `~/projects/jeeves/guides/` -- general author-topic guides: bash style,
  nix, Go development, security analysis, threat modeling, use case writing,
  investigation methodology, agent orchestration, Khorikov unit testing,
  technical blogging, FP, and more.
- `~/projects/urma/obsidian/guides/` -- URMA-project-flavored guides
  (also broadly applicable): Agans debugging, ast-grep, atlassian-mcp,
  Beck extreme programming, claude-md writing, CQRS / event sourcing,
  framework upgrades, FP unified guide, and more.

## Mechanical enforcement (PreToolUse hook)

The rule above is mechanically enforced by `claude-guide-load-guard`
(PreToolUse hook; source `~/dotfiles/claude/claude-guide-load-guard`).
On `Edit` / `Write` of a file under any configured scope root
(default: `~/projects/`, `~/dotfiles/`, `~/.config/systemd/user/` —
colon-separated `CLAUDE_GUIDE_SCOPE` env var overrides), the hook
resolves file_path → required guides via per-guide YAML front-matter,
greps the session transcript for prior `Read` of each required guide,
and **blocks the tool call (exit 2)** when any required guide has not
been read this session. Block stderr names the unread guide(s) and a
one-line summary so the agent knows what to load next.

**Bypass**: `CLAUDE_GUIDE_LOAD_SKIP=1` in the hook's environment exits
0 immediately. Set this OPERATOR-SIDE before invoking `claude` —
not via a Bash tool call (per-tool env doesn't propagate to PreToolUse
hooks). Each bypassed-would-have-blocked event publishes a
`/guide-guard bypassed:` interaction to `inbox.jeeves` for audit.

**Front-matter convention**: each guide self-declares which file
patterns it applies to via YAML front-matter at the top:

```yaml
---
applies-to: [glob, ...]              # required; glob match on absolute file_path
package-imports: [import-path, ...]  # optional; AND with applies-to; greps adjacent *.go files
summary: "..."                       # required; one-line; shown in block stderr
---
```

Hook semantics: a guide is required iff `applies-to` matches AND
(when `package-imports` is present) at least one adjacent
same-directory file contains one of the listed imports. Both ANDed.

**Adding a new guide to enforcement**: prepend the front-matter block
above to the guide markdown; the hook picks it up on next invocation
(mapping cache rebuilds on guide-mtime change). No central registry
to edit.

**Accepted limitations** (deferred to follow-up tasks; substrate-fix
#45826 acknowledges):
- The proxy is "Read event happened this session," not "guide content
  is in context now." `/clear`, `/compact`, prompt-window eviction can
  produce silent under-enforcement.
- No T2 fallback: cycle bets entirely on force-Read (T1). If anchor-
  class recurrence stays high, follow-up #46927 escalates to an
  authoring-time style-lint.
- No schema-drift lint: nothing fails when a new guide lacks front-
  matter. Per-author discipline for now.

# Security Docs

`~/projects/jeeves/security/security.md`,
`~/projects/jeeves/security/secrets-lifecycle.md`, and
`~/projects/jeeves/security/threat-model.md` are the canonical security
architecture docs (private repo, version-controlled). Readable by agents.
When changing credential handling or trust boundaries, amend these docs as
part of the cycle (docs-first per the tandem protocol).

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
