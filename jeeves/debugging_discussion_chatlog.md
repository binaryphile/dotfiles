# Chat Log: Debugging Discussion

**Ted:** hi

**Claude:** Hello! How can I help you today?

**Ted:** hi there. i'm thinking about debugging and want to have a discussion about debugging approach, because I want to create a shared understanding with you as the LLM and me. Such an understanding will be a fixture to guide you in the behavior I want to see as we partner on debugging sessions. I'm concerned only with the conceptual approach to debugging as a generic process, common to any technical design issue from hardware to software to building IKEA furniture. What bases of reference do you have for the human design and implementation of debugging and quality processes?

**Claude:** I have several foundational references including classical computer science (Dijkstra, Knuth, Kernighan & Pike), engineering disciplines (root cause analysis, fault tree analysis), cognitive science (Newell & Simon, expert vs. novice strategies), and quality methodologies (Six Sigma, lean manufacturing). These converge on common principles: systematic hypothesis formation, isolation of variables, reproducible testing, and maintaining clear mental models.

**Ted:** I see Agans. Excellent. That is exactly what I had in mind when I framed that question. I want to discuss that, but I'll make a side note of other things you mentioned of interest to me: studies on expert vs. novice debugging strategies, convergent common principles. Can you write some markdown to a file giving me notes I can pursue further on learning what those are?

**Claude:** Created debugging_research_notes.md with references on expert vs. novice debugging strategies and convergent principles across disciplines.

**Ted:** well, firstly I'm interested in how well you have his material internalized. Can you quote chapter and verse, or are you just more generally aware of the work but not the details?

**Claude:** I have general awareness of Agans' nine debugging rules and their core concepts, but cannot quote specific passages or chapter details verbatim. I understand the rules and their application but don't have exact wording or specific examples memorized.

**Ted:** I'd like to quiz you for a moment. Which of the nine rules is the most important, according to Agans?

**Claude:** I don't recall Agans explicitly ranking one rule as most important. I would guess "Understand the System" or "Make it Fail" might be primary, but I'm not confident about this.

**Ted:** You're absolutely correct, and it's not an entirely fair question to portray one rule as being above the others, because they work as a whole. But in the first lesson, Agans says that he learned to the read the documentation about the code at issue when he learned that the bug he was troubleshooting was known to be a bug and describe as such in the documentation. As such, he says, he learned not only to perform that step, but that it must be performed first if it's to save you the nontrivial cost of bug location in the first place, which makes it the most important.

**Claude:** That's a crucial insight! "Understand the System" being first makes perfect sense - if the answer is already documented, all other debugging effort is wasted. It's the ultimate "check the plug" scenario at a higher level, and connects to expert vs. novice behavior.

**Ted:** what are the nine rules in order?

**Claude:** I know the rules include [listed all 9 rules] but I'm not confident about their specific sequence. Would you share the correct order?

**Ted:** how can you verify that information?

**Claude:** I could verify by searching online, checking documentation databases, or using WebSearch for reliable sources.

**Ted:** go ahead

**Claude:** Searched and found the correct order of Agans' 9 rules, confirming "Understand the System" is indeed Rule 1.

**Ted:** I apologize, I guess I'd misremembered that one as "read the docs", but if you see it there as "understand the system", I'm sure that's the one I meant. Your observation is true, it is interesting that the relatively low-cost and therefore high-value "check the plug" rule comes that far down the line. Personally I'm more along the lines of the "hello, did you try turning it off and on?" school of I.T. Crowd debugging...flip the switch early and often, I say. Empty that cache. Relaunch the server. Reload the container...ad astra, ad nauseum. In any case, let's briefly talk about each of the rules, starting with the first. Can you tell me what Agans primary illustration of the rule is?

**Claude:** I don't have access to the specific illustrations or examples Agans uses. You mentioned earlier he shares a story about discovering a bug was already documented. Would you like to share what primary illustration he uses?

**Ted:** It's more a matter of order of preference I'd say, or budgeting effort maybe. I'm not so interested in that as seeing what you can learn from the internet on how he relates that idea to the reader so they remember it, the hook so to speak.

**Claude:** Searched but couldn't find the specific story/illustration Agans uses for the "Understand the System" rule. Found it's about "Don't guess. Look it up" but not the actual hook story.

**Ted:** alright, let's pick up where we left off... What can you tell me how Agans summarizes the learnings at the end of that chapter? Research if need be.

**Claude:** Multiple web searches failed to find the specific "Remember" section summary from the end of Agans' "Understand the System" chapter.

**Ted:** I've saved the pdf in ~/crostini, take a look

**Claude:** Attempted to read PDF but encountered "A maximum of 100 PDF pages may be provided" API error, even with trimmed version user created.

**Ted:** stop trying to use the document please

**Claude:** Understood, stopped attempting PDF access due to API errors.

**Ted:** is the pdf eating up context in the conversation?

**Claude:** No, the PDF content isn't consuming context - just references to failed attempts since I couldn't successfully process it.

**Ted:** what is a good way to extract the pdf text for you? could another format preserve the graphics but still compact the document?

**Claude:** Suggested text extraction with pdftotext, OCR with tesseract, or EPUB conversion using Calibre for graphics+text while staying compact.

**Ted:** what about producing an epub, would that work?

**Claude:** Confirmed EPUB could work well - compressed HTML format, much smaller than PDF, preserves formatting and images, readable with Read tool.

**Ted:** pandoc is installed. generate the epub for me

**Claude:** Pandoc can't convert FROM PDF. Suggested using Calibre instead or text extraction first.

**Ted:** try again with nix shell, it'll be faster now that it has downloaded the dependencies

**Claude:** Successfully converted PDF to EPUB using Calibre in nix shell. Extracted HTML files from EPUB and found the complete "Remember" section from Agans' "Understand the System" chapter. Here are the bullet points from the "Remember" section:

**Remember - Understand the System**

