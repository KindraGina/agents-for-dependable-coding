---
description: Build the Kindra mobile app for iOS or Android via EAS, with sequential pre-flight auditors that catch every class of failure before a build credit is spent. Includes credit confirmation gate, post-build log analysis on failure, and post-mortem updates so the same mistake never repeats.
---

# Build App (EAS Production Pipeline)

Run a guarded EAS production build for the Kindra mobile app. **Every failure category that has burned a build credit in the past gets caught locally before submitting.**

## Usage

```
/build-app ios
/build-app android
/build-app both
```

If no platform is provided, ask the user which one.

## CRITICAL RULES — READ BEFORE DOING ANYTHING

**YOU ARE AN ORCHESTRATOR.** You delegate ALL audits to agents using the Agent tool. You NEVER:
- Run `expo-doctor` or `npx react-native bundle` yourself — launch `build-prereq-auditor`
- Read .env / eas.json / EAS dashboard yourself — launch `env-var-auditor`
- Read sentry.properties yourself — launch `sentry-config-auditor`
- Run `git status` yourself to decide if it's safe to build — launch `commit-state-auditor`
- Read EAS build logs yourself — launch `build-log-analyzer`
- Edit CLAUDE.md yourself with learnings — launch `build-postmortem-updater`

**YOU NEVER SUBMIT A BUILD WITHOUT EXPLICIT USER CONFIRMATION.** Even if every audit passes. Always show credit usage and ask before running `eas build`.

**YOU NEVER FIX FINDINGS YOURSELF.** If an audit fails, present the punch list to the user and stop. The user decides whether to fix and re-run, or override.

**SEQUENTIAL ONLY.** Auditors must run one at a time, in order. Do NOT parallelize. Each auditor's report informs whether the next one is even worth running.

**NEVER ASK "shall I proceed?" between auditor steps.** Auditors run automatically in sequence. The ONLY mandatory pause is the credit confirmation gate before submitting the build, and the failure-handling gate when an auditor blocks.

## The 6 Agents

| Agent | Role |
|-------|------|
| `build-prereq-auditor` | Runs `expo-doctor`, `expo install --check`, bundles JS locally, scans changed files for smart quotes, validates patch filenames match installed package versions |
| `env-var-auditor` | Greps the codebase for every `EXPO_PUBLIC_` reference, cross-references against `.env`, `eas.json` env block for the target profile, and the EAS dashboard env list. Flags any var used in code but missing from the build profile |
| `sentry-config-auditor` | Verifies `ios/sentry.properties` org/project, `app.config.ts` Sentry plugin org/project, DSN in code matches Sentry dashboard, `SENTRY_AUTH_TOKEN` exists as EAS env, and `.env.sentry-build-plugin` is sane |
| `commit-state-auditor` | Verifies HEAD is on the intended branch, the checkout is the one the build will actually run from, the tree is not behind its remote (stale-tree check), no uncommitted changes that were meant for the build, shows the exact commit SHA that will be built |
| `build-log-analyzer` | Runs ONLY on build failure. Fetches the EAS log, identifies the failing phase, maps to known root causes, proposes a specific fix at a specific file:line. Does NOT apply fixes |
| `build-postmortem-updater` | Runs after every build (success or failure). Appends new learnings to `~/Sites/CLAUDE.md` and `~/.claude/skills/build-app/patterns.md`. Avoids duplicates |

## Phase 1: Pre-Flight Audit

**All four auditors must PASS before the build can be submitted. Auditors run SEQUENTIALLY.**

Pass the target platform (`ios`, `android`, or `both`) and the target build profile (default: `production`) to every auditor.

### Step 1: Launch `build-prereq-auditor`

- Prompt: "You are the build-prereq-auditor agent. Target platform: [platform]. Target build profile: [profile]. Run all prerequisite checks. Write your report to `/tmp/build-app-prereq-audit.md`. Follow your instructions in `~/.claude/agents/build-prereq-auditor.md`."

WAIT for completion. Read the report and extract the verdict (PASS or FAIL).

