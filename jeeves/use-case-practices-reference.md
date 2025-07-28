# Use Case Practices Reference Guide

## Overview
This comprehensive reference provides Alistair Cockburn's complete approach to writing effective use cases. Use this for deeper understanding beyond the behavioral protocol.

## Core Concepts

### Actors
**Definition**: Anything having behavior - "It must be able to execute an IF statement"

**Four Flavors**:
1. **System under discussion (SuD)** - The system being designed
2. **Internal actors** - Subsystems and objects within the SuD
3. **Primary actor** - External actor whose goal drives the use case
4. **Secondary actors** - External actors providing services to SuD

**Key Insight**: "Actors are important at two points: beginning of requirements gathering and just before system delivery. Between those two points, they become remarkably unimportant."

**Why Actors Become Unimportant**: 
- Multiple actors often share same goals
- Generic role names emerge ("order taker", "invoice producer")
- The goals matter more than who executes them

### Stakeholders
**Definition**: Someone with vested interest in system behavior, even without direct interaction

**Critical Principle**: Every system action should protect or further a stakeholder's interest

**Examples**:
- Bank board of directors (for ATM)
- Government regulators
- System owners
- Affected departments

**The Stakeholders & Interests Model**:
- Use case = agreement between stakeholders about behavior
- Success scenario = all interests satisfied
- Failure scenario = all interests protected
- More accurate than just Actors & Goals model

### Design Scope

**Definition**: The extent of what you're designing vs. what already exists

**Three Standard Scopes**:
1. **Corporate/Organization** - Entire company as black box
2. **System** - The specific hardware/software being built  
3. **Subsystem** - Internal component (rarely used for use cases)

**The Printer Story** (War Story):
Team assumed small laser printer in design scope. Reality: huge chain printer with 2-day batch magnetic tape interface already existed outside scope. Lesson: Clarify scope or your estimate might be off by factor of 2+.

**Best Practice**: Label EVERY use case with its design scope

### Goal Levels

**Three Critical Levels**:

1. **Strategic ("White")**
   - Multiple user goals
   - Hours/days/weeks/months to complete
   - Shows context and life-cycle sequencing
   - Typically 5-7 per large system

2. **User Goal ("Blue"/"Sea Level")**
   - Elementary business process
   - 2-20 minutes to complete
   - The "sweet spot" for requirements
   - Test: "Can I ask for a raise if I do many?"
   - Test: "Can I go to lunch after?"
   - Test: "Does job performance depend on how many?"

3. **Subfunction ("Indigo"/"Black")**
   - Below user goals
   - "Underwater" - avoid writing these
   - Include only when needed for clarity
   - "Find customer", "Save file", "Log in"

**The 100-Page Story**: Company sent 100+ pages of underwater use cases. Replaced with 6 user-goal cases - everyone found them easier to understand and work with.

## Writing Principles

### Manage Precision and Energy

**Four Stages of Precision**:
1. **Actors & Goals** (1-bit precision)
   - Just the list
   - Review for completeness
   - Prioritize and assign

2. **Main Success Scenarios** (2nd level)
   - Stakeholders, trigger, main flow
   - Easy to draft
   - Validates stakeholder interests

3. **Failure Conditions** (3rd level)
   - Brainstorm all failures
   - Don't detail handling yet
   - Takes significant energy

4. **Failure Handling** (4th level)
   - How system responds
   - Often reveals hidden requirements
   - Most energy-intensive

**Key Principle**: "Save your energy. If you try to write down all details at first sitting, you won't move from topic to topic in timely way."

### Your Use Case is Not My Use Case

**Tolerance**: How much variation between use cases is acceptable?

**Formality/Ceremony Factors**:
- Team size
- Geographic distribution  
- System criticality
- Domain complexity
- Regulatory requirements

**Template Choice**:
- **Casual** - Low ceremony, small teams, low criticality
- **Fully Dressed** - High ceremony, large teams, high criticality

**Jim Sawyer Quote**: "As long as templates don't feel so formal that you get lost in recursive descent that worm-holes its way into design space. If that starts to occur, strip the little buggers naked and start telling stories and scrawling on napkins."

## Writing Style Guidelines

### Core Writing Rules

1. **Show Intent, Not Mechanism**
   - Bad: "User clicks submit button"
   - Good: "User submits order"

2. **Goal-Achieving Steps**
   - Each step moves process forward
   - Each step has a purpose
   - 3-11 steps per scenario ideal

3. **Sentence Formats**:
   - "Actor does/requests something"
   - "System validates something"
   - "System updates state"
   - "Actor has Actor2 do something"

