# Rules Cleanup — CLAUDE.md files, skills, agents (2026-10-09)

**Status:** PROPOSAL — nothing changed yet. Owner review required before any edit.
**Trigger:** owner question on 2026-10-08, "is there a time where we are adding too many things to the pipeline?"
**Scope:** the rule files every session or pipeline run reads: the three CLAUDE.md layers (home, Sites, repo), the skills and agents in this repo. Memory files are out of scope except where they duplicate a rule (noted, not edited).

---

## 1. Headline numbers

| What | Lines | Note |
|---|---|---|
| Rules loaded by EVERY kindra session (home 87 + Sites 622 + kindra 751) | **1,460** | before any skill or agent text |
| Rules loaded by every KindraApp session (87 + 622 + 98) | 807 | 238 of the Sites lines are KindraApp-only (see F2) |
| All agent files | 3,611 | 18 files |
| All skill files | 9,935 | incl. `build-app/patterns.md` 777 |
| Dated "Why" incident paragraphs, Sept 2026 alone | **90** | vs 53 for April–Aug combined |
| Commits to this repo since 2026-09-01 | 60 | |

The lesson-learner agent shipped on 2026-08-27. Since then the incident-paragraph rate went from roughly 10 a month to 90 a month. Every one was evidenced. The files are now growing faster than any reader, human or agent, can weight them.

---

## 2. Findings (each verified this session, raw output in §7)

### F1 — kindra `CLAUDE.md` contains a duplicated block of its own content (65 lines, since 2026-01-31)
Lines 439–503 repeat `## Testing`, `# Planning & Files`, `## Plans`, `## File Safety`, `## File Editing Rules` which already exist at 236–438 in a longer, newer form. The duplicate entered in commit `bfd955c9` ("feat(TASK-007): Completed Tab UI"), an unrelated feature commit — an accidental paste, not a decision. 34 of the 65 lines are verbatim copies of earlier lines; the rest are older wording of the same rules.

### F2 — 238 lines of KindraApp-only content live in the Sites-wide `CLAUDE.md`
Sections `## Mobile App — Not a Server`, `## Package Management — Expo`, `## Dependency Health` (lines 192–252) and the whole `## Deployment` section with its 13 EAS sub-sections (335–511) apply only to KindraApp, yet load into every kindra and kinlia-web session. Meanwhile `KindraApp/CLAUDE.md` is 98 lines.

### F3 — Operational state is stored as a rule
`## Kindra Production DB — current posture (as of 2026-05-24)` (Sites lines 61–80) is a snapshot of RDS state with "as of" dates, loaded into every session of every repo. It expires by nature and has already needed two dated corrections.

### F4 — The orchestrator skills share large identical blocks
| Pair | Identical lines (>40 chars) |
|---|---|
| pipeline (435) vs pipeline-light (368) | 89 |
| cascade (187) vs cascade-light (180) | 65 |
| pipeline vs review-code | 44 |
| pipeline vs pipeline-audit | 32 |

The "Plain-Language Reporting (2026-09-13)" block is in **16 files**. "YOU ARE AN ORCHESTRATOR ONLY" is in 7. The "no progress, not round count" rule (2026-10-01) is in 4. When one copy is edited the others drift — the owner's cascade-light gate drift (noted in home CLAUDE.md) was exactly this.

### F5 — The reviewer/coder agents share the same incident stories
"April 2026 donation-upsell incident" is told in **9 files**; "July 2026 tag-taxonomy incident" in 7; "Sept 23 stale-Jest-suites" in 6; "UNVERIFIED is always acceptable" in 5. Each copy is 3–8 lines.

