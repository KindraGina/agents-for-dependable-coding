# Rules Cleanup — shared rule files in this repo (2026-10-09)

**Status:** PROPOSAL — nothing applied. Owner review required before any edit.
**Trigger:** owner question on 2026-10-08, "is there a time where we are adding too many things to the pipeline?"

## Target
- pwd: `/Users/ginalevy/claude-pipeline-agents`
- branch: `main` (work happens on a new branch `chore/rules-cleanup`, PR back to `main`)
- remote: `git@github.com:KindraGina/agents-for-dependable-coding.git`
- Working tree clean at planning time (see R0).

## Summary

Every rule file that sessions and pipeline runs read is growing by append only. Since the lesson-learner shipped (2026-08-27) the rate of dated incident paragraphs went from ~10/month to 93 in September (R12). The problems are not bad lessons — every one was evidenced — but four structural ones, all measured below:

1. **Duplication.** The orchestrator skills share 30–90 identical lines pairwise (S2); one paragraph exists in 16 files, one incident story in 9 (R9). Copies drift (the cascade-light gate drift recorded in `~/CLAUDE.md` was exactly this).
2. **Misplacement.** 238 lines of KindraApp-only rules (mobile, Expo, EAS) sit in the Sites-wide `CLAUDE.md` (S8) and load into every kindra and kinlia-web session. A 20-line infrastructure snapshot ("prod DB posture as of …") sits there too.
3. **Expiring claims.** 19 `file:NNN` line-number citations (R11) that the repo's own rules forbid, plus "as of"/"not yet" claims.
4. **One-way process.** `lesson-learner.md` is append-only by rule (R13) with no retire, merge, or size budget.

This plan edits only files in THIS repo: `claude-md/sites/CLAUDE.md` (which `~/Sites/CLAUDE.md` symlinks to — R2), `skills/*`, `agents/*`, and new files under `docs/` and `scripts/`. The kindra and KindraApp `CLAUDE.md` changes are listed under Cross-Repo Dependencies and get their own plans.

**Guarantee:** no rule is removed. The 669 distinct bold rule headings that exist today (S9) must all exist after, in their file or in a `_shared` file, checked by a script this plan adds.

## Verified References

