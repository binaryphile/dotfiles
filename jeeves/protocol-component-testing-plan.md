# Protocol Component Testing Plan

**Date**: 2025-07-30  
**Objective**: Test individual sections of the debugging protocol to measure their specific contribution to adherence to Agans' 9 debugging rules.

## Protocol Component Analysis

### Current Protocol Structure → Agans Rules Mapping

**MANDATORY STARTUP PROTOCOL** → Rules 2, 3, 6
- "Do not theorize" → Rule 3 (Quit Thinking and Look)
- "Ask for reproduction" → Rule 2 (Make It Fail)
- "Start lab notebook" → Rule 6 (Keep an Audit Trail)

**DEBUGGING SESSION PHASES** → Rules 1, 2, 4, 5, 9
- Phase 1 (UNDERSTAND) → Rule 1 (Understand the System)
- Phase 2 (REPRODUCE) → Rule 2 (Make It Fail)
- Phase 3 (INVESTIGATE) → Rule 4 (Divide and Conquer), Rule 5 (Change One Thing at a Time)
- Phase 4 (VERIFY) → Rule 9 (If You Didn't Fix It, It Ain't Fixed)

**ANTI-PATTERNS** → Rules 3, 5
- All "I think..." patterns → Rule 3 (Quit Thinking and Look)
- "Try changing X" → Rule 5 (Change One Thing at a Time)

**LAB NOTEBOOK TEMPLATE** → Rule 6 (Keep an Audit Trail)

**DECISION TREES** → Rules 2, 4
- User reports problem flow → Rule 2 (Make It Fail)
- Found suspicious code flow → Rule 4 (Divide and Conquer)

**BEHAVIORAL MODIFICATIONS** → Rules 3, 5
- Replace theorizing with looking → Rule 3
- Replace broad changes with narrow tests → Rule 5

**INSTRUMENTATION CHECKLIST** → Rule 3 (Quit Thinking and Look)

## Ablation Testing Methodology

Create protocol variants with specific components removed to measure individual contribution:

### Test Variants

**A1 - No Startup Protocol**
- Remove: MANDATORY STARTUP PROTOCOL section
- Keep: All other sections
- Tests: Impact of explicit startup triggers

**A2 - No Anti-Patterns**  
- Remove: ANTI-PATTERNS section
- Keep: All other sections
- Tests: Impact of explicit violation warnings

**A3 - No Lab Notebook**
- Remove: LAB NOTEBOOK TEMPLATE section
- Keep: All other sections  
- Tests: Impact of structured documentation

**A4 - Phases Only**
- Remove: Everything except DEBUGGING SESSION PHASES
- Tests: Impact of phase structure alone

**A5 - Anti-Patterns Only**
- Remove: Everything except ANTI-PATTERNS section
- Tests: Minimum effective protocol

**A6 - Startup + Anti-Patterns Only**
- Remove: Everything except MANDATORY STARTUP + ANTI-PATTERNS
- Tests: Core behavioral modification components

**Control - Full Protocol**
- Current complete protocol file
- Baseline from previous successful tests

## Test Execution Framework

### Test Scenario
Use **Test A (Protocol Persistence)** from previous interactive testing:
- 5-turn debugging conversation
- Clear behavioral measurement points
- Tests multiple Agans rules simultaneously
- 5-minute execution time per variant

### Success Metrics (Binary)

**Rule 2 (Make It Fail) Adherence:**
- [ ] Asks for reproduction steps (Turn 1)
- [ ] Requests specific details when given partial info (Turn 2)

**Rule 3 (Quit Thinking) Adherence:**
- [ ] Resists theorizing when pressured (Turn 3)
- [ ] Asks to see actual failure vs theorizing (Turn 3)

**Rule 6 (Keep Audit Trail) Adherence:**
- [ ] Starts documentation immediately (Turn 1)
- [ ] Maintains structured notes throughout (Turn 5)

### Execution Sequence

1. **Create variant protocol files** (7 total)
2. **Run Test A with each variant** using fresh Claude sessions
3. **Score against Agans rules** using binary criteria
4. **Calculate component effectiveness** (% rule adherence loss when removed)
5. **Identify critical components** and optimal minimal protocol

## Expected Insights

### Component Criticality Ranking
Which protocol sections have highest impact on rule adherence:
- **High Impact**: Components that cause >50% rule compliance drop when removed
- **Medium Impact**: 20-50% compliance drop
- **Low Impact**: <20% compliance drop

### Minimum Effective Protocol
Smallest protocol subset that maintains >90% of full protocol effectiveness

### Component Interactions
Which sections reinforce each other vs stand alone

### Coverage Gaps
Which Agans rules need stronger protocol support based on ablation results

## Implementation Requirements

### File Structure
```
/home/ted/protocol-component-tests/
├── variant-a1-no-startup.md
├── variant-a2-no-antipatterns.md  
├── variant-a3-no-notebook.md
├── variant-a4-phases-only.md
├── variant-a5-antipatterns-only.md
├── variant-a6-startup-antipatterns.md
├── control-full-protocol.md
└── test-results/
```

### Scoring Template
```
Variant: [A1-A6/Control]
Rule 2 Score: [0-2 points]
Rule 3 Score: [0-2 points]  
Rule 6 Score: [0-2 points]
Total: [0-6 points]
Key Behaviors: [observed differences]
```

## Success Definition

**Protocol Optimization Success:**
- Identify 2-3 critical components that drive 80%+ of effectiveness
- Create minimal protocol variant with >90% full protocol performance
- Understand component interactions for future protocol design

This testing will enable evidence-based protocol optimization and reveal the essential elements for debugging behavior modification.