---
description: What should I work on now? Reads the Kinlia Work Board and names the top three things to do, in plain English, from any terminal in any repo. Usage - /next
---

# Next — what do I do now?

Read the Kinlia Work Board and answer one question: what are the next three things to do?
It changes nothing in any repo. On the board it makes one kind of change, in Step 0.

**Why it exists (2026-11-23):** with work spread over four repos and dozens of terminals, the
owner could not tell what to finish next. The answer has to be the same from every terminal.

## Step 0 — Bring the board up to the checklist

The daily sweep (8:30 on the owner's Mac, `board-sync/daily-sweep.sh`) moves cards when a
PR merges, but it cannot read the team checklist. Only an open session can, so do it here:

1. Read the Pass / Fail / Skip marks as `~/.claude/skills/board-sync/SKILL.md` Step 2 describes.
2. For each card in **On Staging**: if every check for it is marked Pass, move it to
   **Passed Staging Test**. If a check is marked Fail, leave it and make its Next action
   name the failed check. Same for **On Production** and **Passed Production Test**.
3. Write those changes with `apply.sh` and tell the owner in one line what moved. Never move
   a card on a note or a guess: no marks, no move.

If `~/.cache/board-sync/daily-report.txt` lists new cards, say how many in one line; their
titles are GitHub's and want renaming.

## Step 1 — Read the board

```bash
N=$(gh project list --owner KindraConnect --format json --jq '.projects[] | select(.title=="Kinlia Work Board") | .number')
gh project item-list "${N}" --owner KindraConnect --limit 1000 --format json
```

Each item carries: `title`, `status`, `area`, `key`, `next action`, `waiting on`, `where`, `last touched`.

If the command fails or the board is empty, say exactly that and stop. Do not answer from
memory or from the current repo; a guess here sends a whole day in the wrong direction.

## Step 2 — Rank

Finishing comes before starting. Take cards in this order until there are three:

1. **On Staging** cards that another card names in its `waiting on` (they unblock the most).
2. Other **On Staging** cards, oldest `last touched` first. The job is to run the staging test.
3. **On Production** cards: run the production test.
4. **In Progress**, oldest `last touched` first.
5. **Has Plan**, then **Backlog/Todo**.

Skip:

- **Passed Staging Test** and **Passed Production Test**: nothing to do on the card itself.
- The roll-up cards whose Key ends `:note:release-backlog`: they are a count, not a task.
- Any card whose Next action begins "Deferred by owner". The owner already decided; do not re-raise it.
- Any card whose `waiting on` names a card that has not reached On Production. Say what it
  is waiting for only if the owner asks.

If the owner adds a word after the command (`/next frontend`, `/next backend`, `/next website`), rank only that Area.

## Step 3 — Answer

At most three items. For each: the card title, then its Next action in one plain sentence,
then where to do it (which repo or folder). No jargon, no code, no branch names unless the
Next action cannot be done without one.

Then one line of counts, for example:
`Board: 13 backlog · 3 has plan · 10 in progress · 21 on staging · 7 passed staging · 0 on production`

If **Passed Staging Test** holds cards and nothing is left in **On Staging**, say so in one
sentence: a release is the next step. Do not start one. Any push to `master` on the backend is
a production deploy and needs the owner's explicit yes.

If the newest `last touched` on the board is more than a week old, add one line: the board may
be stale, run `/board-sync`.

Nothing else. No headers, no explanation of the ranking.
