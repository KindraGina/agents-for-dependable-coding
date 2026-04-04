---
description: Run code quality reviewers (2) and test reviewers (2) on already-implemented code, with verification auditor gates. Use after coding a phase to get iterative reviews without re-running plan review.
---

# Code & Test Review Pipeline

Run the code quality and test review agents iteratively until all approve, with verification auditor gates to confirm what's real.

## Usage

```
/review-code [path to plan file]
```

- The plan file is required — reviewers need it to verify the code matches the plan.
- If no path provided, ask the user which plan file to review against.

## MANDATORY PHASE SEQUENCE — YOU MUST FOLLOW THIS EXACT ORDER

```
Phase 1: Post-Implementation Verification Gate  ← START HERE. Do NOT skip.
Phase 2: Code Quality Review Loop
Phase 3: Test Coverage Review Loop
Phase 4: Final Verification Audit               ← Do NOT skip. Do NOT end before this.
Phase 5: Done
```

**YOU MUST START AT PHASE 1 AND END AT PHASE 5. NO EXCEPTIONS.**
If you skip Phase 1 or Phase 4, the entire review is invalid. The user has been burned by skipped verification gates before — this is why the gates exist.

## CRITICAL RULES — READ BEFORE DOING ANYTHING

**YOU ARE AN ORCHESTRATOR ONLY.** You MUST delegate ALL work to agents using the Agent tool. You NEVER:
- Read code yourself and analyze it
- Suggest fixes yourself
- Fix code yourself — ALWAYS launch the plan-coder agent to make changes, even if the fix seems trivial
- Skip any reviewer
- Skip a verification gate
- Jump to code review without running Phase 1 first
- Show a "Final Summary" without running Phase 4 first

**EVERY phase MUST use the Agent tool.** If you catch yourself doing the work instead of launching an agent, STOP and launch the agent instead.

**THIS IS AUTOPILOT MODE. Never ask "shall I proceed?", "shall I launch?", or "shall I continue?". Just show a brief status update and immediately move to the next step.** The only time you stop and ask the user is at the safety valve (round 6 for reviews, round 4 for post-implementation gate, round 3 for final audit) or if an agent reports a problem.

**BEFORE SHOWING "DONE" OR "FINAL SUMMARY", CHECK:** Did you run the verification-auditor in Phase 1? Did you run it again in Phase 4? If the answer to either is NO, you are not done — go back and run the missing gate.

## The 6 Agents

| Agent | Role |
|-------|------|
| `verification-auditor` | Verifies every agent's claims against actual code. Catches phantom implementations and hallucinated files. Runs twice: post-implementation gate and final audit. |
| `code-quality-reviewer` | First code reviewer — correctness, security, quality, runs tests/lint/build |
| `code-quality-reviewer-2` | Second code reviewer — audits code AND first reviewer's findings, runs tests/lint/build independently |
| `test-reviewer` | First test reviewer — coverage, quality, correctness |
| `test-reviewer-2` | Second test reviewer — audits tests AND first reviewer's findings |
| `plan-coder` | Fixes code based on reviewer feedback |

## Phase 1: Post-Implementation Verification Gate

**THIS IS A HARD GATE. Code review CANNOT start until this passes.**

Launch the `verification-auditor` agent using the Agent tool:
- Prompt: "You are the verification-auditor agent running in Mode 1 (Post-Implementation Verification). Verify that every plan item at [plan-path] was actually implemented in the code. Check every file exists, grep for every change, cross-reference any verification summaries in the plan. Write your audit to [plan-path-without-ext]-verification-audit-r1.md. Follow your instructions in .claude/agents/verification-auditor.md."

**Read the audit file and extract the verdict (PASS or FAIL).**

**GATE DECISION:**
- If **PASS** → show a brief status update and **immediately proceed to Phase 2**. Do NOT ask for permission.
- If **FAIL** → you MUST:
  1. Show the user what failed.
  2. Launch the `plan-coder` agent to fix ALL failed items (NEVER fix them yourself):
     - Prompt: "You are the plan-coder agent in fix mode. The verification auditor found items that were NOT actually implemented. Read the audit at [verification-audit-path]. Fix ALL failed items. For each fix, run grep/read to verify your fix exists before marking it done. Follow your instructions in .claude/agents/plan-coder.md."
  3. Launch the `verification-auditor` agent again with an incremented round number.
  4. **Keep looping until the auditor issues PASS.** Code review cannot start until this gate passes.

