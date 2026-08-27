# Plan: `lesson-learner` — automatic lesson extraction after every pipeline / review run

**Date:** 2026-08-27
**Status:** DRAFT — awaiting user approval before implementation
**Repo:** `~/claude-pipeline-agents` (source of truth for agents + skills; symlinked into `~/.claude/`)
**Inspired by:** Fluent's "Learner" agent (github.com/mrinalwadhwa/fluent) — but with a human approval gate, consistent with this system's verification-first philosophy.

---

## Why

Today this system learns only from disasters: an incident happens, a human writes a post-mortem into CLAUDE.md. The one exception is `build-postmortem-updater`, which runs after every build and records patterns automatically. Every `/pipeline`, `/pipeline-light`, `/critique`, and `/pr-review` run also surfaces lessons (what reviewers caught, what took three rounds, what the human had to correct) — and today those lessons evaporate when the session ends.

`lesson-learner` generalizes the `build-postmortem-updater` pattern to all four skills, with one deliberate difference from Fluent: **it proposes; the human approves; only then does it write.**

## What exists today (original intent, behaviors to preserve)

- `agents/build-postmortem-updater.md` is the proven model: dedupe-before-write, append-only, "CLAAUDE.md only when broader than one pattern", never rewrite/reorganize, sanitize secrets. All of those rules carry over.
- The four target skills each end with a fixed final sequence (verified below). The Learner must be added AFTER each skill's existing final step, must not alter any existing phase, gate, or rule, and must never block completion — if the Learner fails, the run still reports success and the failure is mentioned.
- Pipeline rule preserved: "USE THE AGENT TOOL FOR EVERY PHASE. Never do the work yourself" — the Learner is an agent launched by the orchestrator, and it writes its own files (orchestrator never writes them for it).
- Pipeline autopilot rule preserved: the Learner's approval ask is added to the pipeline's explicit list of allowed stopping points (it is a new, sanctioned stop — see Step 3).

## Design

### New agent: `agents/lesson-learner.md`

Frontmatter: `tools: Read, Grep, Glob, Bash, Write, Edit` , `model: opus` (same tool set as build-postmortem-updater, which it is modeled on).

**Two modes, passed in the prompt:**

**Mode 1 — PROPOSE (default).** Inputs: the plan/review file path(s) from the just-finished run, the repo path, and the orchestrator's one-paragraph summary of what happened (rounds, issues caught, human corrections). Process:
1. Read the run's artifacts (plan file, review files, critique/pr-review file).
2. Identify candidate lessons in three buckets:
   - **Repo lesson** → destination: that repo's `CLAUDE.md`
   - **Process lesson** (about how the pipeline/skills/agents behave) → destination: the relevant `SKILL.md` or agent `.md` in `~/claude-pipeline-agents`; if none fits, `~/claude-pipeline-agents/docs/lessons.md` (created on first use, append-only)
   - **User-preference lesson** → destination: a memory file under `~/.claude/projects/-Users-ginalevy/memory/`
3. **Dedup with pasted evidence (hard rule):** for each candidate, grep the destination file(s) AND `MEMORY.md` for related content, and paste the raw grep output in the proposal. A lesson without pasted dedup evidence is invalid. If an existing entry already covers it, propose refining that entry or propose nothing.
4. Write proposals to `[plan-directory]/[plan-name]-lessons.md` (same directory convention as reviews/critiques). Format per lesson: **the rule (one sentence)** / **why (one sentence, with date)** / **how to apply (one sentence)** / **destination file + exact insertion point** / **dedup evidence (raw grep output)**.
5. **0–3 lessons maximum. Zero is a valid and common outcome.** No manufactured lessons — a routine run that went cleanly teaches nothing and the proposal file says exactly that.

**Mode 2 — APPLY.** Input: the proposal file path and the list of lesson numbers the user approved. Process: apply ONLY the approved lessons as append-only edits (3–8 lines each) at the stated insertion points; never rewrite or reorganize a destination file; then `cd ~/claude-pipeline-agents && git add/commit/push` if any file in that repo changed (repo CLAUDE.md and memory edits are NOT committed by the agent — those repos/dirs have their own workflows). Report a diff summary.

