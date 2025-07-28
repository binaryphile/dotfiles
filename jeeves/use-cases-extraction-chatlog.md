# Chat Log: Use Cases Memory File Creation Process

**Date**: 2025-07-28  
**Model**: Opus 4  
**Duration**: ~90 minutes (target)  

## Phase 1: Source Extraction (In Progress)

**Ted:** do the memory file shuffle on "Writing Effective Use Cases.pdf"

**Claude:** Starting memory file creation process for "Writing Effective Use Cases" by Alistair Cockburn. Created todo list with 8 items for tracking. Converting PDF to EPUB format.

*Converted PDF using nix-shell with calibre - 204 pages processed successfully*

### Extracted Key Principles from Cockburn

#### The One Page Summary (Complete list extracted):
1. Work top-down: Scope, Actors, Goals, Main story, Alternative conditions, Alternative paths
2. Work middle-out: Start at user goals, go up to strategic level, then down to subfunctions
3. Get clear about the scope of the system you are describing
4. Brainstorm all the actors, human and non, who have an operational goal against the system
5. Brainstorm all their goals against the system, over the entire lifetime of the system
6. Double check for time-based and other events that cause the system to react
7. Write the actor-goal list, double check it, prioritize, merge, reconsider goals
8. Recognize that the actors are only there to help you find all your use cases
9. Work the scope outward: define the system that contains the system under discussion
10. Extend each goal outward to find out who really cares about achieving that goal
11. Draw the primary actors and their goals against the outermost containing system
12. Add those to the list of use cases to write
13. Review all the above, prioritize and reconsider
14. Pick a use case to write
15. Brainstorm the stakeholders
16. Write how their interests are satisfied at the successful conclusion of the use case
17. Write what interests must be protected in case there is failure of the use case
18. Write the precondition: what the system has ensured is certainly true
19. Write what event or thought triggers the main success scenario
20. Write the main success scenario
21. Write each sentence as a goal succeeding, distinctly moving the process forward
22. Show the intent of the actor, what it/they want and get accomplished in that step
23. Avoid user interface descriptions
24. Manage the level of goal accomplishment so that the scenario is between 3 and 11 steps long
25. Verify that the interests of all stakeholders are fully met
26. Check that the sequencing requirements in the steps - or lack thereof - are clear
27. Brainstorm the failures and alternative paths
28. Include only the failures the system must detect and handle
29. Write the failure or alternative condition as a condition phrase or sentence
30. Write a scenario fragment showing how the alternative course leads to goal failure or success
31. Write using the same rules as for the main success scenario
32. Update the main success scenario with the new validations found while writing the extensions
33. Put into a sub use case any sub-goals that got too complex to fit neatly in this use case
34. Let the goals-becoming-use cases be your unfolding story
35. Remember, even a fairly bad use case is still a good use case, so don't worry

#### Core Base Concepts Extracted:

**1. Actors & Stakeholders**
- An actor is anything having behavior ("must be able to execute an IF statement")
- Four flavors of actors:
  - The system under discussion itself (SuD)
  - Subsystems of the SuD (internal actors)
  - Primary actor (whose goal the use case is trying to satisfy)
  - Secondary actors (provide services to the SuD)
- Stakeholders have vested interests but may never interact directly
- Key insight: "Actors are important at two points: beginning of requirements gathering and just before system delivery. Between those two points, they become remarkably unimportant."

