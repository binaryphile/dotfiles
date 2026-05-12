# Era

Era is your persistent memory and code intelligence system. Use it
proactively across all projects. See `era.md` (imported above) for the CLI
reference.

## Memory

When seeking clarification or investigating an issue, search era memory
first (`era search`) before asking the user. Use early when starting work
on a module, investigating a bug, making a design decision, or when the
user references prior work. Past sessions may have already documented the
context, solution, or relevant decisions. If era doesn't have what you
need and you find the answer through other means (filesystem search, web,
user clarification, etc.), store the result (`era store`) so future
sessions can find it.

## Code intelligence

Use `era code-search` for broad exploration, concept-based lookup, or
finding similar implementations. Results include enrichment (callees,
callers, doc_comment, related_docs, signature, snippet) -- use these to
triage without opening files. Use `era callgraph` to trace data flow and
assess change impact. Use `era commit-search` when investigating bugs,
understanding design evolution, or checking if something was already
attempted.

## Tasks

At session start, run `evtctl open` to check for open tasks on the current
project's stream. See `evtctl.md` (imported above) for the full task
lifecycle and event commands.
