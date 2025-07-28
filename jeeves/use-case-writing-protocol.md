# Use Case Writing Behavior Protocol

## 🛑 MANDATORY STARTUP
When user asks for use case or requirements documentation, IMMEDIATELY:
1. **STOP** - Do not start writing scenarios
2. **IDENTIFY** - Determine design scope (Corporate/System/Subsystem)
3. **LABEL** - Mark every use case with its scope and goal level

## 📋 USE CASE DEVELOPMENT PHASES

### Phase 1: SCOPE & ACTORS
**Actions**:
- [ ] Define system boundaries - what's IN vs OUT of design scope
- [ ] Brainstorm ALL actors with operational goals
- [ ] Include time-based triggers as actors
- [ ] Create Actor List with name and characterization

**Gate**: Can you name the system and draw its boundary?
→ No: STOP → Clarify with in/out list technique
→ Yes: Proceed to Phase 2

### Phase 2: GOALS DISCOVERY
**Actions**:
- [ ] List all actor goals over system lifetime
- [ ] Apply user goal test: "Can I ask for a raise if I do many?"
- [ ] Apply lunch test: "Can I go to lunch when done?"
- [ ] Classify goals: White (strategic) / Blue (user) / Indigo (subfunction)
- [ ] Create Actor-Goal list

**Gate**: Are most goals at "blue" (user goal) level?
→ No: STOP → Refactor underwater goals up, overly strategic goals down
→ Yes: Proceed to Phase 3

### Phase 3: STAKEHOLDER ANALYSIS
**Actions**:
- [ ] Identify ALL stakeholders (not just actors)
- [ ] List each stakeholder's interests
- [ ] Document what must be protected on failure
- [ ] Check: Does every system action protect an interest?

**Gate**: Are all stakeholder interests covered?
→ No: Add missing validations and protections
→ Yes: Proceed to Phase 4

### Phase 4: MAIN SUCCESS SCENARIO
**Actions**:
- [ ] Write trigger event/condition
- [ ] Write preconditions (what's guaranteed true)
- [ ] Write 3-11 steps showing goal achievement
- [ ] Each step shows actor intent, not UI mechanics
- [ ] Verify all stakeholder interests satisfied

**Gate**: Scenario between 3-11 meaningful steps?
→ No: Combine small steps or extract sub-use cases
→ Yes: Proceed to Phase 5

### Phase 5: FAILURE HANDLING
**Actions**:
- [ ] Brainstorm ALL failure conditions first
- [ ] Include only failures system must detect
- [ ] Write condition as detectable phrase
- [ ] Write recovery/failure scenario fragments
- [ ] Update main scenario with discovered validations

**Gate**: All system-detectable failures handled?
→ No: Add missing failure scenarios
→ Yes: Use case complete

## 🚫 ANTI-PATTERNS

❌ "User clicks the submit button"
→ STOP → Write intent: "User submits order"

❌ "System displays error message"
→ STOP → Write outcome: "System informs user of invalid data"

❌ Writing without scope label
→ STOP → Add "Scope: [System Name]" to every use case

❌ "The owner of the vending machine..."
→ STOP → Owner is stakeholder, not actor (unless refilling machine)

❌ 47-step scenario
→ STOP → Extract sub-use cases for complex sequences

❌ "Log in" as a complete use case
→ STOP → Not a user goal - fold into real goal

## 🔄 DECISION TREES

### Goal Level Decision
```
What level is this goal?
├─ Multiple user sessions? → White (strategic)
├─ 2-20 minute task? → Blue (user goal)
└─ Part of another task? → Indigo (subfunction)
```

### Precision Decision
```
What stage of requirements?
├─ Initial scoping? → Actor-Goal list only
├─ Validation needed? → Main scenarios only
├─ Full specification? → Add all failure handling
└─ High ceremony project? → Use fully dressed template
```

### Scope Confusion Resolution
```
Actor location unclear?
├─ Draw nested boxes for scopes
├─ Place actor outside their system
└─ Label every use case with scope
```

## 📝 TEMPLATES

### Actor-Goal List Entry
```
ACTOR: [Role/System Name]
CHARACTERIZATION: [Skills, frequency, expertise]
GOALS:
- [Blue] Goal name (priority)
- [White] Strategic goal name
```

### Use Case Header
```
USE CASE: [Number] [Name]
Scope: [Corporate|SystemName|Subsystem]
Level: [White|Blue|Indigo]
Primary Actor: [Name]
Stakeholders & Interests:
- [Stakeholder]: [Interest to protect]
Precondition: [What's guaranteed true]
Trigger: [Event that starts use case]
```

### Scenario Step Format
```
[Number]. [Actor] [does something with intent] [achieving sub-goal]
```

## ✅ QUALITY VERIFICATION

Before declaring use case complete:
- [ ] Scope clearly identified and labeled?
- [ ] 90% of use cases at blue level?
- [ ] Each step shows intent, not mechanism?
- [ ] All stakeholder interests protected?
- [ ] Failures that must be detected are handled?
- [ ] Would "fairly bad" version still be useful?

## 🎯 REMEMBER

**Cockburn's Reassurance**: "Even mediocre use cases are useful, more useful than many competing requirements files being written. So relax, write something readable, and you will have done your organization a service already."

**The Ever-Unfolding Story**: Let the goals-becoming-use cases be your ever-unfolding story. Your task is to write this story so readers can understand and navigate it.

**Precision Management**: Save your energy. Low precision first (actor-goal list), add detail only as needed. High precision too early wastes effort if goals are wrong.

*If there is any question, read use-case-practices-reference.md for details on use case
writing practices.*
