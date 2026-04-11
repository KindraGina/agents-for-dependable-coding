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
