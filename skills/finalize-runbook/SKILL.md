---
description: Pre-execution gate for ops runbooks (AWS CLI sequences, deployment procedures, manual migrations — anything you the operator will execute manually, one command at a time, with per-command approval). Verifies state claims are pasted live, M-commands are properly labeled and single-mutation, recovery paths are complete, and verification steps are data-independent. Cardinal rule: DO NOT WRITE FROM MEMORY. Different from /finalize-plan (which is for code-change plans that go through /pipeline). Usage: /finalize-runbook [path to runbook file].
---

# /finalize-runbook — Pre-Execution Gate for Ops Runbooks

You are the last structural check before the operator runs commands against production (or staging). Your job: confirm the runbook is grounded in live evidence (not memory) and structurally safe to execute. Reject anything that fails — running a memory-written runbook against production is how outages happen.

## When to use

Use AFTER drafting an ops runbook, BEFORE executing any mutating command. Typical sequence:

1. Operator drafts the runbook (with Claude or another agent).
2. Operator runs `/finalize-runbook [runbook path]` — this skill.
3. If READY → operator runs `/review-runbook [runbook path]` for substantive review.
4. If READY again → operator executes M-commands one at a time, with per-command approval.

This is for runbooks where YOU execute commands manually. NOT for code-change plans (those use `/finalize-plan` → `/pipeline`).

## YOUR ABSOLUTE FIRST ACTION — INVOCATION CHECK

Before reading the runbook, confirm the user explicitly invoked this skill in their CURRENT message.

Explicit invocation = ONE of:
- User typed `/finalize-runbook` in their current message.
- User typed "finalize the runbook" / "check if the runbook is ready" / similar specific phrase.
- User approved a prior proposal by saying "yes /finalize-runbook" — naming the action.

NOT explicit invocation: "continue", "yes", "go ahead", "proceed", "do it" — ambiguous, do not count.

If called programmatically without explicit invocation, STOP and tell the user verbatim:

> "I was about to finalize the runbook but don't see explicit invocation in your most recent message. Reply with `yes /finalize-runbook` to confirm."

## THE CARDINAL RULE — DO NOT USE MEMORY

Every claim in your audit must come from a file or command you ran in this session. The same applies to the runbook: every state claim, every resource ID, every file path, every command flag must be backed by pasted live output from `aws describe-*`, SSH, psql, `ls`, etc. If the runbook says "MasterUsername=postgres" without pasted output from `aws rds describe-db-instances`, the runbook was likely written from memory and is REJECTED.

When the audit completes, state plainly: "I read the following in this session: [runbook file, plus N live commands re-run for spot-check]. Every claim in this audit is backed by those reads."

## Process

### Step 1 — Read the runbook IN FULL

Use the Read tool on the runbook path. Read every section. Don't skim Procedure or Recovery.

### Step 2 — Run the 12 checks

Run them in order. ANY single failure = NEEDS WORK verdict.

---

**Check 1 — Live Verified State appears FIRST in the runbook body. THIS CHECK IS TERMINATING.**

The runbook structure MUST be:
1. Title
2. Target / Why (top-of-file metadata)
3. **Live Verified State** (or `## Verified State`, `## Current state`, `## Live state` — must be the section that documents the actual current state of the system) ← MUST be here, BEFORE Procedure / M-commands
4. Target end state
5. Risks + mitigations
6. Procedure (numbered M-commands)
7. Verification (V-checks)
8. Recovery levers
9. Sign-off

**If the runbook has M-commands (M1, M2, etc.) and no clear "Live Verified State" section before them, STOP. Do NOT run Checks 2–12. Write the audit file with verdict NEEDS WORK and only this Failed Checks entry:**

> "Check 1 (STRUCTURAL FAILURE): Runbook must have a Live Verified State section (containing pasted live command output documenting the current system state) appearing BEFORE the Procedure / M-command section. It is currently [missing / at the bottom / not identifiable]. Restructure with state first, then re-run `/finalize-runbook`. No further checks performed."

**Special case — wrong tool:** If the file has `## Proposed Changes` (code-change section) and no `M_n` mutating commands, this is a code-change plan, not a runbook. Output verdict NEEDS WORK with: "This appears to be a code-change plan, not an ops runbook. Use `/finalize-plan` instead."

---