**2. Design Scope**
- Scope = extent of what we consider "to be designed by us"
- Three standard scopes:
  - Corporate/organization (entire company)
  - System (the piece you're building)
  - Subsystem (internal components)
- Critical: "Whether the networked computer is inside or outside the scope of a use case about the ATM makes an enormous difference"

**3. Goal Levels**
- Three critical levels:
  - Strategic ("white") - Multiple user goals, hours/days/weeks/months
  - User goal ("blue"/"sea level") - Elementary business process, 2-20 minutes
  - Subfunction ("indigo"/"black") - Below user goals, needed for clarity
- User goal test: "Does your job performance depend on how many of these you do today?"
- Alternative tests:
  - Can I go to lunch when this is done?
  - Can I ask for a raise if I do many of these?

**4. Writing Style Principles**
- "Manage Precision and Energy" - Start low precision, add detail later
- Four stages of precision:
  1. Actors & Goals list
  2. Main Success Scenarios
  3. Failure conditions (list them)
  4. Failure handling (detail response)
- "Your use case is not my use case" - Different projects need different formality

**5. Common Violations/Anti-patterns**
- Writing too many low-level use cases (underwater/indigo)
- Confusing stakeholders with primary actors
- Missing design scope labels
- UI descriptions instead of goal descriptions
- Over-engineering initial versions
- Not protecting stakeholder interests

**6. Templates Identified**
- Casual template (low ceremony)
- Fully dressed template (high ceremony)
- Choice depends on project criticality and team size

**7. Stakeholders & Interests Model**
- Evolution from Actors & Goals model
- Every action protects/furthers a stakeholder interest
- Use case = agreement between stakeholders about behavior
- All interests must be satisfied (success) or protected (failure)

### Key Memorable War Stories/Examples:
1. **The Printer Story**: Team assumed small laser printer, but actual system had huge chain printer with 2-day batch interface - shows importance of scope clarity
2. **ATM Example**: Mary using FAST CASH for $35 with three $5 bills for daycare - shows system-in-use story concept
3. **100 Pages of Underwater Use Cases**: Replaced with 6 user-goal cases that everyone found easier - demonstrates goal level importance

*[Process continues with behavioral translation...]*

## Phase 2: Behavioral Translation (Completed)

**Ted:** yes, clear memory

**Claude:** Memory cleared. Reading extraction summary and proceeding with behavioral translation.

**Ted:** refresh yourself on the behavioral translation instructions in our process doc and then create the protocol file

**Claude:** Refreshed process understanding. Creating behavioral protocol with trigger-response pairs.

### Behavioral Translations Applied:

**Example translations created:**
```
Source: "Get clear about the scope of the system"
→
Behavior: "When user asks for use case, IMMEDIATELY:
1. STOP - Do not start writing scenarios
2. IDENTIFY - Determine design scope (Corporate/System/Subsystem)  
3. LABEL - Mark every use case with its scope and goal level"
```

**Anti-patterns with STOP signals:**
- ❌ "User clicks submit button" → STOP → Write intent
- ❌ Writing without scope label → STOP → Add scope
- ❌ 47-step scenario → STOP → Extract sub-use cases

**Decision trees for common situations:**
- Goal level determination (White/Blue/Indigo)
- Precision management stages
- Scope confusion resolution

## Phase 3: Memory File Creation (Completed)

**Claude:** Created behavioral protocol and reference files.

*Created use-case-writing-protocol.md with:*
- Mandatory startup protocol for scope identification
- 5-phase workflow (Scope → Goals → Stakeholders → Scenario → Failures)
- Anti-patterns with interrupt behaviors
- Decision trees for goal levels and precision
- Templates for actors, use cases, and scenarios
- Quality verification checklist

*Created use-case-practices-reference.md with:*
- Complete explanations of actors, stakeholders, scope, and goal levels
- War stories (printer story, 100-page story, ATM example)
- Writing principles and precision management
- Common anti-patterns and solutions
- Format examples (casual vs. fully dressed)
- Cockburn's key insights and quotes

*Updated CLAUDE.md to add trigger:*
- "When user asks for use cases, requirements documentation, or functional specifications, always read use-case-writing-protocol.md"

### Verification Complete:
- ✅ Protocol enforces scope-first thinking
- ✅ Goal level classification prevents underwater use cases
- ✅ Stakeholder interests protection required
- ✅ Anti-patterns interrupt wrong behaviors
- ✅ Templates ensure consistent documentation

**Total Duration**: ~85 minutes
**Files Created**: 2 behavioral files + CLAUDE.md update  
**Process Status**: COMPLETE