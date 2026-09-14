---
description: Create an implementation plan using the plan-creator agent with strict verified references. Use when you want a formal plan that will go through the pipeline.
---

# Create Plan

Launch the plan-creator agent to write a formal implementation plan with verified references.

## Usage

```
/plan [description of what to build or fix]
```

## What This Does

Launches the `plan-creator` agent as a subprocess with its full ruleset:
- Reads the actual codebase before writing any code snippets
- Verifies every function signature, return type, field name, and association
- Produces a `## Verified References` section with file:line evidence
- Single-repo only — flags cross-repo dependencies separately
- Writes to `docs/plans/YYYY-MM-DD-[feature-name].md`

## Your First Action

**Run `pwd` and `git branch --show-current`.** Show the user:
- "Working directory: [pwd output]"
- "Branch: [branch-name]"

Then launch the agent.

## Launch the Agent

Use the Agent tool to launch the `plan-creator` agent:
- Prompt: "You are the plan-creator agent. Create an implementation plan for: [user's description]. Write the plan to docs/plans/YYYY-MM-DD-[feature-name].md. Follow your instructions in .claude/agents/plan-creator.md."

## After the Agent Returns

1. Read the plan file the agent created.
2. Show the user:
   - Plan file path
   - The `## Summary` section
   - The `## Verified References` section (so the user can see what was verified)
   - Number of files to change
   - Whether tests are included
3. Ask: "Want to review this plan, run it through the pipeline, or make changes?"

## Plain-Language Reporting (MANDATORY)

The person reading your chat reports is not an engineer. Every message shown to the user in chat MUST follow these rules:

- Lead with the bottom line in one everyday sentence ("This change is safe to merge" / "I found 2 problems that must be fixed before this ships").
- Use everyday words. A technical term may appear only if it is immediately explained in plain words in parentheses — e.g. "the merge-base (the point where the PR branched off)". Otherwise leave it out.
- Never reference internal names the reader doesn't know — check numbers ("Check 6"), tier labels ("Tier 1"), agent or skill file names ("test-reviewer.md"), or section headings. Say what the thing does instead: "the step that checks whether tests were already failing before this change."
- Keep ALL the technical evidence (file:line citations, pasted code, raw test output) — but put it in the saved plan file, not the chat message. The chat message is the plain-language translation; the file keeps full rigor. Never weaken the file's rigor to satisfy this rule.
- When relaying another agent's findings to the user, translate them first — never paste agent-to-agent output into chat.
- End with the decision the user needs to make, as one plain question, with what each answer would mean.

**Why this exists (2026-09-13):** PR-review and lesson-learner reports were written engineer-to-engineer ("refine Check 6 — 'merge-base' appears nowhere") and the user could not tell what was being proposed or what decision they were being asked to make. The user is non-technical; a report the user cannot understand has failed, no matter how rigorous the work behind it.
