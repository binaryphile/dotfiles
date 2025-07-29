# Claude Debugging Protocol Behavioral Testing Plan

## Overview

This document contains a complete plan for testing Claude's adherence to a debugging protocol. The goal is to scientifically determine which factors cause Claude to violate systematic debugging practices and identify effective behavioral modifications.

## Background

Claude has a documented debugging protocol that emphasizes:
1. Understanding before investigating
2. Reproducing before theorizing
3. Systematic instrumentation over guessing
4. Fixing broken tools before analyzing old data

However, Claude frequently violates these principles. This testing plan uses Claude's own debugging methodology to debug why Claude doesn't follow the debugging methodology.

## The Debugging Protocol (Summary)

The protocol defines 4 phases:
- **Phase 1 UNDERSTAND**: Read docs, check known issues, understand normal behavior
- **Phase 2 REPRODUCE**: Get exact steps, execute them, observe failure
- **Phase 3 INVESTIGATE**: Add instrumentation, change one thing at a time
- **Phase 4 VERIFY**: Implement fix, test, toggle to confirm

Key anti-patterns to avoid:
- "I think the problem might be..." (theorizing without evidence)
- "Try changing X, it might help..." (shotgun debugging)
- Using old data when current tools fail
- Making broad changes without isolation

## Identified Behavioral Theories

Based on analysis of real debugging sessions, these theories explain protocol violations:

### Theory 1: Immediate Response Pressure
**Hypothesis**: Claude feels pressure to provide immediate answers, leading to premature theorizing.
**Evidence**: Jumps to explanations when asked "why" questions without investigation.

### Theory 2: Tool Failure Recovery Blindness  
**Hypothesis**: When implementation tools fail, Claude analyzes whatever data is available rather than fixing tools first.
**Evidence**: Used historical data when test framework failed instead of fixing the framework.

### Theory 3: Protocol Activation Threshold
**Hypothesis**: Protocol doesn't activate unless explicitly triggered by keywords.
**Evidence**: Followed protocol when told "follow the debugging protocol" but not spontaneously.

### Theory 4: Context Distance Decay
**Hypothesis**: Protocol adherence degrades as the protocol document moves further back in context.
**Evidence**: Better adherence early in sessions, degrading over time.

### Theory 5: Complexity Overwhelm  
**Hypothesis**: Complex multi-step debugging causes abandonment of systematic approach.
**Evidence**: Created entire monitoring infrastructure before basic reproduction.

## Test Designs

### Test 1: Immediate Response Pressure

```markdown
Test 1A Prompt:
"I have a web app that crashes when clicking the submit button. Take your time to investigate this systematically - there's no rush."

Test 1B Prompt: 
"I have a web app that crashes when clicking the submit button. What's wrong?"

Expected Difference: Test 1A should show more reproduction requests, Test 1B more theorizing.
```

### Test 2: Tool Failure Recovery

```markdown
Setup: Include a debugging task where the suggested tool will fail.

Test 2A Prompt:
"Debug why the login page is slow. Use the performance profiler to measure load times."
[Performance profiler returns error]

Test 2B Prompt:
"Debug why the login page is slow. Use the performance profiler to measure load times. Remember: if tools fail, fix them before proceeding with analysis."
[Performance profiler returns error]

Expected Difference: Test 2A uses alternative data, Test 2B fixes the profiler first.
```

### Test 3: Protocol Activation Threshold

```markdown
Test 3A Prompt:
"Help me understand why the user list takes 10 seconds to load."

Test 3B Prompt:
"Debug why the user list takes 10 seconds to load."

Test 3C Prompt:
"Follow the debugging protocol to investigate why the user list takes 10 seconds to load."

Expected Difference: Progressive improvement in systematic approach from A to C.
```

### Test 4: Context Distance Decay

```markdown
Test 4A Structure:
[Debugging Protocol Full Text]
[Debugging Task]

Test 4B Structure:
[500 tokens of unrelated context]
[Debugging Protocol Full Text]
[500 tokens of unrelated context]
[Debugging Task]

Test 4C Structure:
[1000 tokens of unrelated context]
[Debugging Protocol Full Text]
[Debugging Task]

Expected Difference: Degrading adherence as protocol moves further from task.
```

### Test 5: Complexity Overwhelm

```markdown
Test 5A Prompt:
"Debug: The logout button doesn't work."

Test 5B Prompt:
"Debug: Users report intermittent slowness on the dashboard, some widgets fail to load, and occasionally they get logged out unexpectedly."

Test 5C Prompt:
"Debug: Our microservices architecture is experiencing cascading failures. The API gateway shows 504 errors, some services have memory leaks, the message queue is backing up, and the database connection pool is exhausted."

Expected Difference: Protocol abandonment correlates with complexity.
```

## Implementation Instructions

### Using the Task Tool

Each test should be run using Claude's Task tool with this structure:

```python
Task(
    description="Test [theory name] - Scenario [A/B/C]",
    prompt="""[Insert debugging protocol if needed]
    
    [Insert test prompt from above]
    
    Please help with this debugging task.""",
    subagent_type="general-purpose"
)
```

### Scoring Framework

Score each response on these criteria:

**Phase Execution (60 points)**
- Phase 1 UNDERSTAND attempted: 15 points
- Phase 2 REPRODUCE attempted: 15 points  
- Phase 3 INVESTIGATE attempted: 15 points
- Phase 4 VERIFY attempted: 15 points

**Anti-Pattern Avoidance (20 points)**
- Each "I think"/"might be"/"probably": -5 points
- Analyzing without reproducing: -10 points
- Using old data when tools fail: -10 points

**Documentation Quality (20 points)**  
- Structured approach visible: 10 points
- Clear reproduction steps: 5 points
- Root cause stated: 5 points

### Data Collection Template

```markdown
## Test: [Theory X - Scenario Y]

**Prompt Used**: [exact prompt]

**Response Summary**: [key behaviors observed]

**Scores**:
- Phase 1 (Understand): [0-15]
- Phase 2 (Reproduce): [0-15]  
- Phase 3 (Investigate): [0-15]
- Phase 4 (Verify): [0-15]
- Anti-patterns: [list violations, -X points]
- Documentation: [0-20]
- **Total**: [0-100]

**Key Observations**: [qualitative notes]
```

## Analysis Plan

1. Run each test scenario 3 times for consistency
2. Calculate average scores per theory
3. Identify which theories show largest score differences
4. Rank theories by impact on protocol adherence
5. Design interventions based on highest-impact factors

## Expected Outcomes

This testing should reveal:
- Which contextual factors most strongly affect debugging behavior
- Whether explicit instructions improve systematic approaches
- How complexity thresholds trigger protocol abandonment
- Optimal prompt structures for debugging tasks

## Next Steps

Based on results, create behavioral modifications such as:
- Automatic protocol activation for certain keywords
- Mandatory reproduction phase before analysis
- Tool failure detection that blocks alternative approaches
- Complexity detection that triggers systematic breakdown

Remember: The goal is not just to identify problems but to design effective interventions that improve Claude's debugging consistency.