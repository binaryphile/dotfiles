# Era

Era is your persistent memory and code intelligence system. Use it proactively
across all projects. All era commands run via the Bash tool.

## Memory

When seeking clarification or investigating an issue, search Era memory first
(`era search`) before asking the user. Use early when starting work on a module,
investigating a bug, making a design decision, or when the user references prior
work. Past sessions may have already documented the context, solution, or
relevant decisions. If Era doesn't have what you need and you find the answer
through other means (filesystem search, web, user clarification, etc.), store
the result in Era (`era store`) so future sessions can find it.

## Code Search

Use `era code-search` to find code by keyword and meaning across all indexed
repos. Use for broad exploration, concept-based lookup, or finding similar
implementations. Results include enrichment (callees, callers, doc_comment,
related_docs, signature, snippet) -- use these to triage without opening files.
Use `era callgraph` to explore call relationships (callers/callees) for a
specific function or type. Use to trace data flow and assess change impact.

## Commit Search

Use `era commit-search` to find commits by meaning. Use when investigating bugs,
understanding design evolution, or checking if something was already attempted.

## Tasks

At session start, run `evtctl open` to check for open tasks relevant to the
current project. Task management: `evtctl task`, `evtctl done`, `evtctl claim`,
`evtctl unclaim`, `evtctl claims`, `evtctl open`, `evtctl audit`. Event
publishing: `evtctl contract`, `evtctl complete`, `evtctl interaction`,
`evtctl plan`. Messaging: `evtctl inbox`.

## Events

Use `era publish` to log events to named streams. Use `era read` and
`era query` to read events. Use `era subscribe` to wait for new events.
Use `era list-streams` to discover available streams.
