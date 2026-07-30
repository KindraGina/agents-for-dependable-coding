---
description: Run the full plan → review → code → verify → review → verify pipeline with iterative loops. Agents review each other's work in rounds until all approve. Includes verification auditor gates to catch phantom implementations.
---

# Agent Pipeline

Run the full iterative agent pipeline for a feature, bug fix, or refactor.

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

**Why this rule exists (April 2026 donation-upsell incident):** A pipeline ran on `staging` directly with no feature branch. 11 files were modified on the protected branch with no PR boundary, no clean rollback path, and contaminated the staging deploy line. The pipeline confirmed the branch at startup but didn't refuse to run on it.

**Then read the plan file** (if a path was provided). Look at the `## Target` section.
- If the branch matches → say "Branch confirmed: [branch]" and proceed.
- If they DON'T match → ask the user which branch to use. **STOP until they answer.**
- If the plan has a `## Prerequisites` or `## Dependencies` section, verify each one is done (grep/ls). If any are NOT DONE, tell the user and ask how to proceed.

**WORKING-TREE ENTANGLEMENT CHECK — run `git status --short` and compare against the plan:**
- If the working tree has uncommitted modifications to ANY file the plan's `## Proposed Changes` will touch, STOP and tell the user: "The working tree already has uncommitted changes to `[files]`, which this plan also edits. Running the pipeline here would entangle the plan's commit with that in-flight work (and break any cherry-pick step the plan depends on). How do you want the existing changes handled?" Do NOT stash, commit, or discard anything yourself — the user decides.
- Uncommitted changes to files the plan does NOT touch: report them briefly ("N unrelated modified files present — leaving them alone") and proceed.