**Check 2 — Every state claim has pasted live command output.**

For each row / fact in the Live Verified State section:
- Is the actual command shown (e.g., `aws rds describe-db-instances ...`)?
- Is the actual output pasted in a fenced code block (or as a table built directly from the output)?

If a state claim is bare prose ("Production runs PG13.20") without pasted command + output, REJECT.

---

**Check 3 — Re-run ALL Live Verified State commands and diff.**

Re-run EVERY command cited in the Live Verified State section (not a sample — all of them). For each:
1. Run the exact command the runbook cites (or the closest read-only equivalent).
2. Compare the output to what the runbook documents.
3. If the output matches → PASS that entry.
4. If the output differs (state drift, different resource ID, wrong username, wrong DB name, etc.) → record the discrepancy with both the runbook's claimed value and the actual live value.

If ANY entry has a mismatch, REJECT with every discrepancy listed. State changes between when the runbook was written and now mean the runbook is operating on stale facts — and fabricated state claims (written from memory, never actually verified) will fail here too.

**Why exhaustive, not sampled:** A 3-item spot-check lets memory-written claims slip through if they aren't in the random sample. The Postgres upgrade runbook had wrong `MasterUsername` and wrong DB name — both would have been caught by exhaustive re-run but survived spot-checking because they weren't selected. The extra ~30 seconds of command re-runs is worth it for any runbook that touches production infrastructure.

---

**Check 4 — Every M-command has a host label.**

For each M-step (M1, M2, ...), confirm it's labeled with where it runs: `[LAPTOP]`, `[SSH-EC2]`, `[SSH-STAGING]`, or equivalent.

If any M-command is unlabeled, REJECT. Unlabeled commands at 2 AM are how operators run the wrong thing on the wrong host.

---

**Check 5 — No bundled mutating commands (CLAUDE.md April-29 rule).**

For each M-step:
- Does the command combine multiple mutating effects? Common offender: `aws rds modify-db-instance` with BOTH `--engine-version` AND `--db-parameter-group-name` in one call.
- If yes, is there an explicit callout in the runbook justifying the bundle AND showing the verbatim command (not hidden behind a section number)?

If a bundled command lacks a justification callout, REJECT. This is the exact CLAUDE.md rule.

---

**Check 6 — Every M-command requires explicit per-command approval text.**

For each M-step, the runbook must state (somewhere near the command or in a top-of-Procedure preamble) that it requires its own explicit "yes, run M_n" approval. Blanket "approve the plan" language is NOT sufficient.

If approval discipline is missing or fuzzy, REJECT.

---

**Check 7 — Every recovery lever has the full required flag list.**

For each rollback / restore / recovery command:
- Run `aws SERVICE help` (or equivalent docs) and verify all REQUIRED flags are present.
- Common offenders: `restore-db-instance-from-db-snapshot` needs `--db-subnet-group-name`, `--vpc-security-group-ids`, `--db-parameter-group-name`, `--db-instance-class` — missing any → restored instance lands in the wrong VPC or applies wrong params.

If any recovery command is missing required flags, REJECT.

---

**Check 8 — Sed/replace commands have pre/post assertions.**

For any `sed -i`, regex replace, file substitution in the runbook (especially in rollback paths):
- Pre-assertion: `grep -c PATTERN file` to confirm the old pattern exists?
- Post-assertion: `grep -c NEW_PATTERN file` to confirm substitution count matches?

Without these, sed silently no-ops. If absent, REJECT.

---

**Check 9 — Verification checks are data-independent.**

For each V-check (verification step in the Verification section):
- Does it assert against transient data state? E.g., `count > 0 for events within 50mi of SF` — fails at 2 AM if no SF events exist.
- Or is it tautological / system-testing? E.g., `SELECT ST_AsText(ST_Point(...))` tests PostGIS itself.

If any V-check could fail for "data state changed" reasons (vs "system actually broken"), REJECT — the operator can't distinguish real failure from data drift.

---

**Check 10 — Conditional steps are correctly classified as mandatory vs optional.**

For each "do X only if Y" step in Procedure or Recovery:
- Is Y actually conditional, or is Y effectively always true?
- Example: an "M_n reboot if `ParamApplyStatus=pending-reboot`" step is effectively mandatory if the parameter has `ApplyMethod=pending-reboot` (which it does for `rds.force_ssl`). Marking it "optional" means the operator skips it and the app fails.

