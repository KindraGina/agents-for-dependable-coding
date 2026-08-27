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
- You were invoked by an in-progress `/cascade` run that the user started by explicitly typing `/cascade` — the cascade's description states it runs the pipeline as Stage 2, so naming `/cascade` IS naming the pipeline. This exception applies ONLY to `/cascade`; any other skill or session calling you programmatically still requires fresh confirmation.

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

**The `pwd` output is this run's LAUNCH REPO.** Every branch, file edit, test run, and git command in this entire pipeline run — by you or any agent you launch — happens inside this repo and nowhere else. See the REPO BOUNDARY rule under Important Rules.

**PROTECTED BRANCH REFUSAL — this is a HARD STOP:**

If the current branch is one of `main`, `master`, `staging`, `testflight`, `production`, `prod`, or `release`, you MUST refuse to run. Tell the user verbatim:

> "You're on the protected branch `[branch]`. The pipeline cannot run here directly — changes must be made on a feature branch and merged back. Please create a feature branch (e.g. `git checkout -b feature/[short-description]`) and re-run the pipeline. STOPPING."

Do NOT proceed. Do NOT offer to create the branch yourself. Do NOT ask "should I proceed anyway?" — the user creates the branch themselves and re-runs the pipeline.

**Why this rule exists (April 2026 donation-upsell incident):** A pipeline ran on `staging` directly with no feature branch. 11 files were modified on the protected branch with no PR boundary, no clean rollback path, and contaminated the staging deploy line.

**Then read the plan file** (if a path was provided). Look at the `## Target` section.
- If the branch matches → say "Branch confirmed: [branch]" and proceed.
- If they DON'T match → ask the user which branch to use. **STOP until they answer.**
- If the plan has a `## Prerequisites` or `## Dependencies` section, verify each one is done (grep/ls). If any are NOT DONE, tell the user and ask how to proceed.

**WORKING-TREE ENTANGLEMENT CHECK — run `git status --short` and compare against the plan:**
- If the working tree has uncommitted modifications to ANY file the plan's `## Proposed Changes` will touch, STOP and tell the user: "The working tree already has uncommitted changes to `[files]`, which this plan also edits. Running the pipeline here would entangle the plan's commit with that in-flight work (and break any cherry-pick step the plan depends on). How do you want the existing changes handled?" Do NOT stash, commit, or discard anything yourself — the user decides.
- Uncommitted changes to files the plan does NOT touch: report them briefly ("N unrelated modified files present — leaving them alone") and proceed.