**TARGET-CODE EXISTENCE CHECK — before any agent launches:**
- Grep the current branch's checkout for the main function(s)/file(s) the plan edits (take them from the plan's `## Verified References`). If the code the plan modifies does not exist on THIS branch, the plan was verified against a DIFFERENT branch — STOP and tell the user which branch actually contains it. Line numbers and references do not cross branches.
- **Why these checks exist (July 2026 recent-event-names near-miss):** a datetime fix was nearly run on a branch carrying a large pile of unrelated uncommitted edits to the exact file the plan targeted — which would have destroyed the clean cherry-pickable commit the plan's rollout step required — and was then nearly branched off `master`, where the buggy function didn't exist at all (the plan's references had been verified against `develop`).

**Only after branch is confirmed and both checks pass may you proceed to the finalize-audit gate below.**

## FINALIZE-PLAN AUDIT GATE — MANDATORY, NO EXCEPTIONS

The pipeline ONLY runs on plans that have passed `/finalize-plan`. This is a structural firewall against memory-written plans reaching the pipeline.

**Step A — A plan FILE PATH is required.** If the user invoked `/pipeline` with only a description and no `docs/plans/...md` path, REFUSE verbatim:

> "The pipeline requires a plan file PATH, not a description. Draft your plan first (e.g. with a separate planning agent or `/plan`), run `/finalize-plan [plan-path]` until it passes, then re-run `/pipeline [plan-path]`. STOPPING."

**Step B — Look for the finalize-plan audit.** Compute the expected audit path: take the plan path, strip `.md`, append `-finalize-audit.md`. Run `ls` on it.

**Step C — If the audit file does NOT exist, REFUSE verbatim:**

> "No `/finalize-plan` audit found for `[plan-path]`. Expected file: `[expected-audit-path]`. Please run `/finalize-plan [plan-path]` first and ensure the verdict is READY before invoking `/pipeline`. STOPPING."

**Step D — If the audit file exists, read it.** Extract the `## Verdict:` line.
- If verdict is **READY** → proceed to Phase 2 (Plan Review Loop).
- If verdict is **NEEDS WORK** → REFUSE verbatim:

> "The `/finalize-plan` audit at `[audit-path]` has verdict NEEDS WORK. Fix the failed checks listed in that file, re-run `/finalize-plan` until the verdict is READY, then re-invoke `/pipeline`. STOPPING."

**Step E — Retroactive plans get the FULL path.** If the plan contains a `## Retroactive Plan` marker (it documents code that already exists), do NOT compress or skip any phase. Phase 3 becomes "plan-coder verifies the existing diff implements the plan and fixes gaps," and Phases 3.5–5.5 run in full against the actual diff. Documentation of existing work is never pre-approved work.

**Phase 1 (Plan Creation) is no longer reachable from `/pipeline`.** Plans must be drafted outside the pipeline and finalized before invocation. The plan-creator agent is still used in Phase 2 for REVISIONS during the review loop — that's its only remaining role.

**Why this gate exists:** Plans written from memory contain wrong function names, wrong return types, wrong schema fields, wrong table names — bugs that the pipeline reviewers were never designed to catch (they assume the plan is grounded). The `/finalize-plan` audit catches memory-writing by verifying every code reference has pasted source. Without this gate, memory-written plans burn pipeline cycles and ship bugs.

## Usage

```
/pipeline [path to existing plan]
```

- The plan path is REQUIRED. The pipeline refuses to run without one.
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

**HOW TO LAUNCH AGENTS:** Use the Agent tool with a prompt that tells the agent what to do and which files to read. Example:

```
Agent tool call:
  description: "Plan reviewer round 1"
  prompt: "You are the plan-reviewer agent. Review the plan at docs/plans/2026-03-12-feature.md. Write your review to docs/plans/2026-03-12-feature-review-1-r1.md. Follow your instructions in .claude/agents/plan-reviewer.md."
```

## The 10 Agents

| Agent | Role |
|-------|------|
| `plan-creator` | Creates and revises the implementation plan |
| `plan-reviewer` | First plan reviewer — checks completeness, architecture, feasibility |
| `plan-reviewer-2` | Second plan reviewer — audits plan AND reviewer 1's feedback |
| `plan-reviewer-3` | Third plan reviewer — audits plan AND both reviewers' feedback. Focused on production risk, deployment, real-world user impact |
| `plan-coder` | Implements the approved plan using TDD |
| `verification-auditor` | Verifies every agent's claims against actual code. Catches phantom implementations and hallucinated files. Runs twice: after implementation and as final audit. |
| `code-quality-reviewer` | First code reviewer — correctness, security, quality |
| `code-quality-reviewer-2` | Second code reviewer — audits code AND first reviewer's findings |
| `test-reviewer` | First test reviewer — coverage, quality, correctness |
| `test-reviewer-2` | Second test reviewer — audits tests AND first reviewer's findings |

## Phase 1: Plan Creation (skip if user provided a plan path)

Launch the `plan-creator` agent using the Agent tool:
- Prompt: "You are the plan-creator agent. Create an implementation plan for: [user's description]. Write the plan to docs/plans/YYYY-MM-DD-[feature-name].md. Follow your instructions in .claude/agents/plan-creator.md."

After the agent returns, show the user a brief status update and **immediately proceed to Phase 2**. Do NOT ask for permission to continue.

## Phase 2: Plan Review Loop

This loop repeats until ALL THREE reviewers issue an APPROVE verdict **in the same round**.

**IMPORTANT: Reviewers MUST run SEQUENTIALLY, NOT in parallel.** Each reviewer depends on the previous reviewer's output. ALWAYS wait for each reviewer to finish before launching the next one.

**Each round (N = 1, 2, 3, ...):**

**Step 1:** Launch the `plan-reviewer` agent using the Agent tool. **WAIT for it to complete and write its file before proceeding to Step 2.**
- Prompt: "You are the plan-reviewer agent. This is review round [N]. Review the plan at [plan-path]. Write your review to [plan-path-without-ext]-review-1-r[N].md. If round 2+, also read your previous reviews. Follow your instructions in .claude/agents/plan-reviewer.md."

**Step 2 (ONLY after Step 1 is complete):** Launch the `plan-reviewer-2` agent. This agent READS reviewer 1's output, so it CANNOT run at the same time.
- Prompt: "You are the plan-reviewer-2 agent. This is review round [N]. Review the plan at [plan-path] AND reviewer 1's feedback at [review-1-rN-path]. Write your review to [plan-path-without-ext]-review-2-r[N].md. If round 2+, also read your previous reviews. Follow your instructions in .claude/agents/plan-reviewer-2.md."

**Step 3 (ONLY after Step 2 is complete):** Launch the `plan-reviewer-3` agent. This agent READS both reviewer 1's AND reviewer 2's output.
- Prompt: "You are the plan-reviewer-3 agent. This is review round [N]. Review the plan at [plan-path], reviewer 1's feedback at [review-1-rN-path], AND reviewer 2's feedback at [review-2-rN-path]. Write your review to [plan-path-without-ext]-review-3-r[N].md. If round 2+, also read your previous reviews. Follow your instructions in .claude/agents/plan-reviewer-3.md."

**Step 4:** Read all three review files yourself ONLY to extract the verdicts (APPROVE or NEEDS CHANGES). Do NOT analyze the plan yourself.

**Step 5:** Show a brief status update (do NOT wait for user input, just keep going):
- "Round N complete. Reviewer 1: [verdict]. Reviewer 2: [verdict]. Reviewer 3: [verdict]."
- Briefly list critical/important issues from all reviews.
- **Immediately proceed to Step 6.** Do NOT ask "shall I continue?" or "shall I launch reviewers?"

**Step 6: LOOP DECISION — this is critical, do not skip this logic:**
- If ALL THREE say APPROVE → show a brief status update and **immediately proceed to Phase 3**. Do NOT ask for permission.
- If ANY reviewer says NEEDS CHANGES → you MUST:
  1. Launch the `plan-creator` agent to revise (NEVER fix the plan yourself, even if the fix seems trivial):
     - Prompt: "You are the plan-creator agent in revision mode. Read all three reviews at [review-1-path], [review-2-path], and [review-3-path]. Revise the plan at [plan-path] to address all critical and important issues. Add a 'Revision Notes — Round N' section. Follow your instructions in .claude/agents/plan-creator.md."
  2. **SINGLE-REPO RE-CHECK — mandatory after EVERY revision.** The finalize-plan single-repo gate ran BEFORE the pipeline; revisions can smuggle cross-repo work in after it. Grep the revised plan's `## Proposed Changes` and numbered implementation steps for file paths outside the launch repo (absolute paths like `~/Sites/...`, or another repo's name — `kindra`, `kinlia-web`, `kindraapp` — when it is not the launch repo). Cross-repo work may ONLY appear in a `## Cross-Repo Dependencies` section (informational — never implemented by this run). If a mainline step targets another repo, the revision is defective: re-launch the plan-creator to move that work into `## Cross-Repo Dependencies`, and report the cross-repo need to the user in your next status update — the other repo gets its own plan and its own pipeline run only if the user says so. Reviewers cannot authorize cross-repo scope; only the user can. **(July 2026 tag-taxonomy incident:** a Round-2 revision wrote a kinlia-web fix into mainline Step 9 after the plan had passed finalize as single-repo; nothing re-checked, and the run edited files in kinlia-web — another session's active repo.)
  3. **GO BACK TO STEP 1 with N incremented.** Do NOT move to Phase 3. Do NOT stop. Run another FULL round of ALL THREE reviewers on the revised plan. **Even if 2 of 3 approved last round, ALL THREE must review again** — the revision may have introduced new issues.

**YOU MUST KEEP LOOPING until all three reviewers APPROVE in the same round.** One round is almost never enough. Expect 2-4 rounds. Do not treat round 1 as sufficient.

**Safety valve**: If you reach round 6 without all three approving, pause and ask the user how to proceed.

## Phase 3: Implementation

Launch the `plan-coder` agent using the Agent tool:
- Prompt: "You are the plan-coder agent. Implement the approved plan at [plan-path]. Read all review files too. Follow TDD — write tests first, then implement. Implement ALL items in the plan — you do not get to skip items or invent scope boundaries. If the plan lists a file in the launch repo, that file is in your scope regardless of language or directory. Files outside the launch repo are NEVER in scope — a plan step targeting another repo is a plan defect: do not implement it, report it as BLOCKED per your REPO BOUNDARY rule. Follow your instructions in .claude/agents/plan-coder.md."

After the agent returns, show a brief status update and **immediately proceed to Phase 3.5**. Do NOT ask for permission.

## Phase 3.5: Post-Implementation Verification Gate

**THIS IS A HARD GATE. Code review CANNOT start until this passes.**

Launch the `verification-auditor` agent using the Agent tool:
- Prompt: "You are the verification-auditor agent running in Mode 1 (Post-Implementation Verification). Verify that every plan item at [plan-path] was actually implemented in the code. Check every file exists, grep for every change, cross-reference the plan-coder's verification summary. Write your audit to [plan-path-without-ext]-verification-audit-r1.md. Follow your instructions in .claude/agents/verification-auditor.md."

**Read the audit file and extract the verdict (PASS or FAIL).**

**ORCHESTRATOR PHANTOM-FILE CROSS-CHECK (mandatory — even if the auditor said PASS):**

Before accepting the auditor's PASS verdict, you (the orchestrator) MUST independently verify that every file the audit references actually exists on disk. The auditor is supposed to do this (Phantom File Detection is its first check), but the May 2026 notificationsEventDeepLink incident proved that even the auditor can fail this check. You add a second layer.

1. Read the audit file. Extract every file path mentioned (test files, source files, migrations, anything claimed to exist).
2. Run `ls -la` via the Bash tool on each path.
3. If ANY file does NOT exist, OVERRIDE the auditor's PASS verdict and treat the audit as FAIL. Tell the user verbatim:

> "Orchestrator override: the verification auditor reported PASS, but my cross-check found phantom files: `[list]`. The auditor's PASS verdict is invalid. Treating as FAIL. Re-launching plan-coder to actually create the missing files. (This is the failure mode from the May 2026 notificationsEventDeepLink incident — fabricated test files claimed to exist but did not. The orchestrator is the trust anchor outside the subagent chain.)"

Then loop as if the auditor returned FAIL.

**GATE DECISION (only after the orchestrator cross-check passes):**
- If **PASS** (and cross-check confirms) → show a brief status update and **immediately proceed to Phase 4**. Do NOT ask for permission.
- If **FAIL** (auditor OR orchestrator cross-check) → you MUST:
  1. Launch the `plan-coder` agent to fix ALL failed items (NEVER fix them yourself):
     - Prompt: "You are the plan-coder agent in fix mode. The verification auditor found items that were NOT actually implemented. Read the audit at [verification-audit-path]. Fix ALL failed items. For each fix, run grep/read AND `ls -la` to verify your fix exists before marking it done. Follow your instructions in .claude/agents/plan-coder.md."
  2. Launch the `verification-auditor` agent again with an incremented round number.
  3. **Keep looping until the auditor issues PASS AND the orchestrator cross-check passes.** Code review cannot start until both pass.

**Safety valve**: If you reach round 4 of this gate without passing, pause and ask the user how to proceed.

## Phase 4: Code Quality Review Loop

This loop repeats until BOTH code reviewers issue an APPROVE verdict **in the same round**.

**Each round (N = 1, 2, 3, ...):**

**IMPORTANT: Code reviewers MUST run SEQUENTIALLY, NOT in parallel.** Reviewer 2 reads reviewer 1's output.

**Step 1:** Launch `code-quality-reviewer` agent. **WAIT for it to complete before Step 2.**
- Prompt: "You are the code-quality-reviewer agent. This is code review round [N]. Review the code changes for the plan at [plan-path]. The verification auditor has already confirmed the code exists (see [verification-audit-path]). Run git diff to see changes. Write your review to [plan-path-without-ext]-code-review-1-r[N].md. If round 2+, read your previous reviews. Follow your instructions in .claude/agents/code-quality-reviewer.md."

**Step 2 (ONLY after Step 1 is complete):** Launch `code-quality-reviewer-2` agent:
- Prompt: "You are the code-quality-reviewer-2 agent. This is code review round [N]. Review the code AND reviewer 1's feedback at [code-review-1-rN-path]. Also read the verification auditor's report at [verification-audit-path]. Write your review to [plan-path-without-ext]-code-review-2-r[N].md. If round 2+, read your previous reviews. Follow your instructions in .claude/agents/code-quality-reviewer-2.md."

**Step 3:** Extract verdicts. Show a brief status update and **immediately proceed to Step 4**. Do NOT ask for permission.

**Step 4: LOOP DECISION — this is critical, do not skip this logic:**
- If BOTH APPROVE → **immediately proceed to Phase 5**. Do NOT ask for permission.
- If EITHER says NEEDS CHANGES → you MUST:
  1. Launch `plan-coder` agent to fix the issues (NEVER fix the code yourself).
  2. **GO BACK TO STEP 1 with N incremented.** Run BOTH reviewers again, even if one approved last round.

**YOU MUST KEEP LOOPING until both code reviewers APPROVE in the same round.** Do not stop at round 1.

**Safety valve**: Pause at round 6.

## Phase 5: Test Coverage Review Loop

**SEQUENTIAL — reviewer 1 first, WAIT, then reviewer 2. Never run them in parallel.**

This loop repeats until BOTH test reviewers issue an APPROVE verdict **in the same round**.

**Each round (N = 1, 2, 3, ...):**

**Step 1:** Launch `test-reviewer` agent. **WAIT for completion.**
- Prompt: "You are the test-reviewer agent. This is test review round [N]. Review the tests for the plan at [plan-path]. Run the tests. Write your review to [plan-path-without-ext]-test-review-1-r[N].md. If round 2+, read your previous reviews. Follow your instructions in .claude/agents/test-reviewer.md."

**Step 2 (ONLY after Step 1 complete):** Launch `test-reviewer-2` agent.
- Prompt: "You are the test-reviewer-2 agent. This is test review round [N]. Review the tests AND reviewer 1's feedback at [test-review-1-rN-path]. Write your review to [plan-path-without-ext]-test-review-2-r[N].md. If round 2+, read your previous reviews. Follow your instructions in .claude/agents/test-reviewer-2.md."

**Step 3:** Extract verdicts. Show a brief status update and **immediately proceed to Step 4**. Do NOT ask for permission.

**Step 4: LOOP DECISION — this is critical, do not skip this logic:**
- If BOTH APPROVE → **immediately proceed to Phase 5.5 (Final Audit)**. Do NOT ask for permission.
- If EITHER says NEEDS CHANGES → you MUST:
  1. Launch `plan-coder` agent to fix the test issues (NEVER fix the code yourself).
  2. **GO BACK TO STEP 1 with N incremented.** Run BOTH reviewers again, even if one approved last round.

**YOU MUST KEEP LOOPING until both test reviewers APPROVE in the same round.** Do not stop at round 1.

**Safety valve**: Pause at round 6.

## Phase 5.5: Final Verification Audit

**THIS IS THE FINAL GATE. Nothing is "done" until this passes. This is where we catch every agent that lied.**

Launch the `verification-auditor` agent using the Agent tool:
- Prompt: "You are the verification-auditor agent running in Mode 2 (Final Audit). This is the final verification before the pipeline completes. Your job is to verify that EVERY agent actually did what it claimed. Read the plan at [plan-path], ALL code review files, ALL test review files, and the post-implementation audit at [verification-audit-path].

You MUST run the full Agent-by-Agent Accountability Check from your instructions. Specifically:

1. PLAN-CREATOR: Did they verify files exist before listing them? Check the Target section.
2. PLAN REVIEWERS: Did they give specific file:line references or generic rubber-stamps? Spot-check their claims.
3. PLAN-CODER: Did they paste grep evidence for every VERIFIED item? Re-run every grep yourself.
4. CODE REVIEWERS: Did they include Repo & Branch Verification? Did they actually do Plan-to-Code Verification? Spot-check their VERIFIED claims.
5. TEST REVIEWER 1: Did they paste RAW TERMINAL OUTPUT from running tests — not a summary, the actual output? Did they verify test files exist with ls? Did they paste actual assertion code when claiming coverage? RUN THE TESTS YOURSELF and compare your output to what they claimed.
6. TEST REVIEWER 2: Did they paste raw test output? Did they compare their output to reviewer 1's? Did they audit whether reviewer 1 pasted raw output? RUN THE TESTS YOURSELF and compare to both reviewers.

For EVERY agent, issue an HONEST or DISHONEST verdict with specific evidence.

Write your audit to [plan-path-without-ext]-final-audit.md. Follow your instructions in .claude/agents/verification-auditor.md."

**Read the audit file and extract the verdict (PASS or FAIL) AND the per-agent HONEST/DISHONEST verdicts.**

**ORCHESTRATOR PHANTOM-FILE CROSS-CHECK (mandatory — even if the auditor said PASS and all agents HONEST):**

The May 2026 notificationsEventDeepLink incident: final audit said PASS, all 9 agents HONEST. The orchestrator believed it. The test file the audit said was passing did not exist on disk. Five separate agents fabricated terminal output.

Before accepting the final PASS:
1. Read the final audit file. Extract every file path mentioned across the audit (especially every test file).
2. Run `ls -la` via the Bash tool on each path.
3. If ANY file does NOT exist, OVERRIDE the final PASS and treat as FAIL. Tell the user verbatim:

> "Orchestrator override: the final verification auditor reported PASS with all agents HONEST, but my cross-check found phantom files: `[list]`. The audit's PASS verdict is invalid — the test files supposedly executed do not exist on disk. This is the failure mode from the May 2026 notificationsEventDeepLink incident. Re-launching the plan-coder to actually create the missing files, then re-running Phase 4 and Phase 5."

Then loop as if the final audit returned FAIL.

**Show the user:**
- Overall verdict (after cross-check)
- Per-agent accountability: which agents were HONEST, which were DISHONEST, and what they lied about
- Cross-check result: how many files the orchestrator verified, any phantoms found

**GATE DECISION (only after the orchestrator cross-check passes):**
- If **PASS** (and cross-check confirms) → show a brief status update and **immediately proceed to Phase 6 (Done)**. Do NOT ask for permission.
- If **FAIL** (auditor OR orchestrator cross-check) → you MUST:
  1. Show the user which agent claims failed verification (or which phantom files were found) and what was caught.
  2. Launch the `plan-coder` agent to fix ALL failed items.
  3. **Go back to Phase 4 (Code Quality Review Loop)** — because fixes may introduce new issues that need code and test review.
  4. After code and test reviews pass again, run the final audit again — and re-run the orchestrator cross-check.

**Safety valve**: If the final audit (or orchestrator cross-check) fails 3 times, pause and ask the user how to proceed.

## Phase 6: Done

**Step 1: Read the plan file.** Run `Read` on the plan file to get its name and `## Summary` section. You need this for the output below.

**Step 2: Update the plan file.** Use the Edit tool to add a `## Pipeline Results` section at the bottom of the plan file with:
- Date pipeline completed
- Total rounds per phase
- Key issues caught and fixed (with brief descriptions)
- Final test count and pass status
- Final audit verdict
- List of all review/audit files created

This makes the plan the permanent source of truth for what happened during the pipeline.

**Step 3: Show the summary.** Your FIRST line of output MUST be:

**Pipeline Complete: [plan file name] — [1-2 sentence summary from the plan's ## Summary section]**

This is NOT optional. The user runs multiple pipelines in parallel and needs to know which plan just finished. If your first line does not contain the plan name and what it does, the summary is useless.

Then show the rest:
- Branch and repo
- Phase table (rounds and results)
- Deleted files count
- Key issues caught and fixed
- Agent accountability
- Files in docs/plans/
- "Would you like to commit these changes?"

## Important Rules

- **USE THE AGENT TOOL FOR EVERY PHASE.** Never do the work yourself. Never fix the plan yourself. Never fix code yourself. ALWAYS delegate to the appropriate agent.
- **REPO BOUNDARY — THE PIPELINE NEVER LEAVES ITS LAUNCH REPO.** The `pwd` recorded at startup is the launch repo for the entire run. Neither you nor ANY agent you launch may create branches, edit files, run tests, or run git commands in any other repository — no matter what the plan says, and no matter how emphatically a reviewer or plan revision insists the change "cannot be silently dropped" or "must ship together." If a plan step, reviewer finding, or agent report calls for changes in another repo: do NOT execute it; ensure it lives only in the plan's `## Cross-Repo Dependencies` section (informational); and surface it to the user as a separate decision — the other repo gets its own plan and its own pipeline run if the user wants one.
  **Why this rule exists (July 2026 tag-taxonomy incident):** the backend tag-taxonomy plan passed finalize as single-repo; a Pipeline Round-2 revision then wrote the exact kinlia-web fix into mainline Step 9 ("specified here so it cannot be silently dropped"); nothing re-checked single-repo after the revision, and the run created a branch and edited files inside kinlia-web — a repo with its own active session — leaving unannounced uncommitted changes in that session's working tree. Every containment rule existed at the agent level; the orchestrator had none.
- **ALL REVIEWER GROUPS MUST RUN SEQUENTIALLY.** Reviewer 1 first, wait for completion, THEN reviewer 2, wait, THEN reviewer 3 (for plan reviews). NEVER launch reviewers in parallel.
- **ALL reviewers in a group must APPROVE in the SAME ROUND.** If one approved last round but the plan was revised, they must review again. No skipping reviewers because they approved a previous version.
- NEVER skip a reviewer. All reviewers in each group must run every round.
- **NEVER skip a verification gate.** Both gates (Phase 3.5 and Phase 5.5) are mandatory. Code review cannot start without passing Phase 3.5. The pipeline cannot complete without passing Phase 5.5.
- **TEST RUNS MUST BE THE FULL SUITE, NOT JUST TOUCHED FILES.** Every reviewer that runs tests (code-quality-reviewer, code-quality-reviewer-2, test-reviewer, test-reviewer-2) must invoke `mix test` (kindra) / `yarn test:run` (kinlia-web) / `yarn test` (kindraapp) with NO file path argument. The April 2026 tier-upsell incident shipped to staging because reviewers ran a 126-test subset of a 2,175-test project, and the regression was in an untouched file. If any reviewer reports a test count far below the project's known total, treat it as an invalid review.
- **THE VERIFICATION AUDITOR IS NEVER OPTIONAL.** Even if the plan is a deployment plan, a merge plan, or any other non-code plan where you skip coding/review phases — the verification auditor MUST still run at the end (Phase 5.5) to verify that what was claimed actually happened. Did the merge succeed? Did the push go through? Are conflicts resolved? The auditor catches lies and verifies claims — this applies to ALL plan types, not just code plans. If you skip Phases 3-5 because there's no code to write, you MUST still run Phase 5.5 before Phase 6.
- **NEVER skip the pre-flight checks (Phase 0).** Branch must be confirmed and prerequisites verified before ANYTHING else happens — before plan review, before implementation, before everything.
- The plan-creator revises the plan IN PLACE (same file, adds revision notes).
- The plan-coder fixes code based on ALL reviewer feedback.
- If any agent reports a discrepancy, STOP and tell the user.
- All review files go in the same directory as the plan.
- **VERIFY AGENT OUTPUT FILES EXIST AFTER EVERY AGENT RETURNS.** After each agent completes, immediately run `ls` on the file the agent was supposed to write. If the file does NOT exist, re-launch the SAME agent — do NOT write the file yourself. An orchestrator-written review is not a real review. The agent must write its own file. If the agent fails to write the file after 2 attempts, STOP and tell the user.
- **NEVER write review, audit, or test files yourself.** You are an orchestrator. If an agent didn't write its file, re-launch the agent. Do NOT reconstruct the file from the agent's response — the agent may have returned a summary, not the full review.
- **NEVER OVERRIDE A FAIL VERDICT.** If the verification auditor returns FAIL, you MUST loop — launch the plan-coder to fix, then re-run the auditor. You do NOT get to reinterpret FAIL as "false positive," "artifact issue," or "not a real failure." The auditor's FAIL is mechanical: items in the plan were not found in the code. The orchestrator's only permitted override is the phantom-file cross-check (upgrading PASS to FAIL when files don't exist on disk). Downgrading FAIL to PASS is never permitted.
  **Why this rule exists (June 2026 marketing-placement incident):** The verification auditor returned FAIL because 4 frontend items from the plan were not implemented. The orchestrator dismissed the FAIL, conflating it with a separate artifact issue (missing review files). The result: the pipeline reported success with 4 plan items unimplemented. Hosts could not use the features the pipeline claimed to have shipped.
- **PLAN-CODER PROMPTS MUST INCLUDE THE SCOPE WARNING.** Every prompt you send to the plan-coder (initial implementation or fix mode) MUST include this sentence: "Implement ALL items in the plan — you do not get to skip items or invent scope boundaries. If the plan lists a file in the launch repo, that file is in your scope regardless of language or directory. Files outside the launch repo are NEVER in scope — a plan step targeting another repo is a plan defect: do not implement it, report it as BLOCKED per your REPO BOUNDARY rule." This reinforces the rule in the plan-coder's own agent file and prevents the "frontend-only, outside backend scope" failure mode.
- **THIS IS AUTOPILOT MODE. Never ask "shall I proceed?", "shall I launch?", or "shall I continue?". Just show a brief status update and immediately move to the next step.** The only time you stop and ask the user is at the safety valve (round 6 for reviews, round 4 for post-implementation gate, round 3 for final audit) or if an agent reports a problem.
