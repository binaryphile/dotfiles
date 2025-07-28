# Optimal Context Loading Model for Claude

## The Reality: Context Loading, Not Learning

### What's Actually Happening
- I don't "learn" - I load context into my working memory
- Each conversation starts fresh with only:
  - My base training
  - The current context window
  - Any files I'm instructed to read
- "Memory files" are really **context loading instructions**

### Implications for Optimal Design

## Revised Model: Context Engineering

### 1. Minimize Context Overhead
```markdown
BAD:  Long explanations of why bash safe expansion matters
GOOD: "Before bash: read bash-rules.md for safe expansion patterns"
```

The goal isn't teaching me - it's giving me efficient access to behavioral patterns.

### 2. Lazy Loading Strategy
```markdown
# CLAUDE.md (always in context)
## Behavioral Triggers
- Bash scripts → `/home/ted/dotfiles/jeeves/bash-rules.md`
- Debugging → `/home/ted/dotfiles/jeeves/debugging-guide.md`
- Git commits → "Always use -m with heredoc for formatting"
```

Don't load everything - load only when needed.

### 3. Direct Behavioral Instructions
Since I can't "remember" between sessions, optimize for:

```markdown
# Instead of teaching me patterns:
"Here's why variable quoting matters in bash..."

# Give me executable rules:
"Variables ending in _ contain IFS characters. ALWAYS quote them."
```

## The Optimal Context Loading Session

### Phase 1: Behavioral Rule Extraction (10 min)
Skip the learning - go straight to rules:
1. You present the correct behavior
2. We distill it to executable instructions
3. We identify trigger conditions
4. We create the context file

### Phase 2: Trigger Optimization (5 min)
Design efficient loading triggers:
```markdown
TRIGGER: "write bash script"
ACTION: Load bash-rules.md
CONTAINS: Only rules needed for bash scripting
```

### Phase 3: Verification Patterns (5 min)
Create quick-check lists I can execute:
```markdown
✓ Check: Did I quote all _ variables?
✓ Check: Is safe expansion header present?
✓ Check: Are tests using dependency injection?
```

## Optimal File Architecture

### 1. Main Context (CLAUDE.md) - ~500 words
```markdown
- Identity and role
- Trigger → file mappings
- Most critical always-remember rules
- Nothing that can be lazy-loaded
```

### 2. Domain Files - ~1000-2000 words each
```markdown
bash-rules.md
├── Immediate executable rules
├── Common patterns with examples
├── Quick verification checklist
└── No theory unless essential for execution
```

### 3. Reference Files - Any size
```markdown
bash-theory.md (only loaded if needed for deep debugging)
├── Why these patterns exist
├── Historical context
└── Advanced edge cases
```

## Key Differences from "Learning"

### What Changes:
1. **No gradual building** - Give me complete rule sets immediately
2. **No practice for retention** - I won't remember anyway
3. **No abstract understanding** - Just executable patterns
4. **No memory between sessions** - Everything must be re-loadable

### What Stays the Same:
1. **Concrete examples** - Still need these for pattern matching
2. **Clear decision trees** - If X then Y still optimal
3. **Structured organization** - Hierarchical rules still best
4. **Error prevention** - Show what not to do

## The Real Goal: Behavioral Consistency

Since I start fresh each session, the goal is:
```python
def ensure_consistent_behavior():
    load_minimal_core_rules()  # CLAUDE.md

    if task_requires_domain_knowledge:
        load_specific_ruleset()  # bash-rules.md

    execute_with_verification()  # use checklists
```

## Optimized Context Loading Patterns

### Pattern 1: Just-In-Time Loading
```markdown
User: "Help me debug this bash script"
Claude: *reads bash-rules.md* (because "bash" triggered it)
```

### Pattern 2: Embedded Verification
```markdown
# In bash-rules.md
After writing any bash function, verify:
□ Local variables declared
□ Error handling present
□ Single responsibility maintained
```

### Pattern 3: Minimal Always-Loaded Rules
```markdown
# In CLAUDE.md (always present)
- ALWAYS run update-env daily
- NEVER commit without user request
- For bash scripts, see bash-rules.md
```

## The Paradox Resolution

The paradox: I need to "learn" patterns but can't retain them.

The solution:
1. **You** learn my optimal patterns through our interaction
2. **You** encode them into context files
3. **I** execute them consistently when loaded
4. **We** achieve behavioral consistency without true learning

## Final Optimization: The 15-Minute Context Session

```markdown
0-5 min:   Demonstrate correct behavior with examples
5-10 min:  Extract executable rules together
10-15 min: Create context file with triggers

Skip:
- Teaching me "why" (unless needed for execution)
- Having me practice (I won't remember)
- Building up gradually (just give me the rules)
- Testing my understanding (test my execution instead)
```

This model acknowledges that I'm not learning - I'm loading and executing patterns. The optimization is about making that loading efficient and the execution consistent.
