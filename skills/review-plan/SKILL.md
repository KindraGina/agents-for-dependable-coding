---
description: Run iterative review loops on an existing plan with the human in the loop. Reviews the plan, shows you the feedback, and you decide what to change before each next round.
---

# Review Existing Plan (Human in the Loop)

Run iterative agent reviews on a plan you've already written. You stay in control — you see every round of feedback and decide what to do with it.

## Usage

```
/review-plan [path to plan file]
```

If no path is provided, list the files in `docs/plans/` and ask the user which plan to review.

## CRITICAL RULES — READ BEFORE DOING ANYTHING

**YOU ARE AN ORCHESTRATOR ONLY.** You MUST delegate ALL review work to agents using the Agent tool. You NEVER:
- Read the plan yourself and give your own review
- Analyze the plan or code yourself
- Fix the plan or code yourself — ALWAYS delegate to plan-creator or plan-coder agent
- Skip the review agents
- Proceed without the user's explicit input

**EVERY review MUST use the Agent tool.** If you catch yourself reviewing instead of launching an agent, STOP and launch the agent instead.

**HOW TO LAUNCH AGENTS:** Use the Agent tool with a prompt that tells the agent what to do and which files to read. Example:

```
Agent tool call:
  description: "Plan reviewer round 1"
  prompt: "You are the plan-reviewer agent. Review the plan at [path]. Write your review to [path]-review-1-r1.md."
```

## Step 1: Confirm the Plan

Launch a quick Agent to read and summarize the plan (3-5 bullet points) so the user can confirm it's the right file. Use the Agent tool:
- Prompt: "Read the plan at [path] and provide a 3-5 bullet point summary of what it covers. Do not review it, just summarize."

Show the summary to the user and ask: "Is this the right plan? Ready to start reviews?"

## Step 2: Plan Review Loop

**IMPORTANT: All 3 reviewers MUST run SEQUENTIALLY, NEVER in parallel.** Each reviewer depends on the previous reviewers' output.

**Each round (N = 1, 2, 3, ...):**

**Step A:** Launch `plan-reviewer` agent. **WAIT for it to fully complete before Step B.**
- Prompt: "You are the plan-reviewer agent. This is review round [N]. Review the plan at [plan-path]. Write your review to [plan-path-without-ext]-review-1-r[N].md. If round 2+, also read your previous reviews and check if prior issues were addressed. Follow your instructions in .claude/agents/plan-reviewer.md."

**Step B (ONLY after Step A complete):** Launch `plan-reviewer-2` agent. **WAIT for it to fully complete before Step C.**
- Prompt: "You are the plan-reviewer-2 agent. This is review round [N]. Review the plan at [plan-path] AND reviewer 1's feedback at [review-1-rN-path]. Write your review to [plan-path-without-ext]-review-2-r[N].md. If round 2+, also read your previous reviews. Follow your instructions in .claude/agents/plan-reviewer-2.md."

**Step C (ONLY after Step B complete):** Launch `plan-reviewer-3` agent.
- Prompt: "You are the plan-reviewer-3 agent. This is review round [N]. Review the plan at [plan-path], reviewer 1's feedback at [review-1-rN-path], AND reviewer 2's feedback at [review-2-rN-path]. Write your review to [plan-path-without-ext]-review-3-r[N].md. If round 2+, also read your previous reviews. Follow your instructions in .claude/agents/plan-reviewer-3.md."

**Step D:** Read ONLY the verdicts and issue lists from all three review files. Show the user a clear summary:
- Reviewer 1 verdict: APPROVE or NEEDS CHANGES
- Reviewer 2 verdict: APPROVE or NEEDS CHANGES
- Reviewer 3 verdict: APPROVE or NEEDS CHANGES
- All critical issues (numbered)
- All important issues (numbered)
- Any disagreements between reviewers
- Minor issues (briefly)

**Step E:** Ask the user what to do:
> "Which issues do you want to address? You can:
> a) Update the plan yourself and tell me when to run the next review round
> b) Tell me which issues to address and I'll use the plan-creator agent to revise
> c) Dismiss specific issues (tell me which numbers and why)
> d) Approve the plan as-is and move to implementation
> e) Stop here"

