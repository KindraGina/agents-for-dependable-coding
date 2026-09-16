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

**UNCHANGED-PR SHORT-CIRCUIT — check this before doing anything else.** If a prior `/pr-review` run reviewed this PR (a posted review comment or a review file from a previous run — both record the head SHA they reviewed), compare that SHA to the PR's CURRENT head SHA (`gh pr view <number> --json headRefOid`). Compare SHAs ONLY — never GitHub's "updated X ago" timestamp, which also ticks when a review is posted, a label changes, or the base branch moves. If the SHAs are identical, the code has not changed: do NOT redo the 15 checks. Instead run just the merge-freshness part of Check 10 (the base branch keeps moving even when the PR doesn't) and report: "Head SHA `[sha]` is unchanged since my [date] review — verdict [X] stands. Merge check against the current `[base]` tip: [result]." That is the whole review.
**Why (PR #415, 2026-09-14):** GitHub showed "Updated 17 hours ago," but the only update was the previous review being posted. A full re-review — all 15 checks, four test-suite runs — was redone to reach the byte-identical verdict. The timestamp lies; the head SHA does not.

Get the diff: `gh pr diff <number>`.

**Review from an isolated worktree, never from the user's checkout.** After fetching the PR, run `git fetch origin <headRef>` then `git worktree add /tmp/pr-<number> --detach <head-sha>`, and do ALL file reads and ALL test-suite runs in that worktree. Delete it when done.

WHY (2026-09-13, PR #416): the day-to-day KindraApp checkout was on an unrelated branch with uncommitted changes. Reading files or running Jest there measures a tree that is not the PR — and the reviewer cannot tell, because the files still exist and the tests still pass. Record the worktree absolute path and the head SHA in the review header so every claim is attributable to the PR head.

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

If the diff contains ZERO tests, Check 5 is FAIL by default — a bug fix with no test leaves the exact regression it fixed unguarded.

A PR body that pastes green test output is NOT a substitute. Open the test files it names, grep them for the changed symbol/behavior, and paste that grep in your review. Output can be genuine and still prove nothing about this PR. (2026-09-13, PR #415: the body's "TDD proof" was 10 real passing tests from two suites that contained no `bell` assertion at all — the bell could have been deleted outright and every test in the repo would still pass.)

---

**Check 6 — Full test suite passes (EVERY suite CI runs, not just the default).**

First, open the project's CI workflow (`.github/workflows/*.yaml`) and its `package.json` scripts to find EVERY test command CI runs. Run ALL of them locally — NOT a subset, no file path argument:
- kindra: `cd kindra && mix test`
- kinlia-web: `cd kinlia-web && yarn test:run`
- kindraapp: `cd kindraapp && yarn test` AND `cd kindraapp && yarn test:expo`

WHY two commands for kindraapp: `yarn test` (jest.config.js) excludes all `*.expo.test.*` files via `testPathIgnorePatterns`; those component tests only run under `yarn test:expo` (jest.expo.config.js). CI's pr-tests workflow runs BOTH. A review that only runs `yarn test` can approve a PR that breaks CI — this happened with PR #394 (a CodeModal placeholder change broke an `.expo.test.` file that no local run ever executed; CI stayed red for weeks before anyone noticed).

If a suite fails, check whether the failure is PRE-EXISTING (fails on the base branch too, without this PR's changes) by checking recent CI runs on the base branch or running the suite on the base branch. A pre-existing failure is not the PR author's FAIL — but report it loudly as a separate finding, because a red baseline hides new breakage.

This applies to WARNINGS too, not just failures — "Jest did not exit", new console noise, and open-handle notices all get the same treatment. And "pre-existing" is a CLAIM: prove it with an isolation run before you write the word. Run the suite (a) with the PR's new/changed test files excluded and (b) with only those files, and paste both outputs.

WHY (2026-09-13, PR #416): the expo suite's "Jest did not exit one second after the test run has completed" warning was proven to live on the base — excluded-run still warned, new-files-only exited cleanly in 3.29s. Without that pair of runs it would have been guesswork, and a previous pipeline shipped a false "pre-existing" claim about an agent-made CardGame.tsx diff.

Refinements to the pre-existing check (PRs #413/#414/#417, 2026-09-13): run the baseline comparison at the MERGE-BASE commit (`git merge-base <base> <head>` — the point where the PR forked), not the base branch tip, so commits landed after the fork cannot pollute the result. Whenever you write "pre-existing", paste the baseline run's output next to the head run's, naming the SHA and the absolute path of the checkout it ran in. A warning you cannot attribute is an unresolved finding — report it as such rather than ignoring it. Also record base-vs-head test counts: the delta is a free cross-check of the PR's claimed new-test count (PR #413: 140 base vs 149 head independently confirmed the claimed 9 new tests).

Paste the FULL terminal output of every suite. Note each suite's total test count. If a count is far below the project's known total, you ran a subset — re-run.

WHERE to run them: in the isolated worktree from Step 1, install dependencies with the lockfile frozen (`yarn install --frozen-lockfile`) so the deps match CI. To skip the slow install you may symlink `node_modules` from ANY local checkout of the project (e.g. `~/Sites/KindraApp` or `~/Sites/kindraapp-tf-build`) — the safety comes from the proof, not from which folder: BOTH the PR head's `package.json` AND its `yarn.lock` must be byte-identical to the donor checkout's (`shasum` all four files and paste all four hashes in the review; the lockfile matters because it, not `package.json`, determines what is actually installed). If either file differs, or the PR touches `package.json` or the lockfile, you MUST do a real install in the worktree — symlinked deps would no longer be the PR's deps. (PRs #413/#415, 2026-09-13/14: the main checkout was on a different branch with a different dependency list, so the tf-build copy was the valid donor — proven, then used.)

FAIL if any test fails because of this PR. FAIL if you ran a subset or skipped one of the project's suites.

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

**MERGE-FRESHNESS: a green badge is not a green merge.** CI proved the PR against the code it FORKED FROM — the base branch has kept moving since. In every review (including the unchanged-PR short-circuit in Step 1), run a practice merge against the base branch's CURRENT tip:

```bash
git fetch origin <base>
git merge-tree --write-tree origin/<base> <head-sha>
```

(Non-zero exit / conflict markers in the output = conflicts. On older git without `merge-tree --write-tree`, do a throwaway `git merge --no-commit --no-ff` in a detached temp worktree and abort it.) Report how many commits the base has advanced since the PR forked (`git rev-list --count <merge-base>..origin/<base>`). Conflicts = FAIL — the PR cannot merge as-is. A clean practice merge with a much-moved base is a PASS with the advance count noted, so the merger knows the tested-against code and the merged-into code differ.

**Why (PR #415, 2026-09-14):** `testflight` had advanced 12 commits while the PR sat open. The badge was green against the fork point; nothing in this checklist required proving it still merged cleanly against the branch as it exists today. The reviewer did the practice merge on their own initiative — this makes it mandatory.

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

### Step 4 — Lessons (after the review is delivered; never blocks completion)

After presenting the review (and posting it to GitHub if the user asked), launch the `lesson-learner` agent in PROPOSE mode with: the review file path, the PR number, the repo path, and a one-paragraph summary of the review (verdict, notable findings, anything the checks missed or the human corrected). When it returns, show the user the numbered proposals (or "no lessons proposed") and ask in plain text: "Apply any of these? (e.g. 'apply 1 and 3', or 'skip')". On approval, re-launch `lesson-learner` in APPLY mode with the approved numbers. On 'skip' or no reply, do nothing — the proposal file remains on disk (`/tmp/pr-review-[number]-lessons.md`). If the learner errors, say so and finish normally; a learner failure never changes the review verdict.

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
- **NEVER approve without running the tests yourself.** "The PR's CI passed" is not enough — run every test suite CI runs, locally (see Check 6). CI catches some things; you catch others.
- **NEVER approve without checking every changed symbol's callers.** Cross-project ripple is the #1 source of intern PR bugs.
- **Be specific in failures.** "Security issue" is not enough — "SQL injection at `src/foo.ts:42` via string interpolation into the query" is.
- **Be kind in tone.** This is for interns. Lead with what's good, then flag what needs to change. Don't pile on.
- **Don't approve with TODOs.** If you find ANY Tier 1 or Tier 2 FAIL, the verdict is REQUEST CHANGES. No "approve but please fix X next time."
- **Confirm memory compliance at the top of the review.** "I read the following in this session" — the user must see the evidence trail.

## Plain-Language Reporting (MANDATORY)

The person reading your chat reports is not an engineer. Every message shown to the user in chat MUST follow these rules:

- Lead with the bottom line in one everyday sentence ("This change is safe to merge" / "I found 2 problems that must be fixed before this ships").
- Use everyday words. A technical term may appear only if it is immediately explained in plain words in parentheses — e.g. "the merge-base (the point where the PR branched off)". Otherwise leave it out.
- Never reference internal names the reader doesn't know — check numbers ("Check 6"), tier labels ("Tier 1"), agent or skill file names ("test-reviewer.md"), or section headings. Say what the thing does instead: "the step that checks whether tests were already failing before this change."
- Keep ALL the technical evidence (file:line citations, pasted code, raw test output) — but put it in the saved report file, not the chat message. The chat message is the plain-language translation; the file keeps full rigor. Never weaken the file's rigor to satisfy this rule.
- When relaying another agent's findings to the user, translate them first — never paste agent-to-agent output into chat.
- End with the decision the user needs to make, as one plain question, with what each answer would mean.

**Why this exists (2026-09-13):** PR-review and lesson-learner reports were written engineer-to-engineer ("refine Check 6 — 'merge-base' appears nowhere") and the user could not tell what was being proposed or what decision they were being asked to make. The user is non-technical; a report the user cannot understand has failed, no matter how rigorous the work behind it.
