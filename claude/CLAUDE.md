# evtctl
@~/projects/era/docs/evtctl.md

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

# Security Docs

`docs/security.md`, `docs/secrets-lifecycle.md`, and `docs/threat-model.md` are
sensitive documents stored in 1Password. They are not readable by agents. When
changing credential handling or trust boundaries, tell Ted to review them.

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