### F6 — Sites `CLAUDE.md` and kindra `CLAUDE.md` overlap
87 identical long lines: both carry `## Instructions`, `## Bug Investigation Checklist`, `## Working Style`, `## Code Changes`, `## Understanding Original Intent`, `## Commenting Guidelines`, `## Testing`, `## Plans`, `## File Safety`, `## File Editing Rules`. The kindra copies have diverged (e.g. kindra's Bug Investigation Checklist lacks item 7 and the new item 8).

### F7 — Expiring claims
20 `file.ext:NNN` line-number citations across agents/skills/CLAUDE.md (the repo's own "cite by searchable string, not line number" rule forbids these). Plus "as of <date>", "currently line N", and "not yet device-tested" style claims (34 matches), including the one added yesterday for PR #443.

### F8 — The lesson process is structurally one-way
`agents/lesson-learner.md` rules: "NEVER rewrite or reorganize a destination file. Append-only edits." There is no delete, merge, or retire mode, no size ceiling, and no requirement that a new lesson name what it replaces. Growth can only go up.

---

## 3. Principles for the cleanup

1. **No rule is deleted.** Every bold rule heading that exists today exists after. What gets cut is duplication, misplacement, stale state, and story length — not rules. Verified mechanically (§6).
2. **A rule lives in exactly one place; everything else points to it.**
3. **Repo facts go in the repo.** Quantum's UTC default belongs in kindra; EAS build rules belong in KindraApp.
4. **A "Why" earns its length by age.** Under 3 months: full paragraph stays. Over 3 months: compressed to one line (`Why (date, incident): one sentence`) with the full story moved to `docs/incidents.md` in this repo, keyed by date. The rule itself never shrinks.
5. **State is not a rule.** Snapshots of infrastructure go in a runbook or the repo's docs, never in a CLAUDE.md.
6. **Line numbers are banned in rule files.** Cite by unique string.

---

## 4. The plan — four phases, each independently shippable

### Phase 1 — Mechanical, zero judgment (one `/pipeline-light` run, kindra + KindraApp + this repo)
- **1a.** kindra `CLAUDE.md`: delete lines 439–503 after a diff proves every line is either verbatim-duplicated above or an older wording of a rule present above. Paste the diff in the PR. (−65 lines)
- **1b.** Move Sites lines 192–252 and 335–511 into `KindraApp/CLAUDE.md` under their existing headings. Sites keeps a 2-line pointer: "Mobile build, dependency, and EAS rules: `KindraApp/CLAUDE.md`." (Sites −238, KindraApp +238)
- **1c.** Move `## Kindra Production DB — current posture` to `kindra/docs/runbooks/prod-db-posture.md` (new). Sites keeps the AWS-mutation rule (it is a rule) and a pointer to the posture file. (Sites −20)
- **1d.** Replace all 20 `file:NNN` citations with unique-string anchors. Each one re-verified by grep before rewriting.

**Result:** every kindra session loads ~1,140 lines instead of 1,460; KindraApp sessions load the mobile rules they actually need.

### Phase 2 — Single source for shared blocks (this repo only)
- **2a.** Create `skills/_shared/orchestrator-rules.md` holding: "YOU ARE AN ORCHESTRATOR ONLY", "USE THE AGENT TOOL FOR EVERY PHASE", "NEVER skip a verification gate", "Plain-Language Reporting", "Pause on NO PROGRESS, not round count" (+ the round-ceiling text), the `-rN` leftover-file mtime rule. Each of the 9 orchestrator skills replaces its copy with: `**Read \`skills/_shared/orchestrator-rules.md\` before Step 1 — it is part of this skill.**`
- **2b.** Create `agents/_shared/evidence-rules.md` holding: "NEVER FABRICATE OUTPUT / UNVERIFIED is acceptable", the pasted-output rules, and the donation-upsell / tag-taxonomy / stale-Jest incident stories. The 9 agent files replace their copies with one read-first line.
- **2c.** The symlink layout means agents read these via `~/.claude/agents/_shared/...` and `~/.claude/skills/_shared/...`; add the two symlinks and verify with `realpath`.

**Risk:** an agent that skips the read-first line loses the rules. **Mitigation:** the read-first line is the FIRST line after the frontmatter, in bold, and `verification-auditor` gets one check: "did the orchestrator's transcript show the shared file being read?" Decide in review whether that check is worth its own line.

**Estimated result:** ~400 lines removed across skills/agents with zero rules lost.

### Phase 3 — Compress and retire stories (this repo + Sites + kindra CLAUDE.md)
- **3a.** Create `docs/incidents.md` in this repo: one entry per incident, dated, full story, which rule(s) it produced.
- **3b.** Every "Why" paragraph older than 2026-07-09 (3 months) becomes one line pointing at its incidents entry. Rules keep their full text.
- **3c.** Resolve every expiring claim: "Status update … RESTORED" blocks collapse to the rule + one dated line; "as of" facts either move to runbooks (Phase 1c) or get re-verified today and dated today.
- **3d.** Sites vs kindra overlap (F6): kindra's copies of the 10 shared sections are diffed against Sites. Where kindra adds nothing, the kindra section becomes a one-line pointer to Sites. Where kindra adds repo-specific detail, only the delta stays.

**Estimated result:** Sites ~300 lines, kindra ~450 lines.

### Phase 4 — Stop the regrowth (lesson-learner + a budget)
- **4a.** `agents/lesson-learner.md` gains a fourth bucket: **RETIRE/MERGE** — every proposal run must also propose 0–2 existing entries to compress, merge, or delete, with the same pasted evidence. "No candidates" is an acceptable answer, but it must be stated.
- **4b.** Destination policy written once in `lesson-learner.md`: repo fact → that repo's CLAUDE.md; reviewer behaviour → the agent file; procedure/recipe → a skill or reference doc the rule points to; incident story → `docs/incidents.md`.
- **4c.** A size budget per file, checked by the learner before proposing: CLAUDE.md layers 400 lines each, any SKILL.md 300, any agent 250. Over budget → the proposal must include a compression to pay for the addition. Numbers are a starting point for the owner to set.
- **4d.** A quarterly `/rules-review` pass (a new small skill, or a calendar note): re-run the F1–F8 measurements in §7 and act on anything over budget. First run: 2027-01-09.

---

## 5. What I recommend doing first
Phase 1 alone fixes the two largest problems (a paste error nobody noticed for 8 months and 238 lines of mobile rules in every backend session) with no judgment calls. Run it as `/pipeline-light` this week. Phase 4 should ship right after, so the files stop growing while Phases 2–3 are reviewed. Phases 2 and 3 are the ones that need your eye on wording.

## 6. Verification (applies to every phase)
- **Rule-preservation check:** before and after, run `grep -hoE "^\s*-? ?\*\*[^*]{15,}\*\*" <all rule files> | sort -u` and diff. Every heading present before must be present after (in its file or in a `_shared` file). Paste the diff; it must be empty on the "removed" side.
- **Line-count table** before/after per file, pasted.
- **Hook test:** `echo '{"prompt":"what happened to X"}' | hooks/evidence-trigger.sh` still prints the rule (Phase 2 must not touch hooks).
- **Symlink check (Phase 2c):** `realpath ~/.claude/skills/_shared/orchestrator-rules.md` resolves under `/Users/ginalevy/claude-pipeline-agents/`.
- **Spot test:** one `/pipeline-light` dry run on a trivial plan after Phase 2 to confirm an orchestrator reads the shared file (transcript shows the Read).

## 7. Verified References (raw output, this session)

### Rules loaded per session
Command: `wc -l ~/CLAUDE.md claude-md/sites/CLAUDE.md ~/Sites/kindra/CLAUDE.md ~/Sites/KindraApp/CLAUDE.md`
```
      87 /Users/ginalevy/CLAUDE.md
     622 /Users/ginalevy/Sites/CLAUDE.md
     751 /Users/ginalevy/Sites/kindra/CLAUDE.md
      98 /Users/ginalevy/Sites/KindraApp/CLAUDE.md
```

### F1 duplicate block and its origin
Command: `grep -n "^## \|^# " ~/Sites/kindra/CLAUDE.md` (excerpt)
```
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
```
Command: `comm -12 <(sed -n 1,438p CLAUDE.md | grep -E '.{30,}' | sort -u) <(sed -n 439,503p CLAUDE.md | grep -E '.{30,}' | sort -u) | wc -l`
```
      34
```
Command: `git log --format='%h %ad %s' --date=short -L460,462:CLAUDE.md | grep -E "^[0-9a-f]{7,} " | tail -2`
```
bfd955c9 2026-01-31 feat(TASK-007): Completed Tab UI with table and event drawer
```

### F2 mobile-only sections in Sites CLAUDE.md
Command: `grep -n "^## \|^#### " claude-md/sites/CLAUDE.md` (excerpt)
```
192:## Mobile App — Not a Server
203:## Package Management — Expo Version Compatibility
219:## Dependency Health — Check the Foundation Before Building On It
253:# Code Quality
335:## Deployment
...
502:#### A documented config claim expires — re-verify before restating it
512:# Planning & Files
```

### F4 sibling overlap
Command: `comm -12 <(grep -E '.{40,}' skills/A/SKILL.md | sort -u) <(grep -E '.{40,}' skills/B/SKILL.md | sort -u) | wc -l`
```
pipeline (435) vs pipeline-light (368): 89 identical
cascade (187) vs cascade-light (180): 65 identical
pipeline (435) vs review-code (226): 44 identical
pipeline (435) vs pipeline-audit (230): 32 identical
```
Command: `grep -rl "Why this exists (2026-09-13)" agents skills claude-md`
```
agents/lesson-learner.md agents/plan-creator.md skills/pipeline/SKILL.md skills/review-plan/SKILL.md skills/review-code/SKILL.md skills/verify/SKILL.md skills/plan/SKILL.md skills/finalize-runbook/SKILL.md skills/finalize-plan/SKILL.md skills/review-runbook/SKILL.md skills/cascade/SKILL.md skills/pipeline-audit/SKILL.md skills/critique/SKILL.md skills/cascade-light/SKILL.md skills/pipeline-light/SKILL.md skills/pr-review/SKILL.md
```

### F5 shared incident stories
Command: `grep -rl "April 2026 donation-upsell incident" agents skills claude-md`
```
agents/plan-reviewer-3.md agents/plan-coder.md agents/plan-reviewer-2.md agents/verification-auditor.md agents/plan-reviewer.md agents/plan-creator.md skills/pipeline/SKILL.md skills/finalize-plan/SKILL.md skills/pipeline-light/SKILL.md
```

### F6 Sites vs kindra overlap
Command: `comm -12 <(grep -E '.{40,}' claude-md/sites/CLAUDE.md | sort -u) <(grep -E '.{40,}' ~/Sites/kindra/CLAUDE.md | sort -u) | wc -l`
```
      87
```

### F7 expiring claims
Command: `grep -rnoE "[A-Za-z_./-]+\.(ex|exs|js|jsx|ts|tsx|mm|kt|md|json|yaml):[0-9]{1,4}" agents skills/*/SKILL.md claude-md | cut -d: -f1 | sort | uniq -c | sort -rn`
```
   4 skills/pr-review/SKILL.md
   2 claude-md/sites/CLAUDE.md
   2 agents/plan-coder.md
   2 agents/env-var-auditor.md
   1 skills/pipeline-light/SKILL.md
   1 skills/finalize-plan/SKILL.md
   1 skills/critique/SKILL.md
   1 agents/plan-reviewer.md
   1 agents/plan-reviewer-3.md
   1 agents/plan-reviewer-2.md
   1 agents/plan-creator.md
   1 agents/code-quality-reviewer.md
   1 agents/code-quality-reviewer-2.md
```

### Incident paragraphs by month
Command: (Why-paragraph date extraction, see session) 
```
  11 April 2026
   8 May 2026
   5 June 2026
  14 July 2026
  15 August 2026
  90 September 2026
  18 October 2026 (9 days)
```

### F8 lesson-learner is append-only
Command: `grep -n -i "delete\|remove\|retire\|size\|budget\|merge\|consolidat" agents/lesson-learner.md`
```
79:- **NEVER duplicate.** Grep first, paste the evidence; refine an existing entry instead of adding a parallel one. ...
80:- **NEVER rewrite or reorganize a destination file.** Append-only edits at the stated insertion point.
```
(no match for delete / retire / size / budget)

---

## 8. Decisions needed from the owner
1. The size budgets in 4c (400 / 300 / 250 lines) — keep, raise, or lower.
2. The 3-month cutoff for compressing a "Why" paragraph (3b) — or a different age.
3. Whether Phase 1 runs as one `/pipeline-light` across three repos or as three small PRs (my recommendation: three PRs, one per repo, same day).