If a "conditional" step is actually load-bearing for safety, REJECT — must be marked mandatory.

---

**Check 11 — Rollback paths reference live-verified resource IDs.**

For each resource ID in recovery levers (subnet group, security group IDs, param group names, snapshot IDs, instance class):
- Does it appear in Live Verified State?
- If not, it's memory-written or doc-sourced. REJECT.

---

**Check 12 — All file paths in commands have been `ls`-verified.**

For every file path referenced in M-commands or recovery (`/opt/X/Y`, `~/something`):
- Has it been confirmed with `ls` (or equivalent) in this session AND documented in Live Verified State?

If a file path is asserted without evidence, REJECT. Memory-based file paths (the `/opt/kindra/RELEASE_SHA` issue) fail silently.

---

### Step 3 — Write the audit file

Save to `[runbook-path-without-ext]-finalize-audit.md`.

## Output Format

```markdown
# Runbook Finalization Audit — [Runbook Name]

## What I read/ran this session (memory-compliance evidence)
- Runbook file: [path] — read in full: YES
- Live commands re-run for exhaustive Check 3: [list every command + result]
- AWS CLI help commands run (for Check 7): [list]
- Files ls-checked (for Check 12): [list]

## Verdict: READY / NEEDS WORK

## Memory Compliance
- This audit was written from files/commands I read in this session, not from memory: CONFIRMED
- Runbook's own memory compliance (state claims backed by pasted output, sample matches live): PASS / FAIL — [details]

## Checklist Results

| # | Check | Result | Notes |
|---|---|---|---|
| 1 | Live Verified State appears first | PASS / FAIL (TERMINATING) | [details] |
| 2 | Every state claim has pasted output | PASS / FAIL | [missing claims] |
| 3 | ALL state claims match live (exhaustive) | PASS / FAIL | [drift details — list every mismatch] |
| 4 | Every M-command has host label | PASS / FAIL | [unlabeled commands] |
| 5 | No bundled commands (or with justification callout) | PASS / FAIL | [bundled M-steps + whether justified] |
| 6 | Per-command approval discipline | PASS / FAIL | [missing approval text] |
| 7 | Recovery levers have full flag lists | PASS / FAIL | [missing flags per command] |
| 8 | Sed/replace has pre/post assertions | PASS / N/A / FAIL | [missing assertions] |
| 9 | V-checks are data-independent | PASS / FAIL | [data-dependent V-checks] |
| 10 | Conditional steps correctly classified | PASS / FAIL | [mis-marked steps] |
| 11 | Rollback resource IDs in Live Verified State | PASS / FAIL | [unverified IDs] |
| 12 | All file paths ls-verified | PASS / FAIL | [unverified paths] |

## Failed Checks — What to Fix

[For each FAIL above, give specific instructions:]
- Check N: [exact issue + how to fix + file:line if applicable]

## Recommended Next Steps

If READY:
- "Runbook is structurally ready. Recommend running `/review-runbook [runbook-path]` next for substantive review (AWS command correctness, recovery path soundness, timing realism). After that passes, you can begin executing M-commands one at a time."

If NEEDS WORK:
- "Runbook is NOT ready. Address the failed checks above, then re-run `/finalize-runbook`."
- Order the fixes by check number.
```

## Rules

- **NEVER use memory.** Every claim in the audit comes from a file/command read this session. Paste evidence inline.
- **Check 3 is exhaustive.** Re-run ALL Live Verified State commands, not a sample. For Checks 2, 4, 5, 6, 7, 8, 9, 10, 11, 12 you also check ALL relevant items.
- **Be specific in failures.** "Recovery lever missing flags" is not enough. "Recovery `restore-db-instance-from-db-snapshot` at line N missing `--db-subnet-group-name` and `--vpc-security-group-ids` — required per `aws rds restore-db-instance-from-db-snapshot help` output (pasted in §3 of this audit)." That's specific.
- **READY / NEEDS WORK — no soft verdicts.** No "looks mostly good" / "minor issues but ship it." Any FAIL → NEEDS WORK.
- **Confirm memory compliance explicitly at the top of the audit.** The user must see the evidence trail.
- **Save the audit file alongside the runbook**: `[runbook-name]-finalize-audit.md`.
