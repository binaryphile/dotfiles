# evtctl
@~/projects/era/evtctl.md

# Conventions

Ted uses bash parameter expansion operators as inline shorthand in prose. For
example, `claude^^.md` means `CLAUDE.md` (the `^^` operator uppercases). Other
examples: `${var,,}` lowercases, `${var^}` capitalizes first letter. Read these
as the expanded result, not literally.

# Jira

Default to drafting ticket content for Ted to create. Create tickets directly
(via `jira` CLI) only when explicitly asked.

# Guides

`~/projects/jeeves/guides/` -- read the relevant guide before speculating or
searching the web. Covers: bash, nix, go, security analysis, use case writing,
investigation methodology, agent orchestration, and more.

# Security Docs

`docs/security.md`, `docs/secrets-lifecycle.md`, and `docs/threat-model.md` are
encrypted at rest (`.age` files). They are not readable by agents. When changing
credential handling or trust boundaries, tell Ted to decrypt and review them
(`scripts/security-docs decrypt`).

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