### R0 target
Command: `pwd; git branch --show-current; git remote get-url origin; git status --short`
```
/Users/ginalevy/claude-pipeline-agents
main
git@github.com:KindraGina/agents-for-dependable-coding.git
```
### R1 sizes
Command: `wc -l ~/CLAUDE.md claude-md/sites/CLAUDE.md ~/Sites/kindra/CLAUDE.md ~/Sites/KindraApp/CLAUDE.md ~/Sites/kinlia-web/CLAUDE.md`
```
      87 /Users/ginalevy/CLAUDE.md
     622 claude-md/sites/CLAUDE.md
     751 /Users/ginalevy/Sites/kindra/CLAUDE.md
      98 /Users/ginalevy/Sites/KindraApp/CLAUDE.md
      63 /Users/ginalevy/Sites/kinlia-web/CLAUDE.md
    1621 total
```
### R2 symlinks
Command: `python3 -c "import os;print(os.path.realpath(os.path.expanduser(\"~/Sites/CLAUDE.md\")));print(os.path.realpath(os.path.expanduser(\"~/.claude/skills/pipeline\")));print(os.path.realpath(os.path.expanduser(\"~/.claude/agents/plan-coder.md\")))"`
```
/Users/ginalevy/claude-pipeline-agents/claude-md/sites/CLAUDE.md
/Users/ginalevy/.claude/skills/pipeline
/Users/ginalevy/claude-pipeline-agents/agents/plan-coder.md
```
### R3 agents+skills totals
Command: `wc -l agents/*.md | tail -1; wc -l skills/*/*.md | tail -1`
```
    3611 total
    5356 total
```
### R4 kindra headings
Command: `grep -n "^## \|^# " ~/Sites/kindra/CLAUDE.md`
```
1:# Kindra Project - Claude Guidelines
3:## Table of Contents
23:# Collaboration
25:## Instructions
35:## When Asking Permission to Proceed
42:## Bug Investigation Checklist
79:## Bug Fix Process
112:## Working Style
127:# Git Workflow
129:## Branch Strategy - ALWAYS FOLLOW THIS
180:# Code Quality
182:## Code Changes
191:## Understanding Original Intent
215:## Commenting Guidelines
236:## Testing
370:# Planning & Files
372:## Plans
424:## File Safety
431:## File Editing Rules
439:## Testing
460:# Planning & Files
462:## Plans
488:## File Safety
495:## File Editing Rules
504:# Project Setup
506:## Local Development - ALWAYS USE DOCKER
530:# From ANY worktree, run tests via the main project's container:
533:# Or use -e for test environment:
553:# Install assets deps (main checkout, compose container already running):
556:# Install assets deps (git worktree — no compose here, use an ephemeral container):
559:# Run Jest (worktree or main checkout):
615:## Admin User Management
653:## Deployment Troubleshooting
693:## DNA
712:## Design System
742:## Detected Project Info
```
### R5 kindra dup verbatim count
Command: `comm -12 <(sed -n 1,438p ~/Sites/kindra/CLAUDE.md | grep -E ".{30,}" | sort -u) <(sed -n 439,503p ~/Sites/kindra/CLAUDE.md | grep -E ".{30,}" | sort -u) | wc -l; sed -n 439,503p ~/Sites/kindra/CLAUDE.md | grep -cE ".{30,}"`
```
      34
36
```
### R6 kindra dup origin
Command: `cd ~/Sites/kindra && git log --format="%h %ad %s" --date=short -L460,462:CLAUDE.md | grep -E "^[0-9a-f]{7,} "`
```
bfd955c9 2026-01-31 feat(TASK-007): Completed Tab UI with table and event drawer
```
### R7 sites headings
Command: `grep -n "^## \|^# \|^#### " claude-md/sites/CLAUDE.md`
```
1:# Claude Guidelines
5:## ⚠️ CRITICAL RULES - READ FIRST
61:## Kindra Production DB — current posture (as of 2026-05-24)
81:## Table of Contents
99:# Collaboration
101:## Instructions
118:## Bug Investigation Checklist
161:## Working Style
175:## Debugging Rules
192:## Mobile App — Not a Server
203:## Package Management — Expo Version Compatibility
219:## Dependency Health — Check the Foundation Before Building On It
253:# Code Quality
255:## Code Changes
264:## Understanding Original Intent
288:## Commenting Guidelines
314:## Testing
335:## Deployment
374:#### TL;DR — use the yarn scripts
388:#### TestFlight build (staging — dev bundle)
400:#### Production build (App Store — production bundle)
411:#### Android — no yarn script yet
424:#### GitHub Actions workflow — manual-dispatch only since 2026-05-20
432:#### Key Configuration Files
437:#### Important Notes
443:#### EAS Secrets are Scoped to a Project — Always Force the Right Project When Inspecting
454:#### Apple Pay / Capability Changes Require Provisioning Profile Regeneration
465:#### Native dirs are gitignored — always prebuild after `app.config.ts` edits
476:#### `.easignore` REPLACES `.gitignore` for EAS uploads — "gitignored" does NOT mean "not shipped"
484:#### More than one KindraApp checkout exists — verify the directory before every fix
492:#### A missing config block is not proof it was never wanted — read the file's history
502:#### A documented config claim expires — re-verify before restating it
512:# Planning & Files
514:## Plans
524:#### ⚠️ NEVER WRITE PLAN CODE FROM MEMORY — THIS IS THE #1 SOURCE OF PLAN BUGS
535:#### Other Planning Rules
551:## Plan Verification — Hard Rules
611:## File Safety
618:## File Editing Rules
```
### R9 shared blocks
Command: `grep -rl "Why this exists (2026-09-13)" agents skills claude-md | wc -l; grep -rl "Why this exists (2026-09-13)" agents skills claude-md`
```
      16
agents/lesson-learner.md
agents/plan-creator.md
skills/pipeline/SKILL.md
skills/review-plan/SKILL.md
skills/review-code/SKILL.md
skills/verify/SKILL.md
skills/plan/SKILL.md
skills/finalize-runbook/SKILL.md
skills/finalize-plan/SKILL.md
skills/review-runbook/SKILL.md
skills/cascade/SKILL.md
skills/pipeline-audit/SKILL.md
skills/critique/SKILL.md
skills/cascade-light/SKILL.md
skills/pipeline-light/SKILL.md
skills/pr-review/SKILL.md
```
Command: `grep -rl "YOU ARE AN ORCHESTRATOR ONLY" agents skills claude-md | wc -l; grep -rl "YOU ARE AN ORCHESTRATOR ONLY" agents skills claude-md`
```
       7
skills/pipeline/SKILL.md
skills/review-plan/SKILL.md
skills/review-code/SKILL.md
skills/verify/SKILL.md
skills/review-runbook/SKILL.md
skills/pipeline-audit/SKILL.md
skills/pipeline-light/SKILL.md
```
Command: `grep -rl "Pause on NO PROGRESS, not on round count" agents skills claude-md | wc -l; grep -rl "Pause on NO PROGRESS, not on round count" agents skills claude-md`
```
       2
skills/pipeline/SKILL.md
skills/pipeline-light/SKILL.md
```
Command: `grep -rl "April 2026 donation-upsell incident" agents skills claude-md | wc -l; grep -rl "April 2026 donation-upsell incident" agents skills claude-md`
```
       9
agents/plan-reviewer-3.md
agents/plan-coder.md
agents/plan-reviewer-2.md
agents/verification-auditor.md
agents/plan-reviewer.md
agents/plan-creator.md
skills/pipeline/SKILL.md
skills/finalize-plan/SKILL.md
skills/pipeline-light/SKILL.md
```
Command: `grep -rl "July 2026 tag-taxonomy incident" agents skills claude-md | wc -l; grep -rl "July 2026 tag-taxonomy incident" agents skills claude-md`
```
       7
agents/plan-reviewer-3.md
agents/plan-coder.md
agents/plan-reviewer-2.md
agents/plan-reviewer.md
skills/pipeline/SKILL.md
skills/cascade/SKILL.md
skills/pipeline-light/SKILL.md
```
Command: `grep -rl "Sept 23, 2026, kindra stale-Jest-suites" agents skills claude-md | wc -l; grep -rl "Sept 23, 2026, kindra stale-Jest-suites" agents skills claude-md`
```
       6
agents/plan-coder.md
agents/test-reviewer.md
skills/pipeline/SKILL.md
skills/cascade/SKILL.md
skills/cascade-light/SKILL.md
skills/pipeline-light/SKILL.md
```
Command: `grep -rl "IS ALWAYS AN ACCEPTABLE ANSWER" agents skills claude-md | wc -l; grep -rl "IS ALWAYS AN ACCEPTABLE ANSWER" agents skills claude-md`
```
       5
agents/code-quality-reviewer-2.md
agents/plan-coder.md
agents/test-reviewer-2.md
agents/test-reviewer.md
agents/code-quality-reviewer.md
```
### R10 sites vs kindra
Command: `comm -12 <(grep -E ".{40,}" claude-md/sites/CLAUDE.md | sort -u) <(grep -E ".{40,}" ~/Sites/kindra/CLAUDE.md | sort -u) | wc -l`
```
      87
```
### R11 line cites
Command: `grep -rnoE "[A-Za-z_./-]+\.(ex|exs|js|jsx|ts|tsx|mm|kt|md|json|yaml):[0-9]{1,4}" agents skills/*/SKILL.md claude-md`
```
agents/code-quality-reviewer-2.md:95:event_ticket_controller_upsell_tiers_test.exs:503
agents/plan-reviewer-3.md:94:event_ticket_controller_upsell_tiers_test.exs:503
agents/plan-coder.md:131:event_ticket_controller_upsell_tiers_test.exs:503
agents/plan-coder.md:146:SmsHistory.js:204
agents/plan-reviewer-2.md:91:event_ticket_controller_upsell_tiers_test.exs:503
agents/env-var-auditor.md:38:contexts/authContext.tsx:31
agents/env-var-auditor.md:135:src/foo.ts:42
agents/code-quality-reviewer.md:138:event_ticket_controller_upsell_tiers_test.exs:503
agents/plan-reviewer.md:115:event_ticket_controller_upsell_tiers_test.exs:503
agents/plan-creator.md:191:event_ticket_controller_upsell_tiers_test.exs:503
skills/critique/SKILL.md:236:OfferingCrossSell.tsx:71
skills/finalize-plan/SKILL.md:195:pipeline/SKILL.md:80
skills/pipeline-light/SKILL.md:37:skills/cascade-light/SKILL.md:92
skills/pr-review/SKILL.md:156:contexts/communities.tsx:1001
skills/pr-review/SKILL.md:156:docs/TODO.md:48
skills/pr-review/SKILL.md:342:notificationsHandler.ts:379
skills/pr-review/SKILL.md:427:src/foo.ts:42
claude-md/sites/CLAUDE.md:307:holders.js:466
claude-md/sites/CLAUDE.md:309:holders.js:466
```
### R12 why by month
Command: `grep -rhoE "\*\*Why[^*]{0,60}" agents skills/*/SKILL.md claude-md ~/Sites/kindra/CLAUDE.md ~/Sites/KindraApp/CLAUDE.md | grep -oE "(2026-[0-9]{2}|(January|February|March|April|May|June|July|August|Aug|Sept|September|October|Oct) [0-9]{0,2},? ?2026)" | sed -E "s/ [0-9]{1,2},? / /; s/^(Aug|August) 2026/2026-08/; s/^(Sept|September) 2026/2026-09/; s/^(Oct|October) 2026/2026-10/; s/^July 2026/2026-07/; s/^June 2026/2026-06/; s/^May 2026/2026-05/; s/^April 2026/2026-04/" | sort | uniq -c`
```
   9 2026-04
   5 2026-05
   5 2026-06
  14 2026-07
  15 2026-08
  93 2026-09
  24 2026-10
```
### R13 lesson-learner
Command: `grep -n -i "delete\|remove\|retire\|budget\|merge\|consolidat\|append-only\|reorganize" agents/lesson-learner.md`
```
28:   - **Process lesson** (about how the pipeline/skills/agents themselves behave or should behave) → the relevant `SKILL.md` or agent `.md` in `~/claude-pipeline-agents`; if none fits, `~/claude-pipeline-agents/docs/lessons.md` (create with a one-line header on first use; append-only thereafter)
70:1. Read the proposal file. Apply ONLY the approved lessons, using each lesson's exact proposed text at its stated insertion point. Append-only, 3–8 lines each. Never rewrite or reorganize a destination file.
80:- **NEVER rewrite or reorganize a destination file.** Append-only edits at the stated insertion point.
90:- Write each numbered rule and its one-line "why" in everyday words, as if explaining to a smart friend who doesn't code. Example: instead of "Attribute test-suite warnings at the merge-base — refine Check 6; 'merge-base' appears nowhere", write "When tests print a warning, prove whether it existed before the change — the instructions already require this for failures, but not for warnings."
```
### R14 shared dirs
Command: `ls skills/_shared agents/_shared docs/incidents.md 2>&1`
```
ls: agents/_shared: No such file or directory
ls: docs/incidents.md: No such file or directory
ls: skills/_shared: No such file or directory
```
### R15 lesson-learner buckets anchor
Command: `grep -n "three buckets\|^## \|NEVER rewrite" agents/lesson-learner.md`
```
10:## Why You Exist
14:## Two Modes
26:2. **Identify candidate lessons** in three buckets, each with its destination:
42:## Lesson 1: [one-line rule]
56:## No further lessons
75:## Hard Rules
80:- **NEVER rewrite or reorganize a destination file.** Append-only edits at the stated insertion point.
86:## Plain-Language Reporting (MANDATORY)
```
### R16 git log since sept
Command: `git log --since=2026-09-01 --oneline | wc -l`
```
      64
```
### R17 hook test
Command: `echo "{\"prompt\":\"what happened to X\"}" | hooks/evidence-trigger.sh | cut -c1-80`
```
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"E
```

