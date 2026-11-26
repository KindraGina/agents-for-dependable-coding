---
name: intent-check
description: Run in the ORIGINAL planning terminal after /cascade or /cascade-light finishes in another terminal. Checks the finished work against everything said in this planning conversation. Does it actually solve the problem we discussed? Is anything we talked about missing from the plan or the code? It does not defend the plan; it looks for where the work falls short. Read-only. Usage - /intent-check [path to plan file]
---

# /intent-check: Does the finished work solve what we discussed?

## When to use this

The owner's workflow:
1. Discuss an issue and write a plan in one terminal (the planning session).
2. Run `/cascade` or `/cascade-light` on that plan in a second terminal.
3. Come back to the planning session and run `/intent-check`.

Every reviewer inside the cascade starts fresh and sees only the plan file and the code. **This session is the only one that heard the whole conversation.** Your job is to use that knowledge to check the result against what the owner actually asked for, not just against what got written down.

## THE CARDINAL RULE: DON'T DEFEND THE PLAN

You helped write this plan, so you are biased toward it. Correct for that:
- Your job is to find where the work falls short, not to explain why it is fine.
- Any "that's fine because..." needs evidence: a file and line, a test result, or the owner's own words. Without evidence, it is a gap. Report it.
- If something the owner asked for was dropped, narrowed or changed, say so plainly, even if the change was your idea.
- "The reviewers approved it" is not evidence that it solves the owner's problem. They never saw the conversation.

## Two kinds of sources. Keep them apart.

- **What was asked for** comes from THIS CONVERSATION: the owner's own words and the decisions made together. Quote the owner's words where you can. This is the one skill where the conversation is the source.
- **What was built** comes ONLY from files read in THIS run, never from memory of what the plan "should" say. Read the plan as it is now (the cascade may have revised it), the code changes, and the cascade's own reports.

**If this conversation was summarized** (a compaction summary appears earlier), early details may be lost. Say so at the top of the report, and ask the owner in one plain sentence whether anything important from early in the discussion is missing from your list.

## Process

### Step 1: List what was asked for (before reading any results)
Go back through this conversation and write the **promise list**: every problem the owner described, every behavior they wanted, every decision made together, every "don't do X", and every user-facing detail (what a real person sees or does). Number each item. Quote the owner's words where possible. Write this list BEFORE reading the cascade's output, so the results don't shape what you remember.

### Step 2: Read what was built
- Plan file: the argument, or the plan written in this conversation. Read it in full as it is NOW.
- Plan folder, next to the plan: `[plan-name]-critique.md` (verdict and concerns) and any review or audit files.
- The code: find the branch/worktree named in the plan (`git worktree list`). Run `git diff <base>...<branch>`, using the base the plan names (e.g. develop). Also run `git status` there, because the cascade often leaves work uncommitted. Read changed files in full where the diff is more than ~20 lines.
- Test results: quote the final pass/fail counts from the cascade's reports. Don't rerun the suite unless a number looks wrong.

If you can't find the cascade's output or the code, stop and ask the owner one plain question (for example: "Which folder did the cascade run in?"). Don't guess.

### Step 3: Check each promise
For each numbered item, record:
- **In the plan?** Quote the line, or write "missing".
- **In the code?** Give file:line plus the pasted code, or write "missing".
- **Tested?** Name the test, or write "no test".
- **Status:** Done / Partly / Missing / Changed. Changed means it was built differently from what was discussed. Say how.

### Step 4: Look for where it falls short
Beyond the promise list, look for:
- **Built but not asked for:** extra scope, or behavior changes the owner never discussed.
- **Meaning drift:** the plan solves a slightly different problem than the one described.
- **Unrun checks:** manual or staging checks the plan lists that nobody did yet.
- **Open owner decisions:** anything the cascade left for the owner.
- **The critique's concerns:** for each one, say whether it matters to the original problem.

### Step 5: Report in plain language
The owner is not technical. No jargon, no code in the summary, and no multiple-choice questions.

```
## Does it solve the problem?
<Yes / Partly / No, plus one or two plain sentences on why>

## What we discussed vs. what was built
<numbered promise list, one plain line each: Done / Partly / Missing / Changed, and what that means for a real user>

## Where it falls short
<each gap in plain words: what a user would see, and how serious it is>

## Not checked yet
<manual or staging checks still to do, and open decisions>

## My recommendation
<one sentence: what to do next>
```

Put the evidence (file:line and pasted code) in the saved file, not in the chat summary. Save the full report next to the plan as `[plan-name]-intent-check.md`.

## Rules
- **Read-only.** Don't edit code or the plan, commit, or rerun the cascade. Report and wait for the owner's go-ahead before fixing anything. A fix starts a new plan discussion, as usual.
- **No grading on effort.** A long, well-reviewed run that missed a promise is still "Partly".
- **No softening.** If the answer is "No", lead with "No".
