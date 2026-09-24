---
description: Lightweight plan-to-critique cascade. Run this AFTER you and the Plan Creator have finished drafting the plan together. Chains finalize-plan → pipeline-light → critique in sequence, with automatic revision loops where needed. Usage: /cascade-light [path to plan file]
---

# /cascade-light — Lightweight Plan-to-Critique Cascade

You are the orchestrator of a four-stage cascade. You do NOT write code, review code, or modify the plan yourself. You invoke skills and agents in sequence, pass results between them, and enforce gates.

This is the lightweight variant of `/cascade`. It always uses `/pipeline-light` — there is no pipeline choice step.

## When to use this

The user has already collaborated with the Plan Creator agent to draft a plan. The plan file exists at `docs/plans/YYYY-MM-DD-[name].md`. Now the user wants to run the full quality gauntlet without manually invoking each step, using the lighter pipeline.

## Inputs

When the user runs `/cascade-light [plan path]`:
- Take the plan file path. If not provided, ask: "Which plan file should I cascade? (path under `docs/plans/`)"

## THE CARDINAL RULE — DO NOT USE MEMORY

Every claim, every file reference, every assertion must come from reading actual files in this session. Do not recall, assume, or guess.

---

## Stage 0 — Launch Preflight (before ANY agent is spawned)

Thirty seconds of read-only shell checks that prevent hours of wasted agent rounds. Run these yourself, in order. If any fails, STOP — report it in plain language and wait for the user; do not spawn any agent.

1. **The plan file exists.** `ls` the exact path given. If missing, say so and ask the user where the plan lives — do not go searching other checkouts on your own.
2. **Right place.** Print `pwd` and `git branch --show-current` and compare against the plan's `## Target` section. Mismatch = STOP: the plan was verified against a different checkout or branch.
   - **Never fix a mismatch by switching branches in a SHARED checkout.** If the plan's branch doesn't exist yet or the checkout is on another branch, create a dedicated worktree (`git worktree add <repo>-worktrees/<branch> -b <branch>`) and run from there — do not `git checkout` in place. **Why (Sept 20, 2026, kinlia-web):** a run opened with `git checkout -q -b` in a checkout shared by four live sessions on four branches — the exact shape of the Sept 13 incident. The branch guard will (correctly) stop the in-place switch anyway; the worktree removes the danger instead of confirming it.
   - **NO IN-PLACE GIT REVERTS OR BRANCH MOVES — the branch guard hook will stop the run.** Every checkout in this setup is shared with other live sessions, and a PreToolUse hook asks Gina before any `git checkout`, `git switch`, `git restore`, `git stash`, `git clean`, `git rebase`, or `git reset --hard`, even in bypass-permissions mode. Each ask stalls the run until she answers. Revert a file from a scratchpad backup (`cp <backup> <file>`) or from HEAD without touching the index (`git show HEAD:<path> > <path>`); never `git checkout -- <file>` or `git restore <file>`. Move to another branch only via a worktree (`git worktree add ...`), never in place. Merge or fast-forward a deploy branch with `git push origin <feature>:<deploy-branch>` (add `git fetch origin <deploy-branch>` and `git merge-base --is-ancestor` first for a fast-forward check), never by `git checkout <deploy-branch>` in the shared tree. **Why (Sept 23, 2026, kindra stale-Jest-suites cascade):** the run stalled twice on hook prompts — once on `git checkout -- $H` used to revert negative controls, once on `git checkout -q develop ... git checkout -q fix/...` in a deploy step. The hook was right both times; the commands were wrong for a shared checkout. This applies to EVERY stage of the cascade, including the pipeline's negative-control reverts and any merge/deploy step at the end — not just the opening branch check.
