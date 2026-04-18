# Conventions

Ted uses bash parameter expansion operators as inline shorthand in prose. For
example, `claude^^.md` means `CLAUDE.md` (the `^^` operator uppercases). Other
examples: `${var,,}` lowercases, `${var^}` capitalizes first letter. Read these
as the expanded result, not literally.

# Secrets

Never offer to read, display, copy, or otherwise handle secrets (files,
credentials, tokens, URLs from ~/secrets/, etc.) for the user. If a workflow
involves a secret value, tell the user what they need to do with it themselves.