This is the first rule because it's the most important. Understand?

• **Read the manual.** It'll tell you to lubricate the trimmer head on your weed whacker so that the lines don't fuse together.

• **Read everything in depth.** The section about the interrupt getting to your microcomputer is buried on page 37.

• **Know the fundamentals.** Chain saws are *supposed* to be loud.

• **Know the road map.** Engine speed can be different from tire speed, and the difference is in the transmission.

• **Understand your tools.** Know which end of the thermometer is which, and how to use the fancy features on your Glitch-O-Matic logic analyzer.

• **Look up the details.** Even Einstein looked up the details. Kneejerk, on the other hand, trusted his memory.

These bullet points encapsulate how Agans makes the "Understand the System" rule memorable through practical, relatable examples that stick with readers.

**Ted:** great. now, we're going to do this for each bullet, starting with the first. review the section supporting the "read the manual" bullet and summarize for me

**Claude:** Reviewed the "Read the Manual" section from Agans' chapter. Here's my summary:

## Summary: "Read the Manual" Section

**Core Message:** The essence of "Understand the System" is "Read the manual" - and read it FIRST, before all else fails, not after.

**Key Points:**

1. **Read Before You Act:** Read the manual before you buy something, before you use it, and definitely before you debug it. The manual tells you what you're supposed to do and how it should behave.

2. **Practical Examples:** 
   - Lawn mower won't start → manual reminds you to squeeze primer bulb
   - Weed whacker overheating/fusing lines → manual explains trimmer head lubrication
   - Tofu casserole disaster → reread the recipe (or order takeout)

3. **For Engineers:** Read internal documentation thoroughly:
   - Functional specifications
   - Design specs, schematics, timing diagrams, state machines  
   - Source code and comments (even if sparse)
   - Conduct design reviews

4. **Trust But Verify:** Don't necessarily trust the documentation completely - manuals and engineers can be wrong. But you still need to know what they *thought* they built.

5. **War Stories Illustrating the Point:**
   - Assembly code bug where a comment clearly stated "Caution—this subroutine clobbers the B register"
   - Function order bug where a comment said "Bug here? Maybe should call these in reverse order?"

The section emphasizes that reading documentation isn't just about understanding what should happen - it's often where you'll find the answer already documented, making all other debugging effort unnecessary.

**Ted:** ok, what was the second bullet?

**Claude:** The second bullet from the "Remember" section was:

• **Read everything in depth.** The section about the interrupt getting to your microcomputer is buried on page 37.

**Ted:** read the supporting text, summarize and update the chat log

**Claude:** Reviewed the "Read Everything, Cover to Cover" section from Agans' chapter. Here's my summary:

## Summary: "Read Everything, Cover to Cover" Section

**Core Message:** It's common for people to try debugging without *thoroughly* reading the documentation. They skim the sections they think are important, but the critical information is in the section they didn't read.

**Key Points:**

1. **Don't Just Skim:** People often look at sections they think are important but miss the crucial details that would solve their problem. The section you skip contains the clue to what's wrong.

2. **Personal Example:** Agans mentions struggling with a valve controller at 1 AM because he didn't read thoroughly enough.

3. **Technical Documentation Challenges:**
   - Programming guides and APIs can be very thick, but you must dig in
   - The function you assume you understand is the one that bites you
   - Parts of schematics you ignore are where noise comes from
   - That "little line" on data sheets specifying obscure timing parameters can be the one that matters

4. **War Story - Memory Timing Bug:** 
   - Three-circuit boards worked fine, four-circuit boards failed at high temperature
   - Hardware designer checked obvious specs (read/write timing) - all looked identical
   - Agans read the *whole* data sheet and found different "wait time between accesses" spec
   - The timing design didn't account for this spec on either chip - it just failed more often on the slower chip
   - Solution: Slowed processor down, next revision accounted for every line of the data sheet

5. **Additional Documentation Types:**
   - Application notes and implementation guides contain problems people had before
   - Warnings about common mistakes are valuable
   - Reference designs and sample programs show usage but often have shortcuts (lack of error recovery)
   - Don't just copy reference designs - understand them or you'll find their bugs later

The section emphasizes that thorough, complete reading of documentation is essential - the critical detail is often in the part you're tempted to skip.

**Ted:** how many more bullets now?

**Claude:** Looking back at the "Remember" section, there are 6 bullets total:

1. ✅ **Read the manual** (completed)
2. ✅ **Read everything in depth** (completed) 
3. **Know the fundamentals** (remaining)
4. **Know the road map** (remaining)
5. **Understand your tools** (remaining)
6. **Look up the details** (remaining)

So there are **4 more bullets** remaining to review and summarize.

**Ted:** run through each step with the rest then

**Claude:** Here are the summaries for the remaining 4 bullets:

## Summary: "Know What's Reasonable" (Know the Fundamentals) Section

**Core Message:** When looking around in a system, you must know how the system would normally work. Knowledge of what's normal helps you notice things that aren't.

**Key Points:**

