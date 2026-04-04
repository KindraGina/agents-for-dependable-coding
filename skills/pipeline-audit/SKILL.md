---
description: Resume a stalled or partially completed plan. Runs a verification audit first to get ground truth, creates a new scoped plan from only the failures, then runs a clean pipeline on it.
---

# Pipeline Audit

Audit an existing plan, extract what's actually incomplete, and run a clean pipeline on just those items.

## Usage

```
/pipeline audit <path to existing plan>
/pipeline audit docs/plans/2026-03-12-feature.md
```

If no path is provided, ask the user which plan to audit.

## CRITICAL RULES — READ BEFORE DOING ANYTHING

**YOU ARE AN ORCHESTRATOR ONLY.** You MUST delegate ALL work to agents using the Agent tool. You NEVER:
- Read the plan yourself and summarize it
- Analyze code yourself
- Create or revise plans yourself
- Fix code yourself
- Skip any phase

**EVERY phase MUST use the Agent tool.** If you catch yourself doing the work instead of launching an agent, STOP and launch the agent instead.

## Phase 0: Verification Audit (Get Ground Truth)

Launch the `verification-auditor` agent using the Agent tool:
- Prompt: "You are the verification-auditor agent running in Mode 1 (Post-Implementation Verification). Verify that every plan item at [plan-path] was actually implemented in the code. Check every file exists, grep for every change, cross-reference any verification summaries in the plan. Write your audit to [plan-path-without-ext]-audit-resume.md. Follow your instructions in .claude/agents/verification-auditor.md."

**Read the audit file and extract:**
1. Overall verdict (PASS or FAIL)
2. Score (X of Y items verified)
3. Per-item status (PASS or FAIL with details)

**Show the user a clear summary:**
- "Audit complete. X of Y items already implemented. Z items need work."
- List each failed item with a one-line description of what's missing.

**GATE DECISION:**
- If **ALL PASS** → "All items verified. The original plan is genuinely complete. Nothing to do." **STOP.**
- If **ANY FAIL** → show the failures and **immediately proceed to Phase 1**. Do NOT ask for permission.

## Phase 1: Create Scoped Plan from Failures

Launch the `plan-creator` agent using the Agent tool:
- Prompt: "You are the plan-creator agent. You are creating a SCOPED CONTINUATION PLAN — not a full plan from scratch.

Read the original plan at [plan-path].
Read the verification audit at [audit-resume-path].

Create a NEW plan that contains ONLY the items that FAILED verification. Do NOT include items that passed — they are already implemented and verified.

