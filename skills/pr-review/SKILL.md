---
description: Review a GitHub pull request against the current codebase. Reads the PR diff, traces every changed symbol's callers and downstream effects, runs the full test suite locally, audits for security issues, leftover debug noise, anti-patterns, backwards-compatibility breaks, migration rollback safety, and PR hygiene (description matches diff, CI passed, not from a protected branch, sensible commits, docs/size sanity). The cardinal rule is DO NOT USE MEMORY — every claim must come from the PR diff and code read in this session. Usage: /pr-review [PR URL or PR number].
---

# /pr-review — Pull Request Review

Your job: review a teammate's (or intern's) PR against this codebase. Be thorough, adversarial, and specific. Don't approve anything you can't defend with file:line evidence.

## When to use

User runs `/pr-review [PR URL or PR number]` when they want Claude to review an incoming PR before they merge it.

This is for PRs from teammates / interns / contributors — NOT for PRs the user themselves authored (those go through `/pipeline` + `/critique`).

## YOUR ABSOLUTE FIRST ACTION — INVOCATION CHECK

Before reading anything, confirm the user explicitly invoked this skill in their CURRENT message.

Explicit invocation = ONE of:
- User typed `/pr-review` in their current message.
- User typed "review the PR" / "review PR #N" / "review this pull request" in their current message.
- User approved a prior proposal by saying "yes /pr-review" — naming the action.

NOT explicit invocation: "continue", "yes", "go ahead", "proceed", "do it" — ambiguous, do not count.

If called programmatically without explicit invocation, STOP and tell the user verbatim:

> "I was about to review the PR but don't see explicit invocation in your most recent message. Reply with `yes /pr-review` to confirm."

## THE CARDINAL RULE — DO NOT USE MEMORY

Every claim in the review must come from a file you read in this session, or the PR diff retrieved in this session. Quote actual lines. Paraphrase = invalid.

When the review completes, you MUST state: "I read the following in this session: [PR diff, file paths, test output]. Every claim is backed by these reads."

## Process

### Step 1 — Fetch the PR

Use `gh` CLI:
- If given a PR number: `gh pr view <number> --json title,body,author,baseRefName,headRefName,state,statusCheckRollup,additions,deletions,changedFiles,commits,files`
- If given a URL: extract the number, do the same.

Record: title, body, author, head branch, base branch, CI status, files changed, additions/deletions, commit messages.

Get the diff: `gh pr diff <number>`.

### Step 2 — Run the 15 checks

Run them in order. Track each as PASS / FAIL / WARN with specific evidence.

---

#### Tier 1 — Must Pass

**Check 1 — PR description vs diff match.**

Compare the PR's body description to the actual diff. Does the description describe what the code does? Is there scope creep (diff includes changes unrelated to the description)? Are acceptance criteria stated? Is a ticket linked?

FAIL if: description is missing, generic ("fixes stuff"), or describes work that isn't in the diff. WARN if: diff includes unrelated changes beyond the stated scope.

---

**Check 2 — Cross-project ripple.**

For EVERY symbol the PR adds, modifies, or removes (exported functions, types, components, routes, DB columns, API endpoints):

1. List the symbols touched (grep the diff for `export`, `defmodule`, `def `, `class`, route definitions, schema fields).
2. For each one, grep the WHOLE codebase for callers: `grep -rn "symbolName" --include='*.ts' --include='*.tsx' --include='*.ex' --include='*.exs' --include='*.js'`.
3. For each caller: does the PR's change still work for that caller? If a function's signature changed, do callers pass the new args? If a field was renamed, do queries still find it?

FAIL if any caller would break.

---

**Check 3 — Security scan.**

Scan the diff for:
- SQL injection / Ecto fragment injection (string interpolation into queries)
- XSS (`dangerouslySetInnerHTML`, unescaped user input in JSX)
- Missing authentication/authorization checks on new endpoints
- Secrets / credentials accidentally committed (API keys, passwords, tokens, `.env` contents)
- CSRF protection on new state-changing endpoints
- Sensitive data in logs (passwords, tokens, PII in `Logger` / `console.log`)

FAIL on any finding.

---