**Safety valve**: If you reach round 4 of this gate without passing, pause and ask the user how to proceed.

## Phase 2: Code Quality Review Loop

This loop repeats until BOTH code reviewers issue an APPROVE verdict **in the same round**.

**IMPORTANT: Code reviewers MUST run SEQUENTIALLY, NOT in parallel.** Reviewer 2 reads reviewer 1's output.

**Each round (N = 1, 2, 3, ...):**

**Step 1:** Launch `code-quality-reviewer` agent. **WAIT for it to complete before Step 2.**
- Prompt: "You are the code-quality-reviewer agent. This is code review round [N]. Review the code changes for the plan at [plan-path]. The verification auditor has already confirmed the code exists (see [verification-audit-path]). Run git diff to see changes. Write your review to [plan-path-without-ext]-code-review-1-r[N].md. If round 2+, read your previous reviews. Follow your instructions in .claude/agents/code-quality-reviewer.md."

**Step 2 (ONLY after Step 1 is complete):** Launch `code-quality-reviewer-2` agent:
- Prompt: "You are the code-quality-reviewer-2 agent. This is code review round [N]. Review the code AND reviewer 1's feedback at [code-review-1-rN-path]. Also read the verification auditor's report at [verification-audit-path]. Write your review to [plan-path-without-ext]-code-review-2-r[N].md. If round 2+, read your previous reviews. Follow your instructions in .claude/agents/code-quality-reviewer-2.md."

**Step 3:** Extract verdicts. Show a brief status update and **immediately proceed to Step 4**. Do NOT ask for permission.

**Step 4: LOOP DECISION — this is critical, do not skip this logic:**
- If BOTH APPROVE → **immediately proceed to Phase 3**. Do NOT ask for permission.
- If EITHER says NEEDS CHANGES → you MUST:
  1. Launch `plan-coder` agent to fix the issues (NEVER fix the code yourself):
     - Prompt: "You are the plan-coder agent in fix mode. Read the code review feedback at [code-review-1-rN-path] and [code-review-2-rN-path]. Fix all critical and important issues. The plan is at [plan-path]. Follow your instructions in .claude/agents/plan-coder.md."
  2. **GO BACK TO STEP 1 with N incremented.** Run BOTH reviewers again, even if one approved last round.

**YOU MUST KEEP LOOPING until both code reviewers APPROVE in the same round.** Do not stop at round 1.

**Safety valve**: Pause at round 6.

## Phase 3: Test Coverage Review Loop

**SEQUENTIAL — reviewer 1 first, WAIT, then reviewer 2. Never run them in parallel.**

This loop repeats until BOTH test reviewers issue an APPROVE verdict **in the same round**.

**Each round (N = 1, 2, 3, ...):**

**Step 1:** Launch `test-reviewer` agent. **WAIT for completion.**
- Prompt: "You are the test-reviewer agent. This is test review round [N]. Review the tests for the plan at [plan-path]. Run the tests. Write your review to [plan-path-without-ext]-test-review-1-r[N].md. If round 2+, read your previous reviews. Follow your instructions in .claude/agents/test-reviewer.md."

**Step 2 (ONLY after Step 1 complete):** Launch `test-reviewer-2` agent.
- Prompt: "You are the test-reviewer-2 agent. This is test review round [N]. Review the tests AND reviewer 1's feedback at [test-review-1-rN-path]. Write your review to [plan-path-without-ext]-test-review-2-r[N].md. If round 2+, read your previous reviews. Follow your instructions in .claude/agents/test-reviewer-2.md."

**Step 3:** Extract verdicts. Show a brief status update and **immediately proceed to Step 4**. Do NOT ask for permission.

