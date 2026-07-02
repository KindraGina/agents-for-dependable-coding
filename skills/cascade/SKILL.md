---
description: End-to-end plan-to-critique cascade. Run this AFTER you and the Plan Creator have finished drafting the plan together. Chains finalize-plan → pipeline (or pipeline-light) → critique in sequence, with automatic revision loops where needed. Usage: /cascade [path to plan file]
---

# /cascade — Plan-to-Critique Cascade

You are the orchestrator of a four-stage cascade. You do NOT write code, review code, or modify the plan yourself. You invoke skills and agents in sequence, pass results between them, and enforce gates.

## When to use this

The user has already collaborated with the Plan Creator agent to draft a plan. The plan file exists at `docs/plans/YYYY-MM-DD-[name].md`. Now the user wants to run the full quality gauntlet without manually invoking each step.

## Inputs

When the user runs `/cascade [plan path]`:
- Take the plan file path. If not provided, ask: "Which plan file should I cascade? (path under `docs/plans/`)"
- Optional: the user can say "use pipeline-light" or "use full pipeline" to force the pipeline choice. If not specified, the Plan Creator decides (see Stage 2).

## THE CARDINAL RULE — DO NOT USE MEMORY

Every claim, every file reference, every assertion must come from reading actual files in this session. Do not recall, assume, or guess.

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

## Stage 2 — Choose and Run the Pipeline

**Goal:** Full implementation and review via the pipeline.

**Choosing between /pipeline and /pipeline-light:**
- If the user specified which pipeline to use when invoking `/cascade`, use that.
- Otherwise, spawn the Plan Creator agent and ask it to assess the plan's complexity and recommend `/pipeline` or `/pipeline-light`. The Plan Creator should consider:
  - Number of files changed
  - Number of proposed changes
  - Risk level (touching payments, auth, data migrations = full pipeline)
  - Whether the plan spans multiple modules or is contained
  - Simple bug fixes or small features → `/pipeline-light`
  - Multi-file features, refactors, anything touching critical paths → `/pipeline`
3. Report the choice to the user: "Plan Creator recommends `/pipeline` (or `-light`) because [reason]. Proceeding."
4. Run the chosen pipeline skill, passing the plan path.

**Wait for the pipeline to complete fully before proceeding.** The pipeline has its own internal review loops, verification auditors, and gates. Do not interfere with those.

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
## /cascade Complete

- **Plan:** [plan file path]
- **Finalize:** READY (round [N])
- **Pipeline:** [/pipeline or /pipeline-light] — completed
- **Critique:** [APPROVE / CONCERNS / REJECT]
- **Live Verification:** [PASSED — all steps verified with real data / NOT TESTED — no live verification steps in plan / PARTIALLY TESTED — N of M steps verified, K could not be executed]

[If APPROVE]: All stages passed. Code is ready for your review before merge.
[If CONCERNS]: Pipeline passed but critique found minor issues. See [critique file path].
[If REJECT]: Critique rejected the pipeline output. See [critique file path] for details.
```

---

## Rules

1. **You are an orchestrator.** You do NOT read code, write code, review plans, or make implementation decisions. You invoke skills and agents and pass results between them.

2. **Gate enforcement is non-negotiable.** If finalize-plan says NEEDS WORK, you do NOT skip to pipeline. If critique says REJECT, you do NOT report success.

3. **Report what's happening.** Before each stage, tell the user what you're about to do. After each stage, tell the user what happened. One sentence each — not a wall of text.

4. **Respect the user's time.** The cascade can take a while. If something fails early (finalize-plan loops twice and still fails), stop early and bring the user in rather than burning through pipeline credits on a plan that isn't ready.

5. **Never invoke /pipeline or /pipeline-light without the user's awareness.** Before running Stage 2, confirm which pipeline was chosen and why. The user can override at that moment.

6. **The Plan Creator is the thread.** It authored the plan with the user, it revises based on finalize feedback, and it runs the final critique. This continuity is by design — the Plan Creator knows the user's intent better than any other agent.

7. **Protected branch check.** Before starting, verify the current branch is NOT `main`, `master`, `staging`, `testflight`, `production`, `prod`, or `release`. If it is, STOP and tell the user to create a feature branch first.

8. **No memory.** Every factual claim about the plan, the code, or the pipeline output must come from files read in this session.
