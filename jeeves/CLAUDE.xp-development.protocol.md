# XP Development Behavior Protocol

## 🛑 MANDATORY STARTUP
When user requests code changes, IMMEDIATELY:
1. **STOP** - Do not write implementation code
2. **TEST** - Create failing test that specifies behavior
3. **VERIFY** - Run test, confirm it fails for right reason

## 📋 DEVELOPMENT WORKFLOW PHASES

### Phase 1: STORY DEFINITION
When user requests new feature, IMMEDIATELY:
**Actions**:
- [ ] Write user story with customer-visible value
- [ ] Define acceptance criteria  
- [ ] Get effort estimate before proceeding
- [ ] Break into tasks if needed

**Gate**: Story provides clear customer value?
→ No: STOP → Clarify business value first
→ Yes: Proceed to Phase 2

### Phase 2: TEST-FIRST DEVELOPMENT
**Actions**:
- [ ] Write failing automated test for story requirement
- [ ] Run test to confirm failure (red)
- [ ] Write minimal code to make test pass (green)
- [ ] Refactor while maintaining tests (refactor)

**Gate**: All tests passing?
→ No: STOP → Fix failing tests first
→ Yes: Proceed to Phase 3

### Phase 3: INTEGRATION & VERIFICATION
After max 2 hours of coding, IMMEDIATELY:
**Actions**:
- [ ] Integrate changes with main codebase
- [ ] Run full build and test suite
- [ ] Verify no regressions introduced
- [ ] Deploy if all tests pass

**Gate**: Full build passes in under 10 minutes?
→ No: STOP → Fix build performance or failures
→ Yes: Ready for next cycle

## 🚫 ANTI-PATTERNS

❌ "Let me code this quickly then add tests"
→ STOP → Write test first, no exceptions

❌ "This is just a small change, skip the story"
→ STOP → All changes need customer-visible value

❌ "I'll refactor later when I have time"
→ STOP → Refactor now as part of red-green-refactor

❌ "Let me add this extra feature while I'm here"
→ STOP → YAGNI (You Aren't Gonna Need It) - stick to story

❌ "The tests are passing, ship it"
→ STOP → Run full integration build first

## 🔄 DECISION TREES

### Code Quality Decision
```
Code works but is messy?
├─ Technical debt slowing team → REFACTOR immediately
├─ Code clear and simple → CONTINUE with next story  
└─ Unsure about quality → ASK for pair review
```

### Feature Scope Decision
```
User wants additional functionality?
├─ Directly supports current story → ADD to acceptance criteria
├─ Separate customer value → CREATE new story
└─ Technical nice-to-have → DEFER (YAGNI principle)
```

### Testing Strategy Decision
```
What type of test needed?
├─ User-facing behavior → ACCEPTANCE test
├─ Component interaction → INTEGRATION test  
├─ Algorithm/logic → UNIT test
└─ Performance requirement → PERFORMANCE test
```

## 📝 REQUIRED DOCUMENTATION TEMPLATES

### User Story Template
```
As a [user type]
I want [functionality]  
So that [business value]

Acceptance Criteria:
- [ ] [Specific testable condition]
- [ ] [Specific testable condition]
- [ ] [Specific testable condition]

Estimate: [Story points or time]
```

### Test-First Checklist
```
Before writing code:
□ Test written and failing
□ Test failure reason understood
□ Minimal implementation planned
□ Refactoring opportunities identified
```

### Integration Checklist  
```
Before integrating:
□ All local tests passing
□ Code reviewed (pair or async)
□ Build time under 10 minutes
□ No temporary/debug code present
□ Documentation updated if needed
```

## 🎯 SUCCESS VERIFICATION

After each development session, verify:
- [ ] Did I write tests before implementation?
- [ ] Did all work connect to customer stories?
- [ ] Did I refactor during development (not defer)?
- [ ] Did I integrate within 2 hours?
- [ ] Did I avoid gold-plating features?

## ⚡ INTERRUPTION PROTOCOLS

### When Stuck (15+ minutes)
1. **PAIR** - Ask for help or fresh perspective
2. **SIMPLIFY** - Choose simpler solution
3. **RESEARCH** - Time-box investigation to 30 minutes max

### When Requirements Unclear
1. **STOP** - Do not guess or assume
2. **ASK** - Get clarification from customer/user
3. **DOCUMENT** - Update story with new understanding

### When Tests Difficult to Write
1. **DESIGN** - Often indicates poor design, refactor first
2. **TOOLS** - May need better testing framework
3. **PAIR** - Get help with testing approach

## 🔄 WEEKLY CYCLE PROTOCOL

At start of each week:
1. **REVIEW** - Previous week's completed stories
2. **PLAN** - Select stories for upcoming week
3. **ESTIMATE** - Confirm story estimates still accurate
4. **COMMIT** - Team commits to weekly goals
5. **SLACK** - Include buffer tasks that can be dropped

## 🎯 CORE XP VALUES IN ACTION

**Simplicity**: Always ask "What's the simplest thing that could work?"
**Communication**: Over-communicate rather than assume understanding  
**Feedback**: Seek rapid feedback through tests, integration, and user review
**Courage**: Make necessary changes without fear, backed by tests
**Respect**: Respect the code, the team, and the customer's time

---

*Remember: XP is about discipline in small practices that compound into sustainable,
high-quality development.  If there is any question, read xp-development-reference.md for
details on XP practices.*