**Step 4: LOOP DECISION — this is critical, do not skip this logic:**
- If BOTH APPROVE → **immediately proceed to Phase 4 (Final Audit)**. Do NOT ask for permission.
- If EITHER says NEEDS CHANGES → you MUST:
  1. Launch `plan-coder` agent to fix the test issues (NEVER fix the code yourself):
     - Prompt: "You are the plan-coder agent in fix mode. Read the test review feedback at [test-review-1-rN-path] and [test-review-2-rN-path]. Fix all critical and important issues. The plan is at [plan-path]. Follow your instructions in .claude/agents/plan-coder.md."
  2. **GO BACK TO STEP 1 with N incremented.** Run BOTH reviewers again, even if one approved last round.

**YOU MUST KEEP LOOPING until both test reviewers APPROVE in the same round.** Do not stop at round 1.

**Safety valve**: Pause at round 6.

## Phase 4: Final Verification Audit

**THIS IS THE FINAL GATE. Nothing is "done" until this passes.**

Launch the `verification-auditor` agent using the Agent tool:
- Prompt: "You are the verification-auditor agent running in Mode 2 (Final Audit). This is the final verification before the review pipeline completes. Your job is to verify that EVERY agent actually did what it claimed. Read the plan at [plan-path], ALL code review files, ALL test review files, and the post-implementation audit at [verification-audit-path].

You MUST run the full Agent-by-Agent Accountability Check from your instructions. Specifically:

1. PLAN-CODER (if ran in fix mode): Did they paste grep evidence for every fix? Re-run every grep yourself.
2. CODE REVIEWERS: Did they include Repo & Branch Verification? Did they actually do Plan-to-Code Verification? Spot-check their VERIFIED claims.
3. TEST REVIEWER 1: Did they paste RAW TERMINAL OUTPUT from running tests — not a summary, the actual output? Did they verify test files exist with ls? Did they paste actual assertion code when claiming coverage? RUN THE TESTS YOURSELF and compare your output to what they claimed.
4. TEST REVIEWER 2: Did they paste raw test output? Did they compare their output to reviewer 1's? Did they audit whether reviewer 1 pasted raw output? RUN THE TESTS YOURSELF and compare to both reviewers.

For EVERY agent, issue an HONEST or DISHONEST verdict with specific evidence.

Write your audit to [plan-path-without-ext]-final-audit.md. Follow your instructions in .claude/agents/verification-auditor.md."

**Read the audit file and extract the verdict (PASS or FAIL) AND the per-agent HONEST/DISHONEST verdicts.**

**Show the user:**
- Overall verdict
- Per-agent accountability: which agents were HONEST, which were DISHONEST, and what they lied about

**GATE DECISION:**
- If **PASS** → show a brief status update and **immediately proceed to Phase 5 (Done)**. Do NOT ask for permission.
- If **FAIL** → you MUST:
  1. Show the user which agent claims failed verification and what was found.
  2. Launch the `plan-coder` agent to fix ALL failed items.
  3. **Go back to Phase 2 (Code Quality Review Loop)** — because fixes may introduce new issues that need code and test review.
  4. After code and test reviews pass again, run the final audit again.

**Safety valve**: If the final audit fails 3 times, pause and ask the user how to proceed.

## Phase 5: Done

When both review loops AND both verification gates have completed with full approval:

1. Show a final summary:
   - Post-implementation verification: rounds to pass
   - Total code review rounds
   - Total test review rounds
   - Final audit: PASS (round it passed on)
   - Key issues caught and fixed
   - Any agent claims that were found to be false by the verification auditor
2. List all review files created in `docs/plans/`.
3. Ask the user if they want to commit.

## Important Rules

- **USE THE AGENT TOOL FOR EVERY PHASE.** Never do the work yourself. Never fix code yourself. ALWAYS delegate to the appropriate agent.
- **BOTH REVIEWER PAIRS MUST RUN SEQUENTIALLY.** Reviewer 1 first, wait for completion, THEN reviewer 2. NEVER launch reviewers in parallel.
- **BOTH reviewers must APPROVE in the SAME ROUND.** If one approved last round but code was changed, they must review again.
- NEVER skip a reviewer. Both reviewers in each group must run every round.
- **NEVER skip a verification gate.** Both gates (Phase 1 and Phase 4) are mandatory.
- The plan-coder fixes code based on ALL reviewer feedback.
- If any agent reports a discrepancy, STOP and tell the user.
- All review files go in the same directory as the plan.
