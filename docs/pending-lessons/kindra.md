# Waiting lessons for kindra — found by runs in other repos; offered for kindra's CLAUDE.md on the next kindra run.

### 2026-10-29 — from a KindraApp run — A response's message text is a contract: grep the apps for the old wording before changing it
- **Intended destination:** `~/Sites/kindra/CLAUDE.md` — next to the "Bug Investigation Checklist" / mobile-app notes
- **Proposal:** /tmp/pr-review-458-lessons.md (evaluation: /tmp/pr-review-458-lessons-evaluation.md, lesson 1b)
- **Final text:**
  > **A response's message text is a contract.** Before changing the wording of any `result` / `message` / `error` string a controller returns — including indirectly, by swapping the library that produces it — grep `~/Sites/KindraApp` and `~/Sites/kinlia-web` (`--exclude-dir=node_modules`) for a distinctive phrase of the old wording and paste the output. A match in app code means the change breaks the app; old app versions stay installed, so keep the old wording or ship a compatible app first.
  > **Why (KindraApp PR #458, 2026-10-29):** `2f9da99d` (2025-12-21, Authy -> Twilio Verify) changed the phone-check success message from "Verification code is correct." to "Verification successful". The app matched `includes('code is correct')`, so for ten months every correct code was shown as a failure while the server verified it fine.
