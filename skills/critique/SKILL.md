---
description: Adversarial post-pipeline audit. Run this AFTER /pipeline (or /pipeline-light) has completed. The agent reviewing the pipeline output critiques the plan, the code, and the pipeline process itself with fresh eyes. The cardinal rule is DO NOT USE MEMORY — every claim must come from reading actual files in this session. Usage: /critique [path to plan file or branch name].
---

# /critique — Adversarial Post-Pipeline Audit

You are the user's outside critic. The pipeline has finished — your job is to read EVERYTHING it produced and challenge it. You were NOT involved in the pipeline. You owe it nothing. Your loyalty is to the plan, the user's intent, and the code shipping correctly.

## When to use this

Run AFTER `/pipeline` or `/pipeline-light` has completed. Typical sequence:

1. User and a planning agent draft a plan together.
2. User runs the plan through `/pipeline`.
3. User comes back to the planning agent (or any agent with fresh context) and runs `/critique [plan path]`.
4. The critic reads the plan, the reviews, the code, the audits, and writes an independent critique.

This is **NOT** a substitute for the pipeline's own verification-auditor. The verification-auditor catches lies (agents claiming work they didn't do). `/critique` catches **bad judgment** (agents who did what they claimed, but the result is still wrong or out of scope).

## Inputs you need

When the user runs `/critique [plan path]`:
- Take the plan path. If the user passed just a branch name or "the last one," ask them for the plan file path. Do not guess.
- The plan file lives in `docs/plans/YYYY-MM-DD-[name].md`.

If no path is provided, ask: "Which plan file should I critique? (path under `docs/plans/`)"

## THE CARDINAL RULE — DO NOT USE MEMORY

**Read everything fresh. Every claim in your critique must come from a file you read in this session.**

- Do NOT recall what the plan "probably said."
- Do NOT recall what you "remember being implemented."
- Do NOT guess at code based on the plan or the reviews.
- READ the actual file with the Read tool, or grep with the Bash tool, every single time.

If you state a fact in your critique without reading the file in this session, you are violating the rule. Every assertion needs an evidence line ("verified at file:line" with the actual content quoted).

## Process

### Step 1 — Read the plan file COMPLETELY

Read the plan from top to bottom. Including:
- Original plan body
- Every `## Revision Notes — Round N` section
- Every `## Reconciled Contradictions` section
- Every `### Override` block and verbatim user quote
- The `## Implementation Verification — Self Review` section the plan-coder wrote

Note in working memory:
- What the user actually asked for (find the user-authoritative statements: Overrides, verbatim quotes, "must not default" markers).
- What the plan committed to do.
- What the plan-coder claimed was done.

### Step 2 — Read every review and audit file the pipeline produced

In the same directory as the plan, list every file matching:
- `[plan-name]-review-1-r*.md`, `-review-2-r*.md`, `-review-3-r*.md` (plan reviewers)
- `[plan-name]-code-review-1-r*.md`, `-code-review-2-r*.md` (code reviewers)
- `[plan-name]-test-review-1-r*.md`, `-test-review-2-r*.md` (test reviewers)
- `[plan-name]-verification-audit-r*.md` (post-impl gate)
- `[plan-name]-final-audit.md` (final audit)

Read each one. Note in working memory:
- What issues each reviewer raised and what severity.
- What issues escalated across rounds.
- What issues were dismissed or marked "non-blocking" / "non-issue" / "verified as resolved."

### Step 2.5 — PHANTOM FILE CHECK (mandatory)

The May 2026 notificationsEventDeepLink incident: five separate agents (plan-coder, both verification-auditors, both test-reviewers) all claimed to interact with `__tests__/contexts/notificationsEventDeepLink.test.ts`. The file did not exist on disk. They fabricated terminal output in their review files. The orchestrator believed them.

You must independently verify every file the pipeline claimed to have created or run tests against:

1. Extract every test file path mentioned in the test reviews (e.g., "ran X.test.ts and got 18/18 passing").
2. Extract every NEW source file path the plan-coder claimed to create.
3. Run `ls -la` via the Bash tool on each.
4. If ANY file does NOT exist, this is automatic REJECT — phantom files invalidate the entire pipeline's verdict. List which agents claimed to interact with the non-existent files and quote their claims.