3. **Dependencies are installed.** For a `package.json` repo, confirm `node_modules/` exists; for an Elixir repo, `deps/`. Missing = STOP and tell the user — an install can take 30 minutes and is the user's call, not a silent detour mid-cascade.
4. **The test runner actually finds tests HERE.** Run each suite's collection mode from this directory — Jest: `npx jest --listTests | head` (repeat per extra config, e.g. `npx jest -c jest.expo.config.js --listTests | head`); other stacks: the equivalent list/dry-run mode. ZERO tests collected = STOP: every RED/GREEN claim the pipeline would make from this directory would be fake. **Why (Sept 13, 2026):** a cascade ran from a checkout under `.claude/worktrees/`, a path this repo's jest config silently ignores — caught only at finalize round 3, costing a mid-cascade folder move plus a 29-minute dependency install.
   - **"Nonzero output" is NOT "tests collected" — read the lines.** Each line must look like a test FILE PATH (`*_test.exs`, `*.test.js`, `*.spec.ts`). If the lines are error text, warnings, or a stack trace, the count is ZERO — stop. **Why (Sept 20, 2026):** in an Elixir repo with a JS `assets/` tree, `npx jest --listTests` printed 9 lines of "cannot find module" error because `assets/node_modules` was missing, and the 9 lines were counted as 9 tests; the empty suite surfaced only at finalize round 1.

---

## Stage 0.5 — Scope Gate: ONE PLAN, ONE PROBLEM

**Run this after Stage 0 passes and BEFORE spawning the Stage 1 finalize agent.** It is the cheapest gate in the system — you read one section of one file and ask at most one question. Every round of every later stage re-reads the whole plan, so a plan carrying three problems costs roughly three times as much at every stage after this one.

**Step A — Count the distinct problems the plan fixes.** Read the plan's `## Summary` and the `### Issue` / numbered items under `## Proposed Changes`. Count how many separate *problems* it fixes — not how many files it edits, not how long it is.

**Step B — Apply the independence test to each pair.** Two problems belong in ONE plan only if fixing one WITHOUT the other would leave the codebase in a broken or half-finished state. Ask literally: *"If I shipped problem A's fix today and never fixed B, would A still be worth shipping on its own?"* If yes, they are independent and belong in separate plans.

**The distinction that matters: a shared ROOT CAUSE is one problem. A shared DISCOVERY METHOD is not.** Three things that surfaced from the same command, the same PR review, or the same afternoon of poking around are not one problem — they are three problems you happened to find together. This is the single most common way a plan gets too big, and it never looks like scope creep from the inside, because every item is real and every item was genuinely found.

**Step C — If the plan fixes MORE THAN ONE independent problem, STOP and ask the user:**

> "Before I start: this plan fixes [N] separate things — [one short everyday phrase per item]. They were all found together, but each one could ship on its own without the others. Running them as one plan means every review round re-checks all [N], which is roughly [N]× the time and cost — and if one item turns out to be contentious, it holds up the others. I'd recommend splitting into [N] plans and running them separately, starting with [the one with the clearest real-world impact]. Split, or run as one? STOPPING."

Wait for the answer. If the user says run as one, proceed and do not ask again for this run. Do NOT split the plan yourself — the user decides, and the Plan Creator does the splitting.

**Step D — Length alone is NOT a trigger. Measure the right section.** Do not raise the scope gate because the document is long. Measure the `## Proposed Changes` section specifically — from its heading to the next `## ` heading — and ignore total file length.

A long `## Verified References` section is **evidence, not scope**: the repo's rules require pasting raw command output for every code reference, and that bulk grows with rounds of auditing, not with the amount of work. A 1,100-line plan that changes 6 files for one reason is FINE and must pass this gate. A 300-line plan that fixes three unrelated things must not. The later 600-line circuit breaker in `/pipeline` measures total length and therefore cannot tell these apart — this gate can, so do the work here.

**Why this gate exists (Sept 13, 2026 — expo test hygiene cascade):** a cascade ran ~4 hours on a plan that bundled three unrelated problems found by running one command (`yarn test:expo`): Sentry open handles, nine `act()` warnings, and un-gated PII `console.log` lines. The actual production-code change was eight lines in two files — delete six `console.log`s, `__DEV__`-gate two more. The plan reached 1,091 lines and needed **four finalize rounds plus three pipeline review rounds**, each re-reviewing all three problems. Scope also grew mid-run: the round-2 audit found five *more* `console.log` lines, expanding an item two rounds had already signed off on. Split into three plans, each would have been a few hundred lines, passed finalize in one or two rounds, and two of the three could have been dropped or deferred without blocking the third. Nothing in the cascade ever asked whether this should be one plan — the existing circuit breakers fire at 600 lines and at review round 4, by which point the rounds are already paid for.

---

## Stage 1 — Finalize the Plan

**Goal:** Independent verification that the plan is pipeline-ready.

