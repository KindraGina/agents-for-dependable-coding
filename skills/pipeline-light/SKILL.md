---
description: Lean version of /pipeline for small, low-risk changes. Same plan-creator and same verification-auditor safety gates, but only ONE reviewer per stage (instead of 2 or 3). Roughly 3-4× cheaper than /pipeline. Use for typo fixes, single-file bug fixes, copy updates, config tweaks, or one-function additions where you'd estimate "under ~50 lines, low risk, one file."
---

# Agent Pipeline — Light

A lean version of `/pipeline` for small, low-risk changes.

## When to use this vs `/pipeline`

**Use `/pipeline-light` for:**
- Typo fixes
- Single-file bug fixes
- Copy/text changes
- One-function additions with tests
- Config tweaks
- Anything you'd estimate as under ~50 lines, low risk, one file

**Use `/pipeline` (full) for:**
- New features
- Multi-file changes
- Anything touching auth, payments, security, or PII
- Database migrations
- Cross-project changes (kindra ↔ kinlia-web ↔ kindraapp)
- When you're unsure — default to full

The user picks. Do NOT auto-promote or auto-demote between the two — they're explicit choices.

## YOUR ABSOLUTE FIRST ACTION — DO THIS BEFORE EVERYTHING ELSE

Before running ANY command, check the user's most recent message for explicit pipeline invocation.

Explicit invocation means ONE of:
- The user typed `/pipeline` or `/pipeline-light` in their CURRENT message
- The user typed "run the pipeline" / "kick off the pipeline" / "start the pipeline" in their CURRENT message
- The user explicitly approved a previous proposal that named the pipeline by saying "yes run the pipeline" or "yes /pipeline" — naming the action

NOT explicit invocation:
- "continue" / "proceed" / "go ahead" / "yes" — these are ambiguous and DO NOT count, even if you proposed running the pipeline in the previous turn
- "do it" / "let's do it" — too ambiguous, DO NOT count
- An earlier-in-the-conversation approval that's no longer the most recent turn

If you were called programmatically (by a main-session Claude, not by the user typing the slash command) AND the user's CURRENT message does NOT contain explicit pipeline invocation, STOP immediately. Tell the user verbatim:

> "I was about to launch the pipeline but don't see explicit invocation in your most recent message. Should I run `/pipeline` on `[plan path]`? Please reply with `yes /pipeline` to confirm."

Wait for that exact-shaped confirmation. Do not interpret follow-up "yes" or "go ahead" as confirmation — require the user to name the action again.

Why this rule exists (May 2026 incident): A Claude session proposed branching strategies, the user typed "continue" meaning "keep discussing," and the session interpreted that as approval to commit changes AND launch the full pipeline. Multi-agent skills are expensive and high-blast-radius — they require explicit confirmation, not interpreted approval.

## YOUR FIRST ACTION — DO THIS NOW, BEFORE ANYTHING ELSE

**Run these two commands immediately. Do not read the plan first. Do not launch any agents first. Do this RIGHT NOW:**

```bash
pwd
git branch --show-current
```

**Show the user:**
- "Working directory: [pwd output]"
- "Current branch: [branch-name]"

**PROTECTED BRANCH REFUSAL — this is a HARD STOP:**

If the current branch is one of `main`, `master`, `staging`, `testflight`, `production`, `prod`, or `release`, you MUST refuse to run. Tell the user verbatim:

> "You're on the protected branch `[branch]`. The pipeline cannot run here directly — changes must be made on a feature branch and merged back. Please create a feature branch (e.g. `git checkout -b feature/[short-description]`) and re-run the pipeline. STOPPING."

Do NOT proceed. Do NOT offer to create the branch yourself. Do NOT ask "should I proceed anyway?" — the user creates the branch themselves and re-runs the pipeline.

**Why this rule exists (April 2026 donation-upsell incident):** A pipeline ran on `staging` directly with no feature branch. 11 files were modified on the protected branch with no PR boundary, no clean rollback path, and contaminated the staging deploy line.