4. **Avoid UI Descriptions**
   - Focus on goals and outcomes
   - UI details go in UI specifications

### Extensions (Failure Handling)

**Brainstorming Approach**:
1. List all conceivable failures first
2. Include only system-detectable failures
3. Rationalize and reduce list
4. Then write handling scenarios

**Extension Format**:
```
3a. Condition that system can detect:
    3a1. Recovery or failure step
    3a2. Continue with step X or fail
```

## Common Anti-Patterns

### Writing Level Problems
- **Too Low**: "Find tab key", "Click mouse"
- **Underwater**: Below user goals, cluttering document
- **Too High**: "Achieve world peace" 
- **Mixed Levels**: Strategic and subfunction in same scenario

### Scope Confusion
- Not labeling design scope
- Mixing internal and external actors
- Unclear system boundaries
- Secondary actors inside scope

### Actor Confusion
- Stakeholders as primary actors
- Missing time-based triggers
- Over-focus on exact actor names
- "System displays" instead of intent

### Scenario Problems
- UI mechanism instead of intent
- Missing stakeholder protections
- Scenarios too long (>11 steps)
- Not checking failure conditions

## Advanced Concepts

### System-in-Use Story
**Purpose**: Warm-up exercise before writing use cases

**Example (ATM FAST CASH)**:
"Mary, taking her two daughters to daycare on way to work, drives up to ATM, runs card across reader, enters PIN, selects FAST CASH, enters $35. ATM issues $20 and three $5 bills, plus receipt showing balance. Mary likes FAST CASH because it avoids many questions that slow interaction. She comes to this ATM because it issues $5 bills for daycare."

**Value**: Shows context, motivations, specific needs that guide design

### Business vs System Use Cases

**Business Use Cases**:
- Corporate scope
- Often white-box (show departments)
- Strategic level common
- No UI, just business process

**System Use Cases**:
- Software/hardware scope
- Usually black-box
- User-goal level dominant
- Include UI goals/intents

### Parameterized Use Cases
For varying data or rules that don't affect flow, use parameters rather than multiple use cases.

### Technology Variations
Defer technology choices (web vs. thick client, payment types) to a "Technology Variations" section rather than cluttering scenarios.

## Use Case Formats

### Casual Format Example
```
Buy Something
Requestor initiates request to Approver. Approver checks budget and price, completes for submission, sends to Buyer. Buyer finds vendor, Authorizer validates signature. Buyer initiates PO. Vendor delivers goods, Receiver registers delivery to Requestor.

Requestor can change/cancel anytime before receipt.
```

### Fully Dressed Template Sections
- Use Case Name & Number
- Context of Use
- Scope
- Level  
- Preconditions
- Success End Condition
- Failed End Protection
- Primary Actor
- Trigger
- Main Success Scenario
- Extensions
- Sub-variations
- Project Information (priority, frequency, etc.)
- Open Issues

## Project Standards Recommendations

### For Different Project Types

**Small, Low-Ceremony (2-6 people)**:
- Casual template
- High tolerance for variation
- Focus on goals and main scenarios
- Skip extensive failure handling

**Large, High-Stakes**:
- Fully dressed template
- Low tolerance (strict standards)
- Complete failure handling
- Multiple reviews

**Business Process Projects**:
- Corporate scope
- White-box acceptable
- Focus on department interactions
- Strategic level important

## Cockburn's Key Insights

**On Completeness**: "Even mediocre use cases are useful, more useful than many competing requirements files."

**On Actors**: "It is really the goals we are after. Actors are only there to help find all use cases."

**On Levels**: "People write too many use cases at too low a level. A really large system might have seven use cases." (referring to white level)

**On Energy**: "Managing precision to which you work is therefore priority in how you work."

**On Variation**: "Not all projects need same precision, not all need templates filled same way."

**The Ever-Unfolding Story**: "Our task is to write this 'ever-unfolding story' in such a way that reader can read, understand, and move around in it."

## Practical Application Tips

1. **Start with In/Out List** to clarify scope
2. **Brainstorm actors first**, then goals - gets better coverage
3. **Write a few white use cases** for context
4. **Keep 90% at blue level** for requirements
5. **Let failures emerge** from success scenario
6. **Test with outsiders** - can they understand?
7. **Iterate precision** - don't perfect too early

---

*"Use cases are fundamentally an exercise in writing natural language essays, with all the difficulties in articulating 'good' that comes with natural language prose writing in general."* - Alistair Cockburn