### S1 skills symlink audit
Command: `for d in ~/.claude/skills/*/; do f=$d/SKILL.md; [ -f "$f" ] && { r=$(python3 -c "import os,sys;print(os.path.realpath(sys.argv[1]))" "$f"); case "$r" in /Users/ginalevy/claude-pipeline-agents/*) ;; *) echo "NOT IN REPO: $r";; esac; }; done; echo done`
```
done
```
### S2 sibling overlap
Command: `ov(){ comm -12 <(grep -E ".{40,}" skills/$1/SKILL.md | sort -u) <(grep -E ".{40,}" skills/$2/SKILL.md | sort -u) | wc -l | tr -d " "; }; echo "pipeline/pipeline-light $(ov pipeline pipeline-light)"; echo "cascade/cascade-light $(ov cascade cascade-light)"; echo "pipeline/review-code $(ov pipeline review-code)"; echo "pipeline/pipeline-audit $(ov pipeline pipeline-audit)"`
```
pipeline/pipeline-light 89
cascade/cascade-light 65
pipeline/review-code 44
pipeline/pipeline-audit 32
```
### S3 no-progress rule
Command: `grep -rli "NO PROGRESS, not" skills agents`
```
skills/pipeline/SKILL.md
skills/cascade/SKILL.md
skills/cascade-light/SKILL.md
skills/pipeline-light/SKILL.md
```
### S4 shared-block anchors in pipeline
Command: `grep -n "ORCHESTRATOR ONLY\|## Plain-Language Reporting\|NO PROGRESS, not\|USE THE AGENT TOOL FOR EVERY PHASE\|NEVER skip a verification gate\|Canonical NEWER than" skills/pipeline/SKILL.md | cut -c1-160`
```
86:  - **Canonical NEWER than the highest `-rN`** → the round file is a leftover from an earlier draft's finalize run that the current run superseded. Do NOT st
142:**YOU ARE AN ORCHESTRATOR ONLY.** You MUST delegate ALL work to agents using the Agent tool. You NEVER:
193:2. **Pause on NO PROGRESS, not on round count.** Before launching round N+1 (N ≥ 2), compare the critical/important issues in round N's reviews with round N
402:- **USE THE AGENT TOOL FOR EVERY PHASE.** Never do the work yourself. Never fix the plan yourself. Never fix code yourself. ALWAYS delegate to the appropria
408:- **NEVER skip a verification gate.** Both gates (Phase 3.5 and Phase 5.5) are mandatory. Code review cannot start without passing Phase 3.5. The pipeline c
424:## Plain-Language Reporting (MANDATORY)
```
### S5 evidence-block anchors in plan-coder
Command: `grep -n "NEVER FABRICATE\|IS ALWAYS AN ACCEPTABLE\|donation-upsell\|tag-taxonomy\|stale-Jest" agents/plan-coder.md | cut -c1-160`
```
28:   - **NO IN-PLACE GIT REVERTS OR BRANCH MOVES — the branch guard hook will stop the run.** Every checkout in this setup is shared with other live sessions, 
77:    **NEVER FABRICATE GREP OUTPUT.** The evidence you paste MUST be the actual output from running the command. Do NOT write grep output from memory or guess
78:    **"UNVERIFIED" IS ALWAYS AN ACCEPTABLE ANSWER; FABRICATED OUTPUT NEVER IS.** If you cannot run a command (environment broken, suite too slow, tool unavai
123:  - **Why this rule exists (July 2026 tag-taxonomy incident):** a backend plan's Pipeline Round-2 revision wrote the exact kinlia-web `TagPicker.tsx` change
130:  - **Why this rule exists (April 2026 donation-upsell incident):** Plan line 42 said "Implementer must NOT default this decision — surface it to the user a
```
### S6 lesson-learner buckets
Command: `sed -n 26,34p agents/lesson-learner.md`
```
2. **Identify candidate lessons** in three buckets, each with its destination:
   - **Repo lesson** (a fact or rule about the codebase being worked on) → that repo's `CLAUDE.md`
   - **Process lesson** (about how the pipeline/skills/agents themselves behave or should behave) → the relevant `SKILL.md` or agent `.md` in `~/claude-pipeline-agents`; if none fits, `~/claude-pipeline-agents/docs/lessons.md` (create with a one-line header on first use; append-only thereafter)
   - **User-preference lesson** (how the user wants to work) → a new or updated memory file under `~/.claude/projects/-Users-ginalevy/memory/` (with a `MEMORY.md` index line)

   A candidate is only a lesson if it would change what a FUTURE session does. "Reviewer 2 found a bug" is not a lesson. "Reviewer 2 found a bug because the plan cited line numbers from the wrong branch — and the plan-creator has no rule against that" IS a lesson.

   **Skip build-pattern-shaped lessons entirely** (EAS build failures, config/signing patterns) — those belong to `build-postmortem-updater` and `~/.claude/skills/build-app/patterns.md`. Do not double-write.

```
### S7 scripts dir / runbooks dir
Command: `ls scripts 2>&1; ls ~/Sites/kindra/docs/runbooks 2>&1 | head -3`
```
ls: scripts: No such file or directory
ls: /Users/ginalevy/Sites/kindra/docs/runbooks: No such file or directory
```
### S8 sites section sizes
Command: `awk "NR>=192&&NR<=252" claude-md/sites/CLAUDE.md | wc -l; awk "NR>=335&&NR<=511" claude-md/sites/CLAUDE.md | wc -l; awk "NR>=61&&NR<=80" claude-md/sites/CLAUDE.md | wc -l; sed -n 192p claude-md/sites/CLAUDE.md; sed -n 253p claude-md/sites/CLAUDE.md; sed -n 335p claude-md/sites/CLAUDE.md; sed -n 512p claude-md/sites/CLAUDE.md; sed -n 61p claude-md/sites/CLAUDE.md; sed -n 81p claude-md/sites/CLAUDE.md`
```
      61
     177
      20
## Mobile App — Not a Server
# Code Quality
## Deployment
# Planning & Files
## Kindra Production DB — current posture (as of 2026-05-24)
## Table of Contents
```
### S9 bold headings count baseline
Command: `grep -hoE "^\s*-? ?\*\*[^*]{15,}\*\*" agents/*.md skills/*/SKILL.md claude-md/*/CLAUDE.md | sed -E "s/^\s*-? ?//" | sort -u | wc -l`
```
     669
```