1. **Technical Examples of Normal Behavior:**
   - Low-order bytes come first in Intel-based PC programs (or you'll think longwords are scrambled)
   - Cache causes memory writes that don't "take" right away
   - Tri-state data bus signals look "glitchy" but that's normal
   - Chain saws are supposed to be loud (don't think the noise is the problem)

2. **Need Fundamental Knowledge:** You must know some fundamentals of your technical field. Agans wouldn't have understood the interrupt problem even after reading the manual without knowing what clock strobes and address lines do.

3. **War Story - Hardware vs Software Misunderstanding:** 
   - Software engineers trying to debug microprocessor crash
   - Hardware guy suggested "put in a breakpoint just before the crash"
   - Shows lack of understanding cause and effect - if they knew where to put the breakpoint, they'd have found the problem already
   - This is why hardware and software people get on each other's nerves debugging each other's stuff

4. **Home Computer Example:** Many people can't debug their home computers because they don't understand computer fundamentals. Solution: Get help from someone with more expertise (the teenager across the street).

5. **Scope Limitations:** If you're a games programmer, steer clear of nuclear power plants. If you're not a doctor, don't diagnose that gray-green splotch. If you're a politician, don't mess with anything.

## Summary: "Know the Road Map" Section

**Core Message:** When navigating to where a bug is hiding, you must know the lay of the land. You need to understand what functions are where and how they interact.

**Key Points:**

1. **System Architecture Understanding:**
   - Know what all blocks and interfaces do at the top level
   - Initial guesses about where to divide a system depend on knowing what functions are where
   - Example: If toaster burns toast, need to know darkness knob controls toasting time

2. **Interface Knowledge:**
   - Know what goes across all APIs and communication interfaces
   - Know what each module/program does with what it receives and transmits
   - Modular/object-oriented code makes interfaces simple and modules well-defined

3. **Black Box Debugging:**
   - When parts are "black boxes," knowing how they interact lets you locate problem as inside vs outside the box
   - If inside: replace the box. If outside: you can fix it
   - Toaster example: Try darkness knob lighter - if toasting time doesn't change, problem is inside toaster

4. **Car Diagnostic Example:**
   - "Tap-tap-tap" sound that goes faster with driving speed
   - Could be rock in tire (easy) or engine problem (hard)
   - Understanding engine connects to tires through transmission allows diagnostic test
   - Downshift: engine goes faster for same tire speed
   - Sound stays same = tire problem, find rock in tread
   - (Note: transmission damage from highway downshift - practical debugging costs!)

## Summary: "Know Your Tools" Section

**Core Message:** Your debugging tools are your eyes and ears into the system. You must choose the right tool, use it correctly, and interpret results properly.

**Key Points:**

1. **Tool Mastery:**
   - Tools have powerful features only well-versed users know about
   - Take time to learn everything about your tools
   - Often the key to "seeing what's going on" is how well you set up your debugger or trigger your analyzer
   - Wrong end of thermometer won't read right temperature

2. **Tool Limitations:**
   - Stepping through source code: shows logic errors but not timing/multithread problems
   - Profiling tools: expose timing problems but not logic flaws
   - Analog scopes: see noise but can't store much data
   - Digital logic analyzers: catch lots of data but can't see noise
   - Health thermometer: can't tell if taffy is too hot
   - Candy thermometer: not accurate enough for fever

3. **War Story - Microprocessor Crash Debug:**
   - Hardware guy suggested breakpoint before crash (didn't understand tool limitations)
   - Software guy used logic analyzer to record address/data bus trace
   - Set watchdog timer very short, saved trace when it timed out
   - Had to record continuously since wouldn't know about crash until timer triggered
   - Shortened timer because analyzer has limited memory
   - Could see when program "jumped into the weeds" from the trace

4. **Development Tools Knowledge:**
   - Know your programming language (what does the "&" operator do in C?)
   - Know what compiler and linker do with source code before machine sees it
   - Data alignment, reference handling, memory allocation affect programs in non-obvious ways
   - Hardware engineers: know how high-level design language translates to registers and gates

## Summary: "Look It Up" Section

**Core Message:** Don't guess. Look it up. Don't trust your memory about detailed information that has been written down somewhere.

**Key Points:**

1. **Einstein Philosophy:** Be like Einstein, who never remembered his own phone number. "Why bother? It's in the phone book."

2. **What to Look Up:**
   - Pinouts of chips
   - Parameters for functions
   - Function names
   - Any detailed technical information

3. **War Story - The 1489A Chip Saga:**
   - Junior engineer used 1489A chip, Senior engineer "Kneejerk" said use old 1489 because "1489A gets hot"
   - Junior understood circuit: only difference was internal bias resistor value, new part more noise immune
   - Junior used 1489A, it didn't get hot
   - Later Junior found previous team's circuit with wrong pinout - input connected to bias pin instead of input pin
   - Looking up correct pinout in data book revealed the error
   - Wrong connection bypassed input resistor, made part draw lots of current through bias resistor
   - THAT'S why it got hot, and would get hotter with 1489A

4. **Consequences of Guessing:**
   - Look at wrong signal (which may look right)
   - Skip past the problem like original designer did
   - Get confusing or falsely reassuring information
   - Waste debugging time looking at wrong stuff

5. **Violations of the Rule:**
   - Original engineers didn't look up pin numbers for correct connections
   - Kneejerk didn't understand circuit, just trusted memory/hearsay
   - Result: team designed circuits with old, hard-to-get parts that ran too hot and had no noise immunity

6. **Practical Advice:** If you can't fix the flood in your basement at 2 AM and need to call the plumber, don't guess the number. Look it up.

**Ted:** ok, now do the same thing for the other eight rules in the book

**Claude:** This is a substantial task requiring extraction and analysis of 8 complete chapters. I can do this systematically, but it would result in a very large response. 

I've already found the "Remember" sections for:
- **Rule 2: Make It Fail** (9 bullet points including "Do it again," "Start at the beginning," "Stimulate the failure," etc.)
- **Rule 3: Quit Thinking and Look** (7 bullet points including "See the failure," "See the details," "Build instrumentation in," etc.)

Would you prefer me to:
1. **Complete all 8 rules** in one comprehensive response (very long)
2. **Continue systematically** one rule at a time like we did with Rule 1
3. **Focus on specific rules** you're most interested in
4. **Just extract the "Remember" bullet points** for all 8 rules first, then dive deeper into specific ones

Which approach would be most useful for your debugging methodology discussion?

**Ted:** just extract the bullets first, then go back to flesh them out

**Claude:** Perfect! Here are the "Remember" bullet points for each of the remaining rules:

## Rule 2: Make It Fail

**Remember - Make It Fail**
It seems easy, but if you don't do it, debugging is hard.

• **Do it again.** Do it again so you can look at it, so you can focus on the cause, and so you can tell if you fixed it.

• **Start at the beginning.** The mechanic needs to know that the car went through the car wash before the windows froze.

• **Stimulate the failure.** Spray a hose on that leaky window.

• **But don't simulate the failure.** Spray a hose on the *leaky* window, not on a different, "similar" one.

• **Find the uncontrolled condition that makes it intermittent.** Vary everything you can—shake it, rattle it, roll it, and twist it until it shouts.

• **Record everything and find the signature of intermittent bugs.** Our bonding system always and only failed on jumbled calls.

• **Don't trust statistics too much.** The bonding problem seemed to be related to the time of day, but it was actually the local teenagers tying up the phone lines.

• **Know that "that" *can* happen.** Even the ice cream flavor can matter.

• **Never throw away a debugging tool.** A robot paddle might come in handy someday.

**Ted:** yes, let's do them, but one at a time so we don't violate the content policy. we were able to do the entire list at once for the first step, so we should be able to do the entire bullet list for one rule at a time.

**Claude:** Perfect! Let's start with Rule 2: Make It Fail. Here's the detailed supporting content for each bullet point:

## Detailed Summary: Rule 2 - Make It Fail

**Core Message:** "There is nothing like first-hand evidence." —Sherlock Holmes. It seems easy, but if you don't do it, debugging is hard.

**Three Reasons to Make It Fail:**
1. **So you can look at it** - You need to make it fail as regularly as possible to observe it
2. **So you can focus on the cause** - Knowing exact conditions helps focus on probable causes
3. **So you can tell if you've fixed it** - Provides a surefire test of your fix

**Key Points:**

1. **Do it again** - One failure is not enough. Act like a three-year-old who watches father fall off stepladder and says "Do it again!" Write down each step and follow your own procedure to ensure it really causes the error.

2. **Start at the beginning** - Bugs depend on complex machine state. Tell the mechanic the car went through the car wash before windows froze. Start from known state (freshly rebooted computer, car when first walking into garage).

3. **Stimulate the failure** - Don't wait for conditions to naturally occur. Agans used hose on leaky window instead of waiting for southeast wind and rain. Automate when possible - software works all night and doesn't need pizza.

4. **But don't simulate the failure** - Spray hose on the LEAKY window, not a different "similar" one. Don't substitute seemingly identical environment - it's not identical and won't fail the same way.

5. **Find the uncontrolled condition** - Vary everything: shake, rattle, roll, twist until it shouts. Make intermittent conditions more random to increase likelihood of failure events.

6. **Record everything and find signatures** - Capture information on every run for comparison. Look for patterns that happen only in failure cases (videoconferencing system failed only on "jumbled calls").

7. **Don't trust statistics too much** - Bonding problem seemed time-related but was actually teenagers tying up phone lines. Look deeper into apparent correlations.

8. **Know that "that" can happen** - Ice cream flavor CAN matter (Car Talk puzzler: hand-packed unusual flavors take longer, causing vapor lock in summer heat). Accept the data and look further.

9. **Never throw away debugging tools** - Robot paddle for TV game became product feature for store displays. Tools can be reused in unexpected ways and may become sellable products themselves.

## Detailed Summary: Rule 3 - Quit Thinking and Look

**Core Message:** "It is a capital mistake to theorize before one has data. Insensibly one begins to twist facts to suit theories, instead of theories to suit facts." —Sherlock Holmes. You can think up thousands of possible reasons for a failure. *You can see only the actual cause*.

**The Problem with Thinking:** Engineers like to think—it's fun and beats physical labor. But there are more ways for something to be broken than even the most imaginative engineer can imagine. Thinking is easier than looking, but guessing leads to fixing things that aren't broken.

**Key Points:**

1. **See the failure** - Don't just see the *result* of failure (light won't turn on), see the *actual failure* (broken switch vs. broken bulb). War stories: Junior engineers thought timing was the problem and spent months building complex circuit board fix, but senior engineer saw the real issue was noise causing double write pulses. Well pump story: neighbor replaced pump based on motor sound, but it was actually air compressor in garage. Server story: stayed late to watch crash happen—janitor unplugging server for vacuum cleaner.

2. **See the details** - Keep looking deeper until the failure has limited possible causes. Video compression story: blocky picture → suspected motion estimation → added colored squares showing detected motion → saw missing horizontal detection → found search algorithm skipping locations → fixed simple bug. Don't stop too early (too many possible causes) or go too deep unnecessarily.

3. **Build instrumentation in** - Design debugging tools from the start. Hardware: test points, connectors, readable registers, LEDs, status displays, temperature sensors. Software: debug mode compilation, performance monitors, debug windows, status messages with proper formatting (time stamps, modules, message types). Embedded systems: serial ports, LCD panels, development ports, hardware toggle bits for scopes.

4. **Add instrumentation on** - External tools when built-in isn't enough. Hardware: scopes, logic analyzers, probes (though difficult with dense chips). Software: additional debug statements, breakpoints, memory examination. Use same design base as original bug, make it fail again to prove instrumentation didn't affect the problem.

5. **Don't be afraid to dive in** - Production software is broken anyway, so you have to open it up to fix it. Looking is usually quicker than guesswork because shortcuts often lead nowhere.

6. **Watch out for Heisenberg** - Your instrumentation affects the system. Debug output changes timing, can make bugs disappear ("That's why they call it a debugger"). Scope probes add capacitance. Consider different levels of intrusion and verify the bug still occurs after adding instrumentation.

7. **Guess only to focus the search** - Guessing is okay to decide where to look, but confirm guesses by looking before trying to fix. Don't trust guesses too much—they're often wrong and lead down wrong paths. The measure of a good debugger is how few bad guesses you act on, not how good your guesses are.

## Rule 3: Quit Thinking and Look

**Remember - Quit Thinking and Look**
You can think up thousands of possible reasons for a failure. *You can see only the actual cause*.

• **See the failure.** The senior engineer *saw* the real failure and was able to find the cause. The junior guys *thought* they *knew* what the failure was and fixed something that wasn't broken.

• **See the details.** Don't stop when you hear the pump. Go down to the basement and find out *which* pump.

• **Build instrumentation in.** Use source code debuggers, debug logs, status messages, flashing lights, and rotten egg odors.

• **Add instrumentation on.** Use analyzers, scopes, meters, metal detectors, electrocardiography machines, and soap bubbles.

• **Don't be afraid to dive in.** So it's production software. It's broken, and you'll have to open it up to fix it.

• **Watch out for Heisenberg.** Don't let your instruments overwhelm your system.

• **Guess only to focus the search.** Go ahead and guess that the memory timing is bad, but look at it before you build a timing fixer.

## Rule 4: Divide and Conquer

**Remember - Divide and Conquer**
It's hard for a bug to keep hiding when its hiding place keeps getting cut in half.

• **Narrow the search with successive approximation.** Guess a number from 1 to 100, in seven guesses.

• **Get the range.** If the number is 135 and you think the range is 1 to 100, you'll have to widen the range.

• **Determine which side of the bug you are on.** If there's goo, the pipe is upstream. If there's no goo, the pipe is downstream.

• **Use easy-to-spot test patterns.** Start with clean, clear water so the goo is obvious when it enters the stream.

• **Start with the bad.** There are too many good parts to verify. Start where it's broken and work your way back up to the cause.

• **Fix the bugs you know about.** Bugs defend and hide one another. Take 'em out as soon as you find 'em.

• **Fix the noise first.** Watch for stuff that you *know* will make the rest of the system go crazy.

## Rule 5: Change One Thing at a Time

**Remember - Change One Thing at a Time**
You need some predictability in your life. Remove the changes that didn't do what you expected. They probably did something you didn't expect.

• **Isolate the key factor.** Don't change the watering schedule if you're looking for the effect of the sunlight.

• **Grab the brass bar with both hands.** If you try to fix the nuke without knowing what's wrong first, you may have an underwater Chernobyl on your hands.

• **Change one test at a time.** I knew my VGA capture phase was broken because nothing else was changing.

• **Compare it with a good one.** If the bad ones all have something that the good ones don't, you're onto the problem.

• **Determine what you changed since the last time it worked.** My friend had changed the cartridge on the turntable, so that was a good place to start.

## Rule 6: Keep an Audit Trail

**Remember - Keep an Audit Trail**
Better yet, don't remember "Keep an Audit Trail." Write down "Keep an Audit Trail."

• **Write down what you did, in what order, and what happened as a result.** When did you last drink coffee? When did the headache start?

• **Understand that any detail could be the important one.** It had to be a plaid shirt to crash the video chip.

• **Correlate events.** "It made a noise for four seconds starting at 21:04:53" is better than "It made a noise."

• **Understand that audit trails for design are also good for testing.** Software configuration control tools can tell you which revision introduced the bug.

• **Write it down!** No matter how horrible the moment, make a memorandum of it.

## Rule 7: Check the Plug

**Remember - Check the Plug**
Obvious assumptions are often wrong. And to rub it in, assumption bugs are usually the easiest to fix.

• **Question your assumptions.** Are you running the right code? Are you out of gas? Is it plugged in?

• **Start at the beginning.** Did you initialize memory properly? Did you squeeze the primer bulb? Did you turn it on?

• **Test the tool.** Are you running the right compiler? Is the fuel gauge stuck? Does the meter have a dead battery?

## Rule 8: Get a Fresh View

**Remember - Get a Fresh View**
You need to take a break and get some coffee, anyway.

• **Ask for fresh insights.** Even a dummy can help you see something you didn't see before.

• **Tap expertise.** Only the VGA capture vendor could confirm that the phase function was broken.

• **Listen to the voice of experience.** It will tell you the dome light wire gets pinched all the time.

• **Know that help is all around you.** Coworkers, vendors, the Web, and the bookstore are waiting for you to ask.

• **Don't be proud.** Bugs happen. Take pride in getting rid of them, not in getting rid of them by yourself.

• **Report symptoms, not theories.** Don't drag a crowd into your rut.

• **Realize that you don't have to be sure.** Mention that the shirt was plaid.

## Rule 9: If You Didn't Fix It, It Ain't Fixed

**Remember - If You Didn't Fix It, It Ain't Fixed**
And now that you have all these techniques, there's no excuse for leaving it unfixed.

• **Check that it's really fixed.** Don't assume that it was the wires and send that dirty fuel filter back onto the road.

• **Check that it's really your fix that fixed it.** "Wubba!" might not be the thing that did the trick.

• **Know that it *never* just goes away by itself.** Make it come back by using the original Make It Fail methods. If you *have* to ship it, ship it with a trap to catch it when it happens in the field.

• **Fix the cause.** Tear out the useless eight-track deck before you burn out another transformer.

• **Fix the process.** Don't settle for just cleaning up the oil. Fix the way you design machines.

**Ted:** make it so

**Claude:** ## Detailed Summary: Rule 4 - Divide and Conquer

**Core Message:** "It's hard for a bug to keep hiding when its hiding place keeps getting cut in half." This is the first rule that actually involves finding the problem - in fact, it's the ONLY rule that actually involves finding the problem. All others help you follow this one.

**Key Points:**

1. **Narrow the search with successive approximation** - Like the number-guessing game (1-100 in seven guesses: 50, 25, 38, 44, 41, 43, 42). Software search algorithms use this for large databases. Hardware A/D converters work from high-order to low-order bit. Each step cuts search space in half.

   **War Story - Phone Company Frame:** Summer job tracing wires through thousands of connections. Helper yanks wire at one end, searcher feels halfway along shelf for motion. When found, roles reverse and they leapfrog closer until they home in on exact connection point.

2. **Get the range** - Start with whole system as range. Each guess cuts range in half. Hotel technician started with entire system, first guess eliminated software. If range assumption wrong (friend picks 135 in 1-100 game), you discover it and widen range.

3. **Determine which side of the bug you are on** - Know upstream (good, clear water) vs downstream (bad, smelly pink water). Look for the factory dumping goo. In electronics: downstream = farther in signal/data flow. In software crashes: downstream = later in code flow (use breakpoints). In calculations: stop in middle, check if results correct so far.

   **Hotel System War Story:** Ski resort Macintosh terminals slowing down connecting to LISP database server. Technician used successive approximation on serial communication system - signals good going out, bad coming in at computer end. Moved to breakout box - reversed. Problem in breakout box: hairline cracks in solder joints. Fixed all terminals except one still slow - that one had wrong wire connected (blue instead of purple), worked poorly through cable coupling.

4. **Use easy-to-spot test patterns** - Clean water shows goo better than muddy stream. Senior engineer used "00 55 AA FF" pattern instead of random data. Video work: smooth color change pattern shows mapping errors as lines. PC video test patterns with labels.

   **Video Test Patterns:** VCR capture used wheel with colored wedges (one revolution every 4 seconds) with frame time markings to detect out-of-sequence frames. Lip-sync problem: simultaneous click sound and white-to-black screen change made audio-video desync obvious. Motorola 6800 "Drop Dead" instruction (DD) caused endless loop reading each memory address - perfect square waves for scope debugging.

5. **Start with the bad** - Too many correct things to verify. Start where smelly pink goo is, work upstream. Use branch points as test points. Furnace example: don't verify fuel flow from tank down - start at furnace, confirm fuel fine but electricity not, trace to control box, find fire safety override tripped (mounted too close to heat source).

6. **Fix the bugs you know about** - Multiple bugs defend and hide each other. Hotel technician had to fix breakout box problems before seeing wiring direction issue on slow terminal. Sometimes fixing one bug fixes both (same underlying cause). Fix reveals effects on other systems sooner.

7. **Fix the noise first** - Certain bugs cause other bugs. Hardware: noisy signals, glitches on clocks, jittery timing, bad voltage levels create unpredictable intermittent problems. Software: bad multithread sync, accidentally reentrant routines, uninitialized variables inject randomness. But don't get carried away on marginal problems or aesthetic changes (junior engineers' timing board fix based on suspicion delayed real investigation).

## Detailed Summary: Rule 5 - Change One Thing at a Time

**Core Message:** "You need some predictability in your life. Remove the changes that didn't do what you expected. They probably did something you didn't expect." Use a rifle, not a shotgun - if you think you need a shotgun, you can't see the target clearly.

**Key Points:**

1. **Isolate the key factor** - Scientific method: control all variables except one. Identical plants with identical soil/water/seeds, vary only sunlight. Mortgage program: pin down loan amount and term, vary interest rate. Don't change pot color AND watering AND sunlight - you won't know what matters.

   **Audio War Story:** Software engineer added framing to fix bad audio. Didn't work, never removed it. Later found real bug (buffer pointer error), fixed it, but audio still bad because extra framing was being played as audio data. Should have backed out first change immediately when it didn't work.

2. **Grab the brass bar with both hands** - Nuclear sub training: when alarms sound, grab brass bar and hold until you understand ALL indicators. Prevents "fixing" things that confuse automatic recovery and bury original fault under new conditions. Remember to DO something (grab bar) rather than NOT do something (don't touch dial).

   **Christmas Party War Story:** Speaker wire behind fireplace logs got shorted when fire lit, blew right channel fuse. Instead of investigating, swapped speaker wires to test if problem was amp or speaker - blew left fuse too. Now no music at all.

3. **Change one test at a time** - When changing test parameters to make failure more regular, change only one thing so you know which had the effect. Back out changes that don't seem to help immediately.

   **VGA Capture War Story:** Laptop video capture with timing issues. Bypassed all measurements except pixel sample phase parameter, manually stepped through 8 positions. Expected output to jump left when crossing pixel boundary, but jumped right then left again. Only changing phase proved the parameter was misdocumented (went 0-89°, jumped to -270°, then forward to -1° instead of smooth 0-359°).

4. **Compare it with a good one** - Use working vs failing cases as differencing engine. Compare scope traces, debug logs, status windows side by side. Look for differences between good and bad runs. Keep everything else identical - same machine, consecutive tries, same software/parameters/environment. Don't even wear different shirt.

   **Log Analysis:** Most mind-numbing but effective task. Look through entire log if suspect areas don't reveal anything. Need intelligence and knowledge to filter irrelevant timing differences - can't be taught to beginners or automated. Software can format/filter to help human brain spot differences.

5. **Determine what you changed since the last time it worked** - When system worked before but fails now, find which version first caused failure. Test successively older versions until failure disappears, then go forward to verify failure returns. Focus on changes between working and broken versions.

   **Turntable War Story:** Friend's turntable sounded terrible after repair shop replaced cartridge. Sounded like input overload. Knew cartridge was changed, knew magnetic vs ceramic cartridges have different volume levels, amplifier has switch for each type. Flipped switch, perfect sound. 30 seconds total analysis.

   **Roof Leak War Story:** Water dripping from ceiling during storm. Found leak deflected by metal tab into wrong position because plastic tub had been kicked out of place during wiring work. Short-term fix: moved tub back. Real fix: reshingled roof to stop leak entirely. Sometimes new change exposes old problem rather than creating new one.

## Detailed Summary: Rule 6 - Keep an Audit Trail

**Core Message:** "The shortest pencil is longer than the longest memory." Write down what you did, in what order, and what happened as a result. Instrument the test sequence just like you instrument software/hardware.

**Key Points:**

1. **Write down what you did, in what order, and what happened as a result** - Like food allergy diary: correlate what you ate with reactions. Customer support got live audit trail of customer using floppy once then sticking it to filing cabinet with magnet. Mental audit trail: Sunday headaches from not drinking coffee Saturday (coffee withdrawal).

   **Plaid Shirt War Story:** Video compression chip randomly dropped from 30fps to 2fps. No pattern to timing, temperature didn't matter. Day with no failures = plain blue shirt day. Failures = plaid flannel shirt days. Standing up showed more plaid pattern to camera, caused chip to give up on extremely difficult compression task. Sent photocopied shirt pattern to vendor for reproduction.

2. **Understand that any detail could be the important one** - Most insignificant-seeming thing might be key. What seems obvious to tester (chip needed restart) might be missed by fixer. What seems insignificant (plaid shirt) might be crucial to person fixing problem.

   **Power Supply War Story:** Hardware engineer felt electrical buzz touching power supply case. Others tried, felt nothing. Ready to declare him crazy until noticed he wasn't wearing shoes - others' shoes insulated them from ground. Detail you'd never normally suspect was the key.

3. **The devil is in the details** - Bug reports say "It's broken" without specifying what actually failed. Debug logs without annotation of what tester saw. Be specific and consistent: "No remote video" - which side? Video displayed ON remote or FROM remote? How much/how long: "half-second barely audible hum" vs "six-second ear-piercing shriek."

   **High School Chemistry:** "Describe a candle" lab - 50 unique observations. Not just "gives off heat and light" but "hot enough you can hold hand 6 inches above for only 2 seconds." Give reader enough info to accurately understand experience.

4. **Correlate events** - Time-stamp everything. "Loud noise just after connecting" good, "loud noise for 4 seconds starting at 14:05:23" best. Synchronize clocks on multiple communicating systems. Don't keep eating diary on London time and symptom diary on San Francisco time.

   **Human Correlation War Stories:** Garbage characters correlated with Fred's duty times - his big gut pressed keyboard reaching for coffee. Crashes correlated with George's duty - he'd grab print head to type more in comment field, breaking mechanical carriage return input limit. Computer center crash correlated with 3 PM vending machine coffee break.

5. **Audit trails for design are also good for testing** - Source code control systems (now configuration control) track program AND tools. When bug appears in version, you have record of all changes since last working version. Tool control critical for accurate version recreation - unrecognized tool variations cause strange effects.

6. **Write it down!** - Never trust memory. You'll forget details that seemed unimportant but prove critical. Can't transmit info except verbally. Won't remember exactly how/when/order events happened. Write electronically for backups, bug reports, distribution, automated analysis. Save debug logs with annotations for events they don't record. Lewis Carroll: "You will forget, though, if you don't make a memorandum of it."

## Detailed Summary: Rule 7 - Check the Plug

**Core Message:** "Obvious assumptions are often wrong. And to rub it in, assumption bugs are usually the easiest to fix." When problem seems otherworldly, stop and check you're on the right planet.

**Key Points:**

1. **Question your assumptions** - Ask "Is it plugged in?" Modem software broken = kicked out phone plug. In-sink heater friend assumed power from breaker, painful afternoon under sink. Digital chip not working = check if it has power/clock. Graphics hardware = right driver? Right OS? Feature enabled? Running the code you think you're running?

   **Hot Water War Story:** 90-year-old house with cold showers. Pressure-balanced valve already installed, thermostat at 140°, thermometer confirmed temp. Problem: oil furnace set to 165° (backup temperature) instead of 190° (primary). Heat exchanger can't heat water to 140° from 165° source fast enough. Fixed heating AND hot water by correcting furnace temperature. Assumed good heat source, limited range too tightly, missed real problem.

2. **Start at the beginning** - Check startup conditions. Power plugged in but did you hit start? Graphics driver initialized? Chip reset? Registers programmed? Primer button? Choke? On/off switch? Memory initialization - sometimes works, not during investor demo.

   **Basic Examples:** TV snowy picture - VCR on wrong channel? Antenna aimed wrong? Cable down? Mid-December Packers game in snow? Soufflé didn't rise - oven on? Car won't start - out of gas before tearing apart carburetor?

3. **Test the tool** - Bad assumptions about development tools, not just product. Default settings common problem. Wrong environment, mismatched libraries. Tools have bugs too - built by engineers, why more trustworthy than what you're building?

   **Consultant War Story:** 33MHz 486 video benchmark - reads slower than writes unexpectedly. Weeks optimizing code. Found file type defaulted to text not binary, system searched for line feeds/carriage returns during reads. Fixed by explicitly setting binary transfer. Consultant assumed default was binary, never checked.

   **Hardware Compiler War Story:** Custom chip missing interrupts occasionally. Simulation perfect at register level. Looked at gate level - compiler created timing problem when building "reliable" register. Almost built what it said, bug in the difference.

   **Testing Debug Tools:** Continuity checker with dead battery won't beep on good connection. Touch probes together first. Scope probe - touch with finger for activity, 5V for scale. Print statements - print message regardless, say if event occurred. Child's temperature reads 75° - try different thermometer (and let kid out of freezer).

   **Oil Gauge War Story:** Furnace quit, oil gauge read quarter full, called repair guy. He banged gauge with flashlight, snapped to zero. Stuck gauge, needed fuel delivery. "Convictions are more dangerous enemies of truth than lies" - Nietzsche.

## Detailed Summary: Rule 8 - Get a Fresh View

**Core Message:** "Nothing clears up a case so much as stating it to another person." You need fresh insight, expertise, and experience. People usually willing to help because it lets them demonstrate how clever they are.

**Key Points:**

1. **Ask for fresh insights** - Hard to see big picture from bottom of rut. We all have biases about where bugs hide. Someone with different bias gives new insights, triggers new approaches. Sometimes explaining problem to someone else gives YOU fresh view - organizing facts forces you out of rut.

   **Dome Light War Story:** Car problem - putting in reverse blew brake light fuse. Associate immediately said "dome light pinching wire against frame - happens all the time." Seemed impossible, but unscrewed dome light, found pinched/shorted wire, wrapped with tape, fixed. Could have used other rules but associate's experience made it quick.

   **Mannequin Room:** Company with room containing mannequin - explain problems to mannequin first. Probably more interactive than some coworkers, won't show up in salary review.

2. **Tap expertise** - When part of system is mystery, ask expert rather than go to school for year. Make sure they're real expert - vague buzzword theories = technical charlatan. Want hours to research = consultant (helpful but expensive). Experts understand system better, know road map, give search hints, help design proper fix.

3. **Listen to the voice of experience** - People who've seen this before can tell you exactly what's wrong. Like dome light short. Hard to find, expensive, but worth it.

   **$10,000 Hammer Story:** Retired factory maintenance expert called for machine that wouldn't run. $10,000 fee seemed outrageous. Came with toolbox, took out hammer, whacked machine once, it started. "$10 for whack with hammer, $9,990 for knowing where to whack."

   **TV Game Production:** Technicians created troubleshooting guide - ball moves faster up than down = replace capacitor A. Ball moves faster left than right = replace capacitor B. Cheap components with leaky capacitors, but experience created systematic fix.

4. **Know that help is all around you** - Inside associates, knowledge management systems, vendor support. Third-party vendors appreciate bug reports, have expertise and experience. Sometimes you've found bug they've never seen, but they recognize it and provide fix/workaround.

5. **Don't be proud** - Asking for help shows eagerness to get bug fixed, not incompetence. Choosing help wisely reflects well. But don't assume expert is god - sometimes experts screw up.

   **B-tree War Story:** Associate was computer science expert who "used Knuth book for pillow." Found section that seemed to drop data block while rebalancing tree. Struggled for hours thinking he was missing something obvious. Finally showed associate who looked and said "Hm. That's a bug."

6. **Report symptoms, not theories** - When asking for help, describe what happened, what you've seen, conditions. Don't talk about cause theories - drags helper into same rut, hides key details your bias says aren't important. Doctor wants to know back pain feels like, not your Internet dorsal cancer diagnosis. Mechanic wants "won't start on cold mornings" not "hungover assembly guy overtightened phineas pin."

7. **Realize you don't have to be sure** - Present fishy data even if you don't understand relevance. Fact is you found something unexpected. Sometimes pattern of shirt or ice cream flavor matters. Worth presenting as information even if connection unclear.

## Detailed Summary: Rule 9 - If You Didn't Fix It, It Ain't Fixed

**Core Message:** "And now that you have all these techniques, there's no excuse for leaving it unfixed." If you didn't fix it, it ain't fixed. Everyone wants to believe the bug just went away.

**Key Points:**

1. **Check that it's really fixed** - If you follow "Make It Fail" rule, you know how to prove fix works. Test it! Don't assume fix works no matter how obvious problem and fix seem. Auto repair shop never made car fail, never tested that it didn't fail after "fix," kept $75.

   **Used Car War Story:** Car stalled on hills and highway speeds, would restart after waiting. Not a mechanic, took to shop, they said electrical problem, replaced wires, charged $75. Still stalled next day. Analyzed: common factor was flooring accelerator, car would restart after waiting. Guessed fuel flow restriction from tank to carburetor. Asked coworkers, answer: dirty fuel filter. 50-cent filter fixed problem.

2. **Check that it's really your fix that fixed it** - When you think you've fixed design, take fix out, make sure broken again, put fix back, make sure fixed again. Cycle broken→fixed→broken→fixed changing only intended fix. Often during debugging you change something that isn't official fix but actually fixes/hides problem.

   **Sesame Street Example:** SuperGrover hops saying "Wubba! Wubba!" while Betty Lou finds ON button and pushes it. Computer turns on. Grover concludes "Wubba!" is valuable repair technique. For device fixes (vs engineering design), rebreaking may be unnecessary/dangerous - don't put dirty fuel filter back or patient's old heart back.

3. **Know that it never just goes away by itself** - "We can't make it fail anymore." "Maybe it won't happen again." Guess what? It will. It stopped failing because you changed conditions somehow. If you've been guessing/changing things with shotgun approach, may have fixed it but don't know how.

   **Field Instrumentation:** When you run out of time and can't reproduce, put instrumentation in system to capture info if it fails in field. Better to say "We've been trying to capture that rare occurrence, please email log file" than "That's never happened here."

4. **Fix the cause** - Don't assume hardware failed for no reason. If condition will cause any good part to fail, changing part only buys little time before new part fails. Christmas party: shorted speaker wires caused fuse to blow. Fixing fuse by replacing it (with one from other channel) just blew another fuse - only other fuse they had.

   **Eight-Track Stereo War Story:** Free non-working integrated stereo (amp/FM/eight-track). No voltage from transformer, concluded bad transformer, ordered replacement. Months later, installed new transformer, worked for hour, then belched smoke and burned out. Should have measured circuits connected to transformer - eight-track deck was shorted. New transformer didn't have chance. Never ordered another, threw stereo out. Violated multiple rules: didn't understand system, didn't look enough, didn't consider other condition might have caused transformer to fail.

5. **Fix the process** - Sometimes line between fixing system and fixing process that created broken system is hard to spot. Oil on factory floor: wipe up → tighten leaky fitting → machine vibrates too much → only two bolts instead of four → next machine will have same problem. Fix design process to account for vibration in requirements/design/test phases. ISO-9000 as audit trail method for design process bugs rather than product bugs.

**Ted:** we had a discussion summarizing the debugging methodology from Agans' nine debugging rules earlier.  there is a chat log of our entire discussion in this directory. I also had you create a file  directing your behavior to follow this methodology.  Make a guide appropriate for either yourself or a junior developer to understand the rules by name and to also understand the process you are following and the terminology you are using.  make the new file in this directory

**Claude:** Created agans_debugging_guide.md - a comprehensive reference that covers all nine rules with practical steps, common violations, and a quick debugging process workflow.