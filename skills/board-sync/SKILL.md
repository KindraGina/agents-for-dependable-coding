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

## Step 2 — Read the notes (read-only)

Git cannot see a staging check that is owed or a decision that is pending. Read:

- each project's memory index and the files it links: `~/.claude/projects/*/memory/MEMORY.md`
- each repo's `docs/TODO.md`

A note is a claim with a date, not a fact. Where a note says "not on master", confirm it against
`staged_not_released` in the sweep before repeating it.

## Step 3 — Read the board

```bash
gh project list --owner KindraConnect --format json --jq '.projects[] | select(.title=="Kinlia Work Board") | .number'
gh project item-list <number> --owner KindraConnect --limit 1000 --format json
```

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

### Stage

| Evidence | Stage |
|---|---|
| Tracked files edited, commits unpushed, or an open PR | In progress |
| On staging, not on production, and a note says a check is owed | Staging check owed |
| On staging, not on production, the owed checks are recorded as passed | Ready for production |
| Plan or TODO entry only, and the owner has said it is next | Next up |
| Anything else unfinished, including work the owner deferred | Inbox |
| On production | Done, then archive on the following sync |

- For KindraApp, `testflight` is the staging branch (owner decision 2026-11-23).
- A worktree whose only changes are untracked files is weak evidence. Look at what the files
  are before calling it In progress; loose plan documents alone do not make a card.
- Deferred by the owner: Inbox, with "Deferred by owner <date>" opening the Next action.
  `/next` skips these, which is the point.

### Fields

- **Area:** Backend, Web, Mobile, Scraper, Ops.
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

Show the owner a short table: new cards by Stage, cards that move, cards to archive. For each,
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
