---
description: What should I work on now? Reads the Kinlia Work Board and names the top three things to do, in plain English, from any terminal in any repo. Usage - /next
---

# Next — what do I do now?

Read the Kinlia Work Board and answer one question: what are the next three things to do?
Read-only. It changes nothing on the board or in any repo.

**Why it exists (2026-11-23):** with work spread over four repos and dozens of terminals, the
owner could not tell what to finish next. The answer has to be the same from every terminal.

## Step 1 — Read the board

```bash
N=$(gh project list --owner KindraConnect --format json --jq '.projects[] | select(.title=="Kinlia Work Board") | .number')
gh project item-list "${N}" --owner KindraConnect --limit 1000 --format json
```

Each item carries: `title`, `stage`, `area`, `key`, `next action`, `waiting on`, `where`, `last touched`.

If the command fails or the board is empty, say exactly that and stop. Do not answer from
memory or from the current repo; a guess here sends a whole day in the wrong direction.

## Step 2 — Rank

Finishing comes before starting. Take cards in this order until there are three:

1. **Staging check owed** cards that another card names in its `waiting on` (they unblock the most).
2. Other **Staging check owed** cards, oldest `last touched` first.
3. **In progress**, oldest `last touched` first.
4. **Next up**.

Skip:

- **Inbox** and **Done**. Inbox is unsorted; it is not a to-do list.
- Any card whose Next action begins "Deferred by owner". The owner already decided; do not re-raise it.
- Any card whose `waiting on` names a card that is not Done. Say what it is waiting for
  only if the owner asks.

If the owner adds a word after the command (`/next mobile`, `/next backend`), rank only that Area.

## Step 3 — Answer

At most three items. For each: the card title, then its Next action in one plain sentence,
then where to do it (which repo or folder). No jargon, no code, no branch names unless the
Next action cannot be done without one.

Then one line of counts, for example:
`Board: 4 in progress · 9 staging checks owed · 3 ready for production · 6 next up · 12 inbox`

If **Ready for production** holds cards and nothing is in **Staging check owed**, say so in one
sentence: a release is the next step. Do not start one. Any push to `master` on the backend is
a production deploy and needs the owner's explicit yes.

If the newest `last touched` on the board is more than a week old, add one line: the board may
be stale, run `/board-sync`.

Nothing else. No headers, no explanation of the ranking.