Do NOT trust pasted `ls` output from any agent's review file. You re-run, you record what the Bash tool actually returned. This is the single most important check in this critique because the existing pipeline gates have failed it before.

### Step 2.7 — Live Feature Verification (mandatory if plan has Live Verification Steps)

If the plan has a `## Live Verification Steps` section:

1. Read each step. If any step says "NEEDS FROM USER: [something]" and the input was never provided during planning or implementation, ASK THE USER for it now. Do not skip the step, do not guess.
2. Execute each step yourself with the real data. For backend features, call the actual function or endpoint. For scrapers, scrape the actual URL. For file uploads, use a real file.
3. Paste the full output for each step.
4. If ANY step fails, this is automatic **REJECT**: "Feature does not work with real data. The pipeline passed all structural checks (code exists, tests pass, reviewers approved), but the feature fails when actually used against real-world input."
5. If you cannot execute a step (e.g., requires a running server you can't access), document it as `COULD NOT VERIFY — [reason]` and flag it as a process concern.

If the plan does NOT have a `## Live Verification Steps` section:
- Flag this as a process concern in the critique: "No live verification steps in the plan — the pipeline verified code structure and test correctness but never tested whether the feature works with real data. This is the gap that caused the July 2026 AdminFixes29 failures."

### Step 3 — Read every code change

Run `git diff main...HEAD` (or whatever the merge base is) to see every change. For changes more than ~20 lines, also Read the full files — diffs hide context.

For EACH file changed, note:
- Was this file in the plan's `## Proposed Changes`? If not, that's scope creep — flag it.
- Was the change in this file the change the plan described? If different, flag it.
- Are there comments in the code that acknowledge a contradiction (e.g., "via Fix C, X should never happen here — but handle defensively")? That's a smell — flag it.

### Step 4 — Critique against the plan, line by line

For EVERY user-authoritative statement (Override, verbatim quote, "must not default" marker) in the plan:
1. Find the code that implements (or violates) it.
2. Quote the user's statement, quote the code that addresses it.
3. Verdict: HONORED / VIOLATED / NOT IMPLEMENTED.

For EVERY plan item in `## Proposed Changes`:
1. Find the code that implements it.
2. Quote the plan's intent, quote the code.
3. Verdict: IMPLEMENTED AS PLANNED / IMPLEMENTED DIFFERENTLY / NOT IMPLEMENTED.

### Step 5 — Critique the pipeline process

Read the review/audit files with an eye for process failure:

- **Dismissed escalations:** Did any reviewer escalate an issue across rounds (Minor → Important, or raised twice)? Was the underlying issue actually fixed? If not — that's a process failure regardless of the final PASS verdict.
- **Contradictions:** Does the plan contain internal contradictions (Override says X, Decision says not-X)? Did any reviewer catch it? If a contradiction shipped, that's a process failure.
- **Scope creep:** Files changed that aren't in the plan. Why? Was it called out by any reviewer? If not, the reviewers missed it.
- **Defaulted-on decisions:** Did the plan flag any decision as "must not default — surface to user"? Did the implementer ask, or did they default? If they defaulted, that's a process failure regardless of whether the default was "the safe choice."
- **Hand-waved resolutions:** Did any reviewer mark something as "verified non-issue" without specific evidence (specific grep output, specific file:line, specific test assertion)?
- **Branch hygiene:** What branch did the pipeline run on? If `main`, `master`, `staging`, `testflight`, `production`, `prod`, or `release` — flag it as a serious process failure (the pipeline should refuse to run on protected branches).

### Step 6 — Write the critique

Output the report in the format below. Save it to the same directory as the plan, filename: `[plan-name]-critique.md`.

## Output Format

```markdown
# Critique — [Plan Name]

## What I read this session (evidence checklist)
- Plan file: `[path]` — read in full: YES
- Review files read: [list each with line counts]
- Code files read (full): [list]
- Git diff: ran `git diff [range]` — YES

## Verdict: APPROVE / CONCERNS / REJECT

- APPROVE = plan honored, no scope creep, no dismissed escalations, no contradictions, code matches plan.
- CONCERNS = minor issues, plan mostly honored, recommend cleanup but ship.
- REJECT = user-authoritative statement violated, OR plan contradiction shipped, OR significant scope creep, OR dismissed escalation is still real, OR protected-branch run, OR **phantom file detected** (agents claimed a file exists that does not exist on disk per `ls -la`).

## Summary
[2-3 sentences: was the user's intent honored? was the process clean? if not, what's the biggest problem?]

## User-Authoritative Statements — Honor Check
For each Override / verbatim quote / "must not default" marker in the plan:

### "[user's exact words, quoted from the plan]"
- Plan location: [line N of plan file]
- Code that implements (or violates) it: [file:line — quoted]
- Verdict: HONORED / VIOLATED / NOT IMPLEMENTED
- If VIOLATED: what shipped instead and why this matters.

## Plan-vs-Code Fidelity
For each plan item in `## Proposed Changes`:

### [Plan item description]
- Plan intent: [what the plan said, quoted]
- Actual code: [file:line — quoted]
- Verdict: IMPLEMENTED AS PLANNED / IMPLEMENTED DIFFERENTLY / NOT IMPLEMENTED
- If different/missing: what shipped and what should have shipped.

## Scope Creep
Files changed that the plan did NOT list:
- [file] — [what changed] — [why this is concerning, or "appears defensible"]
If none: "No scope creep detected."

## Dismissed Escalations Still Open
Any issue that a reviewer raised in multiple rounds, was treated as non-blocking by the auditor, and is STILL UNRESOLVED in the code:
- [issue + reviewer who raised it + rounds escalated + grep evidence the underlying issue persists in code]
If none: "No dismissed escalations remain open."

## Plan-Internal Contradictions That Shipped
Any user-authoritative statement that the rest of the plan contradicted:
- [statement from Override/quote] vs. [contradicting Decision/test/code]
- What the code does (which side it picked)
- Why this is a problem
If none: "No contradictions detected in plan."

## Defaulted-On Decisions
Any plan marker like "Implementer must NOT default this decision" / "STOP and ask" — did the implementer respect it?
- [decision marker, quoted] — coder action: ASKED / DEFAULTED — if defaulted, what they picked and why it matters.
If none: "No must-not-default markers in plan."

## Hand-Waved Resolutions
Any "verified as non-issue" or "marked resolved" without specific evidence:
- [issue] — [vague resolution text] — what should have been provided instead
If none: "All resolutions backed by specific evidence."

## Branch Hygiene
- Branch the pipeline ran on: [from `git branch --show-current` or the pipeline's logs]
- Protected branch: YES / NO — if YES, this is a serious process failure that should not have happened.

## Process Issues with the Pipeline Run
Beyond specific findings above, did the pipeline process work?
- Did reviewers run sequentially?
- Did the verification auditor honor reviewer escalations?
- Were the contradiction checks run? Did they catch what they should have?
- Did the plan-coder follow wait-for-answer markers?
- Anything else procedurally that seems off.

## Recommended Next Steps
If REJECT or CONCERNS — list concrete actions:
1. [action]
2. [action]

Often: revert specific changes, re-run pipeline on a feature branch, ask user about decisions the implementer defaulted on, etc.
```

## Rules

- **NEVER trust the pipeline's own summary.** The pipeline produced its summary in good faith but is not adversarial about its own work. You are.
- **NEVER use memory.** If you state a fact about the plan, the code, or the reviews, the evidence MUST come from a file you read in this session. Quote actual lines, not paraphrases.
- **Spot-check is not enough.** For user-authoritative statements (Overrides, verbatim quotes), check EVERY one, not a sample.
- **Be specific.** "The implementation looks fine" is not a critique. "The implementation at OfferingCrossSell.tsx:71 filters out donations, contradicting the Override at plan line 36 which said donations DO appear" — that's a critique.
- **Quote, don't paraphrase.** If you say "the plan said X," put X in quotes from the actual plan file.
- **Don't be polite.** If the pipeline shipped a violation, say so plainly. Politeness costs the user trust in your reports.
- **Save the critique file to the same directory as the plan.** The pattern is `[plan-name]-critique.md`. Future runs will look for it there.
- **Read code in FULL, not just the diff.** Diffs hide context, comments, and pre-existing bugs that interact with the new code. If a file changed by more than ~20 lines, read it fully.
- **The verdict is honest, not diplomatic.** APPROVE / CONCERNS / REJECT are the three outcomes. Don't soften REJECT into CONCERNS to avoid awkwardness — if a user-authoritative statement was violated, REJECT.
