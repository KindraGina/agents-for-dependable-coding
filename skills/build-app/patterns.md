# Build Pattern Library — Kindra Mobile App

This file is maintained by the `build-postmortem-updater` agent. Each entry below describes a failure mode that has been seen in EAS production builds, with the signature, root cause, and fix. The `build-log-analyzer` agent reads this file on every failed build to recognize known patterns instead of guessing.

**Do not edit by hand unless you know what you're doing.** Add new patterns by running `/build-app` and letting the post-mortem agent record them automatically.

---

## Phase: Expo Doctor

### DOCTOR-001 — expo-image version mismatch

- **First seen:** 2026-04-27 (commit 4900123)
- **Last seen:** 2026-04-27
- **Occurrences:** 1
- **Phase:** Expo Doctor
- **Platform:** both
- **Log signature:** `expo-image@3.0.11 - expected version: ~2.4.1`
- **Root cause:** `yarn add expo-image` installed the latest version (3.x) instead of the SDK 53–compatible version (~2.4.1).
- **Fix:** `npx expo install expo-image` (always use `npx expo install` for Expo packages, never `yarn add`).
- **Pre-flight catchable?** Yes — `build-prereq-auditor` Check 2 (`npx expo install --check`).
- **Notes:** Also caused a runtime crash on Android (`IncompatibleClassChangeError`) because the 3.x package called a React Native internal as a static method that became an instance method in RN 0.79.

### DOCTOR-002 — Multiple lockfiles

- **First seen:** 2026-04-27 (commit 1772625)
- **Last seen:** 2026-04-27
- **Occurrences:** 1
- **Phase:** Expo Doctor
- **Platform:** both
- **Log signature:** `Multiple lockfiles detected`
- **Root cause:** Both `yarn.lock` and `package-lock.json` present in repo.
- **Fix:** `rm package-lock.json` (this project uses yarn).
- **Pre-flight catchable?** Yes — `build-prereq-auditor` Check 6.

### DOCTOR-003 — Packages not in React Native Directory

- **First seen:** 2026-04-27 (commit 1772625)
- **Last seen:** 2026-04-27
- **Occurrences:** 1
- **Phase:** Expo Doctor
- **Platform:** both
- **Log signature:** `Validate packages against React Native Directory package metadata`
- **Root cause:** Several legacy packages (`react-native-fs`, `rn-fetch-blob`, etc.) aren't in the React Native Directory or are flagged as untested on the New Architecture. Doctor blocks the build despite `newArchEnabled: false` in app.config.
- **Fix:** Add the specific packages to `package.json` `expo.doctor.reactNativeDirectoryCheck.exclude` array. Setting `listUnknownPackages: false` also helps for unknown-package warnings.
- **Pre-flight catchable?** Yes — `build-prereq-auditor` Check 1.
- **Notes:** Wholesale-disabling this check is discouraged — name the specific packages.

### DOCTOR-004 — react-native / jest-expo SDK mismatch

- **First seen:** 2026-04-27
- **Last seen:** 2026-04-27
- **Occurrences:** 1
- **Phase:** Expo Doctor
- **Platform:** both
- **Log signature:** `react-native@0.79.5 - expected version: 0.79.6` (or similar)
- **Root cause:** Manual install pinned a version that doesn't match SDK 53 expectations.
- **Fix:** `npx expo install react-native jest-expo`.
- **Pre-flight catchable?** Yes — `build-prereq-auditor` Check 2.

### DOCTOR-005 — The expected 8-package Directory advisory (and its drift from `docs/TODO.md`)

