---
description: Run the verification auditor on a plan to check what was actually implemented vs what agents claimed. Use to audit a completed or partially completed plan, or before resuming work on a stalled plan.
---

# Verify

Run the verification auditor against a plan to get ground truth about what's actually done.

## Usage

```
/verify <path to plan file>
/verify docs/plans/2026-03-12-feature.md
```

If no path is provided, ask the user which plan to verify.

## CRITICAL RULES

**YOU ARE AN ORCHESTRATOR ONLY.** You launch the verification-auditor agent and report results. You do NOT verify anything yourself.

## Process

### Step 1: Launch the Verification Auditor

Launch the `verification-auditor` agent using the Agent tool:
- Prompt: "You are the verification-auditor agent running in Mode 1 (Post-Implementation Verification). Verify that every plan item at [plan-path] was actually implemented in the code. Check every file exists, grep for every change, cross-reference any verification summaries in the plan. Write your audit to [plan-path-without-ext]-verification-audit-r1.md. Follow your instructions in .claude/agents/verification-auditor.md."

### Step 2: Report Results

After the agent returns, read the audit file and show the user:

1. **Overall verdict: PASS or FAIL**
2. **Score: X of Y items verified**
3. **For each item:**
   - Item description
   - Claimed status vs actual status
   - PASS or FAIL
4. **If any items failed:** list them clearly so the user can decide what to do next

### Step 3: Offer Next Steps

Based on the results:

- **If all items PASS:** "All items verified. The plan is genuinely complete."
- **If some items FAIL:** Ask the user:
  - "Would you like me to create a new plan with only the failed items and run it through /pipeline?"
  - "Would you like me to just run /pipeline on the existing plan?" (will re-review and re-implement)
  - "Would you like to review the failures first before deciding?"

## Rules

- ALWAYS use the Agent tool to launch the verification-auditor. Never verify anything yourself.
- Show the user the results clearly — they need to understand exactly what's real and what's phantom.
- Do NOT automatically fix anything. Show the results and let the user decide.
- The audit file goes in the same directory as the plan.
