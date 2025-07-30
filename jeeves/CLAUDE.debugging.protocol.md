# Claude Debugging Behavior Protocol

## CRITICAL: This document modifies Claude's debugging behavior. Follow these protocols EXACTLY.

---

## 🛑 MANDATORY STARTUP PROTOCOL

When user mentions any bug, error, or debugging need, IMMEDIATELY:

1. **STOP** - Do not theorize about causes
2. **ASK** - "Can you show me how to reproduce this issue?"
3. **DOCUMENT** - Start lab notebook entry:
   ```
   ## Issue: [Brief description]
   ### Reproduction Steps:
   1. [Waiting for user input...]
   ```

**VIOLATION CHECK**: If you suggested a cause before seeing the failure → You violated Rule 3. Start over.

---

## 📋 DEBUGGING SESSION PHASES

### Phase 1: UNDERSTAND (Before ANY investigation)
**Required Actions**:
- [ ] Read relevant documentation/README
- [ ] Check for known issues in docs and JIRA tickets
- [ ] Understand normal system behavior
- [ ] Identify system architecture/data flow

**Decision Gate**: Can I explain what SHOULD happen? 
- No → Keep reading documentation
- Yes → Proceed to Phase 2

### Phase 2: REPRODUCE (Make It Fail)
**Required Actions**:
- [ ] Get exact reproduction steps from user
- [ ] Start from clean/known state
- [ ] Execute reproduction steps
- [ ] Observe and document the failure
- [ ] Repeat to ensure consistency

**Decision Gate**: Can I make it fail on demand?
- No → Work with user to find reliable reproduction
- Sometimes → Find the varying condition
- Yes → Proceed to Phase 3

### Phase 3: INVESTIGATE (Systematic Search)
**Required Actions**:
- [ ] SEE the actual failure (not just the end result)
- [ ] Add instrumentation/logging
- [ ] Use binary search to isolate
- [ ] Change ONE thing at a time
- [ ] Document each test and result

**Decision Gate**: Do I know the root cause?
- No → Add more instrumentation and continue search
- Maybe → Test hypothesis by toggling the condition
- Yes → Proceed to Phase 4

### Phase 4: VERIFY (Confirm Fix)
**Required Actions**:
- [ ] Implement fix
- [ ] Test with original reproduction steps
- [ ] Remove fix and confirm failure returns
- [ ] Re-apply fix and confirm success
- [ ] Check for side effects

**Decision Gate**: Is it actually fixed?
- No → Return to Phase 3
- Yes → Document solution and root cause

---

## 🚫 ANTI-PATTERNS (STOP if you catch yourself doing these)

### ❌ "I think the problem might be..."
**STOP** → Have you SEEN the failure yet? No? → Go to Phase 2

### ❌ "Try changing X, it might help..."
**STOP** → Are you changing one thing at a time? Have you verified current state? → Go to Phase 3

### ❌ "This is probably caused by..."
**STOP** → Show me the instrumentation that proves this → Add logging first

### ❌ "The error suggests..."
**STOP** → Error messages lie. What does the BEHAVIOR show? → Instrument and observe

### ❌ "In my experience, this type of issue..."
**STOP** → Every bug is unique. Start with THIS bug's specific symptoms → Phase 2

---

## 📓 LAB NOTEBOOK TEMPLATE (Use for EVERY debugging session)

```markdown
## Issue: [One line description]
**Date**: [timestamp]
**Reporter**: [user]

### Reproduction Steps
1. Starting state: [describe clean state]
2. Action: [exact command/operation]
3. Expected: [what should happen]
4. Actual: [what actually happens]

### Investigation Log
[timestamp] Checked documentation: [what you looked for]
[timestamp] Instrumentation added: [what you added where]
[timestamp] Test 1: [what you did] → Result: [what happened]
[timestamp] Test 2: [change made] → Result: [new behavior]

### Root Cause
[Explain the actual problem, not the symptom]

### Fix
[Exact changes made]

### Verification
- [ ] Original repro steps now work correctly
- [ ] Toggled fix off/on to confirm
```

---

## 🔄 DECISION TREES

### "User reports problem"
```
Can you reproduce it?
├─ No → Get reproduction steps (Phase 2)
├─ Sometimes → Find varying condition (Phase 2)
└─ Yes → Have you seen actual failure?
    ├─ No → Add instrumentation (Phase 3)
    └─ Yes → Begin binary search (Phase 3)
```

### "Found suspicious code/condition"
```
Is this a guess or observation?
├─ Guess → Add instrumentation to confirm
└─ Observation → Can you toggle it?
    ├─ No → Find way to control it
    └─ Yes → Does toggling change behavior?
        ├─ No → Not the cause, keep looking
        └─ Yes → Verify fix properly (Phase 4)
```

---

## 🎯 BEHAVIORAL MODIFICATIONS

1. **Replace theorizing with looking**
   - Old: "This might be a race condition"
   - New: "Let me add logging to see the actual execution order"

2. **Replace broad changes with narrow tests**
   - Old: "Try updating all the dependencies"
   - New: "Let me isolate which component is failing first"

3. **Replace assumptions with verification**
   - Old: "The initialization probably worked"
   - New: "Let me verify the initialization completed successfully"

4. **Replace memory with documentation**
   - Old: "I remember this API works like..."
   - New: "Let me check the current API documentation"

---

## 🔍 INSTRUMENTATION CHECKLIST

Before saying "I don't know what's happening":

- [ ] Added entry/exit logging to suspect functions?
- [ ] Logged all parameter values?
- [ ] Checked return values and error codes?
- [ ] Added timestamps to see sequence?
- [ ] Verified assumptions about state?
- [ ] Looked at actual data, not just code?

---

## 📝 SESSION DOCUMENTATION REQUIREMENTS

**Every debugging session MUST produce**:
1. Reproduction steps that Ted can follow independently
2. Clear description of actual vs expected behavior  
3. Systematic investigation log showing each test
4. Root cause explanation (not just symptom)
5. Verification that fix actually works

**Format**: Lab notebook style - another developer should be able to recreate your entire debugging process from your notes alone.

---

## 🚨 EMERGENCY PROTOCOLS

### "I'm stuck"
1. STOP guessing
2. Return to Phase 1 - what don't you understand?
3. Get fresh perspective (Rule 8)
4. Document what you've tried for next session

### "It works now but I don't know why"
1. It's NOT fixed (Rule 9)
2. Make it fail again
3. Add more instrumentation
4. Find what actually changed

### "User wants quick fix"
1. Explain: "Let me reproduce it first so we can verify the fix works"
2. Follow phases - shortcuts usually make debugging take longer
3. A proper fix is faster than multiple attempts

---

## REMEMBER: You already know Agans' 9 rules. This document makes you FOLLOW them.  If there is any question, consult the agans_debugging_guide.md file in this directory for a detailed explanation of each of the nine rules.

When in doubt: STOP THINKING AND LOOK.