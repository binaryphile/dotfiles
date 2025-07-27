# Agans' Debugging Methodology Guide

## Overview

This guide provides a practical reference for applying David J. Agans' nine debugging rules. These rules form a systematic approach to debugging any system - from software to hardware to everyday problems. The methodology emphasizes looking at actual failures rather than theorizing about causes.

## The Nine Rules (In Order)

1. **Understand the System** - Read the manual first
2. **Make It Fail** - Reproduce the problem consistently  
3. **Quit Thinking and Look** - Observe actual behavior, don't theorize
4. **Divide and Conquer** - Binary search to isolate the problem
5. **Change One Thing at a Time** - Maintain predictability
6. **Keep an Audit Trail** - Document everything
7. **Check the Plug** - Verify basic assumptions
8. **Get a Fresh View** - Ask for help when stuck
9. **If You Didn't Fix It, It Ain't Fixed** - Verify the solution

---

## Rule 1: Understand the System

**Core Principle:** This is the first rule because it's the most important. The answer might already be documented.

### Key Actions:
- **Read the manual** - Before using, before debugging
- **Read everything in depth** - The critical detail is often buried
- **Know the fundamentals** - Understand normal behavior
- **Know the road map** - Understand system architecture and data flow
- **Understand your tools** - Master your debugging tools
- **Look up the details** - Don't trust memory for specifics

### Practical Steps:
1. Read all documentation (manuals, specs, code comments)
2. Understand what SHOULD happen before investigating what DID happen
3. Review design documents, APIs, interfaces
4. Look for known issues or errata
5. Don't trust documentation completely, but know what was intended

### Common Violations:
- Debugging without reading error messages carefully
- Assuming you know how something works
- Not checking if it's a known bug

---

## Rule 2: Make It Fail

**Core Principle:** You need to see the failure to understand it. Make it fail consistently and on demand.

### Three Reasons to Make It Fail:
1. So you can look at it
2. So you can focus on the cause
3. So you can tell if you've fixed it

### Key Actions:
- **Do it again** - One failure isn't enough
- **Start at the beginning** - From a known, clean state
- **Stimulate the failure** - Don't wait for natural conditions
- **But don't simulate the failure** - Use the actual failing system
- **Find the uncontrolled condition** - For intermittent bugs
- **Record everything** - Find failure signatures
- **Don't trust statistics too much** - Look deeper than correlations
- **Know that "that" can happen** - Accept unexpected data
- **Never throw away a debugging tool** - Keep your test setups

### Practical Steps:
1. Document exact reproduction steps
2. Start from a clean/rebooted state
3. Automate the reproduction if possible
4. For intermittent bugs, vary all conditions systematically
5. Keep detailed logs of each attempt

### Common Violations:
- Trying to fix before reproducing
- Using a "similar" system instead of the actual one
- Not documenting the exact steps

---

## Rule 3: Quit Thinking and Look

**Core Principle:** You can think up thousands of possible reasons for a failure. You can see only the actual cause.

### Key Actions:
- **See the failure** - Not just the result, but the actual failure
- **See the details** - Look deeper until causes are limited
- **Build instrumentation in** - Design with debugging in mind
- **Add instrumentation on** - Use external tools when needed
- **Don't be afraid to dive in** - It's broken anyway
- **Watch out for Heisenberg** - Your tools affect the system
- **Guess only to focus the search** - Then verify by looking

### Practical Steps:
1. Add logging/instrumentation before theorizing
2. Watch the actual failure happen
3. Use debug modes, logging, breakpoints
4. Add timestamps and detailed state information
5. Verify the bug still occurs after adding instrumentation

### Common Violations:
- Theorizing about causes without evidence
- Fixing based on assumptions
- Not instrumenting enough to see the problem

---

## Rule 4: Divide and Conquer

**Core Principle:** Binary search the problem space. Cut the hiding place in half repeatedly.

### Key Actions:
- **Narrow with successive approximation** - Like guessing 1-100 in 7 tries
- **Get the range** - Know the system boundaries
- **Determine which side of the bug you are on** - Upstream or downstream
- **Use easy-to-spot test patterns** - Make problems obvious
- **Start with the bad** - Work upstream from the failure
- **Fix the bugs you know about** - They hide each other
- **Fix the noise first** - Eliminate confounding factors

### Practical Steps:
1. Start with the whole system as your range
2. Test at the midpoint
3. Determine if the problem is before or after
4. Repeat until isolated
5. Use distinctive test data (00 55 AA FF patterns)

### Common Violations:
- Random searching instead of systematic
- Not fixing known problems first
- Testing with confusing data

---

## Rule 5: Change One Thing at a Time

**Core Principle:** Maintain predictability. Use a rifle, not a shotgun.

### Key Actions:
- **Isolate the key factor** - Control all variables but one
- **Grab the brass bar with both hands** - Don't panic and change everything
- **Change one test at a time** - Know what caused the effect
- **Compare it with a good one** - Use working vs failing cases
- **Determine what changed since it last worked** - Focus on recent changes

### Practical Steps:
1. Document baseline behavior
2. Change exactly one thing
3. Test and document result
4. Revert changes that don't help
5. Keep detailed change log

### Common Violations:
- Making multiple changes at once
- Not reverting failed attempts
- Changing test conditions while debugging

---

## Rule 6: Keep an Audit Trail

