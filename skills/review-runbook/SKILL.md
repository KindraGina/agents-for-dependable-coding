---
description: Substantive review of an ops runbook by the runbook-reviewer agent. Human-in-the-loop — runs ONE reviewer per round, shows you the findings, you decide what to fix before the next round. Catches AWS command correctness, bundled mutations, missing flags, fragile rollbacks, data-dependent verification, memory-writing, and other substantive issues that /finalize-runbook (structural) doesn't cover. Different from /review-plan (which is for code-change plans, runs 3 reviewers tuned for source-code review). Usage: /review-runbook [path to runbook file].
---

# /review-runbook — Substantive Review of an Ops Runbook

You are the orchestrator. You delegate ALL review work to the `runbook-reviewer` agent. You do NOT review the runbook yourself.

## When to use

Use AFTER `/finalize-runbook` has passed (READY verdict), BEFORE executing any M-commands. Typical sequence:

1. Operator drafts the runbook.
2. `/finalize-runbook [path]` → structural gate (memory check, command discipline).
3. `/review-runbook [path]` → THIS skill — substantive review.
4. Operator executes M-commands one at a time, with per-command approval.

This skill is human-in-the-loop: after each review round, the orchestrator pauses and shows you the findings. YOU decide whether to fix issues, dismiss them, or approve as-is. The orchestrator does NOT auto-revise.

## YOUR ABSOLUTE FIRST ACTION — INVOCATION CHECK

Before launching any agent, confirm the user explicitly invoked this skill in their CURRENT message.

Explicit invocation = ONE of:
- User typed `/review-runbook` in their current message.
- User typed "review the runbook" / "run a runbook review" / similar specific phrase.
- User approved a prior proposal by saying "yes /review-runbook" — naming the action.

NOT explicit invocation: "continue", "yes", "go ahead", "proceed", "do it" — ambiguous, do not count.

If called programmatically without explicit invocation, STOP and tell the user verbatim:

> "I was about to launch a runbook review but don't see explicit invocation in your most recent message. Reply with `yes /review-runbook` to confirm."

## CRITICAL RULES

**YOU ARE AN ORCHESTRATOR ONLY.** You MUST delegate all review work to the `runbook-reviewer` agent via the Agent tool. You NEVER:
- Read the runbook and summarize it yourself.
- Critique commands yourself.
- Make recommendations the agent should make.
- Decide what to fix on the user's behalf.

**EVERY review uses the Agent tool.** If you catch yourself reviewing the runbook directly, STOP and launch the agent instead.

## Pre-flight check (recommended, not required)

Look for `[runbook-path-without-ext]-finalize-audit.md` alongside the runbook.

- If the audit exists and verdict is READY → note this in your kickoff message and proceed.
- If the audit exists and verdict is NEEDS WORK → note this in your kickoff message. Recommend the operator fix `/finalize-runbook` failures first, but PROCEED if they want substantive review anyway (operator's call).
- If the audit does NOT exist → tell the operator: "No `/finalize-runbook` audit found. I recommend running `/finalize-runbook [path]` first to catch structural / memory issues before substantive review. Want to proceed anyway or pause to run `/finalize-runbook` first?" Wait for explicit answer.

## Process

### Round N (N = 1, 2, 3, ...)

**Step 1: Launch the `runbook-reviewer` agent.**

Use the Agent tool:
- description: "Runbook review round N"
- subagent_type: `runbook-reviewer` (or general-purpose if that's unavailable, with explicit instruction to follow `.claude/agents/runbook-reviewer.md`)
- prompt: "You are the runbook-reviewer agent. This is review round [N]. Review the ops runbook at [runbook-path]. If round 2+, also read your previous review(s) at [previous-review-paths]. Write your review to [runbook-path-without-ext]-runbook-review-r[N].md. Follow your instructions in .claude/agents/runbook-reviewer.md. Cardinal rule: do not use memory — every claim must come from files/commands read in this session."

**Step 2: Wait for the agent to complete.** When it returns, immediately run `ls` on the expected review file path. If the file does NOT exist, re-launch the agent ONCE. If still missing after the second attempt, STOP and tell the user.

**Step 3: Read the review file ONLY to extract the verdict.** Do NOT summarize or restate findings — show the file to the user as-is.

**Step 4: Show the user a kickoff summary:**

```
Runbook review round N complete.

Verdict: [APPROVE / NEEDS CHANGES]
Review file: [path]

Critical findings: [count]
Important findings: [count]
Minor findings: [count]
```

If verdict is APPROVE → tell the user: "Reviewer approved. You can begin executing M-commands one at a time, with explicit per-command approval." Stop.

If verdict is NEEDS CHANGES → tell the user verbatim:

> "Reviewer flagged issues. Please review `[review-file]` and decide what to do:
> - **(a)** Fix the issues yourself / with the runbook author, then re-run `/review-runbook` for round N+1.
> - **(b)** Dismiss specific issues (tell me which numbers + reason), then I'll trigger round N+1 against the updated runbook.
> - **(c)** Approve as-is and proceed to execution despite the findings (you accept the risk).
> - **(d)** Stop reviewing — the runbook needs deeper rework before another round helps.
>
> I will NOT auto-revise. Tell me which option."

**Then STOP and wait for the user's reply.** Do NOT proceed to round N+1 without explicit user direction.

### Safety valve

If you reach round 4 and the reviewer keeps finding new issues with no convergence, recommend to the user: "Reviewer found new issues across 4 rounds — runbook may need a different author or a fundamental rewrite. Recommend pausing reviews and addressing root cause (likely memory-writing). Continue anyway?"

## Important Rules

- **USE THE AGENT TOOL FOR EVERY REVIEW.** Never review the runbook yourself.
- **HUMAN-IN-THE-LOOP.** Pause after every round. Don't auto-revise. Don't auto-trigger the next round.
- **ONE REVIEWER PER ROUND.** Unlike `/review-plan` (3 reviewers) or `/pipeline` (rounds of 3), runbook review uses one focused reviewer per round. The operator decides if a second perspective is needed (re-running this skill triggers another round).
- **VERIFY THE AGENT WROTE THE FILE.** After each agent returns, immediately `ls` the expected review file. If it didn't write the file, re-launch once. Never reconstruct the review yourself from the agent's response.
- **NEVER suggest executing M-commands.** That's a separate step the operator decides on. This skill ends with the review — execution is the operator's call.
- **Tell the user where the review file is.** Always include the path in your kickoff summary.
- **Mention the finalize-audit absence if applicable.** Don't refuse to run, but flag it.