**TARGET-CODE EXISTENCE CHECK — before any agent launches:**
- Grep the current branch's checkout for the main function(s)/file(s) the plan edits (take them from the plan's `## Verified References`). If the code the plan modifies does not exist on THIS branch, the plan was verified against a DIFFERENT branch — STOP and tell the user which branch actually contains it. Line numbers and references do not cross branches. (July 2026 recent-event-names near-miss: a fix was nearly branched off `master`, where the buggy function didn't exist at all — the plan had been verified against `develop` — and nearly run on a branch whose working tree had unrelated uncommitted edits to the same file.)

**Only after branch is confirmed and both checks pass may you proceed to the finalize-audit gate below.**

## FINALIZE-PLAN AUDIT GATE — MANDATORY, NO EXCEPTIONS

Pipeline-light ONLY runs on plans that have passed `/finalize-plan`. This is a structural firewall against memory-written plans reaching the pipeline.

**Step A — A plan FILE PATH is required.** If the user invoked `/pipeline-light` with only a description and no `docs/plans/...md` path, REFUSE verbatim:

> "Pipeline-light requires a plan file PATH, not a description. Draft your plan first, run `/finalize-plan [plan-path]` until it passes, then re-run `/pipeline-light [plan-path]`. STOPPING."

**Step B — Look for the finalize-plan audit.** Compute the expected audit path: take the plan path, strip `.md`, append `-finalize-audit.md`. Run `ls` on it.

**Step C — If the audit file does NOT exist, REFUSE verbatim:**

> "No `/finalize-plan` audit found for `[plan-path]`. Expected file: `[expected-audit-path]`. Please run `/finalize-plan [plan-path]` first and ensure the verdict is READY before invoking `/pipeline-light`. STOPPING."

**Step D — If the audit file exists, read it.** Extract the `## Verdict:` line.
- If verdict is **READY** → proceed to Phase 2 (Plan Review Loop).
- If verdict is **NEEDS WORK** → REFUSE verbatim:

> "The `/finalize-plan` audit at `[audit-path]` has verdict NEEDS WORK. Fix the failed checks listed in that file, re-run `/finalize-plan` until READY, then re-invoke `/pipeline-light`. STOPPING."

**Phase 1 (Plan Creation) is no longer reachable from `/pipeline-light`.** Plans must be drafted outside the pipeline and finalized before invocation.

## OBSERVATION GATE — MANDATORY, RUNS AFTER THE FINALIZE GATE

The finalize gate proves the plan is *accurate*. This gate asks whether the work is *worth doing*. Light mode is the most likely route for an unobserved code-health finding to enter the pipeline, so this gate applies here in full — it is NOT one of the checks light mode trims.

**Step A — Answer this in one line, out loud, before Phase 2:**

> **What did a human observe, and when?**

Acceptable answers name a real-world signal: a user report, a bug the owner hit, a screenshot, a Sentry entry, a failing production request, a support ticket. Cite it.

**Step B — If the honest answer is "nothing — an agent found this by reading code," STOP and ask verbatim:**

> "Nothing in this plan traces back to something anyone observed — it was found by reading code. The defect may well be real, but its impact is unproven. Options: (a) run the pipeline anyway, (b) log it in `docs/TODO.md` as a code-health item instead. Which do you want? STOPPING."

Wait for the answer. Do NOT proceed on "yes"/"go ahead" alone — the user must pick (a) or (b). If they pick (b), write the TODO entry and stop; do not launch a single agent.

**Step C — Record the answer verbatim in a `## Provenance` section at the top of the plan** before Phase 2 launches. If the user chose (a) on an unobserved finding, it MUST read: "Unobserved — found by code reading. Owner elected to proceed. Severity is UNKNOWN and no agent may assert otherwise."

**Step D — A real-world test that contradicts the code analysis outranks the code analysis.** If a device repro, staging test, or manual check fails to reproduce the described failure at any point in the run, that is evidence AGAINST the finding — not an obstacle to reason around. STOP and surface it. The pipeline's own unit tests never stand in as proof of real-world impact: a test that hand-drives the failure condition proves the mechanism exists, never that any user reaches it.

**Why this gate exists (August 2026 Discover-race incident):** see the full write-up in `skills/pipeline/SKILL.md`. Summary: ~10 hours and 16 documents were spent on a real-but-unobserved code defect that no user, log, or report had ever surfaced. The owner's staging test failed to reproduce it and that was reasoned around rather than heeded. Every agent asked "is this fix correct?"; none asked "should this work exist?".

## Usage

```
/pipeline-light [path to existing plan]
```

- The plan path is REQUIRED. Pipeline-light refuses to run without one.
- The plan at that path must have a passing `/finalize-plan` audit alongside it (see gate above).

## CRITICAL RULES — READ BEFORE DOING ANYTHING

**YOU ARE AN ORCHESTRATOR ONLY.** You MUST delegate ALL work to agents using the Agent tool. You NEVER:
- Read the plan yourself and summarize it
- Analyze code yourself
- Suggest implementation steps yourself
- Answer questions about the plan yourself
- Skip the review agents
- **Fix the plan or code yourself — ALWAYS launch the plan-creator or plan-coder agent to make changes. Even if the fix seems trivial, delegate it.**
- **Fix code in response to user feedback — if the user points out a gap or asks about a problem, your job is to launch an agent to fix it, not to fix it yourself. The user asking a question is not an invitation to start editing files.**

**EVERY phase MUST use the Agent tool.** If you catch yourself doing the work instead of launching an agent, STOP and launch the agent instead.

**Why this rule exists (June 2026 marketing-placement incident):** The user pointed out that 4 frontend items were missing. The orchestrator immediately started editing form.js directly — 6 Edit tool calls, 180 lines changed — instead of launching the plan-coder agent. The user had to ask "which agent are you doing this?" to surface the violation. The orchestrator is never the right agent to write code, even when the user describes exactly what's missing. Especially then — that's a clear plan-coder task.

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

**CIRCUIT BREAKER — check BEFORE launching each round:**
1. Run `wc -l [plan-path]`. A light-mode plan over **300 lines** has outgrown light scope — pause and invoke the existing "IF THE PLAN GROWS BEYOND LIGHT SCOPE" rule (recommend switching to full `/pipeline` or splitting).
2. If you are about to launch **round 4** without an APPROVE, pause and tell the user: "Three review rounds have not converged — for a light-scope change, that means the plan has likely outgrown its scope. I recommend splitting or switching to full `/pipeline`. Continue anyway, split, or switch?"

**Each round (N = 1, 2, 3, ...):**

**Step 1:** Launch the `plan-reviewer` agent.
- Prompt: "You are the plan-reviewer agent. This is review round [N]. Review the plan at [plan-path]. Write your review to [plan-path-without-ext]-review-1-r[N].md. If round 2+, also read your previous reviews. Follow your instructions in .claude/agents/plan-reviewer.md."

**Step 2:** Read the review file ONLY to extract the verdict (APPROVE or NEEDS CHANGES).

**Step 3:** Show a brief status update — "Light plan review round N: [verdict]. Briefly list critical/important issues." — and **immediately proceed to Step 4**.

**Step 4: LOOP DECISION:**
- If APPROVE → **immediately proceed to Phase 3**. Do NOT ask for permission.
- If NEEDS CHANGES → launch the `plan-creator` agent to revise (NEVER fix the plan yourself):
  - Prompt: "You are the plan-creator agent in revision mode. Read the review at [review-1-path]. Revise the plan at [plan-path] to address all critical and important issues. SCOPE IS FROZEN: do not add new Proposed Changes items — corrections to existing items only. Defects the review discovered that the plan's objective does not require fixing go in a `## Discovered Out of Scope` section plus docs/TODO.md, per your Scope Freeze rule. Add a 'Revision Notes — Round N' section. Follow your instructions in .claude/agents/plan-creator.md."
  - **SCOPE-FREEZE RE-CHECK — mandatory after EVERY revision.** The pipeline NEVER changes scope — new scope needs a new plan. Compare the revised plan's `## Proposed Changes` item list against the list from before the revision. If the revision ADDED any item that is not a correction of an existing item, the revision is defective: re-launch the plan-creator to move the new item(s) into `## Discovered Out of Scope` + `docs/TODO.md`, and report those entries to the user in your next status update. Scope creep matters even more in light mode — a growing plan is by definition no longer a light-scope change. (August 2026 Android multi-tap incident: a plan absorbed discovered defects round after round, grew to ~1,900 lines, ran ~10 hours, and never fixed the reported bug.)
  - **SINGLE-REPO RE-CHECK — mandatory after EVERY revision.** The finalize-plan single-repo gate ran BEFORE the pipeline; revisions can smuggle cross-repo work in after it. Grep the revised plan's `## Proposed Changes` and numbered steps for file paths outside the launch repo (absolute paths like `~/Sites/...`, or another repo's name when it is not the launch repo). Cross-repo work may ONLY appear in a `## Cross-Repo Dependencies` section (informational — never implemented by this run). If a mainline step targets another repo, re-launch the plan-creator to move it there and report the cross-repo need to the user — reviewers cannot authorize cross-repo scope; only the user can. (July 2026 tag-taxonomy incident: a mid-pipeline revision wrote a kinlia-web fix into a mainline step and the run edited files in kinlia-web, another session's active repo.)
  - **GO BACK TO STEP 1 with N incremented.**

**Safety valve**: If you reach round 6 without APPROVE, pause and ask the user how to proceed.

## Phase 3: Implementation

Launch the `plan-coder` agent:
- Prompt: "You are the plan-coder agent. Implement the approved plan at [plan-path]. Read the review file too. Follow TDD — write tests first, then implement. Implement ALL items in the plan — you do not get to skip items or invent scope boundaries. If the plan lists a file in the launch repo, that file is in your scope regardless of language or directory. Files outside the launch repo are NEVER in scope — a plan step targeting another repo is a plan defect: do not implement it, report it as BLOCKED per your REPO BOUNDARY rule. Follow your instructions in .claude/agents/plan-coder.md."

After the agent returns, show a brief status update and **immediately proceed to Phase 3.5**.

## Phase 3.5: Post-Implementation Verification Gate

**THIS IS A HARD GATE. Code review CANNOT start until this passes. This gate is the SAME as in full /pipeline — never skip it, even in light mode.**

Launch the `verification-auditor` agent:
- Prompt: "You are the verification-auditor agent running in Mode 1 (Post-Implementation Verification). Verify that every plan item at [plan-path] was actually implemented in the code. Check every file exists, grep for every change, cross-reference the plan-coder's verification summary. Write your audit to [plan-path-without-ext]-verification-audit-r1.md. Follow your instructions in .claude/agents/verification-auditor.md."

**Read the audit file and extract the verdict (PASS or FAIL).**

**ORCHESTRATOR PHANTOM-FILE CROSS-CHECK (mandatory — even on PASS):**
Read the audit, extract every file path mentioned. Run `ls -la` via Bash on each. If ANY file does NOT exist, OVERRIDE the auditor's PASS and treat as FAIL — phantom files invalidate the verdict. The May 2026 notificationsEventDeepLink incident is the why.

**GATE DECISION (only after orchestrator cross-check passes):**
- If **PASS** (auditor + cross-check) → immediately proceed to Phase 4.
- If **FAIL** (auditor OR cross-check) → launch the `plan-coder` to fix ALL failed items, then re-launch the auditor with incremented round number. **Keep looping until PASS AND cross-check pass.** Code review cannot start until both pass.

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

**ORCHESTRATOR PHANTOM-FILE CROSS-CHECK (mandatory — even on PASS / all HONEST):**
The May 2026 notificationsEventDeepLink incident: final audit said PASS with all 9 agents HONEST. The test file claimed to exist did not. Five agents fabricated terminal output. Don't trust the audit alone.

1. Read the final audit. Extract every file path mentioned (especially test files).
2. Run `ls -la` via Bash on each.
3. If ANY file does NOT exist, OVERRIDE the PASS and treat as FAIL. Tell the user the orchestrator caught phantom files the auditor missed.

**Show the user:**
- Overall verdict (after cross-check)
- Per-agent accountability
- Cross-check result (files verified, any phantoms)

**GATE DECISION (only after orchestrator cross-check passes):**
- If **PASS** (auditor + cross-check) → immediately proceed to Phase 6.
- If **FAIL** (auditor OR cross-check) → launch `plan-coder` to fix, then **go back to Phase 4 (Code Quality Review)** — because fixes may introduce new issues. After code and test reviews pass again, run the final audit again — and re-run the orchestrator cross-check.

**Safety valve**: If the final audit (or orchestrator cross-check) fails 3 times, pause and ask the user how to proceed.

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

**Final step — Lessons (never blocks completion).** Launch the `lesson-learner` agent in PROPOSE mode with: the plan file path, all review/audit file paths from this run, the repo path, and a one-paragraph summary of what happened (rounds, issues caught, human corrections). When it returns, show the user the numbered proposals (or "no lessons proposed") and ask in plain text: "Apply any of these? (e.g. 'apply 1 and 3', or 'skip')". On approval, re-launch `lesson-learner` in APPLY mode with the approved numbers. On 'skip' or no reply, do nothing — the proposal file remains on disk. If the learner errors, say so and finish normally; a learner failure never changes the run's verdict.

## Important Rules

- **USE THE AGENT TOOL FOR EVERY PHASE.** Never do the work yourself. ALWAYS delegate to the appropriate agent.
- **REPO BOUNDARY — THE PIPELINE NEVER LEAVES ITS LAUNCH REPO.** The `pwd` recorded at startup is the launch repo for the entire run. Neither you nor ANY agent you launch may create branches, edit files, run tests, or run git commands in any other repository — no matter what the plan says, and no matter how emphatically a reviewer or plan revision insists the change "cannot be silently dropped" or "must ship together." If a plan step, reviewer finding, or agent report calls for changes in another repo: do NOT execute it; ensure it lives only in the plan's `## Cross-Repo Dependencies` section (informational); and surface it to the user as a separate decision — the other repo gets its own plan and its own pipeline run if the user wants one.
  **Why this rule exists (July 2026 tag-taxonomy incident):** the backend tag-taxonomy plan passed finalize as single-repo; a mid-pipeline revision then wrote the exact kinlia-web fix into a mainline step ("specified here so it cannot be silently dropped"); nothing re-checked single-repo after the revision, and the run created a branch and edited files inside kinlia-web — a repo with its own active session — leaving unannounced uncommitted changes in that session's working tree.
- **NEVER skip a verification gate.** Both gates (Phase 3.5 and Phase 5.5) are mandatory in light mode too. Skipping them would defeat the purpose of having light mode — the auditor is what makes "one reviewer per stage" safe.
- **NEVER skip the pre-flight checks (Phase 0).** Branch must be confirmed before ANYTHING else happens.
- **TEST RUNS MUST BE THE FULL SUITE.** Same rule as full /pipeline — the test-reviewer and verification-auditor must invoke `mix test` / `yarn test:run` / `yarn test` with NO file path argument. Subset runs are an invalid review even in light mode.
- The plan-creator revises the plan IN PLACE (same file, adds revision notes).
- The plan-coder fixes code based on the reviewer's feedback.
- If any agent reports a discrepancy, STOP and tell the user.
- All review files go in the same directory as the plan.
- **VERIFY AGENT OUTPUT FILES EXIST AFTER EVERY AGENT RETURNS.** After each agent completes, immediately run `ls` on the file the agent was supposed to write. If the file does NOT exist, re-launch the SAME agent — do NOT write the file yourself.
- **NEVER write review, audit, or test files yourself.** You are an orchestrator. If an agent didn't write its file, re-launch the agent.
- **NEVER OVERRIDE A FAIL VERDICT.** If the verification auditor returns FAIL, you MUST loop — launch the plan-coder to fix, then re-run the auditor. You do NOT get to reinterpret FAIL as "false positive," "artifact issue," or "not a real failure." The auditor's FAIL is mechanical: items in the plan were not found in the code. The orchestrator's only permitted override is the phantom-file cross-check (upgrading PASS to FAIL when files don't exist on disk). Downgrading FAIL to PASS is never permitted.
  **Why this rule exists (June 2026 marketing-placement incident):** The verification auditor returned FAIL because 4 frontend items from the plan were not implemented. The orchestrator dismissed the FAIL, conflating it with a separate artifact issue (missing review files). The result: the pipeline reported success with 4 plan items unimplemented. Hosts could not use the features the pipeline claimed to have shipped.
- **PLAN-CODER PROMPTS MUST INCLUDE THE SCOPE WARNING.** Every prompt you send to the plan-coder (initial implementation or fix mode) MUST include this sentence: "Implement ALL items in the plan — you do not get to skip items or invent scope boundaries. If the plan lists a file in the launch repo, that file is in your scope regardless of language or directory. Files outside the launch repo are NEVER in scope — a plan step targeting another repo is a plan defect: do not implement it, report it as BLOCKED per your REPO BOUNDARY rule." This reinforces the rule in the plan-coder's own agent file and prevents the "frontend-only, outside backend scope" failure mode.
- **THIS IS AUTOPILOT MODE. Never ask "shall I proceed?", "shall I launch?", or "shall I continue?".** Just show a brief status update and immediately move to the next step. The only time you stop and ask the user is at the safety valve (round 6 for reviews, round 4 for post-implementation gate, round 3 for final audit), at the lesson-learner approval ask (final step — a sanctioned stop), or if an agent reports a problem.
- **IF THE PLAN GROWS BEYOND LIGHT SCOPE:** If during plan creation or review it becomes clear the change is bigger than "under ~50 lines, low risk, one file" (e.g. plan-reviewer flags cross-project impacts, security implications, or multi-file scope), STOP and tell the user: "This plan looks bigger than light scope. I recommend switching to full `/pipeline` for the additional reviewer coverage. Do you want to continue in light mode anyway, or restart with /pipeline?" Do not silently continue in light mode on a change that needs full review.