**Process:**
1. Invoke `/finalize-plan [plan path]` by spawning an agent to run the finalize-plan skill. This agent is NOT the Plan Creator — it is an independent checker.
2. Read the finalize-plan output.

**If verdict is READY:** Proceed to Stage 2.

**If verdict is NEEDS WORK:**
1. Hand the finalize-plan feedback back to the Plan Creator agent (spawn a plan-creator agent with the plan path and the finalize feedback).
2. The Plan Creator revises the plan.
3. Re-run `/finalize-plan` on the revised plan.
4. **Keep looping** (finalize → Plan Creator revision → finalize) until the verdict is READY.
5. Safety valve: if after **5 rounds** the plan still gets NEEDS WORK, **STOP** and report to the user:
   - What finalize-plan keeps flagging.
   - What the Plan Creator has tried across all rounds.
   - Ask the user how to proceed.

---

## Stage 2 — Run Pipeline Light

**Goal:** Implementation and review via the lightweight pipeline.

**Process:**
1. Report to the user: "Running `/pipeline-light` on the finalized plan."
2. Run the `/pipeline-light` skill, passing the plan path. The user's explicit `/cascade-light` invocation carries pipeline authorization through this run — the pipeline's explicit-invocation gate recognizes an in-progress `/cascade-light` and must NOT re-prompt for "yes /pipeline-light".

**Wait for the pipeline to complete fully before proceeding.** The pipeline has its own internal review loops, verification auditors, and gates. Do not interfere with those.

**When the pipeline reports completion, deliver its summary and IMMEDIATELY begin Stage 3 — do NOT ask.** "Want me to run the critique, or would you rather review first?" is a spec violation, not politeness: the user's single `/cascade-light` invocation ordered all three stages (their CLAUDE.md's /cascade exception explicitly authorizes `/critique` for this run), and the cascade is NOT COMPLETE until the critique verdict is in. The pipeline summary is a status update on the way to Stage 3, never a stopping point.
**Why (Sept 2026 ESLint flat-config run):** the cascade stopped after pipeline-light to ask permission for the critique — adding a human round-trip to a stage that was already authorized, on a run the user expected to finish unattended.

**The pipeline is confined to the repo this cascade was launched in.** If the pipeline (or any reviewer inside it) reports that another repo must change, that is information for the user, not work for this cascade — no stage may create branches or edit files in any other repo (see Rule 9). Report the cross-repo need in your next status update and again in the Stage 4 summary.

---

## Stage 3 — Critique the Pipeline Output

**Goal:** Adversarial, independent audit of everything the pipeline produced.

**Process:**
1. Spawn the Plan Creator agent and instruct it to run `/critique [plan path]`.
2. The Plan Creator runs the critique with fresh eyes — it wrote the plan originally, so it knows the intent, but it was NOT part of the pipeline execution.
3. Read the critique output.

**If verdict is APPROVE:** Proceed to Stage 4 (Done).

**If verdict is CONCERNS:**
- Report the concerns to the user.
- Ask: "The critique found minor concerns. Want me to address them, or are you comfortable shipping as-is?"

**If verdict is REJECT:**
- Report the rejection to the user with the full list of issues.
- Do NOT proceed. The user decides next steps (re-run pipeline, manual fixes, etc.).

---

## Stage 4 — Done

Report a summary to the user:

```
## /cascade-light Complete

- **Plan:** [plan file path]
- **Finalize:** READY (round [N])
- **Pipeline:** /pipeline-light — completed
- **Critique:** [APPROVE / CONCERNS / REJECT]
- **Live Verification:** [PASSED — all steps verified with real data / NOT TESTED — no live verification steps in plan / PARTIALLY TESTED — N of M steps verified, K could not be executed]

[If APPROVE]: All stages passed. Code is ready for your review before merge.
[If CONCERNS]: Pipeline passed but critique found minor issues. See [critique file path].
[If REJECT]: Critique rejected the pipeline output. See [critique file path] for details.
```

If the critique capped its verdict at CONCERNS because of unverified interaction changes, reproduce its `## Manual Verification Required` steps verbatim in this summary — the user must run them before merge, and the cascade must not present the run as fully passed until then.

---

## Rules

