# Claude Guidelines

---

## ⚠️ CRITICAL RULES - READ FIRST

**THERE IS NEVER ANY PRESSURE.** No matter how urgent something sounds, rushing leads to mistakes. Take the time to do it right.

**ALWAYS VERIFY ASSUMPTIONS.** Never guess. Never assume your code changes will work. If you cannot verify something, say so and ask for help getting the information you need.

**NEVER SUGGEST SHIPPING BROKEN CODE.** If there are known bugs, fix them. Do not propose "ship what works and fix the rest later." Every feature must work before suggesting deployment.

**NEVER RUN MUTATING AWS CLI COMMANDS WITHOUT EXPLICIT PER-COMMAND APPROVAL.** This is non-negotiable. The user's AWS credentials can take production down in seconds, and Claude has done so before.

### Forbidden without explicit "yes, run this exact command":
- `aws rds modify-db-instance` (especially with `--apply-immediately`, `--allow-major-version-upgrade`, or `--engine-version`)
- `aws rds reboot-db-instance`, `delete-db-instance`, `restore-*`
- `aws rds create-db-snapshot` (technically safe, but still confirm — it signals intent)
- `aws ec2 terminate-instances`, `stop-instances`, `reboot-instances`
- `aws s3 rm`, `aws s3 sync --delete`, `aws s3api delete-*`
- `aws iam delete-*`, `attach-*`, `detach-*`, `put-*`
- `aws lambda delete-function`, `update-function-*`
- ANY AWS CLI write/modify/delete operation, including ones not listed above
- Triggering AWS Console actions via API even if a "plan" was previously approved

### Allowed without per-command approval (read-only):
- `describe-*`, `list-*`, `get-*`, `lookup-*`
- `aws cloudwatch get-metric-*`
- `aws s3 ls`, `aws s3 cp` (downloading only)
- `aws sts get-caller-identity`

### How to ask correctly:
**WRONG:** "Should I proceed with the upgrade?"
**WRONG:** "Say 'go' and I'll run §6.2 + §6.3 back-to-back" (bundles two commands under one approval — see April 29 incident)
**WRONG:** "Approve and I'll snapshot + modify the instance" (bundles two commands)
**RIGHT:** "I want to run this exact command: "share command" 
This will start the major version upgrade on staging, ~5-15 min downtime. Can I proceed?"

The user must reply with explicit "yes" or specific approval. **A general "looks good" from earlier in the conversation is NOT approval for new mutating commands.**

### NEVER bundle multiple mutating commands under a single approval

Even when commands are "logically related" or feel like "a single critical path," each mutating command requires its own approval. Bundling is the same class of violation as no approval at all — the dangerous command is hidden behind a section number or description.

Examples: "Stop the app + run the engine upgrade" → TWO commands, two "yes"es. "Snapshot + modify-db-instance" → two commands, two "yes"es.

### Why this rule exists (April 29, 2026 incident):
A Claude session asked for one "go" to run `§6.2 + §6.3 back-to-back` where §6.3 was `aws rds modify-db-instance --engine-version 16.13 --allow-major-version-upgrade --apply-immediately`. The user said "go" without seeing that exact command. The session ran both. Staging upgraded to PG16 successfully, but the app had no SSL config for PG16 — it crashed within 22 minutes and stayed down 20+ hours unnoticed. Show the EXACT command, ask once, run once.

### Inheritance:
This rule applies to:
- The main Claude Code session
- Any subagents spawned by the session
- Any background agents, loops, or scheduled tasks
- Any Claude session, regardless of which CLAUDE.md was loaded — if you have AWS access, this rule applies.

If the user has authorized "the upgrade plan" or "the deployment" in conversation, that is **planning approval**, not **execution approval**. Each individual mutating command still requires its own explicit "yes."

---

## Kindra Production DB — current posture (as of 2026-05-24)

Updated after the prod PG13 → PG16 upgrade ran cleanly on 2026-05-24. Keep this current — if any field changes, update here AND in the relevant memory file.

