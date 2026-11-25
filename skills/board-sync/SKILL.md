---
description: Sweep every Kinlia repo and note file for unfinished work and bring the Kinlia Work Board up to date. Shows the proposed card changes and waits for a yes before writing anything. Usage - /board-sync
---

# Board Sync — make the board match reality

The Kinlia Work Board (GitHub Project "Kinlia Work Board", owner `KindraConnect`) is the one
list of unfinished engineering work across backend, web, mobile and scraper. This skill
refreshes it. `/next` reads it; `/wrap` adds to it one terminal at a time.

**Why it exists (2026-11-23):** unfinished work lived only in terminal scrollback, memory
notes and ~95 worktrees, so terminals were kept open as reminders and ~87 sessions piled up.

**Cardinal rule: every card states the evidence that put it in its column.** A commit, a PR
number, or the note file and its date. A card sorted from memory is a guess; say so or leave it out.

**What keeps the board current (owner, 2026-11-25).** Three things, so nobody has to remember:
`daily-sweep.sh` runs at 8:30 every morning on the owner's Mac (launchd job
`life.kinlia.board-sweep`, report in `~/.cache/board-sync/daily-report.txt`): it moves cards
whose PR merged (`merge-sync.sh`) and adds a card for any PR or unsaved folder that has none.
`/next` applies the checklist's Pass/Fail marks. A session that merges a PR runs
`merge-sync.sh` straight after. This skill is the full, judged sweep on top of those.

This skill runs in the main session. It does not spawn agents and never invokes `/pipeline`,
`/cascade` or any other multi-agent skill.

## Step 1 — Collect the facts (read-only)

```bash
bash ~/.claude/skills/board-sync/collect.sh > "<scratchpad>/sweep.json"
```

One JSON object per repo: every worktree (`dirty_tracked`, `dirty_untracked`, `unpushed`,
`on_staging`, `on_production`, `ahead_of_production`, `last_commit`), open PRs, stash count,
and `staged_not_released` (merges on the staging branch that production does not have).
Staging and production branch names differ per repo and are set at the top of the script:

| Repo | Staging | Production |
|---|---|---|
| kindra | develop | master |
| KindraApp | testflight | master |
| kinlia-web | staging | production |
| event_scraper | none | main |
| claude-pipeline-agents | none | main |

## Step 2 — Read the notes (read-only)

Git cannot see a staging check that is owed or a decision that is pending. Read:

- each project's memory index and the files it links: `~/.claude/projects/*/memory/MEMORY.md`
- each repo's `docs/TODO.md`
- the team's test checklists, which are claude.ai Artifacts ("Kinlia Backend Release
  Checklist", the "Build NNN QA" pages). Find them with the Artifact tool's `list`, read
  the page for the check numbers and which PR each belongs to, and read the `marks`
  collection with `ArtifactData` for Pass / Fail / Skip.

**The checklist marks decide "Passed Staging Test", not the memory notes.** A card goes to
Passed Staging Test only when every check for it is marked Pass on the checklist. Unmarked,
Skipped or Failed keeps it in On Staging, with the open check numbers in the Next action;
a Fail is named as a fail. (2026-11-25: the first sort used notes only. The owner doubted
it, and the checklist showed Partial refunds with none of its ten checks marked and the
member-profile fix with two checks failed.)

A note is a claim with a date, not a fact. Where a note says "not on master", confirm it against
`staged_not_released` in the sweep before repeating it.

## Step 3 — Read the board

```bash
bash ~/.claude/skills/board-sync/list-items.sh
```

Always read the board with `list-items.sh`, never `gh project item-list`: the gh command costs about 300 of GitHub's 5,000 hourly points per read on this board (measured 2026-11-25) and emptied the allowance for every terminal; `list-items.sh` returns the same JSON for about 2.

## Step 4 — Decide the cards

### One card per piece of work, not per commit

A card is something a person would name as one job: "Partial refunds", "Scraper canary".
Several PRs and worktrees for the same job share one card; list them in the body.

Work that is merged to staging, has no check owed and no note about it does NOT get its own
card. It is counted on one roll-up card per repo, `<repo>:note:release-backlog`
("Release backlog: N merges on staging, not on production"), with the list in the body.

### Key — the card's identity

Look a card up by Key before creating anything. One Key per card.

| Kind | Key | Example |
|---|---|---|
| Pull request | `<repo>:pr:<number>` | `kindra:pr:2112` |
| Branch or worktree with no PR | `<repo>:branch:<branch>` | `kindra:branch:commcreation` |
| Note-only follow-up | `<repo>:note:<short-slug>` | `kindra:note:stripe-live-key-rotation` |