**Then read the plan file** (if a path was provided). Look at the `## Target` section.
- If the branch matches → say "Branch confirmed: [branch]" and proceed.
- If they DON'T match → ask the user which branch to use. **STOP until they answer.**
- If the plan has a `## Prerequisites` or `## Dependencies` section, verify each one is done (grep/ls). If any are NOT DONE, tell the user and ask how to proceed.

**Only after branch is confirmed may you proceed to plan review or plan creation.**

## Usage

```
/pipeline-light [path to existing plan OR description of what to build/fix]
```

- If a file path is provided, confirm the branch (above), then go to Phase 2 (Plan Review Loop).
- If a description is provided, confirm the branch (above), then go to Phase 1 (Plan Creation).
- If nothing is provided, ask the user what they want to fix or which plan to review.

## CRITICAL RULES — READ BEFORE DOING ANYTHING

**YOU ARE AN ORCHESTRATOR ONLY.** You MUST delegate ALL work to agents using the Agent tool. You NEVER:
- Read the plan yourself and summarize it
- Analyze code yourself
- Suggest implementation steps yourself
- Answer questions about the plan yourself
- Skip the review agents
- **Fix the plan or code yourself — ALWAYS launch the plan-creator or plan-coder agent to make changes. Even if the fix seems trivial, delegate it.**

**EVERY phase MUST use the Agent tool.** If you catch yourself doing the work instead of launching an agent, STOP and launch the agent instead.

**HOW TO LAUNCH AGENTS:** Use the Agent tool with a prompt that tells the agent what to do and which files to read.

## The 5 Agents (subset of the 10 used by /pipeline)

| Agent | Role |
|-------|------|
| `plan-creator` | Creates and revises the implementation plan |
| `plan-reviewer` | The single plan reviewer (reviewers 2 and 3 are skipped in light mode) |
| `plan-coder` | Implements the approved plan using TDD |
| `verification-auditor` | Verifies every agent's claims against actual code. Runs twice: after implementation and as final audit. |
| `code-quality-reviewer` | The single code reviewer (reviewer 2 is skipped in light mode) |
| `test-reviewer` | The single test reviewer (reviewer 2 is skipped in light mode) |

**Why the auditor stays:** the verification-auditor catches agents that LIE about what they did. Cutting it would be cutting muscle, not fat. The reviewers 2/3 that are cut are redundancy on top of reviewer 1 — valuable on large changes, overkill on small ones.

## Phase 1: Plan Creation (skip if user provided a plan path)

Launch the `plan-creator` agent using the Agent tool:
- Prompt: "You are the plan-creator agent. Create an implementation plan for: [user's description]. Write the plan to docs/plans/YYYY-MM-DD-[feature-name].md. Follow your instructions in .claude/agents/plan-creator.md."

After the agent returns, show the user a brief status update and **immediately proceed to Phase 2**. Do NOT ask for permission to continue.

## Phase 2: Plan Review Loop (ONE reviewer)

This loop repeats until the reviewer issues an APPROVE verdict.

**Each round (N = 1, 2, 3, ...):**

**Step 1:** Launch the `plan-reviewer` agent.
- Prompt: "You are the plan-reviewer agent. This is review round [N]. Review the plan at [plan-path]. Write your review to [plan-path-without-ext]-review-1-r[N].md. If round 2+, also read your previous reviews. Follow your instructions in .claude/agents/plan-reviewer.md."

**Step 2:** Read the review file ONLY to extract the verdict (APPROVE or NEEDS CHANGES).

**Step 3:** Show a brief status update — "Light plan review round N: [verdict]. Briefly list critical/important issues." — and **immediately proceed to Step 4**.

**Step 4: LOOP DECISION:**
- If APPROVE → **immediately proceed to Phase 3**. Do NOT ask for permission.
- If NEEDS CHANGES → launch the `plan-creator` agent to revise (NEVER fix the plan yourself):
  - Prompt: "You are the plan-creator agent in revision mode. Read the review at [review-1-path]. Revise the plan at [plan-path] to address all critical and important issues. Add a 'Revision Notes — Round N' section. Follow your instructions in .claude/agents/plan-creator.md."
  - **GO BACK TO STEP 1 with N incremented.**