**Hard rules (inherited from build-postmortem-updater, restated in the agent file):** never duplicate (grep first, refine instead), append-only, never include secret values, sanitize quoted output, never write to any file outside the three destination types.

### Skill edits (one short block appended to each)

Identical block, adapted per skill, added as a new final step:

> **Final step — Lessons (never blocks completion).** Launch the `lesson-learner` agent in PROPOSE mode with [the run's file paths + summary]. When it returns, show the user the numbered proposals (or "no lessons proposed") and ask in plain text: *"Apply any of these? (e.g. 'apply 1 and 3', or 'skip')"*. On approval, re-launch `lesson-learner` in APPLY mode with the approved numbers. On 'skip' or no reply, do nothing — the proposal file remains on disk. If the Learner errors, say so and finish normally.

- `skills/pipeline/SKILL.md` — after the Phase 6 summary ("Would you like to commit these changes?"); also add the Learner ask to the autopilot rule's list of allowed stops.
- `skills/pipeline-light/SKILL.md` — same two edits.
- `skills/critique/SKILL.md` — after the critique verdict is presented.
- `skills/pr-review/SKILL.md` — after Step 3 (review written/posted).

### Symlink

New agents are exposed via symlink (same pattern as existing pipeline agents):
`ln -s ~/claude-pipeline-agents/agents/lesson-learner.md ~/.claude/agents/lesson-learner.md`
Also update the symlink list in `~/CLAUDE.md` ("Pipeline Agents — Source of Truth" section) to include `lesson-learner`.

## Implementation steps

1. Write `agents/lesson-learner.md` (full agent per the design above, ~120 lines, mirroring build-postmortem-updater's structure: Why You Exist / Files You Maintain / Inputs / Process / Hard Rules).
2. Create the symlink; verify with `ls -l ~/.claude/agents/lesson-learner.md`.
3. Append the Learner block to the four SKILL.md files; in pipeline + pipeline-light, extend the autopilot allowed-stops sentence.
4. Update `~/CLAUDE.md` symlink list (Edit, append `lesson-learner` to the agents line).
5. Commit + push `~/claude-pipeline-agents` to origin main.
6. **Verification (in place of automated tests — this repo is markdown-only, no test suite exists; `ls ~/claude-pipeline-agents` shows only `agents/ docs/ skills/ templates/ README.md`):**
   - Dry-run: launch `lesson-learner` in PROPOSE mode against an already-completed plan (e.g. a recent plan + critique in `kindra/docs/plans/`) and confirm: proposal file created in the right directory, ≤3 lessons, every lesson has pasted dedup evidence, zero-lesson outcome handled.
   - Confirm the four SKILL.md files still load (invoke each skill's name check / read frontmatter).
   - First real run: the next `/pr-review` exercises the full propose→approve→apply loop.

## Behaviors to preserve (checklist)

- [ ] No existing phase, gate, reviewer loop, or rule in any of the 4 skills is modified — the Learner is purely additive at the end.
- [ ] A Learner failure never changes a run's verdict or blocks its summary.
- [ ] Nothing is written to CLAUDE.md / skills / memory without explicit per-run user approval.
- [ ] Dedup-with-pasted-evidence before every proposal (Rule 1/Rule 7 discipline applies to the Learner itself).
- [ ] build-postmortem-updater is untouched (build lessons keep flowing through it; the Learner skips build-pattern-shaped lessons and defers to patterns.md).

## Verified References

### The repo has no docs/ dir yet and no test suite
Command: `ls ~/claude-pipeline-agents/`
Raw output:
```
agents
README.md
skills
templates
```
(docs/plans/ is created by this plan file itself.)

### build-postmortem-updater exists and is the structural model
Command: `Read ~/.claude/agents/build-postmortem-updater.md` (symlink → this repo)
Raw output (lines 1–6):
```
---
name: build-postmortem-updater
description: Post-build agent that records what was learned. Runs after every build (success or failure). Appends new patterns to ~/.claude/skills/build-app/patterns.md so future builds catch the same issue at pre-flight, and adds CLAUDE.md guidance only when the lesson is broader than a single pattern. Avoids duplicates. Used by the /build-app skill.
tools: Read, Write, Edit, Grep, Glob, Bash
model: opus
---
```
Its Hard Rules section (lines 133–141) includes: "**NEVER duplicate a pattern.** Always grep for the log signature first", "**NEVER rewrite or reorganize patterns.md or CLAUDE.md.** Append-only edits", "**NEVER include secret values**".

### /pipeline's final step and insertion point
Command: `tail -40 ~/claude-pipeline-agents/skills/pipeline/SKILL.md`
Raw output (excerpt — the end of Phase 6 "Step 3: Show the summary", which the Learner block follows):
```
Then show the rest:
- Branch and repo
- Phase table (rounds and results)
- Deleted files count
- Key issues caught and fixed
- Agent accountability
- Files in docs/plans/
- "Would you like to commit these changes?"
```
And the autopilot rule to extend:
```
- **THIS IS AUTOPILOT MODE. Never ask "shall I proceed?", "shall I launch?", or "shall I continue?". Just show a brief status update and immediately move to the next step.** The only times you stop and ask the user are: the Phase 2 circuit breaker (plan over 600 lines, or entering review round 4), the observation re-check (revision shifted the plan's primary work away from the observed symptom), the safety valves (round 6 for reviews, round 4 for post-implementation gate, round 3 for final audit), or an agent reporting a problem.
```

### /pipeline-light has the same summary ending and autopilot rule
Command: `tail -25 ~/claude-pipeline-agents/skills/pipeline-light/SKILL.md`
Raw output (excerpt):
```
- Files in docs/plans/
- "Would you like to commit these changes?"
```
```
- **THIS IS AUTOPILOT MODE. Never ask "shall I proceed?", "shall I launch?", or "shall I continue?".** Just show a brief status update and immediately move to the next step. The only time you stop and ask the user is at the safety valve (round 6 for reviews, round 4 for post-implementation gate, round 3 for final audit) or if an agent reports a problem.
```

### /critique's ending (verdict + file save convention)
Command: `tail -30 ~/claude-pipeline-agents/skills/critique/SKILL.md`
Raw output (excerpt):
```
- **Save the critique file to the same directory as the plan.** The pattern is `[plan-name]-critique.md`. Future runs will look for it there.
```
The Learner block goes after the critique verdict is shown, reusing this same-directory convention for `-lessons.md`.

### /pr-review's ending (Step 3 writes the review)
Command: `Read ~/.claude/skills/pr-review/SKILL.md` (full read this session, lines 217–219)
Raw output:
```
### Step 3 — Write the review

Save to: `/tmp/pr-review-[number].md` (or print to the conversation if the user prefers — ask if unsure).
```
The Learner block becomes a new "Step 4 — Lessons" after this. (For /pr-review the proposal file goes next to the review file in /tmp.)

### File counts of the four skills (size sanity for the appended block)
Command: `wc -l ~/claude-pipeline-agents/skills/pipeline/SKILL.md ~/claude-pipeline-agents/skills/pipeline-light/SKILL.md ~/claude-pipeline-agents/skills/critique/SKILL.md`
Raw output:
```
     407 /Users/ginalevy/claude-pipeline-agents/skills/pipeline/SKILL.md
     338 /Users/ginalevy/claude-pipeline-agents/skills/pipeline-light/SKILL.md
     237 /Users/ginalevy/claude-pipeline-agents/skills/critique/SKILL.md
```

## Decisions made (so they're on the record)

- **Human gate over Fluent-style auto-write** — matches this system's philosophy; cost is ~1 minute per run.
- **`/cascade` gets the Learner for free** — it ends by running `/critique`, so no separate cascade edit.
- **`/build-app` is excluded** — `build-postmortem-updater` already covers it; two learners on one run would double-write.
- **Proposal files are kept even when skipped** — they're cheap, and a future run's dedup grep can see them.

## Open questions

None — all design decisions are made above. Awaiting user approval to implement.