- **First seen:** 2026-08-05 (build a0a56da9-da5b-4f4d-adcc-4a924c168baf, iOS testflight, build 172, v1.80.11, commit 8376d9c3, project `kinliadev` — build SUCCEEDED)
- **Last seen:** 2026-09-18 (builds c4c09357 iOS 179 + b3b5d2e6 Android vc21, testflight, commit 8f188d09 — both SUCCEEDED)
- **Occurrences:** 2
- **Phase:** Expo Doctor (pre-flight only — not an EAS build step)
- **Platform:** both
- **Log signature:** `✖ Validate packages against React Native Directory package metadata` with `17/18 checks passed`
- **Root cause:** Not a defect. Per the no-suppression policy (owner decision 2026-07-14, PR #342), `expo.doctor.reactNativeDirectoryCheck.exclude` in `package.json` is deliberately EMPTY, so expo-doctor flags the repo's legacy dependencies on **every single run, by design**. As of this build the flagged set is exactly 8 packages: `react-native-branch`, `react-native-calendar-events`, `react-native-fs`, `react-native-orientation-locker`, `react-native-rate`, `react-native-text-input-mask`, `react-native-version-check`, `rn-fetch-blob` (the first 7 as "untested on New Architecture" — inert here because `app.config.ts` sets `newArchEnabled: false`, see DECISION-001; four of them additionally as "Unmaintained").
- **Fix:** None at build time — the correct response is REPORT-AND-PASS (see META-003). The only real fix is replacing the libraries, which is backlog work, not build work. Do NOT add packages to the exclude list.
- **Pre-flight catchable?** Yes — `build-prereq-auditor` Check 1 already surfaces it. The auditor must classify it as **ADVISORY / expected**, and should diff the observed package list against this entry's list of 8: an identical list = expected state, PASS; a NEW name appearing = a genuinely new dependency-health regression worth flagging loudly.
- **Notes / open follow-up (backlog drift):** These 8 packages are **not listed** in `docs/TODO.md` → "Legacy Library Refactor". The backlog and the live doctor output have drifted apart — the TODO section was written before the July 2026 migrations landed (PRs #345/#346/#349/#356/#357/#359) and was never reconciled against what doctor actually still reports. Owner follow-up (not a build blocker): reconcile `docs/TODO.md`'s Legacy Library Refactor list with this 8-package set so the backlog reflects reality. Until then, treat THIS entry as the authoritative expected-advisory list. See META-003 for why the advisory must never be a FAIL.
- **Update 2026-09-18 (list drift — the diff the auditor is supposed to do, done):** the observed advisory is no longer the 8 packages above. Current output: **7 "Untested on New Architecture"** (`react-native-branch`, `react-native-calendar-events`, `react-native-fs`, `react-native-orientation-locker`, `react-native-rate`, `react-native-text-input-mask`, `react-native-version-check` — unchanged) and **5 "Unmaintained"**: `@react-native-community/blur`, `react-native-fs`, `react-native-rate`, `react-native-text-input-mask`, `rn-fetch-blob`. `@react-native-community/blur` is a **NEW name** not in the originally recorded set — this entry previously recorded 4 unmaintained packages. Total distinct flagged packages is now **9**. The new name is a genuine dependency-health signal per this entry's own "a NEW name appearing = flag it loudly" rule, and it was recorded in `docs/TODO.md` by PR #424 on 2026-09-18. It is still ADVISORY, still not a build blocker, still must not be suppressed. **Authoritative expected set going forward = the 9 above** (7 untested / 5 unmaintained, with overlap).

### DOCTOR-006 — Upstream Expo patch releases drift the pins between builds

- **First seen:** 2026-08-25 (builds 91651c8e iOS 176 + cf885a62 Android vc19, testflight, commit 47ec056e — both SUCCEEDED after the fix)
- **Last seen:** 2026-08-25
- **Occurrences:** 1
- **Phase:** Expo Doctor (pre-flight)
- **Platform:** both
- **Log signature:** `Check dependencies for packages that should not be installed directly` / `expected version: 54.0.37` (the generic shape is `<pkg>@<installed> - expected version: <newer patch>`)
- **Root cause:** Not a repo defect. Expo publishes patch releases inside the same SDK line between builds. Nothing in the repo changed; upstream moved. On this build the drift was `expo 54.0.36 → 54.0.37`, `expo-constants 18.0.13 → 18.0.14`, `jest-expo 54.0.17 → 54.0.18`. Expect this on any build that follows a gap of days/weeks since the last one.
- **Fix:** `npx expo install expo@54.0.37 expo-constants@18.0.14 jest-expo@54.0.18` — i.e. `npx expo install` with the EXACT versions expo-doctor names, never `yarn add`, never `npx expo install --fix` blind. **Run it in the directory the build will upload from** (see SKILL-006 — the first attempt on this build landed in the wrong checkout). Then re-run `npx expo install --check` in that same directory and confirm clean, and check for nested duplicates (DOCTOR-007).
- **Pre-flight catchable?** Yes — `build-prereq-auditor` Check 2 (`npx expo install --check`) already catches it. Hardening needed: the auditor must print the absolute path it ran in, so a green result from the wrong checkout cannot pass for the build's checkout.
- **Notes:** Distinct from DOCTOR-004 (a human pinned a wrong version by hand) — here the pins were correct when written and went stale on their own. Treat as routine maintenance, not as a regression to investigate. Sister entries: DOCTOR-007 (the duplicate-copy fallout of the fix), SKILL-006 (wrong-checkout hazard).

### DOCTOR-007 — yarn 1.x leaves stale nested copies after a native-module patch bump

- **First seen:** 2026-08-25 (builds 91651c8e iOS 176 + cf885a62 Android vc19, testflight, commit 47ec056e — caught pre-flight, both SUCCEEDED)
- **Last seen:** 2026-08-25
- **Occurrences:** 1
- **Phase:** Expo Doctor / dependency install (pre-flight; would surface as a native build or runtime failure if shipped)
- **Platform:** both
- **Log signature:** `node_modules/expo-asset/node_modules/expo-constants` (generic shape: any `node_modules/<a>/node_modules/<pkg>` path for a package that also exists at the top level at a different version)
- **Root cause:** yarn 1.x does not re-hoist on a patch bump. Bumping `expo-constants` 18.0.13 → 18.0.14 at the top level left THREE nested 18.0.13 copies under `expo-asset/`, `expo-linking/` and `expo-notifications/`, because their lockfile ranges still resolved to the older entry. For a **native** module this is not cosmetic — two copies of the same native module can both be linked into the app, which is an EAS build/link failure risk and a duplicate-symbol risk at runtime. `npx expo install --check` reports clean because it only inspects top-level versions.
- **Fix:** `npx yarn-deduplicate yarn.lock --packages expo-constants` then `yarn install`, then re-verify with `ls -d node_modules/*/node_modules/expo-constants` (a "no matches found" result is the pass condition). Run in the build's checkout (SKILL-006).
- **Pre-flight catchable?** Yes, but NOT covered today — needs a new `build-prereq-auditor` check. Spec: after any Expo package version change, for each changed package run `ls -d node_modules/*/node_modules/<pkg>` and, if any path exists, compare its `package.json` version against the top-level one. Any mismatch on a package with a native module (`expo-*` with an `ios/`, `android/`, or `*.podspec` entry) is a FAIL with the yarn-deduplicate remedy above. A matching-version nested copy is benign — report and PASS.
- **Notes:** The tell is that this hides behind a green `expo install --check`. Anything that only reads the top level of `node_modules` cannot see it. Shipped as PR #405 (branch `ExpoConstantsDedupe_08_25_26`). Related: DOCTOR-006 (the bump that triggered it), DOCTOR-001 (the other way a wrong native-module version reaches the device).

## Phase: Prebuild

(none recorded yet)

## Phase: Native Config Drift (gitignored android/ and ios/)

### VERSION-001 — Stale local native dirs silently override `app.config.ts`

- **First seen:** 2026-05-02 (build 5678bffe-136b-4ff0-9a9a-b953a4f41c37, Android production)
- **Last seen:** 2026-05-02
- **Occurrences:** 1
- **Phase:** EAS upload → build (silent — no error; wrong version stamped on AAB/IPA)
- **Platform:** both (manifested on Android; same risk applies to iOS)
- **Log signature:** `Specified value for 'android.package' in app.config.ts is ignored because an android directory was detected in the project. EAS Build will use the value found in the native code.` (the same logic applies to `version` / `versionName` / `versionCode` / `CFBundleShortVersionString` even though they are not always individually called out in the EAS log)
- **Root cause:** The Kindra repo's `.gitignore` excludes both `android/` and `ios/` (zero tracked files under either). When `app.config.ts` `version` is bumped (e.g., commit 9fc2a38f bumped to `1.80.11`), the local native dirs are NOT regenerated unless someone runs `npx expo prebuild`. EAS uploads the working tree as-is and uses the LOCAL native files: `android/app/build.gradle` `versionName` and `versionCode`, `ios/<App>/Info.plist` `CFBundleShortVersionString` and `CFBundleVersion`. On 2026-05-02, the Android production build compiled successfully and produced an AAB stamped `versionName "1.80.06"` instead of the intended `1.80.11`, because `android/app/build.gradle:98` still had the old value. Result: 1 EAS overage credit burned, AAB unusable for Play Console upload.
- **Fix:** Run `npx expo prebuild --clean` after every `app.config.ts` edit that touches `version`, `ios.bundleIdentifier`, `android.package`, or any Expo plugin block. The `--clean` flag deletes and regenerates `android/` and `ios/` from `app.config.ts` so the native files match the declared config. Hand-editing `android/app/build.gradle` (or the iOS Info.plist) as a workaround is fragile — see corollary below.
- **Pre-flight catchable?** Yes — needs a new auditor or extension to `build-prereq-auditor`. Spec for the check (per-platform, scoped to the build target):
  - Read `app.config.ts` `version` (string) — call this `declared_version`.
  - **For Android builds (platform === "android" or "all"):** read `android/app/build.gradle` and grep for `versionName` (regex: `versionName\s+"([^"]+)"`). Compare to `declared_version`. If different, FAIL with: "Native versionName drift — `app.config.ts` says X but `android/app/build.gradle` says Y. Run `npx expo prebuild --clean` and re-stage."
  - **For iOS builds (platform === "ios" or "all"):** read `ios/<AppName>/Info.plist` (path varies by app name; on Kindra: `ios/Kindra/Info.plist`) and grep for `CFBundleShortVersionString` value. Compare to `declared_version`. Same FAIL semantics.
  - **Critical scoping rule:** Only check the file for the platform being built. An Android-only build must NOT fail on a stale iOS plist (and vice versa). See SKILL-005 for the orchestrator-side bug that violated this scoping today.
  - **Why not also check `versionCode` / `CFBundleVersion`:** those are auto-incremented by EAS (`appVersionSource: "remote"` in `eas.json`), so a local stale value is expected and benign for the build number. Only the human-visible `version` / `versionName` / `CFBundleShortVersionString` need to match `app.config.ts`.
- **Notes:**
  - **Corollary (gitignored hand-edits invisible to git auditors):** Build B on 2026-05-02 (8e5147be) succeeded after a hand-edit to `android/app/build.gradle:98` (`1.80.06` → `1.80.11`). `git status` and `git diff` both showed clean because `android/` is gitignored, so the existing `commit-state-auditor` reported "no source/config drift" — technically true, but blind to the real drift. Once VERSION-001 is implemented, the correct response to its FAIL is `npx expo prebuild --clean`, NOT a hand-edit. A hand-edit will be wiped the next time anyone runs prebuild, re-introducing the bug. Document in the auditor's failure message: "Recommended fix: prebuild. Hand-edit only as time-sensitive emergency workaround, and note in the commit message."
  - **Cost:** 1 EAS build credit at pay-as-you-go overage rate. Could have been worse if the wrong-versioned AAB had been uploaded to Play Console.
  - See `~/Sites/CLAUDE.md` "EAS Build & Deploy" → "Native dirs are gitignored — prebuild after `app.config.ts` edits" for the broader rule.

## Phase: Bundle JavaScript

### BUNDLE-001 — Smart quotes in source file

- **First seen:** 2026-04-28 (commit e72193e)
- **Last seen:** 2026-04-28
- **Occurrences:** 1
- **Phase:** Bundle JavaScript
- **Platform:** both
- **Log signature:** `SyntaxError: ... Unexpected character '\u2018'` (or `\u2019`, `\u201c`, `\u201d`)
- **Root cause:** Smart/curly quotes (`'`, `'`, `"`, `"`) pasted into a `.tsx` file, which Metro cannot parse.
- **Fix:** Open the file at the cited line, replace all curly quotes with straight `'` or `"`. Don't trust visual inspection — use `LC_ALL=C grep -P '[\xe2][\x80][\x98\x99\x9c\x9d]' <file>` to find them.
- **Pre-flight catchable?** Yes — `build-prereq-auditor` Check 4 (bundle test) and Check 5 (smart-quote scan on changed files).
- **Notes:** Caused by pasting code from chat. Cost 4 burned build credits in April 2026 because the visible character looked identical.

## Phase: Install Pods

### PODS-001 — Patch filename version mismatch

- **First seen:** 2026-04-27 (commit 4900123)
- **Last seen:** 2026-04-27
- **Occurrences:** 1
- **Phase:** Project setup / Install Pods
- **Platform:** ios
- **Log signature:** `Cannot apply patch ... patches/expo-image+3.0.11.patch`
- **Root cause:** A `patches/<pkg>+<version>.patch` file was kept after the package was downgraded. patch-package ran in a clean install context and rejected the version-mismatched patch.
- **Fix:** Either delete the stale patch file OR regenerate with `npx patch-package <pkg>` against the currently installed version, which produces a new file with the matching version in the filename.
- **Pre-flight catchable?** Yes — `build-prereq-auditor` Check 3.

## Phase: Run Fastlane (iOS)

### FASTLANE-001 — Sentry source map upload fails (token unavailable to Xcode phase)

- **First seen:** 2026-04-28 (commit 33759e7)
- **Last seen:** 2026-04-28 (build 3240a10b-2b99-47b3-a861-4c75decdd94a)
- **Occurrences:** 5
- **Phase:** Run fastlane → Xcode "Bundle React Native code and images" → sentry-cli source map upload
- **Platform:** ios
- **Log signature:** `Auth token is required for this request` (also: `sentry-cli ... To disable source maps auto upload, set SENTRY_DISABLE_AUTO_UPLOAD=true`, `Loaded file referenced by SENTRY_PROPERTIES`)
- **Root cause:** The Xcode build phase runs `sentry-cli` to upload source maps. It does NOT read environment variables from `eas.json` `env` blocks. It only sees: (a) values from `.env.sentry-build-plugin`, (b) values from `ios/sentry.properties`, and (c) variables stored as EAS environment variables (Secrets) **on the EAS project that the build profile resolves to**. The Kindra app has TWO EAS projects: `@kiniliaapp/kinliadev` (dev/testflight, project ID `d6399725...`) and `@kiniliaapp/kinlia` (production, project ID `b45916c5...`). A `SENTRY_AUTH_TOKEN` stored on the wrong project is **invisible** to the build. Today's failure: token existed on `kinliadev` but not on `kinlia`, so the production build had no token.
- **Fix:** Two valid options:
  - **(A) Make the upload work:** Confirm which EAS project the production profile resolves to (`EAS_BUILD_PROFILE=production npx eas-cli env:list --environment production` — must show the `kinlia` project, NOT `kinliadev`). Then run `EAS_BUILD_PROFILE=production npx eas-cli env:create --name SENTRY_AUTH_TOKEN --type secret --environment production --value <token>`. Confirm `ios/sentry.properties` `defaults.org` matches your real Sentry org slug (was `imranafzal`, should be `kinlia`).
  - **(B) Disable the upload:** Set `SENTRY_DISABLE_AUTO_UPLOAD=true` in `.env.sentry-build-plugin`. Source maps will not be uploaded; production crashes will appear with minified stack traces. (NOT preferred — see DECISION-004.)
- **Pre-flight catchable?** Yes — `sentry-config-auditor` Steps 5 & 8 — **but the auditor as of 2026-04-28 had a project-resolution bug**: it ran `eas env:list` without setting `EAS_BUILD_PROFILE=<profile>`, so the CLI defaulted to whichever project `app.config.ts` resolved to in the agent's shell (the dev project), reported the token as "Present", and PASSED a build that was actually missing the token. **The auditor MUST force `EAS_BUILD_PROFILE=<profile>` and print the resolved project ID/slug in its report. It MUST also live-ping the Sentry API with the discovered token to prove validity, not just presence.**
- **Notes:** **`SENTRY_ALLOW_FAILURE=true` does NOT work** in `@sentry/react-native` v6.x. The error message mentions it but the shell script never checks it. Do not rely on this flag. See also GRADLE-001 (Android variant of the same root cause) and META-001 (the auditor-loop-closure meta-lesson).

### FASTLANE-002 — Wrong Sentry org in sentry.properties

- **First seen:** 2026-04-28
- **Last seen:** 2026-04-28
- **Occurrences:** 1
- **Phase:** Run fastlane
- **Platform:** ios
- **Log signature:** `unable to authenticate ... org imranafzal not found` (or 404 from Sentry API)
- **Root cause:** `ios/sentry.properties` had `defaults.org=imranafzal` (a stale org slug). The real org is `kinlia`.
- **Fix:** Edit `ios/sentry.properties` so `defaults.org=kinlia` and `defaults.project=kinlia` (for production) or `kinlia-staging` (for testflight, if a separate Sentry project is used).
- **Pre-flight catchable?** Yes — `sentry-config-auditor` Step 6.

### FASTLANE-003 — Wrong production Sentry DSN in App.tsx

- **First seen:** 2026-04-28
- **Last seen:** 2026-04-28
- **Occurrences:** 1
- **Phase:** Runtime (not a build failure — silent misrouting)
- **Platform:** both
- **Log signature:** Production crashes don't appear in the production Sentry project.
- **Root cause:** The DSN hardcoded in `App.tsx` for production pointed to a different/stale Sentry project ID. Errors were going to the wrong destination.
- **Fix:** In Sentry → Projects → kinlia → Client Keys (DSN), copy the DSN. Paste into the production branch of `App.tsx`'s DSN ternary.
- **Pre-flight catchable?** Partially — `sentry-config-auditor` Step 7 flags it as NEEDS USER VERIFICATION since cross-checking against Sentry requires an external lookup.

### FASTLANE-004 — Provisioning profile missing Apple Pay capability / Merchant ID

- **First seen:** 2026-05-01 (build 88a27522-05a9-47b5-91fb-e058ca3a8b79, iOS testflight, project `@kiniliaapp/kinliadev`)
- **Last seen:** 2026-05-01 (build 88a27522-05a9-47b5-91fb-e058ca3a8b79)
- **Occurrences:** 1
- **Phase:** Run fastlane → Xcode build → GatherProvisioningInputs (code signing validation)
- **Platform:** ios
- **Log signature:** `Provisioning profile "..." doesn't include the Apple Pay capability` (also: `doesn't support the ... Merchant ID`, `doesn't match the entitlements file's value for the com.apple.developer.in-app-payments entitlement`)
- **Root cause:** The provisioning profile in EAS credentials predates a change to the Bundle ID's enabled capabilities (or its Merchant ID associations). In this case: `app.config.ts:133` declares `merchantIdentifier: ['merchant.com.Kinlia']` for the Stripe Expo plugin, which generates a `com.apple.developer.in-app-payments` entitlement requesting that exact Merchant ID. The `life.kinlia.dev` profile was created 2025-07-15 — before Apple Pay / `merchant.com.Kinlia` were associated with that Bundle ID — so Xcode's `GatherProvisioningInputs` step rejects the build because the entitlement file demands a capability the profile cannot grant. **Why this surfaced now:** prior builds (e.g., 147) had a typo `merchant.kinlia` in `app.config.ts` which Apple silently ignored because no such Merchant ID existed; Phase 1 of the rollback fixed the typo to canonical `merchant.com.Kinlia`, so Apple now takes the entitlement seriously and the stale profile fails closed.
- **Fix:** Two valid options:
  - **(A) Grant the capability and regenerate the profile (preferred for production):**
    1. Apple Developer Portal → Certificates, IDs & Profiles → Identifiers → select the Bundle ID (`life.kinlia.dev` or `life.kindra.Kindra`) → enable Apple Pay → associate the Merchant ID (`merchant.com.Kinlia`).
    2. `EAS_BUILD_PROFILE=<profile> npx eas-cli credentials -p ios` → choose the profile → "Set up a new provisioning profile" so EAS regenerates against the now-updated Bundle ID capability set.
    3. Re-run the build.
  - **(B) Conditionalize the merchantIdentifier on devMode so dev/testflight builds skip Apple Pay:** In `app.config.ts`, change the Stripe plugin block to only include `merchantIdentifier` when `!devMode` (or only for the production Bundle ID). Useful when Apple Pay is not actually required for the dev build path, but be aware: this means dev/testflight will not exercise the same Apple Pay flow as production — flag this as a coverage gap.
- **Pre-flight catchable?** No (as of 2026-05-01) — **needs a new auditor.** See "Future work" below. Existing auditors (`build-prereq-auditor`, `env-var-auditor`, `sentry-config-auditor`, `commit-state-auditor`) all PASSED on this build because none of them inspect the provisioning profile's capability list against the requested entitlements.
- **Notes:** Cost 1 build credit at pay-as-you-go overage rate (user is at 100%+ included quota). Related: see `~/Sites/CLAUDE.md` "Mobile App — Not a Server" → "Apple Pay / Merchant ID changes require provisioning profile regeneration" for the broader rule. Sister pattern to META-001 (recurring failure that an auditor was supposed to catch but didn't) — but here, the auditor doesn't exist yet, so it's a coverage gap rather than an auditor bug.
- **Future work — new auditor needed:** A `provisioning-profile-capability-auditor` that:
  1. Reads `app.config.ts` (and the Stripe / push / other Expo plugin blocks) to enumerate every requested entitlement (Apple Pay merchant IDs, Push Notifications environment, App Groups, associated domains, etc.).
  2. Calls `EAS_BUILD_PROFILE=<profile> npx eas-cli credentials -p ios --json` to get the resolved profile and its capability list.
  3. Confirms each requested entitlement is present in the profile's capability list (and that named identifiers like Merchant IDs match exactly — `merchant.com.Kinlia` vs `merchant.kinlia` is not the same).
  4. Fails closed with a specific message: "Profile X is missing capability Y" or "Profile X does not include Merchant ID Z".

## Phase: Run Gradle (Android)

### GRADLE-001 — Sentry source map upload fails (token unavailable to Gradle task)

- **First seen:** 2026-04-28 (build a7f101ea-87e4-4973-afc1-35b5a60a3d0a)
- **Last seen:** 2026-04-28 (build a7f101ea-87e4-4973-afc1-35b5a60a3d0a)
- **Occurrences:** 1
- **Phase:** Run gradlew → `:app:createBundleReleaseJsAndAssets_SentryUpload_*` → sentry-cli source map upload
- **Platform:** android
- **Log signature:** `Auth token is required for this request` (emitted from a `:app:createBundleReleaseJsAndAssets_SentryUpload` Gradle task)
- **Root cause:** Same root cause as FASTLANE-001 but on the Android side. The Sentry Gradle plugin spawns `sentry-cli` during the release JS bundle task to upload source maps. It can only see env vars present in the EAS build environment — i.e., variables set on the EAS project the build profile resolves to. The Kindra app has TWO EAS projects: `@kiniliaapp/kinliadev` (dev/testflight, ID `d6399725...`) and `@kiniliaapp/kinlia` (production, ID `b45916c5...`). The `SENTRY_AUTH_TOKEN` existed on `kinliadev` only, so the production Android build had no token even though `eas env:list` (without `EAS_BUILD_PROFILE`) reported "Present".
- **Fix:** Identical to FASTLANE-001 (A): create the secret on the production EAS project. Verify with `EAS_BUILD_PROFILE=production npx eas-cli env:list --environment production` and confirm the resolved project ID is `b45916c5...` (NOT `d6399725...`) before trusting the result. Then `EAS_BUILD_PROFILE=production npx eas-cli env:create --name SENTRY_AUTH_TOKEN --type secret --environment production --value <token>`.
- **Pre-flight catchable?** Yes — same auditor as FASTLANE-001 (`sentry-config-auditor`). Same auditor bug applies: must force `EAS_BUILD_PROFILE=<profile>` and print the resolved project so a token-on-wrong-project mistake cannot hide.
- **Notes:** Confirms FASTLANE-001 is platform-agnostic — both iOS Xcode build phase and Android Gradle task fail identically when the token is absent from the resolved EAS project. Treat any future "Auth token is required for this request" as a project-scope issue first, not a token-value issue.

## Phase: Upload / Submit

(none recorded yet)

## Meta-Lessons (auditor / pipeline bugs)

### META-001 — Auditor "Present" did not mean "available to the build"

- **First seen:** 2026-04-28 (builds 3240a10b iOS + a7f101ea Android, both failed the same day for the same root cause)
- **Last seen:** 2026-04-28
- **Occurrences:** 1
- **Affects:** `sentry-config-auditor`
- **What happened:** FASTLANE-001 had been recorded 4 times before today. The `sentry-config-auditor` was specifically built to catch it pre-flight. Today it PASSED pre-flight, yet two production builds (one iOS, one Android) failed at source-map upload because the token was missing on the production EAS project. Root cause of the auditor bug: it ran `npx eas-cli env:list` without `EAS_BUILD_PROFILE=<profile>` set, so the CLI resolved the project from the agent's shell defaults (which produced the dev project where the token DID exist) and reported "Present" for what was actually "Missing on the build's project". Two EAS build credits were burned at 100%+ usage (incurring overage charges) for a class of failure the auditor was supposed to catch.
- **Required hardening:**
  1. The auditor MUST set `EAS_BUILD_PROFILE=<profile>` for every `eas-cli` call so the CLI resolves the same project the build will use.
  2. The auditor MUST print the resolved EAS project slug AND project ID in its report (e.g., "Resolved project: @kiniliaapp/kinlia (b45916c5...)"). If the resolved project does not match the expected production project ID, fail closed.
  3. The auditor MUST do a live Sentry API ping with the discovered token (e.g., `curl -H "Authorization: Bearer $TOKEN" https://sentry.io/api/0/` and require HTTP 200). A token can be present-but-revoked or present-but-malformed; only a live ping proves validity.
  4. If the token cannot be reached or returns non-200, the auditor must FAIL CLOSED — never report "Present" based on existence alone.
- **Why this is a meta-lesson:** The repeating count on FASTLANE-001 (now 5 occurrences) means the loop wasn't closing. A pattern that recurs after the auditor was built specifically to catch it is evidence of an auditor bug, not just a code bug. Future auditor work should always include: (a) reproducing the failure on a known-bad input, (b) confirming the auditor flags it, (c) confirming a known-good input passes — all three, every time.
- **Notes:** This entry exists so the next post-mortem agent and the next auditor author both see, in one place, that "Present" must mean "Present where the build can see it, and verified to work" — not just "exists somewhere".
- **Validation 2026-05-02 (build d7098699-4eae-4eac-bc41-3cb761ac0239, iOS production, 1.80.11):** Hardened auditor PASSED pre-flight, build SUCCEEDED at the source-map upload step. The auditor (a) forced `EAS_BUILD_PROFILE=production`, (b) printed the resolved project (`@kiniliaapp/kinlia` / `b45916c5...`), (c) live-pinged Sentry API and got HTTP 200, (d) verified `SENTRY_DISABLE_AUTO_UPLOAD` was not set. An independent reviewing agent flagged the token post-submit; the build outcome confirmed the auditor's assessment was correct. The "Present is not the same as valid" rule worked as intended. Loop closure for FASTLANE-001 / GRADLE-001 confirmed.

### META-002 — Auditor FALSE FAIL: "EAS builds do not read .env" applied to the testflight/dev EXPO_PUBLIC_ path

- **First seen:** 2026-07-27 (builds 9f54e9fb-4b69-4227-adea-ec80553236a4 iOS + c1600acf-e067-4430-bf4a-e8f7262088e7 Android, both SUCCEEDED, commit e9222059, testflight profile, v1.80.11)
- **Last seen:** 2026-07-27
- **Occurrences:** 1
- **Affects:** `build-prereq-auditor` / `env-var-auditor` (two auditors issued the same false FAIL)
- **What happened:** Two pre-flight auditors independently FAILed the build on the premise "EAS builds do not read `.env`, so the testflight profile's `EXPO_PUBLIC_*` vars are missing." Both FAILs were WRONG and would have blocked two successful builds. The builds succeeded with the config as-is.
- **Ground truth for THIS repo (verify before repeating the premise):**
  1. `.env` is **git-tracked** (DECISION-002 — it is NOT gitignored).
  2. `.easignore` excludes only `credentials.json` and `credentials/` (DECISION-006) — it does NOT exclude `.env`. Therefore `.env` IS uploaded with the working tree to EAS.
  3. Expo SDK 53's CLI **natively inlines `EXPO_PUBLIC_*` values from the uploaded `.env`** into the JS bundle at build time (Expo's own dotenv loading, which runs during bundling on the EAS worker — this is separate from EAS's env injection).
  4. The `eas.json` `env` block existing does NOT stop Expo CLI's dotenv loading. `eas.json` `env` governs EAS's own env injection; dotenv does not override an already-set var, so the two coexist. The testflight profile deliberately relies on the dotenv path (see DECISION-007); production overrides via its full `env` block (see DECISION-003).
- **Required hardening:** Before declaring `EXPO_PUBLIC_*` vars "missing" for a build, an auditor MUST: (a) check whether `.env` is git-tracked (`git ls-files --error-unmatch .env`), (b) check `.easignore` (and `.gitignore` fallback) to confirm `.env` is NOT excluded from the EAS upload, and (c) recognize that for testflight/dev, Expo CLI inlines `EXPO_PUBLIC_*` from the uploaded `.env`. Only if `.env` is excluded from upload AND the var is absent from the resolved `eas.json` `env` block is the var actually missing. Do not treat "not in `eas.json` env" as "missing" — that is only true when the dotenv path is also unavailable.
- **Why this is a meta-lesson:** The generic rule "EAS builds run on remote servers and do not read `.env`" (true for EAS's own env injection, and correctly documented in CLAUDE.md so people put PRODUCTION vars in `eas.json`) was over-applied to the Expo CLI dotenv path and to a git-tracked `.env`. The safety rule stays; the auditor's precondition check must be more precise.

### META-003 — Auditor FALSE FAIL: expo-doctor React Native Directory advisory treated as a build blocker

- **First seen:** 2026-07-27 (builds 9f54e9fb iOS + c1600acf Android, both SUCCEEDED, commit e9222059, testflight profile)
- **Last seen:** 2026-07-27
- **Occurrences:** 1
- **Affects:** `build-prereq-auditor` (expo-doctor check)
- **What happened:** The expo-doctor "React Native Directory" advisory (17 of 18 checks passing; the Directory check flags legacy packages) was risk of being classified as a FAIL. It is NOT a build blocker — both builds succeeded with the advisory present.
- **Ground truth:** Per the no-suppression policy (owner decision 2026-07-14, PR #342), `expo.doctor.reactNativeDirectoryCheck.exclude` in `package.json` stays EMPTY. That means the Directory advisory is the **standing, owner-decided expected state** on every build — it is surfaced on purpose and is NOT suppressed. expo-doctor's Directory check does not abort the EAS build; it is advisory metadata about dependency health.
- **Required hardening:** Prereq auditors must classify the React Native Directory advisory as **ADVISORY / expected**, not FAIL. The correct action is to report it (feeding the `docs/TODO.md` Legacy Library Refactor backlog) and PASS. A FAIL on this advisory would block every build indefinitely, which contradicts the no-suppression + no-block owner posture.
- **Note — supersedes the DOCTOR-003 fix for this repo:** DOCTOR-003's original fix ("add packages to the `reactNativeDirectoryCheck.exclude` list") is now AGAINST policy — the exclude list stays empty (PR #342). The Directory advisory is expected and must not be suppressed nor treated as a blocker. Keep DOCTOR-003 for its diagnostic signature, but do not apply its suppression fix.

### META-004 — Auditor near-FALSE-FAIL: local bundle check greps for a string RN 0.81's CLI never prints

- **First seen:** 2026-08-05 (build a0a56da9-da5b-4f4d-adcc-4a924c168baf, iOS testflight, build 172, v1.80.11, commit 8376d9c3 — build SUCCEEDED)
- **Last seen:** 2026-08-05
- **Occurrences:** 1 (hit independently by TWO auditor runs on the same build)
- **Affects:** `build-prereq-auditor` — Check 4 (JS Bundle Compiles), spec line `~/.claude/agents/build-prereq-auditor.md:77`
- **What happened:** The auditor spec says: **"PASS: Output contains `Done writing bundle output`."** React Native 0.81's bundler CLI does **not** print that string — it renders a TTY spinner/progress UI instead and exits 0 on success. Two independent auditor runs on this build hit the missing literal. Both recovered by reasoning about other evidence, but an auditor that follows the spec literally would FAIL a perfectly healthy bundle and block a good build.
- **Ground truth:** The literal `Done writing bundle output` is an OLDER RN CLI message. Its absence carries no information on RN 0.81. Presence of the string is sufficient evidence of success; **absence is not evidence of failure.**
- **Required hardening (replace the single-grep PASS criterion with all three):**
  1. **Exit code is 0** from the `npx expo export:embed` / bundle command — this is the primary signal.
  2. **A fresh bundle artifact exists on disk** with a modification time inside this run (check size is non-trivial, e.g. > 1 MB, not a 0-byte stub).
  3. **Zero error lines** in the captured output (`error:`, `SyntaxError`, `Unable to resolve module`, `Failed to`).
  Optionally still accept `Done writing bundle output` as a fast-path PASS for older CLIs, but never FAIL solely on its absence.
- **Why this is a meta-lesson:** Same class as META-002/META-003 — an auditor rule hard-coded to a tool's incidental output format silently rots when the tool's UX changes, and then fails closed on healthy input. Any auditor criterion that greps a third-party tool's human-readable log line should be paired with a structural signal (exit code, artifact on disk) that does not depend on wording. Preferring exit codes + artifacts over log-string matching is the general rule.
- **Notes:** Cost this time: zero credits (caught pre-flight, build proceeded and succeeded), but the next agent that follows the spec verbatim would waste a cycle arguing with a green bundle. Fix the spec line, don't rely on agent judgment. Related: BUNDLE-001 (the real failure mode Check 4 exists to catch — a genuinely broken bundle still trips criteria 1 and 3 above).

### META-005 — Sentry symbolication must be verified empirically, not inferred from the `eas.json` flag

- **First seen:** 2026-08-05 (build a0a56da9-da5b-4f4d-adcc-4a924c168baf, iOS testflight, build 172, v1.80.11, commit 8376d9c3 — build SUCCEEDED)
- **Last seen:** 2026-08-05
- **Occurrences:** 1
- **Affects:** `sentry-config-auditor`
- **What happened:** The auditor's policy held that source-map upload must be ON for the testflight profile, making `SENTRY_DISABLE_AUTO_UPLOAD=true` in `eas.json` a build blocker. Live Sentry API data contradicted the inference: staging events from **build 171** were **fully symbolicated** despite that flag being `true`. Source maps are reaching Sentry through a different leg — debug-ID-keyed artifact bundles uploaded around build time — not through the Xcode/Gradle auto-upload step the flag governs.
- **Ground truth:** `SENTRY_DISABLE_AUTO_UPLOAD=true` disables ONE upload path. It does not prove "no source maps in Sentry." The only reliable evidence of symbolication is the **actual state of a recent event in the Sentry project**: pull a recent event for the relevant release/build and inspect whether its stack frames carry real file names, line numbers and `in_app` context (symbolicated) versus minified single-line frames.
- **Required hardening:** Before treating a Sentry source-map setting as a build blocker, the auditor MUST (a) query the Sentry API for the most recent event on the target project/release, (b) inspect that event's frames for symbolication, and (c) only escalate to FAIL if events are genuinely un-symbolicated AND the profile requires symbolication. Report the empirical finding (event ID + symbolication verdict) in the audit output, not just the flag value. A config flag is a hypothesis; the event data is the evidence.
- **Why this is a meta-lesson:** Third instance of the same shape (META-002, META-003, META-004): a static config read was treated as a proxy for a runtime outcome, and the proxy was wrong. It is also the mirror image of META-001 — there, "Present in config" wrongly implied "works"; here, "Disabled in config" wrongly implied "broken." Both directions require checking the live system.
- **Notes:** This does NOT overturn DECISION-008 (testflight sets `SENTRY_DISABLE_AUTO_UPLOAD=true` deliberately; an auditor must not FAIL testflight for it) or DECISION-004 (upload mandatory for production). It adds the empirical check that decides whether the flag matters at all. Open question worth answering once, by the owner: identify exactly which mechanism uploads the debug-ID artifact bundles, so the real dependency is documented rather than observed.

### META-006 — env-var-auditor's testflight FAIL was TRUE: the `eas.json` env block was lost in a revert, not omitted on purpose

- **First seen:** 2026-08-25 (builds 91651c8e iOS 176 + cf885a62 Android vc19, testflight, commit 47ec056e — both SUCCEEDED; the finding is a latent fragility, not a build failure)
- **Last seen:** 2026-08-25
- **Occurrences:** 1
- **Affects:** `env-var-auditor`, and the standing interpretation in META-002 / DECISION-007
- **What happened:** `env-var-auditor` FAILed pre-flight on "the testflight profile has no `EXPO_PUBLIC_*` env block". META-002 and DECISION-007 (recorded 2026-07-27) had classified exactly that FAIL as a false positive on the theory that the absence was a deliberate reliance on Expo CLI dotenv inlining. **Git history says otherwise.** The block existed and was deliberate; it was lost by accident:
  - `bc137882` (2026-05-01, "build: add testflight env block to eas.json") — added `build.testflight.env` with 5 vars: `EXPO_PUBLIC_API_URL`, `EXPO_PUBLIC_TARGET_ENV`, `EXPO_PUBLIC_CLOUDINARY_CLOUD_NAME`, `EXPO_PUBLIC_STRIPE_PUBLISHABLE_KEY`, `EXPO_PUBLIC_PHONE_COUNTRY_CODE`.
  - `d94e42df` (2026-05-15, `Reapply "Merge branch 'master'..."`) — after the revert/reapply cycle, `build.testflight.env` contained only `SENTRY_ALLOW_FAILURE` and `SENTRY_DISABLE_AUTO_UPLOAD`. All 5 `EXPO_PUBLIC_*` vars were gone. Nothing in the commit message mentions env vars.
  - `a55116fb` (2026-08-05, "fix(sentry): re-enable source-map upload for testflight builds") — removed the two Sentry keys, and with them the entire `env` block. `testflight` has had NO `env` key since.
  - Verified at build commit `47ec056e`: `build.testflight` = `{autoIncrement, node, ios.image, android.buildType}` — no `env`.
- **Ground truth:** Both readings are partly right and the distinction matters. Testflight builds DO work today, because `.env` is git-tracked (DECISION-002; confirmed present in `git ls-tree 47ec056e`) and `.easignore` does not exclude it, so Expo CLI inlines `EXPO_PUBLIC_*` from the uploaded `.env` (META-002 mechanism — still correct). But the repo is **one `.easignore` line or one "let's gitignore `.env`" instinct away from silently shipping a testflight build with undefined config** — which is precisely the April 2026 incident that broke App Store submissions for weeks. The mechanism is real; the redundancy that was meant to back it up was deleted by accident and nobody noticed for 3 months.
- **Required hardening:** When an auditor finds a config block absent, it must not choose between "deliberate" and "broken" from the current file alone. Run `git log -p --follow -- <config file>` (or `git log -S'<key name>' -- <file>`) to find whether the block ever existed and how it left. An absence introduced by a *revert, merge-reapply, or unrelated-scope commit* is accidental loss and must be reported as such — LOSS, not DESIGN. Report the removing commit SHA and date in the audit output.
- **Why this is a meta-lesson:** META-002 through META-005 are all "a static read was mistaken for a runtime outcome." This is the inverse failure of the same family: a runtime outcome (build works) was mistaken for evidence that the static config was *intended*. "It works" does not establish "this is how it was designed." A prior post-mortem entry canonized an accident as a decision; the only thing that could have caught that was reading the file's history instead of its contents.
- **Restoration plan (not yet applied at build time):** `/Users/ginalevy/Sites/KindraApp/docs/plans/2026-08-25-restore-testflight-env-block.md`. Restoring the 5 vars is additive and safe: `eas.json` `env` is EAS's own injection, and Expo's dotenv loading does not override an already-set var, so the two paths coexist (META-002 point 4). Note `eas.json` is an ASK-FIRST file — the restoration needs owner approval, not an auto-fix.
- **Supersedes:** DECISION-007's claim that the testflight profile "deliberately" omits these vars. The dotenv path is real and load-bearing; the *omission* was not a decision. See DECISION-012.
- **RESOLVED 2026-08-27 — verified at build commit 8f188d09 on 2026-09-18:** the block was restored by `1f25cafb` ("fix(eas): restore testflight env block lost in 2026-05-15 merge reapply (#409)", 2026-08-27). `build.testflight.env` again holds all 5 vars: `EXPO_PUBLIC_API_URL`, `EXPO_PUBLIC_TARGET_ENV`, `EXPO_PUBLIC_CLOUDINARY_CLOUD_NAME`, `EXPO_PUBLIC_STRIPE_PUBLISHABLE_KEY`, `EXPO_PUBLIC_PHONE_COUNTRY_CODE`, and their values are byte-identical to the git-tracked `.env` (no drift between the two sources). The `env-var-auditor` fragility FAIL this entry authorized is therefore **no longer applicable at HEAD** — do not re-raise it without re-reading `eas.json`. The restoration plan doc is now closed out. The meta-lesson (read the file's history before calling an absence deliberate) stands unchanged. See META-010 for how this resolution went unnoticed for three weeks.

### META-007 — `eas.json` `build.testflight` declares no `environment`, so EAS resolves dashboard secrets from the default environment

- **First seen:** 2026-09-16 (builds 06dbe7c7 iOS 178 + c95ed54c Android 20, testflight, commit f30c7d5e — both SUCCEEDED; flagged pre-flight by two independent auditors)
- **Last seen:** 2026-09-16
- **Occurrences:** 1
- **Phase:** Pre-flight (env-var / sentry config audit) — would surface at Run Fastlane / Run Gradle
- **Platform:** both
- **Log signature:** N/A at audit time. If it ever bites, the runtime signature is the FASTLANE-001 / GRADLE-001 one: `Auth token is required for this request` during the Sentry source-map upload step.
- **Root cause:** `build.production` in `eas.json` sets `"environment": "production"`; `build.testflight` sets no `environment` key at all. Without it, EAS resolves dashboard environment variables from the project's default environment rather than a named one. Today the build works only because `SENTRY_AUTH_TOKEN` happens to exist as a Secret in ALL THREE environments (development / preview / production) on the `kinliadev` project (DECISION-010). That redundancy — not the config — is what is holding this up.
- **Fix:** Owner decision, ASK FIRST (`eas.json` is ASK-FIRST infra per CLAUDE.md). Proposed: add `"environment": "preview"` (or whichever named environment the testflight profile should own) to `build.testflight` in `eas.json`, so secret resolution is explicit rather than incidental. Do NOT auto-edit.
- **Pre-flight catchable?** Yes — and it WAS caught here, by two auditors independently. Keep the check: for every build profile in `eas.json`, assert an explicit `environment` key; report its absence as a FRAGILITY finding (not a build blocker), worded as "resolution falls back to the default environment" rather than "vars are missing".
- **Notes:** Distinct from META-006 (the testflight `env` **block** of `EXPO_PUBLIC_*` vars lost in a revert at `a55116fb`) and from META-001 (the April 2026 incident where the token existed on the wrong EAS *project*). This one is about the wrong *environment within the right project*. All three are the same family: "it resolved to something, therefore it resolved to the right thing" is never sound for EAS secrets. Failure mode if it regresses is silent until the source-map upload step, i.e. a full build credit burned before anyone learns.

### META-008 — `env-var-auditor`'s hard-coded scan paths miss `contexts/`, where a required var is actually read

- **First seen:** 2026-09-18 (builds c4c09357 iOS 179 + b3b5d2e6 Android vc21, testflight, commit 8f188d09 — both SUCCEEDED; caught pre-flight by the auditor widening its own scan)
- **Last seen:** 2026-09-18
- **Occurrences:** 1
- **Affects:** `env-var-auditor` (`~/.claude/agents/env-var-auditor.md`, Step 1)
- **Phase:** Pre-flight (env var audit)
- **Platform:** both
- **Log signature:** `grep -rEho 'EXPO_PUBLIC_[A-Z0-9_]+' --include='*.ts' ... src/ App.tsx index.ts app.config.ts` — the tell is a REQUIRED list that is shorter than reality, with no error of any kind.
- **Root cause:** Step 1 enumerates directories by hand (`src/ App.tsx index.ts app.config.ts`). The Kindra repo's live React Context layer lives in `contexts/` (the shipping architecture — see CLAUDE.md), not under `src/`, and `contexts/authContext.tsx:31` reads `EXPO_PUBLIC_PHONE_COUNTRY_CODE`. `welcome.tsx` at repo root is likewise outside the list. A hand-maintained path list silently under-reports as the repo's layout changes; the auditor then compares an incomplete REQUIRED list against the PROVIDED list and reports "no gaps" — a false PASS that is invisible because nothing errors.
- **Fix:** Scan the whole repo and exclude noise instead of enumerating includes. Applied 2026-09-18 to `~/.claude/agents/env-var-auditor.md` Step 1:
  `grep -rEho 'EXPO_PUBLIC_[A-Z0-9_]+' --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=ios --exclude-dir=android --exclude-dir=__tests__ --exclude-dir=.expo . | sort -u`
  On this run the widened scan (done manually by the auditor before the spec was fixed) found 5 required vars, all 5 provided — verdict unchanged, but only by luck.
- **Pre-flight catchable?** N/A — this IS the pre-flight tool. The auditor should additionally print the exact scan command and the resolved file list count, so a reviewer can see what was and was not searched.
- **Notes:** Same family as META-004 — an auditor rule hard-coded to an incidental fact (there, a log string; here, a directory layout) that rots silently and fails toward a green result. Prefer exclude-lists over include-lists for any repo-wide scan. Consequence if it had bitten: a genuinely missing `EXPO_PUBLIC_*` var reaches the bundle as `undefined`, which is the April 2026 `cloud_name = undefined` crash class (DECISION-002).

### META-009 — Which auditors must be re-run after a mid-run merge into the build branch

- **First seen:** 2026-09-18 (builds c4c09357 iOS 179 + b3b5d2e6 Android vc21, testflight; audits started at `eedf1a5b`, PRs #425/#426 merged mid-run, build shipped from `8f188d09`)
- **Last seen:** 2026-09-18
- **Occurrences:** 1
- **Affects:** `build-app` skill orchestration; all four auditors
- **Phase:** Pre-flight
- **Platform:** both
- **Log signature:** N/A — the tell is an audit report whose `HEAD:` line does not equal the commit EAS uploads. On this run `build-app-env-audit.md` and `build-app-sentry-audit.md` still read `HEAD: eedf1a5b` while the build went out at `8f188d09`.
- **Root cause:** Auditors are a snapshot of one commit. If anything merges into the build branch after they run, every PASS is about a tree that is no longer the one being uploaded. Re-running all four unconditionally is slow (the prereq auditor alone builds two ~9.6 MB bundles); re-running none is how a stale PASS ships.
- **Fix (decision rule — re-run by what the merge actually touched):** diff the new commits against the audited commit (`git diff --name-only <audited> <new>`) and re-run:
  - **`commit-state-auditor` — ALWAYS.** Its entire subject is HEAD, branch sync, open PRs and tree cleanliness. Any new commit invalidates it unconditionally.
  - **`build-prereq-auditor` — ALWAYS.** It validates the bundle, expo-doctor, patches, lockfile freshness and native version stamps against the actual tree. Any source change can break the bundle; any `package.json`/`yarn.lock` change also requires a re-install first (SKILL-007).
  - **`env-var-auditor` — only if the diff touches** `eas.json`, `.env`, `.easignore`, `app.config.ts`, or adds/removes any `EXPO_PUBLIC_` reference (`git diff <audited> <new> -S'EXPO_PUBLIC_'`).
  - **`sentry-config-auditor` — only if the diff touches** `eas.json`, `app.config.ts`, `ios/sentry.properties`, `android/sentry.properties`, `App.tsx`, `.env.sentry-build-plugin`, or `@sentry/*` in `package.json`.
  On this run PRs #425/#426 changed only test and docs files, so prereq + commit-state were re-run and env/Sentry were correctly carried forward — but the carried-forward reports still say `eedf1a5b`, which is the part to fix.
- **Pre-flight catchable?** Yes — cheap and mandatory: immediately before invoking `eas-cli build`, assert that every audit report's recorded HEAD equals `git rev-parse HEAD`. Any mismatch that was not explicitly justified by this entry's diff rule is a HARD STOP. When an audit is deliberately carried forward, the orchestrator must stamp the report with "carried forward from `<sha>` to `<sha>`; diff touched none of <file list>" so the gap is documented rather than invisible.
- **Notes:** Related: SKILL-006 (right commit, wrong checkout) and SKILL-007 (right tree, stale `node_modules`). All three are the same question — "is the thing I validated the thing EAS will build?" — and all three are answered by making the auditor state the absolute path AND the commit it measured.

### META-010 — A post-mortem build record repeated a prior entry's config claim without re-reading the file (stale for 3 weeks)

- **First seen:** 2026-09-18 (discovered while writing the post-mortem for builds c4c09357 / b3b5d2e6, commit 8f188d09)
- **Last seen:** 2026-09-18
- **Occurrences:** 1
- **Affects:** `build-postmortem-updater` (this agent), and by inheritance `~/Sites/CLAUDE.md`
- **Phase:** Post-mortem
- **Platform:** N/A
- **Log signature:** N/A — the tell is a pattern-file claim about current config state that no command in the report ever verified.
- **What happened:** DECISION-014 (recorded 2026-09-16) listed as fragile state #3 that `build.testflight` "still has no `env` block ... still unrestored", carried forward from DECISION-012 / META-006. It was false: `1f25cafb` (PR #409) restored the block on 2026-08-27, three weeks and at least one shipped build earlier. The same stale claim was also sitting in `~/Sites/CLAUDE.md`. Verification is one command: `git show <build-commit>:eas.json`. Nobody ran it, because the claim was inherited rather than measured.
- **Required hardening:** When a post-mortem build record restates a configuration fact from an earlier entry, it must **re-verify that fact against the build commit and paste the command**, exactly like a plan's `## Verified References` (`~/Sites/CLAUDE.md` → Plan Verification Rule 1). Specifically: any bullet of the form "still X / still unresolved / still open" requires a fresh check at the build commit, and the entry should cite it. If it cannot be checked, write "not re-verified this run" rather than asserting continuity.
- **Why this is a meta-lesson:** META-006's own lesson was "'it works' does not establish 'it was designed that way' — read the history." This is the next failure in that chain: *a pattern file's own prior entry is not evidence either.* The pattern library exists to stop repeated mistakes; an unverified claim inside it has the same authority as a verified one to the next reader, so it propagates faster than it would have in chat. Stale entries in this file are more dangerous than missing ones.
- **Notes:** Corrections applied 2026-09-18 to META-006 (RESOLVED note), DECISION-014 (inline CORRECTION), and the corresponding `~/Sites/CLAUDE.md` subsection. Nothing was rewritten — corrections are appended and dated so the original error stays visible.

## Phase: Skill Orchestrator Bugs (build-app skill)

These entries are NOT EAS-build failures — they are bugs in the `build-app` skill's monitoring/automation scripts that wasted agent time or produced misleading status during otherwise-successful builds. The skill author should fix these in `~/.claude/skills/build-app/`.

### SKILL-001 — `local status=$(...)` collides with zsh read-only `$status`

- **First seen:** 2026-05-02 (build d7098699-4eae-4eac-bc41-3cb761ac0239)
- **Last seen:** 2026-05-02
- **Occurrences:** 1
- **Phase:** Skill orchestration (monitor loop)
- **Platform:** N/A (skill bug, not a build bug)
- **Log signature:** `read-only variable: status`
- **Root cause:** zsh treats `$status` as a read-only special variable (analog of bash `$?`). The build-app monitor's polling loop used `local status=$(npx eas-cli build:view ...)`, which crashed on first iteration under zsh.
- **Fix:** In any `~/.claude/skills/build-app/` shell snippets, rename the variable — e.g., `local build_status=$(...)`. Avoid `$status`, `$path`, `$argv`, and other zsh-reserved names anywhere in skill scripts.
- **Pre-flight catchable?** No — would only be caught by running the skill's monitor under zsh before shipping. Recommend: add a `shellcheck`/zsh smoke test for any new monitor snippet.
- **Notes:** The user runs zsh on Darwin. Skill scripts that assume bash semantics will silently break.

### SKILL-002 — `eas-cli build:view --non-interactive` is not a valid flag

- **First seen:** 2026-05-02 (build d7098699-4eae-4eac-bc41-3cb761ac0239)
- **Last seen:** 2026-09-16 (builds 06dbe7c7 iOS 178 / c95ed54c Android 20, commit f30c7d5e — recurred, non-blocking)
- **Occurrences:** 2
- **Phase:** Skill orchestration (monitor loop)
- **Platform:** N/A
- **Log signature:** `error: unknown option '--non-interactive'` (or silent non-zero exit, depending on eas-cli version)
- **Root cause:** The build-app skill's monitor example uses `npx eas-cli build:view <id> --non-interactive`, but `build:view` only accepts `--json` (and other view-specific flags). The flag was dropped/never accepted by `build:view` in current eas-cli; the command exits non-zero before producing output, so the monitor poll fails every iteration.
- **Fix:** In the skill's monitor snippet, use `npx eas-cli build:view <id> --json` (no `--non-interactive`). Reserve `--non-interactive` for `build` and `submit` subcommands where it IS valid.
- **Pre-flight catchable?** Yes — a one-time smoke test (`npx eas-cli build:view <known-id> --non-interactive`) when authoring the skill would catch this. Should be added to skill CI.
- **Notes:** Sister bug to SKILL-001 — both surfaced in the same monitor loop on the same build. Together they prevented the skill from observing build progress; the user had to refresh the EAS dashboard manually. **2026-09-16 recurrence:** still true on the current eas-cli — `npx eas-cli build:view <id> --non-interactive` exits with `Nonexistent flag: --non-interactive`, while `build:list --non-interactive` DOES accept it. The asymmetry is the trap: do not infer flag support on one subcommand from another. The skill snippet has not been fixed since 2026-05-02.

### SKILL-003 — `eas-cli submit:view` does not exist

- **First seen:** 2026-05-02 (build d7098699-4eae-4eac-bc41-3cb761ac0239)
- **Last seen:** 2026-05-02
- **Occurrences:** 1
- **Phase:** Skill orchestration (post-build submission monitor)
- **Platform:** N/A
- **Log signature:** `error: unknown command 'submit:view'`
- **Root cause:** The build-app skill instructions reference `npx eas-cli submit:view <id>` for checking ASC submission status. That subcommand does not exist in the current eas-cli version. Submission status must be observed via the Expo web dashboard or via the submission URL printed at submit time.
- **Fix:** Remove `submit:view` references from the skill. Replace with: "After auto-submit, watch the submission URL printed by the build (e.g., `https://expo.dev/accounts/<acct>/projects/<proj>/submissions/<id>`) or check App Store Connect directly. There is no CLI subcommand for submission status as of eas-cli 16.x."
- **Pre-flight catchable?** Yes — same smoke test as SKILL-002 (verify referenced subcommands exist on the installed eas-cli before shipping the skill).
- **Notes:** Together with SKILL-002, both indicate the skill instructions were authored against an older or imagined eas-cli surface. Recommend adding `npx eas-cli --help` and `npx eas-cli build --help` / `npx eas-cli submit --help` output to the skill author's reference, and re-validating against eas-cli major releases.

### SKILL-005 — Auditor instruction not scoped to the build platform

- **First seen:** 2026-05-02 (Android production rebuild 8e5147be-a95c-4e27-9d7e-da90383ce973)
- **Last seen:** 2026-05-02
- **Occurrences:** 1
- **Phase:** Skill orchestration (audit instruction wording)
- **Platform:** N/A (orchestrator bug)
- **Log signature:** N/A (auditor returned FAIL on a check that should not have applied)
- **Root cause:** The orchestrator instructed `build-prereq-auditor` to FAIL if `app.config.ts` `version` disagreed with EITHER `android/app/build.gradle` OR `ios/<App>/Info.plist`. For an Android-only build, the iOS plist drift is irrelevant (and vice versa). The auditor correctly returned FAIL per the instruction and the user had to override. The bug is in the orchestrator prompt, not the auditor.
- **Fix:** When asking an auditor to check native version drift, scope the check to the platform being built. Pseudo-instruction: "If `--platform android`, only check `android/app/build.gradle` versionName. If `--platform ios`, only check `ios/<App>/Info.plist` CFBundleShortVersionString. If `--platform all`, check both." This scoping must be in the orchestrator's prompt to the auditor — not left to auditor judgment.
- **Pre-flight catchable?** N/A — orchestrator-side authoring bug. Catch it by writing the auditor instruction with explicit per-platform scoping from the start.
- **Notes:** This is the implementation-side counterpart to VERSION-001's "Critical scoping rule". Both must say the same thing or VERSION-001's auditor will produce false FAILs on single-platform builds. Sister of SKILL-001..SKILL-004 (orchestrator/skill bugs surfaced during the 2026-05-02 build day).

### SKILL-006 — Pre-flight fix applied in the wrong checkout (multiple KindraApp working copies exist)

- **First seen:** 2026-08-25 (builds 91651c8e iOS 176 + cf885a62 Android vc19, testflight, commit 47ec056e — recovered pre-flight, both SUCCEEDED)
- **Last seen:** 2026-08-25
- **Occurrences:** 1
- **Phase:** Skill orchestration (pre-flight remediation)
- **Platform:** N/A (agent/orchestrator bug)
- **Log signature:** N/A — the tell is a remediation command that reports success while the auditor keeps FAILing on re-run, or `git status` showing changes in a directory that is not the one being built.
- **Root cause:** There is more than one KindraApp working copy on this machine: `/Users/ginalevy/Sites/KindraApp` (the day-to-day checkout, on feature branches) and `/Users/ginalevy/Sites/kindraapp-tf-build` (the dedicated testflight build worktree, on `testflight`). The DOCTOR-006 version-drift fix was run in `/Users/ginalevy/Sites/KindraApp`, which is NOT the directory EAS uploads from. `npx expo install` reported success, the wrong `node_modules`/`package.json`/`yarn.lock` were updated, and the build worktree was still drifted. This burns no credits only because it was caught before the build; had it not been, the build would have shipped the un-fixed tree.
- **Fix:** Every pre-flight remediation step must (a) `cd` to an ABSOLUTE path — the build worktree — as its first action, (b) print `pwd` and `git rev-parse --show-toplevel HEAD --abbrev-ref HEAD` and assert they match the build target commit/branch, and (c) re-run the failing auditor check **in that same directory** to confirm the fix took. The build-app skill should carry the build worktree path as an explicit parameter and pass it into every auditor and every fix step, rather than relying on the agent's cwd. Note that agent bash calls reset cwd between invocations, which makes cwd-drift the default failure mode, not the exception.
- **Pre-flight catchable?** Yes — cheaply. Any auditor's report should include the absolute path it inspected; the orchestrator should refuse a PASS whose path does not match the build directory.
- **Notes:** This also invalidates the note in the user's MEMORY.md that "only ONE checkout exists now" — a second, build-dedicated worktree exists as of the Aug 2026 testflight builds. Related: DOCTOR-006, DOCTOR-007 (both fixed in the worktree after the misfire).

### SKILL-004 — iOS production build time estimate is too narrow

- **First seen:** 2026-05-02 (build d7098699-4eae-4eac-bc41-3cb761ac0239)
- **Last seen:** 2026-05-02
- **Occurrences:** 1
- **Phase:** Skill orchestration (user-facing time estimate)
- **Platform:** ios
- **Log signature:** N/A (documentation/UX bug)
- **Root cause:** The build-app skill instructions tell the user that an iOS production build takes "25–35 minutes". Today's build finished in ~11 minutes (2026-05-02 10:36:46 PT submitted, 10:47:30 PT finished). The narrow upper-bound-only range causes the user to over-allocate time and may make the monitor appear stuck if it polls less often than the actual build duration.
- **Fix:** Update the skill's time estimate to "10–35 minutes" for iOS production (and consider similar widening for Android). Note that the dataset is small (3 known production builds, 2 of which were faster failures), so re-tighten the range as more successful production data accrues.
- **Pre-flight catchable?** N/A — this is a calibration issue, not a verifiable precondition. Update from observed data.
- **Notes:** Faster-than-documented is a benign surprise compared to the inverse, but the user explicitly called it out for skill accuracy.

### SKILL-007 — `/build-app` never runs an install; `build-prereq-auditor` only READS a possibly-stale `node_modules`

- **First seen:** 2026-09-16 (builds 06dbe7c7 iOS 178 + c95ed54c Android 20, testflight, commit f30c7d5e — caught and remediated pre-flight, both SUCCEEDED)
- **Last seen:** 2026-09-16
- **Occurrences:** 1
- **Phase:** Skill orchestration (pre-flight sequencing)
- **Platform:** N/A (skill gap)
- **Log signature:** N/A — there is no error. The tell is an auditor PASS on a checkout whose `node_modules` predates its `yarn.lock`/`package.json`.
- **Root cause:** The owner asked directly, "I thought `/build-app` now automatically does the yarn install, right?" — it does not, and the skill never claimed to in a way anyone had checked. `build-prereq-auditor` only READS `node_modules` (e.g. comparing patch filenames against installed versions for PODS-001, or nested native-module copies for DOCTOR-007); nothing in the skill installs. On this run `testflight` had just merged PR #420, which changed `package.json` and `yarn.lock`; the build checkout had pulled but not reinstalled, so `node_modules` was stale. The orchestrator ran `yarn install --frozen-lockfile` manually before the auditors. Had it not, every `node_modules`-reading auditor would have measured the PREVIOUS dependency tree and could have returned PASS against the wrong thing — same class as SKILL-006 (fix applied in the wrong checkout): an auditor confidently validating something other than what EAS will build.
- **Fix (skill change, not yet made):** Either (A) `/build-app` runs `yarn install --frozen-lockfile` in the build checkout (absolute path, per SKILL-006) as a mandatory step before any auditor runs, or (B) `build-prereq-auditor` FAILS when the installed tree is older than its manifests. (B)'s check is known feasible — on this run, when explicitly asked, the auditor compared `node_modules/.yarn-integrity` mtime against `yarn.lock` and `package.json` and verified all 1891 lockfile entries resolve. It is simply not mandatory today. Recommend doing both: install first, then assert freshness.
- **Pre-flight catchable?** Yes, cheaply — `node_modules/.yarn-integrity` mtime vs `yarn.lock`/`package.json` mtime, run in the build checkout's absolute path. Any auditor that reads `node_modules` should refuse to report PASS without this assertion.
- **Notes:** Highest-risk trigger is exactly this run's shape: a freshly merged PR that touches dependencies, followed by a pull-without-install in the dedicated build worktree (`/Users/ginalevy/Sites/kindraapp-tf-build`). Related: SKILL-006, DOCTOR-006, DOCTOR-007, PODS-001.

## Successful Builds — Notable Decisions

### DECISION-001 — newArchEnabled is false on purpose

- **Recorded:** 2026-04-27 (commit c1e3482)
- **Decision:** `app.config.ts` sets `newArchEnabled: false`.
- **Why:** A specific iOS 26 crash. Disabling the New Architecture fixed it.
- **Implication:** expo-doctor flags many packages as "untested on the New Architecture" — those warnings can be excluded via the `package.json` `expo.doctor.reactNativeDirectoryCheck.exclude` list. Do NOT re-enable the New Architecture without testing on iOS 26 again.

### DECISION-002 — .env should NOT be in .gitignore

- **Recorded:** 2026-04-28
- **Decision:** `.env` is committed to git. (`.gitignore` does NOT list `.env`.)
- **Why:** This is a mobile app, not a web server. `EXPO_PUBLIC_*` vars are baked into the client bundle and are public by definition. Gitignoring `.env` provides zero security benefit and broke EAS builds for two weeks in April 2026 because EAS started using the `eas.json` env block as the only source of vars.
- **Implication:** Treat any future suggestion to "best-practice" `.env` into `.gitignore` as the wrong instinct for this project.

### DECISION-004 — Sentry source map upload is mandatory for every production / testflight build

- **Recorded:** 2026-04-28
- **Decision:** `SENTRY_DISABLE_AUTO_UPLOAD` must be `false` (or absent) in `.env.sentry-build-plugin`. The Sentry auth token must be present as an EAS environment variable on the target environment AND must return HTTP 200 from the Sentry API at audit time.
- **Why:** A build without working source maps ships minified stack traces to Sentry, making production crashes much harder to diagnose. The user has stated this is a non-negotiable requirement.
- **Implication:** `sentry-config-auditor` enforces this as a CRITICAL FAIL. Do NOT propose disabling Sentry upload as a fix when a build fails — instead, fix the token or the org slug.

### DECISION-005 — EAS overage charges are real and must be acknowledged

- **Recorded:** 2026-04-28
- **Decision:** At ≥100% EAS credit usage, the build still submits but incurs an overage charge. The credit gate requires the user to type the literal phrase `confirm overage` to proceed.
- **Why:** Twelve consecutive failed builds in April 2026 pushed credits past 100% and resulted in unexpected charges. The skill must surface this clearly before any build at 100%+.
- **Implication:** Never auto-proceed past the credit gate. The phrase requirement is intentionally annoying — the friction is the feature.

### DECISION-003 — Source of truth for production env vars is `eas.json` (not `.env`)

- **Recorded:** 2026-04-28
- **Decision:** Every `EXPO_PUBLIC_*` var the app needs at runtime in production must be in `eas.json` `build.production.env` (or as an EAS environment variable on the production environment).
- **Why:** EAS production builds run on a remote server. They do not read `.env` from the project archive. Adding a `EXPO_PUBLIC_*` var to `.env` only is invisible to production builds.
- **Implication:** When adding a new `EXPO_PUBLIC_*` var: update `.env` for local dev, AND update `eas.json` for production builds.

### DECISION-006 — `.easignore` excludes `credentials.json` and `credentials/` from EAS upload

- **Recorded:** 2026-05-02 (Android production rebuild 8e5147be-a95c-4e27-9d7e-da90383ce973)
- **Decision:** A `.easignore` file at repo root excludes `credentials.json` and `credentials/` (containing a vestigial Android dev keystore from a prior bare-workflow setup). Plan A (`.easignore`) was chosen over Plan B (delete the files) for reversibility and intent-documentation.
- **Why:** Without `.easignore`, EAS uploads the local `credentials.json` and uses the local dev keystore for signing. That overrides the remote production keystore and produces an AAB whose signature Play Console rejects. The files cannot simply be `.gitignore`d — `.gitignore` controls git, not EAS upload. EAS uses `.easignore` (or falls back to `.gitignore`) to decide what to bundle in the build archive.
- **Implication:** Do NOT delete `.easignore`. Do NOT remove the `credentials.json` / `credentials/` lines from it. If a future session "cleans up" the file thinking it's redundant with `.gitignore`, the next Android production build will sign with the wrong keystore. Note (as of 2026-05-02): `.easignore` was UNCOMMITTED at build time — recommend committing it with a clear message ("chore(build): exclude vestigial credentials.json from EAS upload — see DECISION-006") so the policy is durable across machines and developers.

### DECISION-007 — testflight profile deliberately relies on Expo CLI dotenv inlining of `EXPO_PUBLIC_*` from the tracked `.env`

- **Recorded:** 2026-07-27 (builds 9f54e9fb iOS + c1600acf Android, both SUCCEEDED, commit e9222059, testflight profile, v1.80.11)
- **Decision:** The `testflight` build profile does NOT enumerate every `EXPO_PUBLIC_*` var in its `eas.json` `env` block. Instead it relies on Expo SDK 53's CLI inlining `EXPO_PUBLIC_*` from the git-tracked `.env` (which `.easignore` does not exclude, so it is uploaded to the EAS worker). Production overrides via its own full `env` block (DECISION-003).
- **Why:** For dev/staging, the single source of `EXPO_PUBLIC_*` values is the committed `.env`; duplicating them into the testflight `eas.json` block is unnecessary because Expo's dotenv loading already inlines them at bundle time. This path is intentional, not an oversight.
- **Implication:** Do NOT "fix" the testflight profile by declaring these vars missing or by deleting `.env` from the upload. See META-002 for the auditor precondition check. Optional hardening (owner's call, not required): mirror the ~3 staging `EXPO_PUBLIC_*` values into the testflight `env` block for belt-and-suspenders — but the build works without it, so this is not a blocker.

### DECISION-008 — testflight deliberately sets `SENTRY_DISABLE_AUTO_UPLOAD=true` (refines DECISION-004's scope)

- **Recorded:** 2026-07-27 (builds 9f54e9fb iOS + c1600acf Android, both SUCCEEDED, commit e9222059, testflight profile)
- **Decision:** The `testflight` profile sets `SENTRY_DISABLE_AUTO_UPLOAD=true` — a deliberate 2026-02-11 decision, kept when production got the real token in commit 74230448 (2026-04-28). testflight staging crashes are un-symbolicated by design. This is NOT a build blocker for testflight builds.
- **Why:** Staging/testflight crash symbolication is not worth a source-map upload per build; only production ships symbolicated maps. DECISION-004 ("source map upload mandatory for every production / testflight build") is hereby **refined**: the mandate applies to **production** builds. For **testflight**, `SENTRY_DISABLE_AUTO_UPLOAD=true` is the intended state and an auditor must NOT FAIL a testflight build for it.
- **Implication:** `sentry-config-auditor` must scope its "source-map upload mandatory / `SENTRY_DISABLE_AUTO_UPLOAD` must be false" rule to the **production** profile only. On testflight, `SENTRY_DISABLE_AUTO_UPLOAD=true` should PASS (and ideally be reported as "expected for staging"). Do NOT propose enabling upload on testflight as a "fix."
- **Open owner follow-ups (not build blockers):** (1) Confirm rotation of the plaintext Sentry token leaked in git history at commit 74230448. (2) Optional: mirror the 3 staging `EXPO_PUBLIC_*` values into the testflight `env` block (see DECISION-007).

### DECISION-009 — `.easignore` REPLACES `.gitignore` for the EAS upload archive (gitignored secrets still upload)

- **Recorded:** 2026-08-05 (build a0a56da9-da5b-4f4d-adcc-4a924c168baf, iOS testflight, build 172, v1.80.11, commit 8376d9c3 — SUCCEEDED)
- **Decision / ground truth:** When a `.easignore` file exists at repo root, EAS uses it **instead of** `.gitignore` to decide what goes into the upload archive — it is a replacement, not an addition. This repo HAS a `.easignore` (see DECISION-006), so **`.gitignore` has zero influence on what EAS uploads.** A file that is gitignored — including a secret-bearing one such as `.env.sentry-build-plugin` — is still uploaded to the EAS builder unless `.easignore` also excludes it.
- **Why it matters:** The instinct "it's gitignored, so it won't leave my machine" is FALSE for EAS builds in this repo. Any secret file sitting on disk at build time ships to a remote build worker.
- **Implication / how to apply:**
  - For secret-bearing files, **absent-from-disk is the safe state at build time.** Do not rely on `.gitignore`; do not rely on `.easignore` alone if the file's contents are sensitive — prefer that the file simply not exist when the build runs (EAS environment variables are the correct home for secrets — see FASTLANE-001 / META-001).
  - If a file must exist locally but must never upload, it needs an explicit entry in `.easignore` — and that entry must be verified, since adding it to `.gitignore` does nothing.
  - Corollary to DECISION-006: because `.easignore` replaces `.gitignore`, anything you were relying on `.gitignore` to exclude from the archive (build artifacts, screenshots, caches) is being uploaded right now. See "Future cleanup" below for the resulting upload-size bloat.

### DECISION-010 — SENTRY_AUTH_TOKEN rotated 2026-08-05 (org-scoped token, both EAS projects)

- **Recorded:** 2026-08-05 (build a0a56da9-da5b-4f4d-adcc-4a924c168baf, iOS testflight, build 172, commit 8376d9c3)
- **Decision:** The Sentry auth token was rotated. The replacement is an **organization token with scope `org:ci`** (not a personal token). It is stored as an EAS environment variable named `SENTRY_AUTH_TOKEN` on BOTH EAS projects: `kinliadev` (environments: development, preview, production) and `kinlia` (environment: production). Old tokens were removed from git-tracked files via **PR #386**.
- **Why:** Closes the open follow-up recorded in DECISION-008 — a plaintext Sentry token had been committed at 74230448 (2026-04-28) and was still live. Org-scoped `org:ci` is the least-privilege scope that still permits source-map/artifact upload, and covering both EAS projects prevents the token-on-the-wrong-project failure that burned two credits in April (FASTLANE-001 / GRADLE-001 / META-001).
- **Implication:**
  - **No token values live in this file or in any repo file.** Read them only via `EAS_BUILD_PROFILE=<profile> npx eas-cli env:list --environment <env>` with the profile forced, per META-001.
  - Because the token changed, any auditor result cached from before 2026-08-05 is stale — re-run the live Sentry API ping (HTTP 200) rather than trusting a prior "Present/valid" verdict.
  - **Open owner action (still outstanding as of this build):** revoke the OLD tokens in the Sentry dashboard. Removal from git-tracked files does NOT revoke them — they remain valid in git history until explicitly revoked. This is the last step of the rotation and is not done.

### DECISION-011 — Build record: a0a56da9 (iOS testflight 172) succeeded with all of the above in place

- **Recorded:** 2026-08-05
- **Build:** `a0a56da9-da5b-4f4d-adcc-4a924c168baf` — iOS, `testflight` profile, build number 172, version 1.80.11, commit 8376d9c3, EAS project `kinliadev`. Built and **auto-submitted to TestFlight successfully** (submission finished).
- **Why recorded:** This build is the known-good reference point for the auditor-policy corrections above. It succeeded WITH: the 8-package expo-doctor Directory advisory present (DOCTOR-005), `SENTRY_DISABLE_AUTO_UPLOAD=true` on testflight (DECISION-008) while Sentry events were nonetheless symbolicated (META-005), the freshly rotated org token (DECISION-010), and a bundle check whose expected log literal never appeared (META-004).
- **Implication:** If a future testflight build FAILS, diff its config against this one before theorizing. Any auditor that would have FAILED this exact configuration is mis-specified — that is a bug in the auditor, not in the repo.

### DECISION-012 — Build record: 91651c8e (iOS testflight 176) + cf885a62 (Android vc19) succeeded from a dedicated build worktree

- **Recorded:** 2026-08-25
- **Builds:** `91651c8e-890a-4b7d-97a7-5e14f1609e48` — iOS, `testflight` profile, build number 176, auto-submitted to TestFlight (ASC `6748651413`). `cf885a62-ac80-41c1-8370-872c7b4caed3` — Android, `testflight` profile, versionCode 19, APK artifact (`eas.json` `build.testflight.android.buildType: "apk"` — internal-distribution APK, not a Play Store AAB; Android has no auto-submit).
- **Built from:** `/Users/ginalevy/Sites/kindraapp-tf-build`, branch `testflight`, commit `47ec056e` (merge of PR #405, `ExpoConstantsDedupe_08_25_26`) — NOT the day-to-day `/Users/ginalevy/Sites/KindraApp` checkout. See SKILL-006.
- **Non-default state these builds succeeded WITH (know this before theorizing about a future failure):**
  1. `build.testflight` in `eas.json` has **no `env` block at all** — all `EXPO_PUBLIC_*` config reached the bundle via Expo CLI dotenv inlining from the git-tracked `.env`. This is load-bearing and accidental, not designed. See META-006.
  2. Pinned to the then-current Expo patch line: `expo@54.0.37`, `expo-constants@18.0.14`, `jest-expo@54.0.18` (DOCTOR-006).
  3. `yarn.lock` deduplicated for `expo-constants` — zero nested copies under `expo-asset`/`expo-linking`/`expo-notifications` at build time (DOCTOR-007).
  4. `.easignore` (which REPLACES `.gitignore`, DECISION-009) excludes `credentials.json`, `credentials/`, the four local build-output dirs, and `.env.sentry-build-plugin` — and deliberately does NOT exclude `.env`.
  5. The 8-package expo-doctor React Native Directory advisory present and correctly treated as ADVISORY (DOCTOR-005 / META-003).
- **Implication:** This is the current known-good testflight reference. Any auditor that would have FAILED this exact configuration is mis-specified — with one exception: `env-var-auditor`'s FAIL on the missing testflight `env` block was **correct as a fragility finding** and should be kept, reworded from "vars are missing" to "the redundant `eas.json` source was lost at `a55116fb`; the build depends solely on `.env` surviving in the upload archive." Restoration is tracked at `/Users/ginalevy/Sites/KindraApp/docs/plans/2026-08-25-restore-testflight-env-block.md` and requires owner approval (`eas.json` is ASK-FIRST).

### DECISION-013 — OPEN EXPOSURE (owner-deferred): an App Store Connect API private key is tracked in git and uploads to the EAS builder

- **Recorded:** 2026-09-16 (builds 06dbe7c7 iOS 178 + c95ed54c Android 20, testflight, commit f30c7d5e)
- **Status:** **NOT RESOLVED.** Owner decision 2026-09-16: explicitly judged not worth blocking the build; remediation DEFERRED to 2026-09-17. Recorded here so it cannot quietly become "the way things are".
- **Finding:** `keys/ApiKey_3TOKLSS7RIR8.p8` — an App Store Connect API private key — is tracked in git (since commit `398acd44`) and has no entry in `.easignore`, so it is uploaded to the remote EAS builder on every single build. `.easignore` correctly excludes `credentials.json`, `credentials/`, and `.env.sentry-build-plugin`, but has no `keys` entry. Its gitignore status is irrelevant: `.easignore` REPLACES `.gitignore` for the upload archive (DECISION-009). This is a concrete instance of DECISION-009's general mechanism, not a new mechanism.
- **Remediation order when it is done (order matters — do not reorder):**
  1. **Revoke and reissue the key in App Store Connect first.** Treat the existing key as compromised; it is in git history and has been shipped to remote builders repeatedly. Every later step is cosmetic until this one is done.
  2. Remove the key file from the working tree.
  3. Add `keys/` to BOTH `.easignore` and `.gitignore`.
  4. Then decide separately whether to purge git history (a rewrite is a bigger call than the first three steps and should not be bundled with them).
- **Implication:** Do NOT record this as fixed in any future post-mortem without evidence of step 1. Do NOT edit `.easignore` to "handle it" on the way past — `.easignore` is ASK-FIRST infra: propose, do not auto-edit. Related: DECISION-006, DECISION-009, DECISION-010 (a prior credential exposure whose revocation step was likewise the one that lagged).

### DECISION-014 — Build record: 06dbe7c7 (iOS testflight 178) + c95ed54c (Android 20) succeeded

- **Recorded:** 2026-09-16
- **Builds:** `06dbe7c7-f31f-4fc6-bc3d-8b089c1a8c29` — iOS, `testflight` profile, build 178, FINISHED, auto-submitted to ASC `6748651413` (submission FINISHED). `c95ed54c-5513-4d98-abe9-ffb77637111e` — Android, `testflight` profile, build 20, FINISHED, APK artifact (no auto-submit — expected, see DECISION-012).
- **Built from:** `/Users/ginalevy/Sites/kindraapp-tf-build`, branch `testflight`, commit `f30c7d5e`, version 1.80.11. All four pre-flight auditors PASSED.
- **Non-default / fragile state these builds succeeded WITH (know this before theorizing about a future failure):**
  1. `node_modules` was stale on arrival (PR #420 had just merged, changing `package.json` + `yarn.lock`); the orchestrator ran `yarn install --frozen-lockfile` MANUALLY before the auditors. The skill does not do this for you — SKILL-007.
  2. `build.testflight` has no `environment` key; dashboard secrets resolved from the default environment and worked only because `SENTRY_AUTH_TOKEN` exists in all three environments on `kinliadev` — META-007.
  3. `build.testflight` still has no `env` block; `EXPO_PUBLIC_*` still reaches the bundle solely via dotenv inlining of the tracked `.env` — META-006 / DECISION-007 / DECISION-012, still unrestored.
     - **CORRECTION 2026-09-18:** point 3 was FALSE when written. `git merge-base --is-ancestor 1f25cafb f30c7d5e` returns true, and `git show f30c7d5e:eas.json` shows `build.testflight.env` with all 5 `EXPO_PUBLIC_*` keys. The block had already been restored on 2026-08-27 by `1f25cafb` (PR #409), three weeks before that build. The claim was copied forward from DECISION-012/META-006 without re-reading the file. See META-010.
  4. `keys/ApiKey_*.p8` uploaded with the archive — DECISION-013, owner-deferred, still open.
  5. Upload archive ~190 MB, with an EAS size warning on every build — see "Future cleanup".
- **Implication:** This is the current known-good testflight reference; supersedes DECISION-012 as the newest one. Any auditor that would have FAILED this exact configuration is mis-specified — except the META-007 `environment` finding, which is a correct FRAGILITY report and should stay.

### DECISION-015 — Jest `__mocks__` are invisible to Metro: `src/__mocks__/@sentry/react-native.js` does not reach the shipped bundle

- **Recorded:** 2026-09-18 (builds c4c09357 iOS 179 + b3b5d2e6 Android vc21, testflight, commit 8f188d09 — both SUCCEEDED)
- **Decision / ground truth:** PR #425 added `src/__mocks__/@sentry/react-native.js` to stop a Jest open-handle hang in the Expo suite. Placing a manual mock for a *real, shipped* native SDK inside `src/` looks alarming — if Metro picked it up, the app would ship with Sentry stubbed out and crash reporting would silently die. It does not. Verified empirically on this build, not reasoned about:
  1. The only references are `jest.expo.config.js:36` (`moduleNameMapper`) and test files under `__tests__/fixes/`. No module in the app import graph imports it.
  2. `metro.config.js` is `getSentryExpoConfig(__dirname)` + `sourceExts.push('cjs')` + the reanimated wrapper — it adds no `roots`, `watchFolders` or `extraNodeModules`. Metro resolves strictly by import graph; `__mocks__` auto-mocking is a **jest-haste-map** behavior, not a Metro one.
  3. **The proof is in the artifact:** `grep -c "src/__mocks__"` = **0** in both `/tmp/ba-ios.js` and `/tmp/ba-android.js`, while the real `@sentry/react-native` appears 5 times in the iOS bundle.
- **Why it matters:** "Is this test-only file in the production bundle?" is answerable in one command against the emitted bundle. Do not settle it by reading config or by reasoning about resolver semantics — **grep the bundle.** The same one-liner answers the question for any future mock, fixture, or dev-only module.
- **Implication / how to apply:** Keep the mock where it is. If a future change adds `roots`/`watchFolders`/`extraNodeModules` to `metro.config.js`, or moves the mock into a directory that *is* on the import graph, this conclusion expires and must be re-tested the same way. Recommended standing check for `build-prereq-auditor` (it ran it manually as Check 9 this time): for each `__mocks__`/test-only path added since the last shipped build, `grep -c` that path in both emitted bundles and require 0.

### DECISION-016 — Build record: c4c09357 (iOS testflight 179) + b3b5d2e6 (Android vc21) succeeded

- **Recorded:** 2026-09-18
- **Builds:** `c4c09357-f01a-4b30-99a2-fa3ac4e4f1ee` — iOS, `testflight` profile, build 179, auto-submitted to ASC `6748651413`. `b3b5d2e6-bc13-4938-b380-4ce36a338dd6` — Android, `testflight` profile, versionCode 21, APK artifact (no auto-submit — expected, see DECISION-012).
- **Built from:** `/Users/ginalevy/Sites/kindraapp-tf-build`, branch `testflight`, commit `8f188d09` (merge of PR #426), version 1.80.11. All four pre-flight auditors PASSED. Contents: 6 merged PRs since the last shipped build (`f30c7d5e`), 438 files, of which only #421 (deleted profile photos reappearing) and #422 (theme-box save navigation) are behavior changes; #423 is a mechanical lint sweep.
- **State these builds succeeded WITH (re-verified this run, not inherited — see META-010):**
  1. `build.testflight.env` **IS present** with all 5 `EXPO_PUBLIC_*` vars, byte-identical to the git-tracked `.env` (restored 2026-08-27 at `1f25cafb` / PR #409). This supersedes the "no env block" state recorded in DECISION-012 and DECISION-014.
  2. `build.testflight` still has **no `environment` key** — dashboard secrets resolve from the default environment and work only because `SENTRY_AUTH_TOKEN` exists in all three `kinliadev` environments. META-007, unchanged, still an open fragility.
  3. `SENTRY_DISABLE_AUTO_UPLOAD` is set **nowhere** in the repo, so source maps DID upload for this testflight build, to org `kinlia` / project `kinlia-staging`. This is a change from DECISION-008's recorded testflight posture (`=true`), which was already gone at `a55116fb` (2026-08-05).
  4. Sentry token validity was **NOT live-pinged** — the EAS variable is SECRET-visibility so the CLI returns `*****` and there is no value to ping with. Verified present + secret + project-scoped + updated 2026-08-05. This is a standing gap in META-001's hardening #3 for secret-visibility variables; presence remains the only evidence obtainable from the CLI.
  5. Two audit reports (env, Sentry) were carried forward from `eedf1a5b` across the mid-run merge of PRs #425/#426 — justified (diff was tests + docs only) but unstamped. See META-009.
  6. `keys/ApiKey_*.p8` still tracked in git and still uploaded to the EAS builder — DECISION-013, owner-deferred to 2026-09-17, **not re-verified as fixed this run.**
  7. expo-doctor advisory is now **9 packages** (7 untested / 5 unmaintained, overlapping), up from the 8 recorded — DOCTOR-005 update.
- **Implication:** This is the current known-good testflight reference; supersedes DECISION-014. Any auditor that would have FAILED this exact configuration is mis-specified — except the META-007 `environment` finding and the DECISION-013 key exposure, which are correct standing reports.

## Future cleanup (low priority)

- **Repo upload size sweep:** Android production upload archive on 2026-05-02 was 847 MB (vs 272 MB for iOS). Repo root has 700+ untracked debugging screenshots (`af-*.png`, `audio-*.png`, `account-*.png`, etc.) accumulated from prior sessions. EAS warned but did not fail. Add these globs to `.easignore` (or clean them up) in a future session to reduce upload time. Not urgent — does not affect build correctness.
- **Upload archive still oversized as of 2026-09-16** (builds 06dbe7c7 / c95ed54c): ~190 MB, and EAS emitted its archive-size warning on BOTH platforms. Raised on every build; costs upload time on every build. The likely cause is that `.easignore` does not exclude enough — remember it REPLACES `.gitignore` (DECISION-009), so everything you assume `.gitignore` is keeping out of the archive is in fact being uploaded. **Pair this work with DECISION-013** (adding `keys/` to `.easignore`): both are `.easignore` edits and should be one reviewed change rather than two drive-by ones. `.easignore` is ASK-FIRST infra — **propose the diff and get owner approval; do not auto-edit it mid-build.**
