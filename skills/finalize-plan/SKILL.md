---
description: Pre-pipeline gate. Run this AFTER drafting a plan but BEFORE running /pipeline or /pipeline-light. Verifies the plan is comprehensive, every code reference has pasted grep/read evidence, no internal contradictions, no cross-repo bleed, and tests are specific. The cardinal rule is DO NOT WRITE FROM MEMORY — every code reference must be backed by actual pasted code from a file read in this session. Usage: /finalize-plan [path to plan file].
---

# /finalize-plan — Pre-Pipeline Plan Readiness Gate

You are the last gate before the pipeline runs. Your job: tell the user whether the plan is ready for `/pipeline` or `/pipeline-light`, and reject anything that doesn't meet the bar. Wasted pipeline runs are expensive and propagate plan-quality problems into shipped code.

## When to use

User runs `/finalize-plan [plan path]` AFTER drafting the plan, BEFORE running the pipeline. Sequence:

1. User and an agent draft the plan in `docs/plans/YYYY-MM-DD-[name].md`.
2. User runs `/finalize-plan [plan path]`.
3. You audit the plan against the 13 checks below.
4. READY → user runs `/pipeline`. NEEDS WORK → user revises, re-runs `/finalize-plan`.

## YOUR ABSOLUTE FIRST ACTION — INVOCATION CHECK

Before reading the plan, confirm the user explicitly invoked this skill in their CURRENT message.

Explicit invocation = ONE of:
- User typed `/finalize-plan` in their current message.
- User typed "finalize the plan" / "check if the plan is ready" / similar specific phrase.
- User approved a prior proposal by saying "yes /finalize-plan" — naming the action.

NOT explicit invocation: "continue", "yes", "go ahead", "proceed", "do it" — ambiguous, do not count.

If called programmatically without explicit invocation, STOP and tell the user verbatim:

> "I was about to finalize the plan but don't see explicit invocation in your most recent message. Reply with `yes /finalize-plan` to confirm."

## THE CARDINAL RULE — DO NOT USE MEMORY

Every claim in your audit must come from a file you read in this session. The same applies to the plan you're auditing: if the plan says "function X returns `{:ok, result}`" without pasting the function source, the plan was likely written from memory and is REJECTED.

When the audit completes, you MUST state plainly: "I read the following files in this session: [list]. Every claim in my audit is backed by those reads."

## Process

### Step 1 — Read the plan IN FULL

Use the Read tool on the plan path. Read every section. Don't skim.

### Step 2 — Run the 13 checks

Run them in order. ANY single failure = NEEDS WORK verdict for the whole plan.

---

**Check 1 — Verified References section appears FIRST in the plan body. THIS CHECK IS TERMINATING.**

The plan structure MUST be:
1. Title
2. `## Target` (pwd / branch / remote)
3. `## Summary`
4. **`## Verified References`** ← MUST be here, BEFORE `## Proposed Changes`
5. `## Proposed Changes`
6. ... rest

**If `## Verified References` is NOT before `## Proposed Changes`, STOP. Do NOT run Checks 2–11. Write the audit file with verdict NEEDS WORK and only the following Failed Checks entry:**

> "Check 1 (STRUCTURAL FAILURE): `## Verified References` must appear before `## Proposed Changes` in the plan. It is currently [missing / at the bottom / elsewhere]. Move it to the position above, repopulate it with pasted code from actual reads, and re-run `/finalize-plan`. No further checks were performed — fix this first."

**Special case — wrong-tool detection:** If the plan has `M_n` mutating commands (M1, M2, etc.) and no `## Proposed Changes` code-change section, this is an ops runbook (AWS CLI sequence / deploy procedure / manual migration), not a code-change plan. STOP with verdict NEEDS WORK and only this entry:

> "Check 1 (WRONG TOOL): This appears to be an ops runbook (has M_n mutating commands, no `## Proposed Changes` code section). `/finalize-plan` is for code-change plans that go through `/pipeline`. Use `/finalize-runbook [path]` instead — that skill is tuned for ops runbook structure (Live Verified State, host labels, recovery flag completeness, etc.)."