**Check 4 — No leftover noise.**

Grep the diff for:
- Commented-out code blocks (lines starting with `//`, `#`, `--` that contain code, not English)
- `console.log` / `console.debug` / `IO.inspect` / `dbg()` / `print(` (Python) / `puts` (Ruby)
- `debugger` statements
- `TODO` or `FIXME` without a ticket reference
- `.only(` or `.skip(` in test files (would skip or single-out tests in CI)
- `xit` / `xdescribe` (Jest skip)

FAIL on any finding.

---

**Check 5 — Tests prove behavior.**

For every new test in the diff:
- What specific behavior does it prove? Read the assertion.
- BAD: `expect(response.status).toBe(200)` (proves it didn't crash)
- GOOD: `expect(response.body.donation_amount).toBe(50)` (proves the value was actually used)

Could the implementation be wrong and this test still pass? If yes → FAIL.

Also: any test that accepts multiple status codes (`status in [200, 422]`) = FAIL (proves nothing).

---

**Check 6 — Full test suite passes.**

Run the FULL test suite for the affected project — NOT a subset, no file path argument:
- kindra: `cd kindra && mix test`
- kinlia-web: `cd kinlia-web && yarn test:run`
- kindraapp: `cd kindraapp && yarn test`

Paste the FULL terminal output. Note the project's total test count. If the count is far below the project's known total, you ran a subset — re-run.

FAIL if any test fails. FAIL if you ran a subset.

---

**Check 7 — Backwards compatibility.**

If the PR changes an API endpoint, response shape, status code, DB column, or any contract used by the mobile app:
- Will users on old mobile-app versions still work? Mobile app updates are not instant.
- Are old response fields still present, or did the PR remove fields?
- Are there migrations that drop columns the app still reads?

FAIL if the change breaks old clients without a deprecation path.

---

**Check 8 — No "filter out / hide features" anti-pattern.**

Grep the diff for: filtering, hiding, disabling, or excluding features as a "fix" for missing cross-repo support.

Example anti-pattern: "filter out donations from cart upsell because the cart UI doesn't have amount-entry yet." This is sabotage of features the business sells — NOT a fix. The real fix is a plan in the missing-support repo.

FAIL if found.

---

**Check 9 — No defaulting on user-decision flags.**

Grep the diff and commit messages for: "I picked the safer option," "defaulted to X for now," "going with Path A," or any indication the author defaulted on a decision that should have gone to the product owner.

FAIL if the author resolved a product decision unilaterally without evidence of asking.

---

#### Tier 2 — Must Pass

**Check 10 — CI passed.**

Check the PR's CI status: `gh pr view <number> --json statusCheckRollup`. Every check must be `SUCCESS` or `NEUTRAL`. Any FAILURE / ERROR = FAIL.

If CI hasn't run yet, WARN and ask the user to wait for CI before merging.

---

**Check 11 — PR not from a protected branch.**

The PR's head branch (`headRefName`) must NOT be one of: `main`, `master`, `staging`, `testflight`, `production`, `prod`, `release`. Work must happen on a feature branch and be merged BACK to a protected branch — never the other way.

FAIL if the head branch is protected.

---

**Check 12 — Migration / data change rollback safe.**

If the PR includes any file under `priv/repo/migrations/` (Elixir), `prisma/migrations/`, `db/migrate/` (Rails), or similar:
- Is there a `down` / `rollback` step?
- Does the migration drop columns or tables (irreversible data loss)?
- Are there backfill scripts? Are they safe to re-run?

FAIL on irreversible migration without explicit acknowledgment in PR body. WARN on missing rollback step.

---

**Check 13 — Commit hygiene.**

Look at the PR's commit list (`gh pr view <number> --json commits`):
- No `wip`, `fix`, `update`, `changes`, `asdf` commit messages (need to be squashed).
- Each commit message describes WHY the change, not just WHAT.
- No commits over 1000 lines (suggests bundled unrelated changes — should be split).

WARN on bad hygiene. Recommend squash-on-merge.

---

#### Tier 3 — Informational

**Check 14 — Documentation updated.**

If the PR changes a public API, configuration, or developer-facing behavior, the relevant README / inline docs / CHANGELOG should be updated. Grep the diff for changes to `.md` files, `README*`, `CHANGELOG*`, `/docs/`.

WARN if a contract changed but no docs touched. Not a hard FAIL.

---

**Check 15 — Reviewable size.**

`additions + deletions` from the PR metadata. If > 500 lines, WARN — large PRs are hard to review well and likely bundle unrelated changes. Recommend splitting.

Not a hard FAIL.

---

### Step 3 — Write the review

Save to: `/tmp/pr-review-[number].md` (or print to the conversation if the user prefers — ask if unsure).

## Output Format

```markdown
# PR Review — #[number]: [PR title]

## What I read this session
- PR metadata: `gh pr view [number]` — pulled
- PR diff: `gh pr diff [number]` — read in full
- Files I opened in this repo: [list with paths]
- Test output: ran `[command]` — full output pasted below

## Verdict: APPROVE / REQUEST CHANGES / NEEDS DISCUSSION

- APPROVE = all Tier 1 + Tier 2 checks PASS. Tier 3 may have WARN.
- REQUEST CHANGES = any Tier 1 or Tier 2 check is FAIL.
- NEEDS DISCUSSION = the PR has a legitimate trade-off the author should explain (e.g., a Tier 2 WARN that may be acceptable).

## Summary
[2-3 sentences: what does the PR do, is it safe to merge, what's the biggest concern?]

## Checklist Results

| # | Check | Tier | Result | Notes |
|---|---|---|---|---|
| 1 | PR description vs diff | 1 | PASS / FAIL / WARN | [specifics] |
| 2 | Cross-project ripple | 1 | PASS / FAIL | [callers checked + verdict] |
| 3 | Security scan | 1 | PASS / FAIL | [findings] |
| 4 | No leftover noise | 1 | PASS / FAIL | [findings with file:line] |
| 5 | Tests prove behavior | 1 | PASS / FAIL | [weak tests] |
| 6 | Full test suite passes | 1 | PASS / FAIL | [count + result] |
| 7 | Backwards compatibility | 1 | PASS / FAIL / N/A | [breaks if any] |
| 8 | No "hide features" anti-pattern | 1 | PASS / FAIL | [findings] |
| 9 | No defaulting on flags | 1 | PASS / FAIL | [findings] |
| 10 | CI passed | 2 | PASS / FAIL / PENDING | [CI status] |
| 11 | Not from protected branch | 2 | PASS / FAIL | [head branch] |
| 12 | Migration rollback safe | 2 | PASS / FAIL / N/A | [migration details] |
| 13 | Commit hygiene | 2 | PASS / WARN | [issues] |
| 14 | Documentation updated | 3 | PASS / WARN / N/A | [docs touched] |
| 15 | Reviewable size | 3 | PASS / WARN | [line count] |

## Failed Checks — Specific Issues

[For each FAIL, give file:line + actual content + what to fix:]
- **Check N — [name]**: [file:line] — `[actual code or output]` — Fix: [specific action]

## Test Run Output (MANDATORY — full output, no summary)

```
[paste the complete terminal output here]
```

## Suggestions for the Author

[Friendly, specific suggestions beyond hard FAILs. Tier 3 warnings + tone advice for interns. Be kind but specific.]
```

## Rules

- **NEVER use memory.** Every claim comes from the PR diff or a file read in this session. Quote, don't paraphrase.
- **NEVER approve without running the tests yourself.** "The PR's CI passed" is not enough — run the full suite locally. CI catches some things; you catch others.
- **NEVER approve without checking every changed symbol's callers.** Cross-project ripple is the #1 source of intern PR bugs.
- **Be specific in failures.** "Security issue" is not enough — "SQL injection at `src/foo.ts:42` via string interpolation into the query" is.
- **Be kind in tone.** This is for interns. Lead with what's good, then flag what needs to change. Don't pile on.
- **Don't approve with TODOs.** If you find ANY Tier 1 or Tier 2 FAIL, the verdict is REQUEST CHANGES. No "approve but please fix X next time."
- **Confirm memory compliance at the top of the review.** "I read the following in this session" — the user must see the evidence trail.