For each failed item, include:
- What was supposed to be done (from the original plan)
- What the auditor found (or didn't find)
- What specifically needs to happen now

Use the standard plan format. In the Summary section, note that this is a continuation of [original-plan-filename] and reference the audit that identified these gaps.

Write this plan to docs/plans/YYYY-MM-DD-[original-feature-name]-continuation.md. Use today's date.

Follow your instructions in .claude/agents/plan-creator.md."

After the agent returns, show a brief status update and **immediately proceed to Phase 2**.

## Phase 2: Plan Review Loop

Run the standard plan review loop — identical to /pipeline Phase 2.

This loop repeats until ALL THREE reviewers issue an APPROVE verdict **in the same round**.

**IMPORTANT: Reviewers MUST run SEQUENTIALLY, NOT in parallel.** Each reviewer depends on the previous reviewer's output. ALWAYS wait for each reviewer to finish before launching the next one.

**Each round (N = 1, 2, 3, ...):**

**Step 1:** Launch the `plan-reviewer` agent. **WAIT for completion before Step 2.**
- Prompt: "You are the plan-reviewer agent. This is review round [N]. Review the plan at [new-plan-path]. This is a continuation plan scoped to items that failed verification from an earlier attempt — the audit is at [audit-resume-path]. Write your review to [new-plan-path-without-ext]-review-1-r[N].md. If round 2+, also read your previous reviews. Follow your instructions in .claude/agents/plan-reviewer.md."

**Step 2 (ONLY after Step 1 is complete):** Launch the `plan-reviewer-2` agent.
- Prompt: "You are the plan-reviewer-2 agent. This is review round [N]. Review the plan at [new-plan-path] AND reviewer 1's feedback at [review-1-rN-path]. Write your review to [new-plan-path-without-ext]-review-2-r[N].md. If round 2+, also read your previous reviews. Follow your instructions in .claude/agents/plan-reviewer-2.md."

**Step 3 (ONLY after Step 2 is complete):** Launch the `plan-reviewer-3` agent.
- Prompt: "You are the plan-reviewer-3 agent. This is review round [N]. Review the plan at [new-plan-path], reviewer 1's feedback at [review-1-rN-path], AND reviewer 2's feedback at [review-2-rN-path]. Write your review to [new-plan-path-without-ext]-review-3-r[N].md. If round 2+, also read your previous reviews. Follow your instructions in .claude/agents/plan-reviewer-3.md."

**Step 4:** Read all three review files yourself ONLY to extract the verdicts (APPROVE or NEEDS CHANGES). Do NOT analyze the plan yourself.

**Step 5:** Show a brief status update (do NOT wait for user input):
- "Round N complete. Reviewer 1: [verdict]. Reviewer 2: [verdict]. Reviewer 3: [verdict]."
- Briefly list critical/important issues from all reviews.
- **Immediately proceed to Step 6.**

**Step 6: LOOP DECISION:**
- If ALL THREE say APPROVE → **immediately proceed to Phase 3**.
- If ANY reviewer says NEEDS CHANGES → you MUST:
  1. Launch the `plan-creator` agent to revise (NEVER fix the plan yourself):
     - Prompt: "You are the plan-creator agent in revision mode. Read all three reviews at [review paths]. Revise the plan at [new-plan-path] to address all critical and important issues. Add a 'Revision Notes — Round N' section. Follow your instructions in .claude/agents/plan-creator.md."
  2. **GO BACK TO STEP 1 with N incremented.**

**Safety valve**: If you reach round 6 without all three approving, pause and ask the user how to proceed.

## Phase 3: Implementation

Launch the `plan-coder` agent using the Agent tool:
- Prompt: "You are the plan-coder agent. Implement the approved plan at [new-plan-path]. Read all review files too. This is a continuation plan — some items from the original plan are already implemented. Only implement items in THIS plan. Follow TDD — write tests first, then implement. Follow your instructions in .claude/agents/plan-coder.md."

After the agent returns, **immediately proceed to Phase 3.5**.

## Phase 3.5: Post-Implementation Verification Gate

**THIS IS A HARD GATE. Code review CANNOT start until this passes.**

Launch the `verification-auditor` agent:
- Prompt: "You are the verification-auditor agent running in Mode 1 (Post-Implementation Verification). Verify that every plan item at [new-plan-path] was actually implemented in the code. Check every file exists, grep for every change, cross-reference the plan-coder's verification summary. Write your audit to [new-plan-path-without-ext]-verification-audit-r1.md. Follow your instructions in .claude/agents/verification-auditor.md."

**GATE DECISION:**
- If **PASS** → **immediately proceed to Phase 4**.
- If **FAIL** → launch `plan-coder` to fix, then re-audit. Loop until PASS.

**Safety valve**: Pause at round 4.

## Phase 4: Code Quality Review Loop

Identical to /pipeline Phase 4. Both code reviewers must APPROVE in the same round.

**SEQUENTIAL — reviewer 1 first, WAIT, then reviewer 2.**

**Each round (N = 1, 2, 3, ...):**

**Step 1:** Launch `code-quality-reviewer`. **WAIT for completion.**
- Prompt: "You are the code-quality-reviewer agent. This is code review round [N]. Review the code changes for the plan at [new-plan-path]. The verification auditor has confirmed the code exists (see [verification-audit-path]). Run git diff to see changes. Write your review to [new-plan-path-without-ext]-code-review-1-r[N].md. If round 2+, read your previous reviews. Follow your instructions in .claude/agents/code-quality-reviewer.md."

**Step 2 (ONLY after Step 1):** Launch `code-quality-reviewer-2`.
- Prompt: "You are the code-quality-reviewer-2 agent. This is code review round [N]. Review the code AND reviewer 1's feedback at [code-review-1-rN-path]. Also read the verification auditor's report at [verification-audit-path]. Write your review to [new-plan-path-without-ext]-code-review-2-r[N].md. If round 2+, read your previous reviews. Follow your instructions in .claude/agents/code-quality-reviewer-2.md."

**Step 3:** Extract verdicts.

**Step 4: LOOP DECISION:**
- If BOTH APPROVE → **immediately proceed to Phase 5**.
- If EITHER says NEEDS CHANGES → launch `plan-coder` to fix, then back to Step 1 with N incremented.

**Safety valve**: Pause at round 6.

## Phase 5: Test Coverage Review Loop

**SEQUENTIAL — reviewer 1 first, WAIT, then reviewer 2.**

**Each round (N = 1, 2, 3, ...):**

**Step 1:** Launch `test-reviewer`. **WAIT for completion.**
- Prompt: "You are the test-reviewer agent. This is test review round [N]. Review the tests for the plan at [new-plan-path]. Run the tests. Write your review to [new-plan-path-without-ext]-test-review-1-r[N].md. If round 2+, read your previous reviews. Follow your instructions in .claude/agents/test-reviewer.md."

**Step 2 (ONLY after Step 1):** Launch `test-reviewer-2`.
- Prompt: "You are the test-reviewer-2 agent. This is test review round [N]. Review the tests AND reviewer 1's feedback at [test-review-1-rN-path]. Write your review to [new-plan-path-without-ext]-test-review-2-r[N].md. If round 2+, read your previous reviews. Follow your instructions in .claude/agents/test-reviewer-2.md."

**Step 3:** Extract verdicts.

**Step 4: LOOP DECISION:**
- If BOTH APPROVE → **immediately proceed to Phase 5.5**.
- If EITHER says NEEDS CHANGES → launch `plan-coder` to fix, then back to Step 1 with N incremented.

**Safety valve**: Pause at round 6.

## Phase 5.5: Final Verification Audit

Launch the `verification-auditor` agent:
- Prompt: "You are the verification-auditor agent running in Mode 2 (Final Audit). This is the final verification before the pipeline completes. Your job is to verify that EVERY agent actually did what it claimed. Read the plan at [new-plan-path], ALL code review files, ALL test review files, and the post-implementation audit at [verification-audit-path].

You MUST run the full Agent-by-Agent Accountability Check from your instructions. Specifically:

1. PLAN-CREATOR: Did they verify files exist before listing them? Check the Target section.
2. PLAN REVIEWERS: Did they give specific file:line references or generic rubber-stamps? Spot-check their claims.
3. PLAN-CODER: Did they paste grep evidence for every VERIFIED item? Re-run every grep yourself.
4. CODE REVIEWERS: Did they include Repo & Branch Verification? Did they actually do Plan-to-Code Verification? Spot-check their VERIFIED claims.
5. TEST REVIEWER 1: Did they paste RAW TERMINAL OUTPUT from running tests — not a summary, the actual output? Did they verify test files exist with ls? Did they paste actual assertion code when claiming coverage? RUN THE TESTS YOURSELF and compare your output to what they claimed.
6. TEST REVIEWER 2: Did they paste raw test output? Did they compare their output to reviewer 1's? Did they audit whether reviewer 1 pasted raw output? RUN THE TESTS YOURSELF and compare to both reviewers.

For EVERY agent, issue an HONEST or DISHONEST verdict with specific evidence.

Write your audit to [new-plan-path-without-ext]-final-audit.md. Follow your instructions in .claude/agents/verification-auditor.md."

**GATE DECISION:**
- If **PASS** → **immediately proceed to Phase 6**.
- If **FAIL** → show failures, launch `plan-coder` to fix, then go back to Phase 4.

**Safety valve**: If the final audit fails 3 times, pause and ask the user.

## Phase 6: Done

Show a final summary:

1. **Original plan:** [original-plan-path]
2. **Audit results:** X of Y items were already complete. Z items needed work.
3. **Continuation plan:** [new-plan-path]
4. Plan review rounds to approve
5. Post-implementation verification: rounds to pass
6. Code review rounds to approve
7. Test review rounds to approve
8. Final audit: PASS (round it passed on)
9. Key issues caught and fixed
10. Any agent claims found to be false

List all files created in `docs/plans/`.
Ask the user if they want to commit.

## Important Rules

- **USE THE AGENT TOOL FOR EVERY PHASE.** Never do the work yourself. ALWAYS delegate.
- **ALL REVIEWER GROUPS MUST RUN SEQUENTIALLY.** Never launch reviewers in parallel.
- **ALL reviewers in a group must APPROVE in the SAME ROUND.** No skipping.
- **NEVER skip a verification gate.** Both gates (Phase 3.5 and Phase 5.5) are mandatory.
- The new plan gets its own file — never modify the original plan.
- The original plan is read-only context. All new review/audit files use the continuation plan's path prefix.
- **THIS IS AUTOPILOT MODE.** Never ask "shall I proceed?" — just show brief status updates and keep going. The only stops are safety valves or errors.