This check is terminating because every other check assumes the plan was written code-first. If `## Verified References` is at the bottom, the body was written from memory and the rest of the audit cannot trust anything in it. Re-running other checks on a memory-written plan produces false confidence.

---

**Check 2 — Every code reference has pasted code evidence.**

For each entry in `## Verified References`:
- file:line citation present?
- The actual code is pasted in a fenced code block (not paraphrased)?

If any reference lacks pasted code (e.g., "verified `foo/2` returns `{:ok, _}`" with no code block beneath it), REJECT.

---

**Check 3 — Re-verify a random sample of 5 references against actual code.**

Pick 5 entries from `## Verified References`. For each:
1. Read the cited file at the cited lines.
2. Confirm the pasted code matches what's actually there.

If ANY mismatch, REJECT with the discrepancy.

---

**Check 4 — Memory-from-author check (Proposed Changes coverage).**

For every code snippet in `## Proposed Changes` that references an existing function, schema field, route, type, or association, confirm there's a matching entry in `## Verified References`. If a Proposed Change uses `MyModule.do_thing/2` or `User.email_verified_at` or any other existing-code reference but `## Verified References` doesn't include it, the plan-author wrote that part from memory. REJECT.

---

**Check 5 — Explore pass evidence.**

If the plan touches new territory (code the user hasn't mentioned in the current session, or a feature area not covered by prior conversation), an Explore pass should have happened first. Look in `## Verified References` for:
- References across multiple files (breadth-first investigation)
- "X is called from Y and Z" findings (Explore output style)

If the plan touches new territory and Verified References only contains 1-2 files with minimal context, output: "ASK USER: This plan touches [area]. Did you run an Explore pass first? If not, recommend running one before pipeline." Set verdict to NEEDS WORK pending the user's answer.

---

**Check 6 — No internal contradictions.**

Find every `### Override` block, every verbatim user quote (text in `> "..."` blockquotes or attributed "user said X"), every "Implementer must NOT default this decision" marker.

For each, grep the rest of the plan for direct contradictions — in Decision sections, "Behaviors to Preserve," test expectations, "Edge Cases," anywhere.

ANY contradiction with a user-authoritative statement = REJECT.

Why: April 2026 donation-upsell incident. Plan line 36 said "donations IN cart" (Override). Plan line 100 said "donations OUT" (Decision 2). Contradiction shipped, broke user's explicit instruction.

---

**Check 7 — Single-repo only.**

Every file in `## Proposed Changes` must be in the current repo (match the plan's `## Target` repo path). Cross-repo work goes in a separate `## Cross-Repo Dependencies` section (informational only — the plan-coder MUST NOT act on it).

If Proposed Changes mixes repos, REJECT.

---

**Check 8 — All file paths exist (or marked "to be created").**

For every file path in `## Proposed Changes`, run `ls` to confirm it exists. If a path doesn't exist AND the plan doesn't explicitly mark it as "new file — to be created," REJECT.

---

**Check 9 — Testing Plan is specific.**

The `## Testing Plan` section MUST:
- Name specific test files (paths)
- Name specific test scenarios (not "covered at integration level," not "may be covered by other tests")
- Specify the framework per test (ExUnit / Vitest / Jest / Playwright / Maestro)

Vague testing = REJECT.

---

**Check 10 — Open Questions resolved or flagged.**

The `## Open Questions` section must either be:
- Empty (all questions answered), OR
- Each question marked with "Implementer must NOT default this decision — surface to user" so the plan-coder doesn't silently pick a default.

Unresolved questions without the flag = REJECT.

---

**Check 11 — Behaviors to Preserve + existing tests pinning behavior.**

If the plan changes the response shape, status code, render path, or return type of any EXISTING function, the plan MUST include a `## Existing Tests Pinning Current Behavior` section that lists the existing tests (file:line + what each asserts) AND explicitly state that the change is in scope of the user's request.

If the plan changes existing behavior without this section, REJECT.

---

**Check 12 — Deferred / Out of Scope section present.**

The plan MUST contain a `## Deferred / Out of Scope` section, even if it just says "None." Every item the plan consciously excludes ("not fixing in this PR," "separate PR," "future work") must be listed there. This is the list the code reviewers and the verification auditor mechanically check the final diff against — deferred work that ships anyway gets caught by grep, not by hoping someone re-reads the prose.

Missing section = REJECT.

---

**Check 13 — Retroactive plan detection.**

Run `git status --short`. If the plan describes work that already exists (phrases like "already implemented," "uncommitted changes from a prior session," "documenting existing work," or the working tree already contains the changes), the plan MUST include a `## Retroactive Plan` marker section stating: "This plan documents code that already exists. The pipeline must run verification, code review, and test review against the ACTUAL DIFF — a retroactive plan is a claim to audit, not a record to trust."

A retroactive plan without this marker = REJECT. Why: the 2026-05-26 TestFlight-fixes plan documented already-implemented changes, zero review rounds ever ran, and an unreviewed component swap shipped a broken phone field (May 2026 MaskInput incident). A plan written after the code is a receipt, not a gate.

---

### Step 3 — Write the audit file

Save to `[plan-path-without-ext]-finalize-audit.md`.

## Output Format

```markdown
# Plan Finalization Audit — [Plan Name]

## What I read this session (memory-compliance evidence)
- Plan file: [path] — read in full: YES
- Code files spot-checked: [list each with file:line]
- Other files referenced: [list]

## Verdict: READY / NEEDS WORK

## Memory Compliance
- This audit was written from files I read in this session, not from memory: CONFIRMED
- Plan's own memory compliance (Verified References complete, evidence pasted, sample matches actual code): PASS / FAIL — [details]

## Checklist Results

| # | Check | Result | Notes |
|---|---|---|---|
| 1 | Verified References appears FIRST in plan | PASS / FAIL | [where it is if FAIL] |
| 2 | Every reference has pasted code | PASS / FAIL | [missing references] |
| 3 | Random 5 references match actual code | PASS / FAIL | [discrepancies] |
| 4 | Proposed Changes references covered in Verified References | PASS / FAIL | [missing coverage] |
| 5 | Explore pass evidence (if new territory) | PASS / N/A / ASK USER | [reasoning] |
| 6 | No internal contradictions | PASS / FAIL | [contradictions found] |
| 7 | Single-repo only | PASS / FAIL | [cross-repo files in Proposed Changes] |
| 8 | All file paths exist | PASS / FAIL | [missing paths] |
| 9 | Testing Plan specific | PASS / FAIL | [vague items] |
| 10 | Open Questions resolved or flagged | PASS / FAIL | [unresolved + unflagged] |
| 11 | Existing-behavior section (if applicable) | PASS / N/A / FAIL | [missing tests-pinning section] |
| 12 | Deferred / Out of Scope section present | PASS / FAIL | [missing section] |
| 13 | Retroactive plan marked (if applicable) | PASS / N/A / FAIL | [retroactive work without marker] |

## Failed Checks — What to Fix

[For each FAIL above, give specific instructions:]
- Check N: [exact issue + how to fix + file:line if applicable]

## Recommended Next Steps

If READY:
- "Plan is ready. You can run `/pipeline [plan-path]` or `/pipeline-light [plan-path]`."

If NEEDS WORK:
- "Plan is NOT ready. Address the failed checks above, then re-run `/finalize-plan`."
- Order the fixes by check number.
```

## Rules

- **NEVER use memory.** Every claim in the audit comes from a file you read in this session. Quote actual lines, not paraphrases. If you can't read a file (path doesn't exist, etc.), mark the check UNVERIFIABLE — don't guess.
- **Spot-check is not skip-check.** For Check 3 you spot-check 5 references. For Checks 6, 7, 8 you check ALL relevant items, not a sample.
- **Be specific in failures.** "Verified References is incomplete" is not enough. "Verified References is missing entries for `EventTicket.upsell_tiers/1` and `host_offerings.product_type` referenced in Proposed Changes line N" — that's specific.
- **Don't be polite.** READY / NEEDS WORK are the verdicts. No "looks mostly good" or "minor issues but ship it." If any check fails, it's NEEDS WORK.
- **Save the audit file to the same directory as the plan.** Filename pattern: `[plan-name]-finalize-audit.md`. Future runs of `/finalize-plan` may compare to a prior audit.
- **Confirm memory compliance explicitly at the top of the audit.** The user needs to see "I read these files in this session" to trust the verdict.
