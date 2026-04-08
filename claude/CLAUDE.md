# Era

Era is your persistent memory and code intelligence system. Use it proactively
across all projects.

## Memory

When seeking clarification or investigating an issue, search Era memory first
(`mcp__era__search`) before asking the user. Past sessions may have already
documented the context, solution, or relevant decisions. If Era doesn't have
what you need and you find the answer through other means (filesystem search,
web, user clarification, etc.), store the result in Era (`mcp__era__store`) so
future sessions can find it.

## Code Search

Use `mcp__era__code_search` to find code by keyword and meaning across all
indexed repos. Results include enrichment (callees, callers, doc_comment,
related_docs, signature, snippet) — use these to triage without opening files.
Use `mcp__era__code_callgraph` to explore call relationships (callers/callees)
for a specific function or type.

## Commit Search

Use `mcp__era__commit_search` to find commits by meaning. Useful for
understanding when and why changes were made.

## Tasks

At session start, run `evtctl open` to check for open tasks relevant to the
current project. Tasks are managed via event streams — use `evtctl task`,
`evtctl done`, `evtctl claim`, `evtctl open`, and `evtctl audit`.

## Events

Use `mcp__era__publish` to log events to named streams. Use `mcp__era__read`
and `mcp__era__query` to read events. Use `mcp__era__subscribe` to wait for
new events.