**Safety valve**: If you reach round 6 without APPROVE, pause and ask the user how to proceed.

## Phase 3: Implementation

Launch the `plan-coder` agent:
- Prompt: "You are the plan-coder agent. Implement the approved plan at [plan-path]. Read the review file too. Follow TDD — write tests first, then implement. Follow your instructions in .claude/agents/plan-coder.md."

After the agent returns, show a brief status update and **immediately proceed to Phase 3.5**.

## Phase 3.5: Post-Implementation Verification Gate

**THIS IS A HARD GATE. Code review CANNOT start until this passes. This gate is the SAME as in full /pipeline — never skip it, even in light mode.**

Launch the `verification-auditor` agent:
- Prompt: "You are the verification-auditor agent running in Mode 1 (Post-Implementation Verification). Verify that every plan item at [plan-path] was actually implemented in the code. Check every file exists, grep for every change, cross-reference the plan-coder's verification summary. Write your audit to [plan-path-without-ext]-verification-audit-r1.md. Follow your instructions in .claude/agents/verification-auditor.md."

**Read the audit file and extract the verdict (PASS or FAIL).**

**GATE DECISION:**
- If **PASS** → immediately proceed to Phase 4.
- If **FAIL** → launch the `plan-coder` to fix ALL failed items, then re-launch the auditor with incremented round number. **Keep looping until PASS.** Code review cannot start until this gate passes.

**Safety valve**: If you reach round 4 of this gate without passing, pause and ask the user how to proceed.

## Phase 4: Code Quality Review (ONE reviewer)

This loop repeats until the reviewer issues an APPROVE verdict.

**Each round (N = 1, 2, 3, ...):**

**Step 1:** Launch `code-quality-reviewer` agent.
- Prompt: "You are the code-quality-reviewer agent. This is code review round [N]. Review the code changes for the plan at [plan-path]. The verification auditor has already confirmed the code exists (see [verification-audit-path]). Run git diff to see changes. Write your review to [plan-path-without-ext]-code-review-1-r[N].md. If round 2+, read your previous reviews. Follow your instructions in .claude/agents/code-quality-reviewer.md."

**Step 2:** Extract verdict. Show a brief status update and **immediately proceed to Step 3**.

**Step 3: LOOP DECISION:**
- If APPROVE → **immediately proceed to Phase 5**.
- If NEEDS CHANGES → launch `plan-coder` to fix, then **GO BACK TO STEP 1 with N incremented**.

**Safety valve**: Pause at round 6.

## Phase 5: Test Coverage Review (ONE reviewer)

This loop repeats until the reviewer issues an APPROVE verdict.

**Each round (N = 1, 2, 3, ...):**

**Step 1:** Launch `test-reviewer` agent.
- Prompt: "You are the test-reviewer agent. This is test review round [N]. Review the tests for the plan at [plan-path]. Run the FULL test suite (mix test / yarn test:run / yarn test with no file path argument). Write your review to [plan-path-without-ext]-test-review-1-r[N].md. If round 2+, read your previous reviews. Follow your instructions in .claude/agents/test-reviewer.md."

**Step 2:** Extract verdict.

**Step 3: LOOP DECISION:**
- If APPROVE → **immediately proceed to Phase 5.5**.
- If NEEDS CHANGES → launch `plan-coder` to fix, then **GO BACK TO STEP 1 with N incremented**.

**Safety valve**: Pause at round 6.

## Phase 5.5: Final Verification Audit

**THIS IS THE FINAL GATE. Nothing is "done" until this passes. SAME as in full /pipeline — never skip it, even in light mode.**