## Proposed Changes

All paths relative to `/Users/ginalevy/claude-pipeline-agents`. Phases are independently shippable PRs; recommended order 1 → 4 → 2 → 3.

### Phase 1 — Mechanical (one PR)

**1a. `claude-md/sites/CLAUDE.md` — remove the KindraApp-only sections, leave pointers.**
- Delete lines from the heading `## Mobile App — Not a Server` up to (not including) `# Code Quality` (61 lines, S8), and from `## Deployment` up to (not including) `# Planning & Files` (177 lines, S8).
- Insert in their place, at the first location:
  ```
  ## Mobile app, Expo dependencies, EAS builds
  These rules apply only to KindraApp and live in `~/Sites/KindraApp/CLAUDE.md` (moved 2026-10, see this repo's `docs/plans/2026-10-09-rules-cleanup.md`).
  ```
- **Ordering constraint:** this deletion ships ONLY after the KindraApp PR (Cross-Repo item X2) that receives the text has merged. The PR for 1a must link that merged PR.

**1b. `claude-md/sites/CLAUDE.md` — move the prod-DB posture out.**
- Delete from `## Kindra Production DB — current posture (as of 2026-05-24)` up to (not including) `## Table of Contents` (20 lines, S8). The AWS mutation rules above it stay untouched; they are rules, not state.
- Insert: `Current prod/staging RDS posture: \`~/Sites/kindra/docs/runbooks/prod-db-posture.md\` (moved 2026-10). Update it, not this file, when the instance changes.`
- Ships only after Cross-Repo item X3 has merged.