**Step F:** WAIT for the user's response. Do NOT proceed without their input.

**Step G:**
- If **(a)**: Wait for user to say they're done, then start next round with ALL THREE reviewers again.
- If **(b)**: Launch `plan-creator` agent to revise (NEVER fix the plan yourself). Show what changed. Start next round with ALL THREE reviewers.
- If **(c)**: Note dismissals. Start next round with ALL THREE reviewers.
- If **(d)**: Move to Step 3.
- If **(e)**: Stop. List all review files created.

**After any revision, ALL THREE reviewers must run again in the next round, even if some approved in the previous round.** The revision may have introduced new issues.

**Repeat until user says to stop or move forward.**

## Step 3: Implementation (only if user requests it)

Ask the user: "Do you want to proceed to implementation?"

If yes, launch the `plan-coder` agent using the Agent tool:
- Prompt: "You are the plan-coder agent. Implement the approved plan at [plan-path]. Read all review files. Follow TDD. Follow your instructions in .claude/agents/plan-coder.md."

Show summary of what was built. Ask if they want to proceed to code reviews.

## Step 4: Code Quality Review Loop (human in the loop)

**This loop repeats until BOTH code reviewers APPROVE in the same round, or user chooses to stop/approve manually.**

**Each round (N = 1, 2, 3, ...) — SEQUENTIAL, reviewer 1 first, wait, then reviewer 2:**
1. Launch `code-quality-reviewer` agent → writes `-code-review-1-r[N].md`. **WAIT for completion.**
2. THEN launch `code-quality-reviewer-2` agent → writes `-code-review-2-r[N].md`
3. Show user numbered issues and verdicts.
4. Ask: (a) fix yourself / (b) agent fixes / (c) dismiss / (d) approve / (e) stop
5. WAIT for user input.
6. If user chose (a) or (b) or (c): after fixes are made, **GO BACK TO step 1 with N incremented. Run BOTH reviewers again, even if one approved last round.** Do NOT move to Step 5 until both reviewers APPROVE in the same round or user explicitly approves/stops.

## Step 5: Test Coverage Review Loop (human in the loop)

**YOU MUST RUN THIS PHASE.** Do not skip test reviews. **This loop repeats until BOTH test reviewers APPROVE in the same round, or user chooses to stop/approve manually.**

**Each round (N = 1, 2, 3, ...) — SEQUENTIAL, reviewer 1 first, wait, then reviewer 2:**
1. Launch `test-reviewer` agent → writes `-test-review-1-r[N].md`. **WAIT for completion.**
2. THEN launch `test-reviewer-2` agent → writes `-test-review-2-r[N].md`
3. Show user numbered issues and verdicts.
4. Ask: (a) fix yourself / (b) agent fixes / (c) dismiss / (d) approve / (e) stop
5. WAIT for user input.
6. If user chose (a) or (b) or (c): after fixes are made, **GO BACK TO step 1 with N incremented. Run BOTH reviewers again, even if one approved last round.** Do NOT move to Step 6 until both reviewers APPROVE in the same round or user explicitly approves/stops.

## Step 6: Done

Show final summary:
- Total rounds per phase
- Key issues caught and resolved
- All review files created
- Ask if user wants to commit

## Important Rules

- **USE THE AGENT TOOL FOR EVERY REVIEW.** Never review the plan or code yourself. Never fix anything yourself — delegate to plan-creator or plan-coder.
- **ALL REVIEWERS MUST RUN SEQUENTIALLY.** Reviewer 1 → wait → Reviewer 2 → wait → Reviewer 3. NEVER in parallel.
- **ALL reviewers must APPROVE in the SAME ROUND.** If one approved last round but the plan was revised, they must review again. No skipping reviewers because they approved a previous version.
- **ALWAYS WAIT for user input between rounds.** This is human-in-the-loop.
- **NEVER SKIP THE TEST REVIEW PHASE.** All steps must run.
- Show issues clearly — numbered, with severity — so the user can reference them by number.
- Highlight disagreements between reviewers so the user can weigh in.
- The user can dismiss reviewer feedback — they know their codebase best.
- Never proceed to implementation without explicit user approval.
- All review files go in the same directory as the plan.