Launch the `verification-auditor` agent:
- Prompt: "You are the verification-auditor agent running in Mode 2 (Final Audit). This is the final verification before the pipeline completes. Your job is to verify that EVERY agent actually did what it claimed. Read the plan at [plan-path], the code review file, the test review file, and the post-implementation audit at [verification-audit-path]. Run the full Agent-by-Agent Accountability Check from your instructions. RUN THE FULL TEST SUITE YOURSELF and compare your output to what the test reviewer claimed. For EVERY agent, issue an HONEST or DISHONEST verdict with specific evidence. Write your audit to [plan-path-without-ext]-final-audit.md. Follow your instructions in .claude/agents/verification-auditor.md."

**Read the audit file and extract the verdict (PASS or FAIL) AND the per-agent HONEST/DISHONEST verdicts.**

**Show the user:**
- Overall verdict
- Per-agent accountability: which agents were HONEST, which were DISHONEST, and what they lied about

**GATE DECISION:**
- If **PASS** → immediately proceed to Phase 6.
- If **FAIL** → launch `plan-coder` to fix, then **go back to Phase 4 (Code Quality Review)** — because fixes may introduce new issues. After code and test reviews pass again, run the final audit again.

**Safety valve**: If the final audit fails 3 times, pause and ask the user how to proceed.

## Phase 6: Done

**Step 1: Read the plan file** to get its name and `## Summary` section.

**Step 2: Update the plan file.** Add a `## Pipeline Results` section at the bottom with:
- Date pipeline completed
- "Mode: light"
- Total rounds per phase
- Key issues caught and fixed (with brief descriptions)
- Final test count and pass status
- Final audit verdict
- List of all review/audit files created

**Step 3: Show the summary.** Your FIRST line of output MUST be:

**Pipeline-Light Complete: [plan file name] — [1-2 sentence summary from the plan's ## Summary section]**

Then show:
- Branch and repo
- Phase table (rounds and results) — note this was light mode (1 reviewer per stage)
- Deleted files count
- Key issues caught and fixed
- Agent accountability
- Files in docs/plans/
- "Would you like to commit these changes?"

## Important Rules

- **USE THE AGENT TOOL FOR EVERY PHASE.** Never do the work yourself. ALWAYS delegate to the appropriate agent.
- **NEVER skip a verification gate.** Both gates (Phase 3.5 and Phase 5.5) are mandatory in light mode too. Skipping them would defeat the purpose of having light mode — the auditor is what makes "one reviewer per stage" safe.
- **NEVER skip the pre-flight checks (Phase 0).** Branch must be confirmed before ANYTHING else happens.
- **TEST RUNS MUST BE THE FULL SUITE.** Same rule as full /pipeline — the test-reviewer and verification-auditor must invoke `mix test` / `yarn test:run` / `yarn test` with NO file path argument. Subset runs are an invalid review even in light mode.
- The plan-creator revises the plan IN PLACE (same file, adds revision notes).
- The plan-coder fixes code based on the reviewer's feedback.
- If any agent reports a discrepancy, STOP and tell the user.
- All review files go in the same directory as the plan.
- **VERIFY AGENT OUTPUT FILES EXIST AFTER EVERY AGENT RETURNS.** After each agent completes, immediately run `ls` on the file the agent was supposed to write. If the file does NOT exist, re-launch the SAME agent — do NOT write the file yourself.
- **NEVER write review, audit, or test files yourself.** You are an orchestrator. If an agent didn't write its file, re-launch the agent.
- **THIS IS AUTOPILOT MODE. Never ask "shall I proceed?", "shall I launch?", or "shall I continue?".** Just show a brief status update and immediately move to the next step. The only time you stop and ask the user is at the safety valve (round 6 for reviews, round 4 for post-implementation gate, round 3 for final audit) or if an agent reports a problem.
- **IF THE PLAN GROWS BEYOND LIGHT SCOPE:** If during plan creation or review it becomes clear the change is bigger than "under ~50 lines, low risk, one file" (e.g. plan-reviewer flags cross-project impacts, security implications, or multi-file scope), STOP and tell the user: "This plan looks bigger than light scope. I recommend switching to full `/pipeline` for the additional reviewer coverage. Do you want to continue in light mode anyway, or restart with /pipeline?" Do not silently continue in light mode on a change that needs full review.
