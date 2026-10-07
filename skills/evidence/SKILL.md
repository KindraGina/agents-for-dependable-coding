---
description: Audit the most recent cause claim in this conversation. Every "the reason is / because / it happened when" sentence must be backed by checkable evidence or rewritten as a hypothesis or "I don't know yet". Also checks whether the session asked the user what they did before the bug, and whether any fix was started before approval. Fires automatically on bug-report prompts via the UserPromptSubmit hook; run /evidence manually when a cause is stated later in a conversation.
---

# Evidence — No Cause Without Proof

A stated cause is a claim. A claim with no evidence is a story. Stories cost more trust
than "I don't know yet." This skill turns every cause statement into something the user
can check.

## When this runs

- **Automatically:** the `evidence-trigger.sh` UserPromptSubmit hook injects this skill
  when a prompt looks like a bug report ("what happened to", "why is", "missing",
  "not showing", "broken", "disappeared", "doesn't work", "stopped working").
- **Manually:** the user types `/evidence` at any point after a cause has been stated.

## Instructions

### Step 1 — Find the cause claims

Identify every sentence in your most recent explanation (or the one you are about to
write) that asserts why something happened. Trigger phrases: "the reason is", "because",
"it happened when", "the cause is", "your screenshot caught", "it was loaded before",
"it's actually there", "that request is slow".

If you have not yet stated a cause, do Step 3 first, then write your explanation
through the table in Step 2.

### Step 2 — Classify each claim

Produce this table. One row per claim. No row may be skipped.

| Claim | Status | Proof |
|---|---|---|
| (the sentence, quoted) | Verified / Unverified / Unknown | (see rules) |

**Verified** — the Proof column contains one of:
- a file path and line with the actual code pasted in a fenced block (read THIS session)
- a log line, console message, or network request pasted verbatim
- the user's own words about what they did, quoted
- `git log` / `git blame` output pasted, for regressions

**Unverified** — you have a plausible mechanism but none of the above. The claim is
rewritten in your reply as: "I haven't confirmed this, but my hypothesis is X. The one
thing I will check next is Y." Then check Y before saying anything else.

**Unknown** — you have no mechanism. The reply says "I don't know yet" and asks the user
one question: "What did you do just before this?"

"It works when I load it" is a single data point. It is never Proof for why it failed
for the user. A fresh load by the session says nothing about the user's path.

### Step 3 — The question you must ask before explaining

Confirm in one line that you have asked the user what they did immediately before the
bug appeared (which screen, which action, which flow). If you have not, ask now and do
not explain anything until they answer. One question early beats an invented story.

### Step 4 — Fix-in-flight check

Run:

```bash
git status --short; git log --oneline -3; git branch --show-current
gh pr list --author @me --state open 2>/dev/null | head
```

If any edit, commit, push, or PR related to this bug exists and the user has not said
"go" / "build it" / "start implementing", report it at the top of your reply:
"A fix is already in flight without approval: <branch / PR>. Stopping. Keep or discard?"
Do not continue coding.

### Step 5 — Verdict

End with one of:
- **Cause verified.** Then, and only then, propose a fix and wait for approval.
- **Cause unverified.** State the hypothesis as a hypothesis, name the next check, run it.
- **Cause unknown.** Say so. Ask the user what they did. Stop.

## Why this exists

**2026-10-07, kinlia-web, Leaders & hosts card.** The card was missing for the owner right
after she created a community. The session saw the card on its own fresh load and told
her "your screenshot caught the page before the data loaded" as if verified. It was
invented. Before she pushed back, the session had already coded a placeholder fix,
committed, pushed, and opened PR #214 — a second violation ("never start coding until
we have agreed") that would have exposed the guess had the gate been respected. The real
cause (the leader list loads only on page mount, so a just-created community never
fetches it until a reload) took three minutes in the code once she said "DO NOT LIE TO
ME." Her request afterwards: "How do I stop you from inventing stories?" This skill is
the answer — the evidence table, not a promise.

Related rules: `~/Sites/CLAUDE.md` → "ALWAYS VERIFY ASSUMPTIONS", Bug Investigation
Checklist item 7 (origin before fix), Plan Verification Rule 7 (code claims need pasted
evidence). Memory: `feedback-no-fabricated-reasons`, `evidence-before-explanation`.