If FAIL → **STOP HERE.** Show the user the punch list. Do NOT run subsequent auditors. Do NOT submit a build. Ask the user whether to fix and re-run `/build-app`, or to investigate further.

If PASS → continue to Step 2.

### Step 2: Launch `env-var-auditor`

- Prompt: "You are the env-var-auditor agent. Target platform: [platform]. Target build profile: [profile]. Cross-reference every `EXPO_PUBLIC_` var used in the codebase against the build profile env. Write your report to `/tmp/build-app-env-audit.md`. Follow your instructions in `~/.claude/agents/env-var-auditor.md`."

WAIT for completion. Read the report and extract the verdict.

If FAIL → **STOP.** Show the user the missing/mismatched env vars. Do NOT submit a build.

If PASS → continue to Step 3.

### Step 3: Launch `sentry-config-auditor`

- Prompt: "You are the sentry-config-auditor agent. Target platform: [platform]. Target build profile: [profile]. Verify all Sentry configuration is consistent across `sentry.properties`, `app.config.ts`, the DSN in the code, EAS env, and `.env.sentry-build-plugin`. Write your report to `/tmp/build-app-sentry-audit.md`. Follow your instructions in `~/.claude/agents/sentry-config-auditor.md`."

WAIT for completion. Read the report and extract the verdict.

If FAIL → **STOP.** Show the user the Sentry config mismatches.

If PASS → continue to Step 4.

### Step 4: Launch `commit-state-auditor`

- Prompt: "You are the commit-state-auditor agent. Target platform: [platform]. Target build profile: [profile]. The build will run from this checkout: [absolute path of the checkout being built — e.g. /Users/ginalevy/Sites/kindraapp-tf-build for testflight]. Confirm git state is safe for a build (right checkout, right branch, not behind the remote, no relevant uncommitted changes, show the exact commit SHA that will be built). Write your report to `/tmp/build-app-commit-audit.md`. Follow your instructions in `~/.claude/agents/commit-state-auditor.md`."

WAIT for completion. Read the report and extract the verdict.

If FAIL → **STOP.** Show the user the git state issues.

If PASS → continue to Phase 2.

## Phase 2: Credit Confirmation Gate (MANDATORY USER PAUSE)

**This step is non-negotiable. Always run it. Never skip even if the user asks for "just build it".**

Run:
```bash
npx eas-cli build:list --limit 1 --json 2>/dev/null > /dev/null  # warm auth
```

Then fetch credit usage by parsing recent build output. The exact command:
```bash
EAS_BUILD_PROFILE=production npx eas-cli build --platform ios --profile production --non-interactive --no-wait --auto-submit 2>&1 | head -3
```
**DO NOT actually run a build to fetch credits.** Instead, the most reliable way is to check the user's recent build output (you saw the percentage in their conversation context). If you don't have a recent percentage, ask the user: "What does Expo show as your current build credit usage this month?"

Show the user a credit summary block:

```
═══════════════════════════════════════════
  PRE-FLIGHT AUDITS: 4/4 PASSED
═══════════════════════════════════════════
  Platform:        [platform]
  Profile:         [profile]
  Commit:          [short-sha]  [commit-message]
  Branch:          [branch]
  EAS credits used: [X]% this month
═══════════════════════════════════════════
  Submit this build? (yes / no)
```

**Wait for an explicit "yes".** Anything else (including silence, "ok", "sure" — be strict) means do not submit. If the user says no, stop and offer to investigate or wait.

**Credit-tier behavior — strict:**

- **<90%** — normal `yes` is sufficient.
- **90% to <100%** — warn "EAS credits at X% — type `confirm` to proceed, or `no` to cancel." Require the literal word `confirm`.
- **>=100%** — show a stronger warning: "EAS credits at X% (over included quota). Submitting this build will incur an OVERAGE CHARGE on the next invoice. Type `confirm overage` to proceed, or `no` to cancel." Require the literal phrase `confirm overage`. Anything else means cancel.