**1c. Replace every `file:NNN` citation in this repo with a searchable anchor.** The 19 hits are listed in R11. For each: open the cited file at the cited line, find a unique string, rewrite the citation as "the `<string>` line in `<file>`". The two `src/foo.ts:42` hits (env-var-auditor:135, pr-review:427) are format examples in templates — rewrite them as `src/foo.ts (the \`<unique string>\` line)` so the template itself models the rule. Add a one-line rule to `agents/lesson-learner.md` Hard Rules: `- **No line numbers in a lesson's proposed text.** Cite by unique string.`

**1d. New `scripts/rules-lint.sh`** (bash, to be created). Exits non-zero and prints offenders if any of:
- a `file.ext:NNN` citation exists in `agents/`, `skills/*/SKILL.md`, `claude-md/` (R11's grep);
- any of the shared-block marker strings (list in 2a) appears in more than one file;
- `claude-md/sites/CLAUDE.md` > 400 lines, any `skills/*/SKILL.md` > 300, any `agents/*.md` > 250 (budgets — Open Question 1);
- `hooks/evidence-trigger.sh` no longer prints the rule for `what happened to X` (R17).
Also `scripts/rules-headings.sh` prints the sorted unique bold-heading set (S9's command) so a before/after diff is one line.

### Phase 2 — One source for shared blocks (one PR)

**2a. New `skills/_shared/orchestrator-rules.md`.** Move these blocks from `skills/pipeline/SKILL.md` (anchors in S4) into it, verbatim: `**YOU ARE AN ORCHESTRATOR ONLY.**` paragraph (line 142 region); `- **USE THE AGENT TOOL FOR EVERY PHASE.**` and `- **NEVER skip a verification gate.**` bullets (402–408 region); `2. **Pause on NO PROGRESS, not on round count.**` with its round-ceiling text (193 region); the `-rN` leftover mtime rule (`**Canonical NEWER than the highest \`-rN\`**`, 86 region); `## Plain-Language Reporting (MANDATORY)` (424 to end). Then in each of the 16 files listed in R9 (first block) and 7 files (second block), replace the copy with one line directly after the frontmatter: `**Before Step 1, read \`~/.claude/skills/_shared/orchestrator-rules.md\` in full — it is part of this skill.**` Where a file's copy differs from pipeline's (cascade's no-progress wording, S3), keep the pipeline wording in `_shared` and note the difference in the PR for the owner to pick.

**2b. New `agents/_shared/evidence-rules.md`.** Move from `agents/plan-coder.md` (anchors in S5): `**NEVER FABRICATE GREP OUTPUT.**` (77), `**"UNVERIFIED" IS ALWAYS AN ACCEPTABLE ANSWER…**` (78) and the paragraph added 2026-10-09 after it, the `July 2026 tag-taxonomy` Why (123), the `April 2026 donation-upsell` Why (130). Each of the 9 / 7 / 5 files in R9 that carries a copy replaces it with: `**Read \`~/.claude/agents/_shared/evidence-rules.md\` before starting — it is part of your instructions.**` as the first line after the frontmatter.

**2c. Symlinks.** `ln -s ~/claude-pipeline-agents/skills/_shared ~/.claude/skills/_shared` and `ln -s ~/claude-pipeline-agents/agents/_shared ~/.claude/agents/_shared`; verify with realpath (R2's command). Add both to the `rules-lint.sh` checks.

**2d. One auditor line.** `agents/verification-auditor.md` gains: `- Confirm the orchestrator's and each agent's first tool call read its \`_shared\` file; if not, record "SHARED RULES NOT READ" as a FAIL.` (Open Question 2: owner may drop this if it costs more rounds than it saves.)

### Phase 3 — Compress stories, resolve expiring claims (one PR)

**3a. New `docs/incidents.md`.** One `### YYYY-MM-DD — <name>` entry per incident, full story, list of rules it produced (file + heading).

**3b.** Every `**Why (…)**` / `**Why this exists (…)**` paragraph dated before 2026-07-09 (Open Question 3) in `agents/`, `skills/*/SKILL.md`, `claude-md/sites/CLAUDE.md` becomes one line: `**Why (<date>, <name>):** <one sentence>. Full story: \`docs/incidents.md\`.` The rule text above each Why is untouched.

**3c.** In `claude-md/sites/CLAUDE.md`: the `**Status update (Sept 18, 2026) — this specific block is RESTORED…**` paragraph and the `expo-image` SDK-53 history under `## Package Management` move to `docs/incidents.md`; the rules stay. Every `as of <date>` fact remaining in the file is either re-verified and re-dated in the PR (command + output pasted) or moved to the kindra runbook (X3).

### Phase 4 — Stop regrowth (one PR, ship right after Phase 1)

**4a. `agents/lesson-learner.md`, after the three-buckets list (S6, the line beginning `   - **User-preference lesson**`):**
```
   - **Retire/merge candidate** (an existing entry the run showed to be duplicated, superseded, resolved, or stale) → the same file it lives in. EVERY proposal run must list 0–2 of these with the same pasted dedup evidence; "No retire candidates found" must be stated explicitly, never omitted.
```
**4b. Same file, Hard Rules, replace** `- **NEVER rewrite or reorganize a destination file.** Append-only edits at the stated insertion point.` **with:**
```
- **NEVER reorganize a destination file.** Additions are append-only at the stated insertion point. The ONLY permitted removals are owner-approved Retire/merge candidates, each as its own numbered item with the exact lines quoted.
- **Destination policy.** Repo fact → that repo's `CLAUDE.md`. Reviewer/coder behaviour → the agent file. Orchestration behaviour → `skills/_shared/orchestrator-rules.md`. Procedure or recipe → a skill or a reference doc the rule points to. Incident story → `docs/incidents.md`; the rule keeps a one-line Why.
- **Size budget.** Before proposing, run `scripts/rules-lint.sh`. If the destination is over budget, the proposal must include a Retire/merge candidate in that file that pays for the addition, or state that the owner must raise the budget.
```
**4c.** `docs/README.md` (new, 10 lines): what `rules-lint.sh` and `rules-headings.sh` do, the budgets, and "run `scripts/rules-lint.sh` before every commit to this repo".

## Cross-Repo Dependencies (informational — NOT for the plan-coder)

- **X1 — kindra `CLAUDE.md`: delete the accidental duplicate block.** Lines 439–503 repeat `## Testing`, `# Planning & Files`, `## Plans`, `## File Safety`, `## File Editing Rules` from 236–438; 34 of its 36 long lines are verbatim repeats (R5); the block entered in `bfd955c9` (2026-01-31, an unrelated feature commit — R6). Separate plan in kindra: `docs/plans/2026-10-09-claude-md-dedupe.md`.
- **X2 — KindraApp `CLAUDE.md`: receive the 238 mobile/EAS lines** from Sites (S8 ranges) under their existing headings. Must merge BEFORE Phase 1a. Separate plan in KindraApp.
- **X3 — kindra `docs/runbooks/prod-db-posture.md` (new; dir does not exist, S7):** receives the 20-line posture block. Must merge BEFORE Phase 1b.
- **X4 — kindra `CLAUDE.md` vs Sites overlap** (87 identical long lines, R10): after X1, diff kindra's 10 shared sections against Sites; keep only kindra-specific deltas. Separate plan, after Phase 3.

## Testing Plan

Framework for all: **bash** (this is a docs/config repo; there is no Jest/ExUnit here).

| # | Test | File | Scenario | Pass criterion |
|---|---|---|---|---|
| T1 | Rule preservation | `scripts/rules-headings.sh` | run on `main` before the PR → `before.txt`; run on the PR branch → `after.txt`; `comm -23 before.txt after.txt` | empty output (no heading lost). Baseline count 669 (S9). |
| T2 | No line-number cites | `scripts/rules-lint.sh` | R11's grep over the three dirs | 0 hits after Phase 1c |
| T3 | Shared blocks single-sourced | `scripts/rules-lint.sh` | for each marker string in 2a/2b, `grep -rl … | wc -l` | exactly 1 after Phase 2 |
| T4 | Hook still fires | `scripts/rules-lint.sh` | R17's command | output begins `{"hookSpecificOutput"` |
| T5 | Symlinks resolve | `scripts/rules-lint.sh` | realpath of `~/.claude/skills/_shared/orchestrator-rules.md` and `~/.claude/agents/_shared/evidence-rules.md` | both start with `/Users/ginalevy/claude-pipeline-agents/` |
| T6 | Negative control for T1 | manual, pasted in PR | delete one bold heading from a skill on a scratch copy, run T1 | `comm` prints that heading; restore; `git diff` empty |
| T7 | Negative control for T3 | manual, pasted in PR | paste the ORCHESTRATOR ONLY paragraph back into one skill on a scratch copy | lint fails naming both files; restore |
| T8 | Orchestrator reads shared file | one `/pipeline-light` dry run on a 5-line docs plan after Phase 2 | transcript | the first tool call of the run is a Read of `_shared/orchestrator-rules.md` |

## Existing Tests Pinning Current Behavior
Not applicable: no function, response shape, or return type changes. The only executable touched is `hooks/evidence-trigger.sh`, which is not edited; T4 pins it.

## Behaviors to Preserve
- Every bold rule heading (669, S9) — T1.
- The evidence hook's trigger behaviour — T4.
- The symlink contract from `~/CLAUDE.md` ("everything under `~/.claude/agents` and `~/.claude/skills` is a symlink into the repo") — S1 shows it holds today; T5 extends it to `_shared`.
- `skills/build-app/patterns.md` is NOT touched (see Deferred).

## Deferred / Out of Scope
- `skills/build-app/patterns.md` (777 lines, 31 `Pre-flight catchable?` entries): a pattern library maintained by `build-postmortem-updater`, not the lesson-learner. Needs its own review; same budget idea applies later.
- Memory directories (66 kindra, 48 KindraApp, 22 kinlia-web files): recalled by relevance, not loaded whole. Where a memory duplicates a CLAUDE.md rule (e.g. `evidence-before-explanation` vs Sites item 8), leave both for now.
- `hooks/*`: not edited.
- X1–X4 above: separate plans in their repos.
- Rewording any rule. This plan moves, compresses stories, and removes copies; it does not change what any rule says.

## Open Questions
1. **Size budgets** (1d): 400 lines per CLAUDE.md layer, 300 per SKILL.md, 250 per agent. Implementer must NOT default this decision — surface to user.
2. **Auditor check 2d**: keep or drop. Implementer must NOT default this decision — surface to user.
3. **Story-compression cutoff** (3b): incidents before 2026-07-09 (3 months). Implementer must NOT default this decision — surface to user.
4. **Cascade's "no progress" wording vs pipeline's** (2a): which text becomes canonical. Implementer must NOT default this decision — surface to user.

## Retroactive Plan
Not retroactive: working tree clean (R0), none of the proposed files exist (R14, S7).