**THIS IS AUTOPILOT MODE — one invocation, all stages, no permission asks.** From `/cascade-light [plan]` to the Stage 4 summary, never ask "shall I proceed?", "want me to run X?", or any variant between stages. The ONLY sanctioned stops are the ones this file scripts: a failed Stage 0 preflight, the Stage 0.5 scope gate, a stale finalize verdict, finalize failing twice (Rule 4), the needs-full-pipeline escalation (Rule 5), the protected-branch check (Rule 7), an uncommitted-changes or cross-repo conflict (Rules 9/10), the pipeline's own internal circuit breakers and safety valves, and a critique verdict of CONCERNS or REJECT. Everything else runs straight through. Announcements (Rule 3) are status updates that do NOT wait for a reply — say it and keep moving; the user can interrupt to override.

1. **You are an orchestrator.** You do NOT read code, write code, review plans, or make implementation decisions. You invoke skills and agents and pass results between them.

2. **Gate enforcement is non-negotiable.** If finalize-plan says NEEDS WORK, you do NOT skip to pipeline. If critique says REJECT, you do NOT report success.

3. **Report what's happening.** Before each stage, tell the user what you're about to do. After each stage, tell the user what happened. One sentence each — not a wall of text.

4. **Respect the user's time.** The cascade can take a while. If something fails early (finalize-plan loops twice and still fails), stop early and bring the user in rather than burning through pipeline credits on a plan that isn't ready.

5. **Always uses /pipeline-light.** This is the lightweight cascade — it never escalates to the full `/pipeline`. If the plan turns out to need the full pipeline, stop and tell the user to run `/cascade` instead.

6. **The Plan Creator is the thread.** It authored the plan with the user, it revises based on finalize feedback, and it runs the final critique. This continuity is by design — the Plan Creator knows the user's intent better than any other agent.

7. **Protected branch check.** Before starting, verify the current branch is NOT `main`, `master`, `staging`, `testflight`, `production`, `prod`, or `release`. If it is, STOP and tell the user to create a feature branch first.

8. **No memory.** Every factual claim about the plan, the code, or the pipeline output must come from files read in this session.

9. **Repo containment.** The cascade and everything it invokes run entirely inside the repo where `/cascade-light` was launched. No stage — finalize, pipeline, critique, or any agent they spawn — may create branches, edit files, or run git commands in another repository, no matter what the plan says or how emphatically a reviewer insists. A cross-repo need discovered mid-cascade goes into the plan's `## Cross-Repo Dependencies` section (informational only) and gets reported to the user; the other repo gets its own plan and its own cascade only if the user says so.

10. **Clean-tree and target-code check.** Before Stage 2, run `git status --short`. If the working tree has uncommitted modifications to any file the plan will edit, STOP and ask the user how to handle them — running the pipeline would entangle the plan's commit with unrelated in-flight work and break any cherry-pick step the plan depends on. Never stash, commit, or discard the user's changes yourself. Also verify the code the plan edits actually exists on the current branch (grep for the plan's main target functions from `## Verified References`); if it doesn't, the plan was verified against a different branch — stop and tell the user which branch contains it.

## Plain-Language Reporting (MANDATORY)

The person reading your chat reports is not an engineer. Every message shown to the user in chat MUST follow these rules:

- Lead with the bottom line in one everyday sentence ("This change is safe to merge" / "I found 2 problems that must be fixed before this ships").
- Use everyday words. A technical term may appear only if it is immediately explained in plain words in parentheses — e.g. "the merge-base (the point where the PR branched off)". Otherwise leave it out.
- Never reference internal names the reader doesn't know — check numbers ("Check 6"), tier labels ("Tier 1"), agent or skill file names ("test-reviewer.md"), or section headings. Say what the thing does instead: "the step that checks whether tests were already failing before this change."
- Keep ALL the technical evidence (file:line citations, pasted code, raw test output) — but put it in the saved report file, not the chat message. The chat message is the plain-language translation; the file keeps full rigor. Never weaken the file's rigor to satisfy this rule.
- When relaying another agent's findings to the user, translate them first — never paste agent-to-agent output into chat.
- End with the decision the user needs to make, as one plain question, with what each answer would mean.

**Why this exists (2026-09-13):** PR-review and lesson-learner reports were written engineer-to-engineer ("refine Check 6 — 'merge-base' appears nowhere") and the user could not tell what was being proposed or what decision they were being asked to make. The user is non-technical; a report the user cannot understand has failed, no matter how rigorous the work behind it.