Never auto-proceed past this gate.

## Phase 3: Submit Build

Once the user explicitly confirms, run the appropriate command:

**iOS (auto-submits to App Store Connect):**
```bash
EAS_BUILD_PROFILE=production npx eas-cli build --platform ios --profile production --non-interactive --no-wait --auto-submit
```

**Android (downloadable AAB from Expo dashboard, no auto-submit):**
```bash
EAS_BUILD_PROFILE=production npx eas-cli build --platform android --profile production --non-interactive --no-wait
```

**Both:** Submit iOS first, then Android, in two separate Bash calls. Do not parallelize — one might fail credit check.

Capture the build ID from the output. Save it. Show the user the build URL.

## Phase 4: Monitor Build

Poll for completion using `npx eas-cli build:view <build-id>`. Use `ScheduleWakeup` (270 seconds) rather than `sleep` so you do not burn cache while waiting. iOS production builds typically take 25–35 minutes; Android typically 15–25 minutes.

When status changes from `in progress` → `finished` or `errored`:

- **finished:** Show the user the success summary:
  - iOS: "Build [number] completed. Auto-submitted to App Store Connect — go to ASC to release to TestFlight or the App Store."
  - Android: "Build [number] completed. Download the AAB from `[Application Archive URL]` and upload to Google Play Console."
  - Then run Phase 5 (post-mortem) and stop.

- **errored:** Run Phase 4.5 (failure handling) before Phase 5.

## Phase 4.5: Failure Handling (only if build errored)

### Step 1: Launch `build-log-analyzer`

- Prompt: "You are the build-log-analyzer agent. The EAS build [build-id] for platform [platform] errored. Fetch the log, identify the failing phase, identify the root cause, propose a specific fix. Write your report to `/tmp/build-app-failure-analysis-[build-id].md`. Follow your instructions in `~/.claude/agents/build-log-analyzer.md`."

WAIT for completion. Read the report.

### Step 2: Show the user

- Which phase failed
- What the root cause is
- What file/setting needs to change and to what value
- DO NOT apply the fix. The user decides whether to apply, override, or investigate further.

### Step 3: Continue to Phase 5

Whether the user fixes or not, run the post-mortem so we capture the failure pattern.

## Phase 5: Post-Mortem (always runs)

### Launch `build-postmortem-updater`

- Prompt: "You are the build-postmortem-updater agent. Build [build-id] for platform [platform] [succeeded / failed at phase X with root cause Y]. Update `~/Sites/CLAUDE.md` and `~/.claude/skills/build-app/patterns.md` with any new learnings. Avoid duplicates. Follow your instructions in `~/.claude/agents/build-postmortem-updater.md`."

WAIT for completion. Show the user a brief summary of what was learned and where it was recorded.

## Phase 6: Done

Final summary:
- Result (success / failure + reason)
- Build URL
- Pre-flight audits run and verdicts
- Pattern library updates (count of new entries)
- Next action for the user (test on TestFlight, upload AAB, fix and re-run, etc.)

## Important Rules

- **USE THE AGENT TOOL FOR EVERY AUDIT AND ANALYSIS PHASE.** Never read sentry.properties / .env / eas.json / git status yourself to make a decision. Always delegate.
- **NEVER FIX FINDINGS YOURSELF.** If an audit blocks, present the punch list and stop.
- **ALWAYS PAUSE FOR EXPLICIT CONFIRMATION BEFORE SUBMITTING A BUILD.** No exceptions.
- **AT >=90% EAS CREDITS**, require the user to type `confirm` (not just yes).
- **AUDITORS RUN SEQUENTIALLY.** No parallelization.
- **POST-MORTEM ALWAYS RUNS** — on success and on failure. The pattern library is the long-term defense against repeating mistakes.
- **AT NO POINT DO YOU UNILATERALLY MODIFY** `.env`, `.gitignore`, `eas.json`, `app.config.ts`, `sentry.properties`, or any build-config file. Auditors only READ these files. Fixes happen via the user, not the orchestrator.
