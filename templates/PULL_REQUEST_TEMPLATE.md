<!--
GitHub PR template. Copy this file to `.github/PULL_REQUEST_TEMPLATE.md`
in any repo where you want it auto-filled into new PR descriptions.

Source: github.com/KindraGina/claude-pipeline-agents — keep this repo
as the source of truth and re-copy when the template changes.
-->

## Why this PR exists

<!-- Explain WHY this change is being made. What problem does it solve?
     What does success look like after this PR? Don't just say what
     changed — the reviewer can see that in the diff. -->



## Linked issue / ticket

<!-- Paste the issue link, or write "no ticket" with a reason. -->



## Plan document used

<!-- Link to or paste the plan that was used to write this code.
     If you didn't use a plan, say so and explain why. -->



## Breaking changes

<!-- Skip this section if the PR is not a breaking change.
     If it IS a breaking change (e.g. modifies how an API returns data,
     removes a DB field, changes a response format, breaks old
     mobile-app versions):
       1. Prefix at least one commit message with `BREAKING:`
       2. Describe below what breaks and how to migrate. -->



## Manual test plan

<!-- Step-by-step instructions for the reviewer to verify the change
     works. Example:
       1. Log in as a test user.
       2. Tap the new button on the Profile screen.
       3. Confirm the modal shows X and the data saves to Y.
     For UI changes, paste screenshots or a short screen recording. -->

1.
2.
3.

## TDD proof — failing-first test output

<!-- Write the test FIRST, before writing the feature. Run it. It MUST
     fail because the feature doesn't exist yet. Paste the failure
     output below. This proves the test actually catches the feature
     being broken. -->

```
[paste failure output here]
```

## TDD proof — passing test output (after the feature was written)

<!-- After writing the feature, run the same test. It should now pass.
     Paste the passing output below. -->

```
[paste passing output here]
```

## Local checks (run before pushing)

<!-- Paste the output of each command so the reviewer can see they ran
     clean before you opened the PR. -->

**Tests (full suite):**
```
[paste full test output]
```

**Linter:**
```
[paste lint output]
```

**Build / compile:**
```
[paste build output]
```

## Pre-flight checklist

<!-- Tick each box once you've actually done it. Do not tick boxes you
     haven't done — the reviewer will check. -->

- [ ] **Plan included** above (link or pasted).
- [ ] **TDD proof included above** — both failing-first and passing outputs are pasted.
- [ ] **Local checks pass** — tests, linter, build output all pasted above.
- [ ] **Manual test plan** above is specific (numbered steps) — not "test it works."
- [ ] **Ripple effects checked** — I searched the rest of the codebase (`grep`) for every function, variable, or file I changed and confirmed all callers still work.
- [ ] **PR description explains WHY**, not just what changed.
- [ ] **Self-reviewed the diff** — I clicked the "Files changed" tab on this PR and read every line. No accidental debug code, no unintended changes.
- [ ] **PR is from a feature branch** — NOT from `main` / `master` / `staging` / `testflight` / `production`.
- [ ] **No secrets in the diff** — no API keys, passwords, `.env` contents, or tokens. New env vars are documented in `.env.example` (without real values).
- [ ] **No debug noise** — removed `console.log`, `debugger`, half-finished comments, commented-out code blocks, and `TODO` notes without a ticket.
- [ ] **Breaking changes flagged loudly** — if the change is incompatible with old code, old back-ends, or old mobile-app versions (mobile users may still be running an old version): (a) prefix at least one commit message with `BREAKING:`, AND (b) describe what breaks and how to migrate in the "Breaking changes" section above. Skip this box if it's not a breaking change.
- [ ] **Documentation updated** — README, setup instructions, or env-var docs updated if the change requires it (skip if not applicable).
- [ ] **PR under ~500 lines** — if larger, I've explained below why it can't be split.

## Notes for the reviewer

<!-- Anything else worth knowing? Trade-offs you made? Things you're
     unsure about? Areas you'd like extra scrutiny? -->