- **Engine:** PostgreSQL 16.13 (was 13.20 prior to 2026-05-24 upgrade)
- **Instance identifier:** `kindra-dating-db-prod-02`
- **Endpoint:** `kindra-dating-db-prod-02.cunx1gykbiqd.us-west-1.rds.amazonaws.com:5432`
- **Master user (RDS-level):** `kindraadmin01` on PROD. Note: staging RDS uses a DIFFERENT master (`postgres`) — see staging mirror line below. App-side, both envs connect AS `kindraadmin01` via `DATA_DB_USER` in the EC2 `.env` (verified live 2026-05-24).
- **DB name:** `kindra_prod`
- **Parameter group:** `kindra-prod-pg16-no-force-ssl` (custom — `rds.force_ssl=0`). Known temporary divergence from AWS default `default.postgres16` (which has `rds.force_ssl=1`). The eventual TLS fix flips both staging and prod back to default param groups; until then, `force_ssl=0` is required for the app to connect.
- **Deletion protection:** ON (enabled 2026-05-24)
- **CA cert:** `rds-ca-rsa2048-g1` (valid until 2027-05-11)
- **Most recent manual snapshot:** `kindra-prod-pre-pg16-20260523` (rollback safety net — retain for at least a week post-upgrade)
- **Staging mirror:** RDS instance `kindra-dating-staging-2`, custom param group `kindra-staging-pg16-no-force-ssl` (same `force_ssl=0` divergence). **RDS master is `postgres`** (not `kindraadmin01` — staging was created with a different master at instance birth; doesn't affect the app, which uses `DATA_DB_USER=kindraadmin01` in `.env`).

**Open follow-up:** TLS in Phoenix + flip both envs back to default param groups. Tracked at `docs/plans/2026-05-11-postgres-ssl-fix.md` on the `chore/postgres-ssl` worktree. Nothing is "done" until that ships.

---

## Table of Contents
- [Collaboration](#collaboration)
  - [Instructions](#instructions)
  - [Bug Investigation Checklist](#bug-investigation-checklist)
  - [Working Style](#working-style)
- [Code Quality](#code-quality)
  - [Code Changes](#code-changes)
  - [Understanding Original Intent](#understanding-original-intent)
  - [Commenting Guidelines](#commenting-guidelines)
  - [Testing](#testing)
- [Planning & Files](#planning--files)
  - [Plans](#plans)
  - [Plan Verification — Hard Rules](#plan-verification--hard-rules)
  - [File Safety](#file-safety)
  - [File Editing Rules](#file-editing-rules)

---

# Collaboration

## Instructions

- NEVER start coding until we have agreed on an approach together
- Do not make unilateral decisions - if we're still discussing, keep discussing
- Always explain what you found and propose changes before making them
- Wait for my explicit approval before starting implementation
- **ALWAYS prompt to create automated tests** - even if I forget to ask, remind me
- **DO NOT ask the user about irrelevant edge-case scenarios.** When reviewing a plan or approach, only ask about product decisions that affect what real users actually see. Do NOT surface defensive-code scenarios that won't happen in practice (e.g. "what if both of these mutually-exclusive fields are set?", "what should happen if the admin form is bypassed?"). Pick a safe default in code, document it in a one-line comment, and move on. If you find yourself constructing an "edge case" hypothetical to ask about — STOP. Only highlight real plausible scenarios.
- **Do not flag "decisions" the user has already implicitly made.** If the user has described the model (e.g. "external products redirect, Kinlia products use Stripe"), don't re-litigate unless something has changed to create real world impact. 
- **STOP PLANNING, CODING, OR FLAGGING FOR MYTHICAL FUTURES. WORK FOR TODAY. (Nuance: realistic what-ifs are good; hypothetical what-ifs about things we're not building are not.)** The line is whether the "what if" connects to something real:
  - **GOOD what-ifs (raise these):** scenarios that can actually happen with what we ARE building now. "What if the API returns 404?" "What if the user double-clicks Buy Now while a payment is in flight?" "What if the buyer refreshes the confirmation page?" "What if `price_cents` is null?" These are real edge cases for the feature being built — surface them, ask about them, code for them.
  - **BAD what-ifs (do NOT raise these):** scenarios about things we are NOT building, may never build, and have no plan to build. "What if a future admin form allows bypassing this validation?" Mythical futures — speculation about possible changes nobody has committed to - Wastes time.
  - **The test:** can this scenario happen with what is in the repo today and what is planned to ship in the current scope? If yes → real what-if, raise it. 
  - Do NOT add code, plan items, dependencies, defensive branches, abstractions, or extra dep-array items for mythical-future protection. 
  - Reminder incident (2026-05-18): flagged "what if the backend ever paginates host_offerings" — not planned, not in scope. User: "Plan and code for the best performance today. No planning or coding for hypothetical futures. Realistic what-ifs are good. Hypothetical what-ifs about things we're not building, not good."
- **NO MULTIPLE-CHOICE QUESTIONS. EVER.** This is the rule the user has had to repeat the most. Every time it happens it costs trust. Do NOT use `AskUserQuestion` to present 2/3/4-option pick-lists. Instead: (a) make the call yourself when you have enough context, (b) ask ONE short open-ended question in plain text when you genuinely need input ("Where are you testing this against?"), or (c) state your recommendation in one sentence and proceed unless told otherwise. The ONLY exception is when the user explicitly types "give me options" in the current turn. 

## Bug Investigation Checklist

Before marking any bug as understood or planning a fix:

1. **Identify ALL affected users**
   - Who sees this bug? (website users, mobile app users, admins, etc.)
   - Don't assume - verify each one

2. **Trace EACH user's code path**
   - For each affected user type, trace from their app to the backend code
   - Don't assume one file handles all cases
   - Different frontends may hit different code paths in the backend

3. **Search for ALL similar functions**
   - Search the ENTIRE codebase for similar function names
   - Example: If fixing `get_items`, search for ALL `get_items` functions across all files
   - Use: `grep -r "function_name" lib/` or appropriate search for your language

4. **Never trust "DONE" status**
   - If documentation says a fix is done, verify by reading the actual code
   - Check if the fix covers ALL affected code paths
   - A fix marked "done" for one frontend may not cover other frontends or admin panels

5. **List ALL files that need changes**
   - Before planning, confirm: "These are ALL the files that need to change"
   - Get user confirmation before proceeding

6. **Include automated tests in EVERY plan**
   - Tests are NOT optional - include them without being asked
   - Write tests BEFORE implementation (TDD)
   - If a plan doesn't have tests, it's not complete

## Working Style

- **Treat every task as complex until proven otherwise.** Never assume something is simple. Investigate thoroughly, trace the full path, and do the work — don't take shortcuts or dismiss problems as "not a code issue" without verifying.
- Prioritize correctness over speed. Take time to fully understand before acting.
- Always read relevant files completely before making changes - never assume content.
- When uncertain, ask clarifying questions rather than guessing.
- Verify assumptions by checking the actual code, don't rely on memory.
- After making changes, review them for correctness before moving on.
- Think through edge cases and potential issues before implementing.
- If a task is complex, break it into steps and validate each step.
- Double-check file paths, function names, and variable references against the actual codebase.
- When debugging, investigate thoroughly rather than trying quick fixes.
- Prefer reading more context over making assumptions.

## Debugging Rules

### Understand the Architecture First
- Before writing any fix, identify ALL code paths that touch the affected feature.
- This codebase has dual architectures (MobX legacy + React Context). A fix in one path doesn't fix the other.
- Ask: "Which screen/flow are you testing?" before starting to debug.

### Ask the Right Questions Early
- Ask the user which screen, which flow, which view they're testing.
- Ask for console logs, screenshots, or screen recordings when the bug is visual.
- One good question early saves hours of wrong-path debugging.

### Stop Going in Circles
- If a fix doesn't work, don't try variations of the same approach.
- Stop, re-read the code, trace the actual execution path, and understand WHY it didn't work.
- List what you've tried and analyze the pattern before trying the next thing.

## Mobile App — Not a Server

**This is a mobile app, not a web server.** Do not apply server-side best practices that don't apply to mobile:

- **Never gitignore `.env` or environment config files.** On a server, `.env` has database passwords and API secrets. On a mobile app, `EXPO_PUBLIC_` variables are baked into the client bundle and downloaded by every user — they are public by definition. Gitignoring `.env` breaks EAS builds for zero security benefit.
- **Never change `.env`, `.gitignore`, build config, or environment setup without asking first.** These are infrastructure decisions, not code fixes. Changing them unilaterally can break builds and deployments in ways that are hard to diagnose.
- **EAS builds run on remote servers.** They do NOT read `.env` files. All production environment variables must be in the `eas.json` build profile `env` block. If you add a new `EXPO_PUBLIC_` variable to `.env`, you must also add it to `eas.json`.

### What happened (.env incident, April 2026):
`.env` was added to `.gitignore` based on server-side convention. EAS production builds lost all `EXPO_PUBLIC_` config values (Cloudinary, Stripe, Zendesk, etc.). After login, the app crashed trying to render a profile image with `cloud_name = undefined`. This caused every App Store submission from April 10 onward to be rejected.

## Package Management — Expo Version Compatibility

### ALWAYS use `npx expo install` for Expo packages
- **NEVER** use `yarn add`, `npm install`, or `npx expo install --fix` for any Expo-related package.
- **ALWAYS** use `npx expo install <package>` — this installs the version compatible with the current Expo SDK.
- **Why this matters:** `yarn add` installs the latest version, which may be built for a newer SDK. The package will install without errors but can cause fatal runtime crashes because it expects different React Native internals than what the current SDK provides.

### What happened (expo-image incident, April 2026):
`yarn add expo-image` installed v3.0.11 (built for a newer SDK). The app uses SDK 53, which requires ~2.4.1. The version mismatch caused a FATAL `IncompatibleClassChangeError` crash on Android — the app died the moment it tried to display any image, affecting every Android user.

### Before every build, run compatibility check:
```bash
npx expo install --check
```
This shows any packages that are incompatible with the current SDK. Fix ALL incompatibilities before building.

## Dependency Health — Check the Foundation Before Building On It

### Rule 1 — Never add a new dependency without a health check
Before adding ANY new package (via `npx expo install` or otherwise), check and report in chat/plan:
- **Last release date** — if no release in ~18 months, it is presumed abandoned. Pick something else or escalate.
- **Maintenance signals** — recent commits, responsive maintainer, open-issue pileup.
- **React Native New Architecture support** — required for anything we add from now on.
- **Prefer, in order:** React Native built-ins → Expo-maintained modules (`expo-*`) → actively maintained community packages. A dead library is never acceptable just because a tutorial or old code uses it.

State the check results explicitly ("last release 3 months ago, New Arch supported") before installing. If the check was not done, the install does not happen.

### Rule 2 — Touching a feature means checking what it stands on
When fixing, rebuilding, or extending ANY feature, identify the third-party libraries its screens/components import and check them against the Legacy Library Refactor list in `docs/TODO.md` and against Rule 1's health criteria. If the feature sits on an unmaintained library:
- **Say so immediately and out loud** — first response, not buried mid-plan: "Heads up: this feature is built on react-native-X, which is unmaintained."
- **Default:** include the library swap in the work, since the feature is being rebuilt anyway.
- **If the swap would blow up scope:** deferring is allowed, but ONLY as an explicit user decision — present it, get a yes/no, and record the deferral in `docs/TODO.md`.
- Silently rebuilding a feature on top of a known-dead library is the same class of failure as shipping untested code.

### Rule 3 — No suppressions. The exclude list stays empty.
The `expo.doctor.reactNativeDirectoryCheck.exclude` list in `package.json` stays EMPTY (owner decision 2026-07-14, PR #342 — "stop all suppression"), and the same applies to lint ignores or any other warning-suppression mechanism for dependency-health signals. Any exception requires (a) the user's explicit approval of that specific single-package suppression, given in response to a plainly-worded ask — "this hides the Unmaintained warning for X permanently; approve?" — never bundled with other changes, and (b) a corresponding entry in `docs/TODO.md` naming why the flag is wrong or accepted and what the plan is. A suppression without a tracked plan is deleting the smoke alarm instead of putting out the fire. Additionally: any suppression ask justified by "it's an upstream/third-party bug" MUST arrive with proof the bug reproduces in a guaranteed-clean environment (fresh worktree, dependencies installed from scratch — pasted output, not a summary). Reproductions that all ran inside one installed environment are one piece of evidence, not several. (Sept 2026 ESLint incident: four "independent confirmations" of an unfixable upstream crash all shared the same corrupted `node_modules`; a clean reinstall fixed it, and three of the four workarounds offered would have permanently hidden code from linting.)

### Why this exists (April 2026, snap-carousel incident):
During the April 2026 Expo upgrade, roughly a week was spent rebuilding the swiping between theme responses in the profile pop-up (`ProfileCollagePopUp.js`) — on top of `react-native-snap-carousel`, a dependency dating to 2017 whose import there dates to 2022, and which was already abandoned. Across that entire week, no session ever mentioned the library was dead. Meanwhile, commit `831a7bfc` ("suppress doctor noise for legacy libs") had silenced the expo-doctor warnings for 15 legacy packages during a build-pipeline firefight. That commit did document the debt (it created docs/TODO.md's "Legacy Library Refactor" section in the same change), but the decision to keep carrying 15 abandoned libraries was never surfaced for explicit user approval — and once suppressed, no tool ever mentioned them again. The rebuild work now has to be partially redone when the library is replaced. The moment the feature was being rebuilt was the cheapest possible moment to swap the library — and it was missed because nothing required anyone to look down.

### Why this exists, part 2 (March–April 2026, video-player incident):
Worse than the carousel: ~3 weeks (builds 80–123, per `docs/plans/2026-04-03-build-chart.md`) were spent debugging black-screen video playback caused by `react-native-video-player` (a dependency since 2017) silently ignoring its own renamed `video={{` → `source={{` prop in v0.16 — the signature failure mode of an unmaintained wrapper. The plan doc wrote "deprecated prop" at least five times across those weeks, but every session treated it as "fix the prop at 11 call sites" and no one ever escalated to "the library itself is dead — should we still be on it?" A 13-file workaround (`disableAudioSessionManagement`) was then bolted onto the dying wrapper; all of it was redone three months later when the library was finally replaced (PR #340). Lesson: when a bug's ROOT CAUSE is a library behaving like abandonware (silent API changes, no errors, no docs), that is Rule 2's trigger — question the dependency, not just the symptom.

### Inheritance:
Applies to the main session, all subagents, pipeline agents (plan-creator must include the dependency check in plans; plan reviewers must reject plans that build on TODO-listed libraries without an explicit deferral decision), and Ralph stories.

---

# Code Quality

## Code Changes

- Never edit code you haven't read first.
- Confirm understanding of existing behavior before modifying.
- Run tests after changes when available.
- Explain your reasoning when making non-obvious decisions.
- Document the "WHY" in comments.
- Add to project documentation when making significant changes.

## Understanding Original Intent

### Before Modifying Code:
1. Explain your understanding of the original code in chat
2. Document that understanding in the plan file
3. Check for existing tests - if none exist, add "write tests" to the plan

### What to Document:
- What the code currently does
- Why it likely works this way (business logic, edge cases, constraints)
- What behaviors MUST be preserved
- Any edge cases or gotchas discovered

### If No Tests or Docs Exist:
- Trace callers (search for which functions call this one to understand how it's used)
- Ask you for context on why the code was written
- Add test creation as a required step in the plan before refactoring
- Don't guess or assume - if the intent is unclear, ask

### Preserving Behavior:
- List "behaviors to preserve" for EVERY change, not just complex refactors
- If code looks buggy but might be intentional, ALWAYS flag it - don't assume or ignore
- When in doubt, ask before changing something that seems off

## Commenting Guidelines

### When to Comment
- Use doc comments for public functions and modules
- Use inline comments for non-obvious implementation choices
- Focus on the "WHY" not the "WHAT" - code shows what, comments explain why

### Always Add Comments When:
- We've discussed an issue and made changes - capture that context in the code
- The approach isn't obvious (explain why this way vs alternatives)
- Edge cases are being handled
- Business logic isn't self-evident from the code
- Something looks wrong but is intentional

### Don't Over-Comment
- Let clear naming speak for itself
- When modifying code, comment your changes, not surrounding code you didn't touch

### Citing Other Code From a Comment
- **Point at code by a unique searchable string, not a line number** ("the `hideOnSinglePage` guard in rc-pagination", not `holders.js:466`). Line numbers drift on the next merge.
- **Never quote a search result the comment itself would match.** State the fact ("this app uses no LocaleProvider") instead of the grep and its zero-match count. Once written, the comment is the match.
  Why (2026-09-20, kindra `docs/plans/2026-09-20-fix-stale-jest-suites.md`): a comment recording a zero-match grep for `LocaleProvider` became its own only match, and a sibling `holders.js:466-467` cite went stale by 3 lines on merge.

### Why This Matters
Conversation context is lost after our session ends. Future developers (including you) won't know why a change was made unless it's in the code.

## Testing

⚠️ **IMPORTANT**: Always prompt to create automated tests with every code change. If the user forgets to ask, remind them. Tests are not optional.

### Test-Driven Development (TDD) - Always Follow This Process:
1. **Write tests first** - Define expected behavior before writing code
2. **Run tests** - They should fail (because fix isn't implemented yet)
3. **Implement fix** - Write the minimal code to make tests pass
4. **Run tests again** - Confirm they pass
5. **Refactor if needed** - Clean up while tests keep you safe

### General Testing Rules:
- With every code change, always prompt to create automated testing
- When creating a new version of a function, reference the old one
- Checklist before merging optimizations:
   - Does the new function handle all edge cases the old one did?
   - Did I run the old function's tests against the new function?
   - Did I test with real data, not just unit tests?
- **Repairing an existing test needs a real negative control, not a mental one.** If a test was red because its query, selector, or assertion was wrong (not because behavior changed), fixing it is guaranteed green and proves nothing. Before calling it fixed: break the app behavior the test guards, run it and show it fail, revert (empty `git diff`), run again and show it pass. Paste both runs. If no break makes it fail, it is a smoke test — say so in the test's comment.
  Why (2026-09-20, kindra `docs/plans/2026-09-20-fix-stale-jest-suites.md`): six Jest tests queried antd-4 class names against antd 3. The negative control showed 3 of 6 failing as predicted and one that could not detect either regression.

## Deployment

### NEVER DEPLOY FROM AN UN-MERGED FEATURE BRANCH

**Non-negotiable.** Before invoking ANY deploy command (`yarn build:*`, `eas-cli build`, GHA trigger), the feature branch MUST be merged into the deploy branch (`testflight` for staging, `master` for production). Then `git checkout <deploy-branch>`, `git pull`, and deploy from there.

Why this rule exists (May 16, 2026): EAS build `33966b53` was shipped to TestFlight directly from a feature branch without merging back to `testflight`. The build worked (EAS builds from working tree), but `testflight` was left out of sync — the next person to deploy from it would have shipped a regressed build. **The PR+merge is not "one more step" — it is the deploy.**

Branch-deploy divergence IS broken state, even if the binary works — the next person to deploy will ship the wrong thing. Re-read "THERE IS NEVER ANY PRESSURE" before any deploy.

The correct sequence, every time, with no exceptions:
1. Commit all changes on the feature branch.
2. Push the feature branch to origin.
3. Run the Pre-Flight Merge Check (below) against the deploy target.
4. Open a PR from feature → deploy branch.
5. Merge the PR.
6. `git checkout <deploy-branch>`, `git pull`.
7. THEN run `yarn build:testflight` or `yarn build:production`.

If the merge has conflicts or the PR is blocked, the deploy is also blocked. Do not invent a workaround by building from the feature branch directly.

### Pre-Flight Merge Check — ALWAYS DO THIS AUTOMATICALLY

Before merging into any shared branch (develop, master), you MUST automatically perform these checks without being asked:

1. **Fetch the target branch** — `git fetch origin <target>`
2. **Check for file conflicts** — verify the target branch hasn't modified any of our changed files
3. **Check related files** — verify the target branch hasn't modified any files from the pre-flight check list (files that reference the code we changed)
4. **Dry-run merge** — run a merge-tree conflict check to confirm 0 conflicts
5. **Report results** — show what you found, then proceed if clean

Do NOT skip this. Do NOT ask "shall I go ahead?" first — just run the checks automatically as part of the deploy process.

### Post-Deploy — ALWAYS UPDATE THE PLAN

After any deployment or branch/workflow change, immediately update the plan doc to reflect what actually happened. Do not wait to be asked.

### EAS Build & Deploy — HOW IT WORKS

#### TL;DR — use the yarn scripts

Two one-line commands, defined in `package.json` since 2026-05-16. **These are the canonical way to build. Do not paste the raw EAS commands into a terminal — zsh line-wrap can drop flags (e.g. `--auto-submit`).**

```bash
yarn build:testflight    # dev bundle → TestFlight (life.kinlia.dev → ASC 6748651413)
yarn build:production    # prod bundle → App Store (life.kindra.Kindra → ASC 1292021975)
```

Each script wraps three steps that MUST happen together:
1. `EAS_BUILD_PROFILE=<profile> npx expo prebuild --clean` — regenerates `ios/` so the native dir's bundle ID matches `app.config.ts` (otherwise EAS uses the stale value from the last build's profile, since EAS reads bundle ID from `ios/<App>/Info.plist` when the dir exists).
2. `EAS_BUILD_PROFILE=<profile> npx eas-cli build --platform ios --profile <profile> --non-interactive --no-wait --auto-submit` — uploads, builds in EAS cloud (~10–20 min), auto-submits to the correct ASC app on completion.
3. The env var must be set for BOTH commands so `devMode` resolves correctly in `app.config.ts`. The yarn scripts handle this.

#### TestFlight build (staging — dev bundle)

`yarn build:testflight`

- **Profile semantics (since 2026-05-16):** TestFlight is the staging channel for the dev app, **not** a pre-release of production. Different bundle, different ASC entry. `devMode = true`.
- **Project:** `@kiniliaapp/kinliadev` (dev)
- **Bundle ID:** `life.kinlia.dev`
- **ASC App ID:** `6748651413` (dev/staging TestFlight)
- **Credentials:** Distribution cert `F5D51AB76A35B61C24CBCCF4E072529` (shared), provisioning profile `GWDS4A6QGA` (kinliadev-scoped)

Note: from 2026-04-18 to 2026-05-16, testflight was bundled with production (`devMode = false`, used production bundle/project). This was reverted because TestFlight should be testable as the dev app, not as the production app pre-release.

#### Production build (App Store — production bundle)

`yarn build:production`

- **Project:** `@kiniliaapp/kinlia` (production)
- **Bundle ID:** `life.kindra.Kindra`
- **ASC App ID:** `1292021975` (production Kinlia App Store entry)
- **Credentials:** Distribution cert `F5D51AB76A35B61C24CBCCF4E072529` (shared), provisioning profile `HFR7AS66D2` (kinlia-scoped)
- Version is set in `app.config.ts` → `version` field
- Build number auto-increments via `appVersionSource: "remote"` in `eas.json`

#### Android — no yarn script yet

Only iOS scripts exist in `package.json` as of 2026-05-16. For Android production:

```bash
EAS_BUILD_PROFILE=production npx eas-cli build --platform android --profile production --non-interactive --no-wait
```

- **Package:** `life.kindra`
- **Build type:** AAB (app-bundle) for Play Store
- Must use the correct Play Store upload keystore (not the EAS dev keystore)
- No auto-submit configured for Android — Play Store upload is manual

#### GitHub Actions workflow — manual-dispatch only since 2026-05-20

The `TestFlightDeploy.yaml` workflow is configured to trigger ONLY on `workflow_dispatch` (manual). Merging to `testflight` does NOT fire an EAS build. This is intentional — see incident below.

To run the cloud build manually: `gh workflow run "TestFlight Deploy" --ref testflight` or use the Actions tab. To run locally (canonical path): `yarn build:testflight`.

⚠️ **Do NOT re-enable `on: push: branches: [testflight]` without reading this.** On 2026-05-20, push-trigger + local build ran in parallel for the same commit — two EAS credits burned. Manual-dispatch eliminates this. Also: the workflow doesn't set `EAS_BUILD_PROFILE` before `eas build` (2026-04-22 issue), so even with push-trigger it would fail with a project-ID mismatch. Fix that too before re-enabling.

#### Key Configuration Files
- `app.config.ts` — `devMode = (EAS_BUILD_PROFILE !== 'production')`. Controls bundle ID, slug, project ID. **TestFlight uses devMode=true (dev bundle).**
- `eas.json` — Build profiles and submit profiles. Submit `ascAppId`: `1292021975` for production, `6748651413` for testflight.
- `package.json` — `build:testflight` and `build:production` scripts.

#### Important Notes
- **EAS builds from the working directory**, not just committed code. Always `git stash` uncommitted changes before building if you only want committed code.
- `appVersionSource: "remote"` means build numbers auto-increment on EAS servers. The `buildNumber`/`versionCode` in `app.config.ts` is ignored for actual builds.
- Two EAS projects exist: `kinliadev` (dev, project ID `d6399725...`) and `kinlia` (production, project ID `b45916c5...`). The `devMode` flag in `app.config.ts` switches between them.
- **Never paste the raw `eas-cli build` command into a terminal manually.** zsh line-wrap can drop `--auto-submit` (the line-break gets interpreted as a separate command), and then you have to run submit by hand. The yarn scripts pass the whole command as a single string from `package.json` and avoid this.

#### EAS Secrets are Scoped to a Project — Always Force the Right Project When Inspecting

**The rule:** EAS environment variables (Secrets) are scoped to a specific EAS project. The Kindra app has TWO EAS projects (`@kiniliaapp/kinliadev` for dev/testflight, `@kiniliaapp/kinlia` for production). A secret stored on the wrong project is **invisible** to the build. When inspecting or creating production secrets, ALWAYS prefix the command with `EAS_BUILD_PROFILE=production` so the CLI resolves the correct project.

**Why (April 28, 2026 incident):** Two production builds (iOS `3240a10b...`, Android `a7f101ea...`) failed at the Sentry source-map upload step with `Auth token is required for this request`. The `SENTRY_AUTH_TOKEN` had been created on `kinliadev` (where dev/testflight builds saw it) but not on `kinlia` (the production project). A pre-flight auditor was supposed to catch this but ran `eas env:list` without forcing the profile, so it resolved to the dev project and reported the token as "Present". Two build credits were burned at 100%+ usage (overage charges).

**How to apply:**
- To inspect production secrets: `EAS_BUILD_PROFILE=production npx eas-cli env:list --environment production`. Confirm the resolved project slug/ID matches `@kiniliaapp/kinlia` / `b45916c5...` before trusting the result.
- To create a production secret: `EAS_BUILD_PROFILE=production npx eas-cli env:create --name <NAME> --type secret --environment production --value <value>`.
- When verifying a token, do a live API ping (e.g., `curl -H "Authorization: Bearer $TOKEN" https://sentry.io/api/0/`) — "Present" is not the same as "valid".

#### Apple Pay / Capability Changes Require Provisioning Profile Regeneration

**The rule:** Whenever you add, remove, or rename a Bundle ID capability or its associated identifiers (Apple Pay Merchant IDs, Push environment, App Groups, associated domains, iCloud containers, etc.) — whether the change is in `app.config.ts` Expo plugin blocks, in the entitlements file, or in the Apple Developer Portal — the EAS-cached provisioning profile becomes stale. You MUST regenerate the profile via `EAS_BUILD_PROFILE=<profile> npx eas-cli credentials -p ios` → "Set up a new provisioning profile" before the next build. Otherwise the build will fail at Xcode's `GatherProvisioningInputs` step with `Provisioning profile "..." doesn't include the <X> capability` or `doesn't match the entitlements file's value for the <Y> entitlement`.

**Why (May 1, 2026 incident, build `88a27522...`):** Changing `merchantIdentifier` from `merchant.kinlia` to `merchant.com.Kinlia` made the EAS-cached provisioning profile stale (created before Apple Pay was enabled on that Bundle ID). Build failed at code-signing. Cost: 1 build credit. No pre-flight auditor catches this yet — see `~/.claude/skills/build-app/patterns.md` FASTLANE-004.

**How to apply:**
- Before any build that follows a change to `app.config.ts` Expo plugin blocks (Stripe, Branch, expo-notifications, expo-apple-authentication, etc.) or to entitlements: ask "did this change the requested capabilities or any named identifier?" If yes, ASK FIRST — do not auto-build.
- Two valid responses: (A) update Apple Developer Portal (enable the capability, associate the Merchant ID / App Group / etc.), then `eas-cli credentials` regenerate the profile; OR (B) conditionalize the change so dev/testflight builds skip the capability they cannot satisfy (flag the resulting coverage gap).
- For Apple Pay specifically: the Merchant ID name MUST match exactly across `app.config.ts`, the entitlements file, the Apple Developer Portal Merchant IDs list, and the Bundle ID's Apple Pay capability associations. `merchant.com.Kinlia` and `merchant.kinlia` are not the same.

#### Native dirs are gitignored — always prebuild after `app.config.ts` edits

**The rule:** `android/` and `ios/` are fully gitignored in this repo (zero tracked files under either). When `app.config.ts` is edited — especially `version`, `ios.bundleIdentifier`, `android.package`, or any Expo plugin block — the local native dirs do NOT update automatically. EAS uploads the working tree as-is and uses the LOCAL `android/app/build.gradle` `versionName` and `ios/<App>/Info.plist` `CFBundleShortVersionString`, NOT the values declared in `app.config.ts`. After every `app.config.ts` edit that touches one of those fields, run `npx expo prebuild --clean` to regenerate the native dirs from `app.config.ts` BEFORE building.

**Why (May 2, 2026 incident, Android build `5678bffe...`):** `app.config.ts` version was bumped to `1.80.11` but no one ran `expo prebuild`. The Android build stamped the AAB with the old `versionName "1.80.06"` from `android/app/build.gradle`. Cost: 1 EAS credit, could not upload to Play Console. EAS's warning about ignoring `android.package` applies to `version`/`versionName` the same way.

**How to apply:**
- After any `app.config.ts` edit, before building: run `npx expo prebuild --clean` from repo root. The `--clean` flag is required — without it, prebuild merges instead of regenerating, and stale values can still survive.
- Hand-editing `android/app/build.gradle` or `ios/<App>/Info.plist` as a workaround is fragile because (a) `git status` shows clean (the dirs are gitignored, so auditors cannot see the drift) and (b) any future `expo prebuild` run wipes the hand-edit. Treat hand-edits as time-sensitive emergencies only, and note them in the commit message so they are not forgotten.
- The `build-prereq-auditor` should compare `app.config.ts` `version` against `android/app/build.gradle` `versionName` (Android builds) or `ios/<App>/Info.plist` `CFBundleShortVersionString` (iOS builds), scoped per-platform — see `~/.claude/skills/build-app/patterns.md` VERSION-001 for the full auditor spec.

#### `.easignore` REPLACES `.gitignore` for EAS uploads — "gitignored" does NOT mean "not shipped"

**The rule:** When a `.easignore` exists at repo root (it does, in KindraApp), EAS uses it *instead of* `.gitignore` to build the upload archive — replacement, not addition. So a gitignored secret file (e.g. `.env.sentry-build-plugin`) is still uploaded to the remote EAS builder unless `.easignore` also excludes it. For secret-bearing files, **absent-from-disk is the safe state at build time**; secrets belong in EAS environment variables, not on disk.

**Why (Aug 5, 2026, build `a0a56da9...`):** Verified during the post-mortem for iOS testflight build 172 — `.gitignore` was found to have zero influence on the archive contents because `.easignore` supersedes it. No incident yet; documented before one happens.

**How to apply:** Before any build, confirm no secret file is sitting on disk; if a file must exist locally but never upload, add it to `.easignore` explicitly and verify — adding it to `.gitignore` accomplishes nothing. See `~/.claude/skills/build-app/patterns.md` DECISION-009 and DECISION-006.

#### More than one KindraApp checkout exists — verify the directory before every fix

**The rule:** KindraApp has at least two working copies: `~/Sites/KindraApp` (day-to-day, feature branches) and `~/Sites/kindraapp-tf-build` (the testflight build worktree, on `testflight`). Any dependency install, config edit, or pre-flight remediation must `cd` to the ABSOLUTE path of the checkout that will actually be built, print `pwd` + `git rev-parse --abbrev-ref HEAD`, and re-run the failing check in that same directory to prove the fix landed.

**Why (Aug 25, 2026, builds `91651c8e` iOS 176 / `cf885a62` Android vc19):** an expo-doctor version-drift fix was run in `~/Sites/KindraApp` while the build uploaded from `~/Sites/kindraapp-tf-build`. `npx expo install` reported success against the wrong tree; the build tree was still drifted. Caught pre-flight, no credit lost. Agent bash calls reset cwd between invocations, so cwd drift is the default, not the exception.

**How to apply:** Never trust a "fix applied" or an auditor PASS that does not name the absolute path it ran in. See `~/.claude/skills/build-app/patterns.md` SKILL-006, DOCTOR-006, DOCTOR-007.

#### A missing config block is not proof it was never wanted — read the file's history

**The rule:** Before concluding that an absent config key (`eas.json` env block, a plugin entry, a script) is a deliberate omission, run `git log -S'<key>' -- <file>` or `git log -p --follow -- <file>`. If the key once existed and disappeared inside a revert, a merge-reapply, or a commit about something else, that is accidental LOSS, not design — say so and cite the removing SHA.

**Why (Aug 25, 2026):** the `build.testflight.env` block added at `bc137882` (2026-05-01) was silently dropped by the `d94e42df` revert/reapply (2026-05-15) and fully removed at `a55116fb` (2026-08-05). A July post-mortem had recorded the absence as an intentional design decision because builds still worked — they work only because git-tracked `.env` rides along in the EAS archive. "It works" never establishes "it was designed this way."

**How to apply:** `eas.json` is ASK-FIRST — report the loss and propose restoration; do not auto-edit. See `~/.claude/skills/build-app/patterns.md` META-006 and `KindraApp/docs/plans/2026-08-25-restore-testflight-env-block.md`.

**Status update (Sept 18, 2026) — this specific block is RESTORED; the rule stands:** `1f25cafb` (PR #409, 2026-08-27) put all 5 `EXPO_PUBLIC_*` vars back into `build.testflight.env`, verified at build commit `8f188d09` via `git show 8f188d09:eas.json`. Do not re-report it as lost, and treat the restoration plan doc as closed.

#### A documented config claim expires — re-verify before restating it

**The rule:** Before restating any "still missing / still broken / still unresolved" config claim from CLAUDE.md, a patterns.md entry, or a prior post-mortem, re-run the one command that proves it at the current commit and cite the output. An inherited claim is a hypothesis, not evidence — the same standard as Plan Verification Rule 1.

**Why (Sept 18, 2026):** the note above sat stale for three weeks, and a build post-mortem (patterns.md DECISION-014, 2026-09-16) copied "the testflight env block is still unrestored" forward from an earlier entry without running `git show <commit>:eas.json`. It had been restored since Aug 27. Documentation that repeats itself unchecked propagates errors faster than chat does, because the next reader treats it as settled.

**How to apply:** when you cannot re-verify, write "not re-verified this run" instead of asserting continuity; when you do correct a stale claim, append a dated correction rather than rewriting history. See `~/.claude/skills/build-app/patterns.md` META-010.

---

# Planning & Files

## Plans

### Plan Files
- Always write plans to docs/plans/
- Use unique, descriptive filenames: docs/plans/YYYY-MM-DD-[feature-name].md
- Never overwrite existing plan files - create a new one for each task
- Before creating a plan, list existing plans in docs/plans/ to avoid name conflicts

### Planning Process

#### ⚠️ NEVER WRITE PLAN CODE FROM MEMORY — THIS IS THE #1 SOURCE OF PLAN BUGS

Before writing ANY code snippet in a plan that references existing code:
1. **Read the actual function** — verify its signature, arity, and return type. `{:ok, result}` is a common convention but NOT universal.
2. **Read the actual schema** — verify field names exist (e.g., don't write `is_virtual` when the field is `is_online`), verify singular vs plural associations.
3. **Read the actual module** — verify function visibility (def vs defp), verify return types match your pattern matching.
4. **Add a `## Verified References` section to the plan** listing every reference you verified, with file:line and the actual code pasted.
5. If you cannot read the actual code, do NOT write code that calls it — flag it as an open question.

This rule exists because multiple pipeline runs have caught wrong field names, wrong return types, and wrong associations that were written from memory. These bugs waste pipeline time and would have been production crashes.

#### Other Planning Rules
1. For coding changes, include exact comment text in plan
   - Comment is written when context is fresh (during planning)
   - Easy to copy-paste during implementation
   - Forces me to think about what future developers need to know

2. Code review step before marking complete
   - Catches missing comments before declaring "done"
   - Can verify comment quality, not just presence
   - Works as a final safety net

3. During Planning
   - Identify the original function (name, file, location)
   - List behaviors that MUST be preserved
   - Include the doc text for the new function

## Plan Verification — Hard Rules

The "NEVER WRITE PLAN CODE FROM MEMORY" rule above is the principle. The six rules below are how to enforce it. Each is reviewer-checkable: another agent or human can verify compliance without trusting prose.

Added after April 2026 rollback-plan errors where plans were rejected for: paraphrased references never actually verified, cross-branch line numbers, global `replace_all` on SHAs corrupting unrelated references, subagent prose treated as truth, and wrong function-boundary claims.

### Rule 1 — Every code reference must paste RAW tool output, not a paraphrase

A `## Verified References` section is incomplete unless every factual claim is backed by a fenced code block containing the literal output of the verification command. REQUIRED format for each entry:

    ### <claim being verified>
    Command: `<exact command run>`
    Raw output:
    ```<lang>
    <pasted unchanged from tool result>
    ```

A bullet that says "verified that the production block has env vars" without the raw output is NOT verified. If raw output is not pasted, the claim remains unverified and the plan reviewer should reject it.

### Rule 2 — Line numbers do not cross branches

When a plan describes editing a file at branch/commit X (the implementer's target) using values cited from branch Y (a reference branch), line numbers from Y are NOT valid edit instructions. The same code lives at different line numbers on different branches.

You must do ONE of:
- Re-find the line at X using `git show X:path | grep -n <unique-token>` and cite X's line number.
- OR use a unique grep-able string instead of a line number ("the line containing `merchantIdentifier`").

A plan that says "L117 of HEAD has the right value, copy to the rollback" is broken. Reject.

### Rule 3 — No global text replaces on identifier-like strings in plans

When updating a plan, do NOT use `replace_all: true` on commit SHAs, branch names, file paths, or function names. The same string can appear in legitimate but semantically distinct contexts (e.g., "fork from commit X" and "branch Y's current tip is X"). Global replace destroys the distinction and silently corrupts other claims.

Each instance must be edited individually after verifying its semantic role.

### Rule 4 — Subagent output is hypothesis, not truth

Any factual claim sourced from an Explore, Plan, or other subagent must be RE-VERIFIED by the main agent before being written into the plan. The re-verification command's output must appear in the plan (per Rule 1), not the subagent's prose summary.

The subagent's report is a hint about where to look. It is not evidence.

### Rule 5 — Function boundaries before line-number claims

Before writing "line N is in function F" (or "line N is the X flow") in any plan, read 30 lines of context around line N and verify the nearest enclosing `function`/`const F = `/`override fun F` declaration. Paste both the line and the enclosing-function header in the plan as evidence.

Single-line citations without surrounding-function context are NOT enough — the surrounding declaration is what makes "line N is in function F" true or false.

### Rule 6 — Reviewer findings get per-issue resolution

When a pipeline reviewer reports N issues, the plan's revision section must list EACH ISSUE INDIVIDUALLY:
- ✅ Fixed at <file:line> (with verification per Rule 1)
- ⏸ Deferred, rationale: <why>
- ❌ Disagree, rationale: <why>

A summary like "all critical issues addressed" is not acceptable. It prevents the next reviewer from auditing the fixes and lets misdiagnosed fixes hide as "✅".

### Rule 7 — Code claims in chat need pasted evidence too

When you state a function exists, returns X, takes args Y, or that a schema has field Z — pair the claim with file:line + the actual pasted code line. If you can't paste it, don't state it. This applies in chat and quick answers, not just plan files. "I recall" / "I think" / "I believe" about a code reference is forbidden — re-read instead.

## File Safety

- NEVER delete files without explicit user approval
- NEVER overwrite existing files without asking first
- When updating a file, show me what will change before doing it
- If a file exists at the target path, ask before proceeding

## File Editing Rules

- When ADDING content to an existing file, use the Edit tool (append), NOT the Write tool (overwrite)
- Only use Write tool when creating NEW files or when explicitly asked to replace entire file contents
- Before overwriting any file, confirm with the user first