`<repo>` is the folder name of the main checkout. When a branch gets a PR, re-key the existing
card (`new_key`); do not make a second one.

### The description — what the owner reads when she opens a card

Every card's body is written for someone who has never seen the work, in plain English with
no code, file names or branch names in the first three parts:

```
**What this is:** what the work does, as a user or the owner would describe it.
**Why it matters:** who is affected or what goes wrong without it.
**Where it stands:** built? on staging? which checks passed, failed or are unmarked, and by whom.
**What to do next:** the very next step and who does it.
**Where the work is:** folder and branch, if it lives on this Mac.
**Links:** the pull request(s).
```

Evidence ("sweep 2026-11-23: unpushed=1") is not a description. Before writing "What this
is", read the PR description, the plan, or the commits; if it is still a guess, say "inferred
from ...". (2026-11-25: the owner opened "Event tags (mobile)", saw only an evidence line, and
could not tell what it was. It turned out to be one unpushed TODO note on a branch that
merely had that name.) `apply.sh` rewrites the title and body of an existing draft card.

### Titles and card type

Write every card as a draft card with a plain-English title the owner would recognise
("Partial refunds", not "PR #2106 feat/partial-refund"), and put the PR link in the body.
A real PR item (`pr_url`) shows GitHub's own title, which the owner cannot read at a glance,
so use it only when she asks for it. The Key still uses the `pr` form.

A branch that was squash-merged looks unmerged to git (`on_staging: false`). Before calling
such a branch unfinished, look for its PR number in `staged_not_released`.

### Status — the board's columns

The owner set these seven columns on 2026-11-25. They follow a piece of work from idea to
checked-on-production, so finished work stays visible instead of vanishing.

| Evidence | Status |
|---|---|
| Idea, note or TODO entry; no plan file | Backlog/Todo |
| A plan file exists in `docs/plans/`; no code yet | Has Plan |
| Tracked files edited, commits unpushed, or an open PR | In Progress |
| Merged to the staging branch; staging test not recorded as passed | On Staging |
| On staging and the staging test is recorded as passed | Passed Staging Test |
| On the production branch; production test not recorded as passed | On Production |
| On production and the production test is recorded as passed | Passed Production Test |

- For KindraApp, `testflight` is the staging branch (owner decision 2026-11-23).
- A worktree whose only changes are untracked files is weak evidence. Look at what the files
  are before calling it In Progress; loose plan documents alone do not make a card.
- Deferred by the owner: Backlog/Todo or Has Plan, with "Deferred by owner <date>" opening
  the Next action. `/next` skips these, which is the point.
- Archive a Passed Production Test card on the sync after the one that put it there.
- The roll-up `release-backlog` cards sit in On Staging.

### Fields

- **Area:** Backend (kindra), Mobile (the mobile app, KindraApp), Website (kinlia-web),
  Skills pipeline (`~/claude-pipeline-agents`: skills, agents, rules), Scraper, Ops.
  The owner's names, 2026-11-25; "Frontend" and "Web" are old names for Mobile and Website.
- **Next action:** one plain sentence a non-engineer can act on. The very next step, not a summary.
- **Waiting on:** the title of the card that must ship first (cross-repo order lives here).
- **Where:** worktree path and branch, or the plan file.
- **Last touched:** date of the last commit or note update.

### Not a card

A worktree that is clean and already on production. Put it on a "looks finished, safe to
remove" list in the report. **Never remove a worktree, branch or stash from this skill** —
each removal is a separate decision for the owner.

## Step 5 — Show the proposal and STOP

Write the cards to `<scratchpad>/cards.json` (format documented at the top of `apply.sh`), then:

```bash
bash ~/.claude/skills/board-sync/apply.sh --dry-run "<scratchpad>/cards.json"
```

Show the owner a short table: new cards by Status, cards that move, cards to archive. For each,
one line of evidence. Then wait. **Write to the board only after the owner says yes.**

## Step 6 — Apply and report

```bash
bash ~/.claude/skills/board-sync/apply.sh "<scratchpad>/cards.json"
```

Then run it a second time with the same file. It must report `created: 0`. If it creates
anything, the Key lookup is broken: stop and say so.

Report in plain English: how many created, moved, archived; the "safe to remove" list; and
anything that could not be sorted, with the reason.

## What this skill may and may not touch

- May: read the repos and notes; `git fetch`; create, edit and archive cards on the board.
- May not: commit, push, delete, stash, close PRs, or edit any file in a product repo.
- Card text is visible to everyone invited to the board. No secrets, keys, passwords or
  customer details in a title, a field or a body.
