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

**If `## Verified References` is MISSING or EMPTY, STOP. Do NOT run Checks 2–13. Write the audit file with verdict NEEDS WORK and only the following Failed Checks entry:**

> "Check 1 (STRUCTURAL FAILURE): `## Verified References` is [missing / empty]. The body was written from memory and nothing in it can be trusted. Create it, populate it with pasted code from actual reads, and re-run `/finalize-plan`. No further checks were performed — fix this first."

**If `## Verified References` EXISTS and is populated but sits BELOW `## Proposed Changes`:** record Check 1 as FAILED — the verdict will still be NEEDS WORK and the section must move — but do NOT stop. Run ALL remaining checks in this same round and report every finding together, so the plan-creator fixes the structure AND any substantive issues in ONE revision instead of two. **Why this refinement (Sept 13, 2026):** a cascade's round 1 rejected a plan for section order alone and skipped the rest of the audit; the substantive findings surfaced only in round 2, costing a full extra revise-and-recheck cycle on a plan whose evidence was already solid.

**Special case — wrong-tool detection:** If the plan has `M_n` mutating commands (M1, M2, etc.) and no `## Proposed Changes` code-change section, this is an ops runbook (AWS CLI sequence / deploy procedure / manual migration), not a code-change plan. STOP with verdict NEEDS WORK and only this entry:

> "Check 1 (WRONG TOOL): This appears to be an ops runbook (has M_n mutating commands, no `## Proposed Changes` code section). `/finalize-plan` is for code-change plans that go through `/pipeline`. Use `/finalize-runbook [path]` instead — that skill is tuned for ops runbook structure (Live Verified State, host labels, recovery flag completeness, etc.)."

The missing/empty case is terminating because every other check assumes verified evidence exists — with none, the body was written from memory and the rest of the audit cannot trust anything in it; running further checks would produce false confidence. The mispositioned case is different: the evidence exists and can be audited wherever it sits, so the full audit runs and the reorder is just one of the round's required fixes.

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

**Write your report to BOTH of these paths, with identical content:**

1. `[plan-path-without-ext]-finalize-audit-r[N].md` — the permanent record of round N. Never overwritten by a later round.
2. `[plan-path-without-ext]-finalize-audit.md` — the CANONICAL path. **Overwrite whatever is there.**

`[N]` is this round's number (round 1 → `-r1.md`, round 2 → `-r2.md`, ...). Write the full report to both paths. Do NOT move or rename an existing file to make room — a two-step move-then-copy is how the round-1 record got clobbered on Sept 14, 2026. Two plain writes, no shuffling.

Round numbering restarts at 1 with each NEW finalize run of a plan. If `-r*.md` files from an earlier draft's run already exist, your same-numbered dual-writes overwrite them — that is expected and allowed: they are records of a superseded draft, and the never-overwrite protection does not extend to them across runs. The dual-write is MANDATORY every round even when the plan passes quickly — on Sept 18, 2026, a finalize run that wrote only the canonical file left an old draft's `-r1` as the highest-numbered sibling, and the pipeline's stale-verdict gate stopped a healthy run on the leftover's NEEDS WORK. Writing your own round files is what keeps the highest-numbered sibling current.

**The canonical file is DESIGNED to be overwritten, and the project's "never overwrite a file without asking" rule DOES NOT APPLY to it.** That rule exists to protect work that would be lost. Nothing is lost here: round N's report is preserved in full at its own `-r[N].md` path, and the canonical path is a pointer to the current verdict, not a record. Do not ask the user for permission to overwrite it, and do not instruct any sub-agent to "write to a new file instead of overwriting the previous audit."