**Core Principle:** Write down what you did, in what order, and what happened. The shortest pencil is longer than the longest memory.

### Key Actions:
- **Write down everything** - Actions, order, results
- **Any detail could be important** - Even shirt color
- **Correlate events** - Use timestamps
- **Be specific** - "4-second noise at 21:04:53"
- **Design audit trails help testing** - Version control reveals when bugs appeared

### Practical Steps:
1. Keep a debugging log/notebook
2. Timestamp all events
3. Record exact commands/actions
4. Note environmental conditions
5. Save all logs and outputs

### Format Example:
```
[timestamp] Action: Started server with flags -v -d
[timestamp] Observation: Crash after 3.2 seconds
[timestamp] Change: Added memory logging
[timestamp] Result: Shows buffer overflow at line 234
```

### Common Violations:
- Relying on memory
- Vague descriptions
- Not correlating events in time

---

## Rule 7: Check the Plug

**Core Principle:** Obvious assumptions are often wrong. These bugs are usually the easiest to fix.

### Key Actions:
- **Question your assumptions** - Is it plugged in?
- **Start at the beginning** - Check initialization
- **Test the tool** - Your debugging tools might be broken

### Common Assumptions to Check:
- Power/connectivity
- Correct version/environment
- Initialization completed
- Tools working correctly
- File permissions
- Network connectivity

### Practical Steps:
1. List all assumptions
2. Verify each one explicitly
3. Test your test tools
4. Check the most basic things first

### Common Violations:
- Assuming the obvious is correct
- Not verifying tool configuration
- Skipping "simple" checks

---

## Rule 8: Get a Fresh View

**Core Principle:** Fresh eyes see things you've become blind to. Don't be proud.

### Key Actions:
- **Ask for fresh insights** - Even explaining helps
- **Tap expertise** - Use specialists
- **Listen to experience** - "It's always the dome light wire"
- **Know help is available** - Vendors, forums, colleagues
- **Don't be proud** - Asking shows eagerness to fix
- **Report symptoms, not theories** - Don't bias helpers
- **You don't have to be sure** - Mention the plaid shirt

### Practical Steps:
1. Prepare clear symptom description
2. Avoid theory contamination
3. Include "irrelevant" details
4. Try rubber duck debugging
5. Engage appropriate experts

### Common Violations:
- Working alone too long
- Explaining theories instead of symptoms
- Pride preventing asking for help

---

## Rule 9: If You Didn't Fix It, It Ain't Fixed

**Core Principle:** Verify your fix actually fixed the problem. Bugs don't just go away.

### Key Actions:
- **Check that it's really fixed** - Test with original failure case
- **Check it's YOUR fix** - Toggle fix on/off
- **It never just goes away** - Find what changed
- **Fix the cause** - Not just the symptom
- **Fix the process** - Prevent future occurrences

### Verification Sequence:
1. Confirm bug exists
2. Apply fix
3. Confirm bug is gone
4. Remove fix
5. Confirm bug returns
6. Reapply fix
7. Confirm bug is gone

### Common Violations:
- Not testing the fix
- Fixing symptoms not causes
- Believing bugs disappear
- Not understanding why fix works

---

## Quick Reference Debugging Process

### Phase 1: UNDERSTAND (Before ANY investigation)
- [ ] Read relevant documentation
- [ ] Check for known issues
- [ ] Understand normal behavior
- [ ] Identify system architecture

**Decision Gate**: Can I explain what SHOULD happen? → No: Keep reading → Yes: Phase 2

### Phase 2: REPRODUCE (Make It Fail)
- [ ] Get exact reproduction steps
- [ ] Start from clean state
- [ ] Execute reproduction
- [ ] Document the failure
- [ ] Repeat for consistency

**Decision Gate**: Can I make it fail on demand? → No: Find reliable reproduction → Yes: Phase 3

### Phase 3: INVESTIGATE (Systematic Search)
- [ ] SEE the actual failure
- [ ] Add instrumentation
- [ ] Use binary search
- [ ] Change ONE thing at a time
- [ ] Document each test

**Decision Gate**: Do I know the root cause? → No: More instrumentation → Yes: Phase 4

### Phase 4: VERIFY (Confirm Fix)
- [ ] Implement fix
- [ ] Test with original steps
- [ ] Toggle fix off/on
- [ ] Check for side effects
- [ ] Document solution

**Decision Gate**: Is it actually fixed? → No: Return to Phase 3 → Yes: Complete

---

## Common Anti-Patterns to Avoid

1. **"I think the problem might be..."** → STOP: Have you SEEN the failure yet?
2. **"Try changing X, it might help..."** → STOP: Are you changing one thing at a time?
3. **"This is probably caused by..."** → STOP: Show me the instrumentation that proves this
4. **"The error suggests..."** → STOP: Error messages lie. What does the BEHAVIOR show?
5. **"In my experience, this type of issue..."** → STOP: Every bug is unique. Start with THIS bug's symptoms

---

## Remember

When debugging:
1. **Look, don't think** - Data beats theories
2. **Document everything** - Memory is unreliable
3. **Be systematic** - Random changes waste time
4. **Verify assumptions** - The obvious is often wrong
5. **Get help** - Fresh perspectives are valuable
6. **Verify fixes** - Hope is not a debugging strategy

The key to successful debugging is replacing guesswork with observation and maintaining a systematic, documented approach throughout the process.