**Why this matters (Sept 14, 2026 — ESLint flat-config cascade):** `/pipeline` locates the audit by computing exactly one filename — plan path, strip `.md`, append `-finalize-audit.md` (`pipeline/SKILL.md:80`) — reads the `## Verdict:` line inside, and REFUSES TO RUN unless it says READY. A session applied the never-overwrite rule here and sent rounds 2 and 3 to new `-r2`/`-r3` filenames, explicitly instructing them "do NOT overwrite the round-1 audit." The plan passed on round 3, but the canonical path still held round 1's NEEDS WORK. The only thing standing between a stale verdict and the code-writing phase was the orchestrator noticing and overriding the gate by hand — which is the same as having no gate. If the canonical file does not hold the LATEST verdict, the gate is broken.

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
- **Re-run EVERY `Command:` line and diff it — Check 3 is not a sample.** Script-extract every `Command:` line in `## Verified References` with its fenced block, re-run each read-only from the plan's `## Target` checkout, diff paste vs. real output, and report every mismatch including boundary-only ones. Apply the same diff to any revision-note claim of the form "re-run and confirmed identical." **Why (Sept 16, 2026, password-reset plan):** the five-reference spot-check passed two rounds while three "Raw output" blocks were hand-edited or fabricated — one had been altered so it would agree with a note asserting the opposite of the file's real code — and two "confirmed identical" revision claims were false. A round-3 mechanical re-run of all 33 commands found every one of them. Evidence that was edited is indistinguishable from a plan written from memory, even when the conclusions happen to be right.
- **Be specific in failures.** "Verified References is incomplete" is not enough. "Verified References is missing entries for `EventTicket.upsell_tiers/1` and `host_offerings.product_type` referenced in Proposed Changes line N" — that's specific.
- **Don't be polite.** READY / NEEDS WORK are the verdicts. No "looks mostly good" or "minor issues but ship it." If any check fails, it's NEEDS WORK.
- **Hard-coded test counts are a failure.** If the plan states a suite total or pass criterion as a fixed number without a this-session measurement (command + raw output, run in the plan's `## Target` checkout) pasted in `## Verified References`, flag it: pass criteria must be relative to a measured baseline. (Sept 13, 2026: a count copied from another branch caused rejections in three separate runs in one day.)
- **Save the audit file to the same directory as the plan, at BOTH paths** — `[plan-name]-finalize-audit-r[N].md` (this round's permanent record) and `[plan-name]-finalize-audit.md` (canonical; overwrite it). The canonical path must ALWAYS hold the LATEST round's verdict, because `/pipeline` reads that one filename and nothing else. See Step 3 — the never-overwrite rule does not apply to the canonical file.
- **Confirm memory compliance explicitly at the top of the audit.** The user needs to see "I read these files in this session" to trust the verdict.
- **Causal and scope claims need a NEGATIVE control — re-running the plan's commands cannot verify them.** When a plan says "this works because of X," "X is what makes this safe," or "this only affects A, not B," the observation that the good outcome happens is not evidence X caused it. Require a pasted command that DISABLES or removes X and shows the outcome changing; if there is none, mark the claim unverified in the audit. **Why (Sept 18, 2026, Jest open-handle plan):** the plan claimed its fix was scoped to one Jest config by one mapping line. The mock file was in fact auto-registered in BOTH suites via `roots`, so deleting the mapping changed nothing. Three finalize rounds mechanically re-ran all 39 `Command:` blocks and could not see it — every block was a positive observation. Code review found it in one negative control.
- **An insertion point inside an existing function must come with its control flow.** When a plan says "add this after X" inside an existing function, require the plan to quote every guard, early return, and loading branch that sits ABOVE that point and state explicitly whether the new code is intentionally subject to them. If it does not, mark it unverified — re-running the plan's `Command:` blocks cannot detect it, because each paste is individually correct. **Why (Sept 23, 2026, kindra SMS-blast-history plan):** three finalize rounds verified all 32 evidence blocks and returned READY; plan review round 1 then found the new full-message block was specified to render after two `historyDetail` early returns unrelated to it, so the message — the entire point of the change — would disappear whenever the per-recipient detail fetch failed or a second blast row was expanded. Same family as the negative-control rule above: evidence integrity is not design review.

## Plain-Language Reporting (MANDATORY)

The person reading your chat reports is not an engineer. Every message shown to the user in chat MUST follow these rules:

- Lead with the bottom line in one everyday sentence ("This change is safe to merge" / "I found 2 problems that must be fixed before this ships").
- Use everyday words. A technical term may appear only if it is immediately explained in plain words in parentheses — e.g. "the merge-base (the point where the PR branched off)". Otherwise leave it out.
- Never reference internal names the reader doesn't know — check numbers ("Check 6"), tier labels ("Tier 1"), agent or skill file names ("test-reviewer.md"), or section headings. Say what the thing does instead: "the step that checks whether tests were already failing before this change."
- Keep ALL the technical evidence (file:line citations, pasted code, raw test output) — but put it in the saved report file, not the chat message. The chat message is the plain-language translation; the file keeps full rigor. Never weaken the file's rigor to satisfy this rule.
- When relaying another agent's findings to the user, translate them first — never paste agent-to-agent output into chat.
- End with the decision the user needs to make, as one plain question, with what each answer would mean.

**Why this exists (2026-09-13):** PR-review and lesson-learner reports were written engineer-to-engineer ("refine Check 6 — 'merge-base' appears nowhere") and the user could not tell what was being proposed or what decision they were being asked to make. The user is non-technical; a report the user cannot understand has failed, no matter how rigorous the work behind it.
