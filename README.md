# Claude Pipeline Agents

A team of AI agents and orchestration skills for Claude Code that automate code planning, review, testing, and verification.

## What This Is

This is a set of markdown-based agent prompts and skill playbooks that turn Claude Code into a multi-agent development pipeline. Each agent has a specific role and runs autonomously as a subprocess with its own tools.

## Architecture

```
/pipeline (skill = orchestrator instructions)
  └── Claude Code (follows the skill, acts as orchestrator)
        ├── Agent: plan-creator
        ├── Agent: plan-reviewer (×3 reviewers)
        ├── Agent: plan-coder
        ├── Agent: verification-auditor
        ├── Agent: code-quality-reviewer (×2 reviewers)
        └── Agent: test-reviewer (×2 reviewers)
```

## Agents (`agents/`)

| Agent | Role |
|-------|------|
| `plan-creator` | Creates implementation plans from requirements. Single-repo only. |
| `plan-reviewer` | First plan reviewer — completeness, architecture, feasibility |
| `plan-reviewer-2` | Second plan reviewer — audits plan AND reviewer 1's feedback |
| `plan-reviewer-3` | Third plan reviewer — real-world impact, deployment risk |
| `plan-coder` | Implements plans using TDD. Also fixes code from reviewer feedback. |
| `verification-auditor` | Verifies every agent's claims against actual code. Catches phantom implementations. |
| `code-quality-reviewer` | First code reviewer — correctness, security, quality |
| `code-quality-reviewer-2` | Second code reviewer — audits code AND reviewer 1's findings |
| `test-reviewer` | First test reviewer — coverage, quality, runs actual tests |
| `test-reviewer-2` | Second test reviewer — audits tests AND reviewer 1's findings |
| `runbook-reviewer` | Reviews ops runbooks (AWS CLI sequences, deployment procedures, manual migrations) for command correctness, bundled mutations, missing flags, and fragile rollbacks |

## Skills (`skills/`)

### Full Pipelines

| Skill | Usage | What It Does |
|-------|-------|-------------|
| `/pipeline` | `/pipeline docs/plans/my-plan.md` | Full autopilot: plan → review → code → verify → review → verify |
| `/pipeline-light` | `/pipeline-light docs/plans/my-plan.md` | Lean pipeline for small, low-risk changes. Same safety gates, one reviewer per stage instead of 2-3. Roughly 3-4x cheaper than `/pipeline`. |
| `/cascade` | `/cascade docs/plans/my-plan.md` | End-to-end chain: finalize-plan → pipeline (or pipeline-light) → critique. Run after you and the plan-creator have finished drafting. |
| `/pipeline-audit` | `/pipeline-audit docs/plans/stalled-plan.md` | Resume a stalled plan: verification audit → new scoped plan from failures → clean pipeline run |

### Plan Creation & Review

| Skill | Usage | What It Does |
|-------|-------|-------------|
| `/plan` | `/plan docs/plans/my-plan.md` | Create a formal implementation plan using plan-creator with strict verified references |
| `/finalize-plan` | `/finalize-plan docs/plans/my-plan.md` | Pre-pipeline gate. Verifies plan completeness, pasted evidence for every code reference, no contradictions, no cross-repo bleed. Run AFTER drafting, BEFORE `/pipeline`. |
| `/review-plan` | `/review-plan docs/plans/my-plan.md` | Human-in-the-loop plan review (you decide what to change each round) |

### Code Review & Verification

| Skill | Usage | What It Does |
|-------|-------|-------------|
| `/review-code` | `/review-code docs/plans/my-plan.md` | Code + test reviews with verification gates (skips plan review) |
| `/verify` | `/verify docs/plans/my-plan.md` | Verification audit only — see what's actually done vs. claimed |
| `/critique` | `/critique docs/plans/my-plan.md` | Adversarial post-pipeline audit. Reviews the plan, code, and pipeline process with fresh eyes. Run AFTER `/pipeline` completes. |
| `/pr-review` | `/pr-review <PR-URL-or-number>` | Review a GitHub PR: reads diff, traces callers, runs tests, audits for security, anti-patterns, and PR hygiene |

### Runbook Skills

| Skill | Usage | What It Does |
|-------|-------|-------------|
| `/finalize-runbook` | `/finalize-runbook docs/runbooks/my-runbook.md` | Pre-execution gate for ops runbooks. Verifies state claims, single-mutation commands, recovery paths. Different from `/finalize-plan` (which is for code-change plans). |
| `/review-runbook` | `/review-runbook docs/runbooks/my-runbook.md` | Substantive runbook review by the runbook-reviewer agent. Human-in-the-loop — one round at a time. Catches AWS command issues, bundled mutations, fragile rollbacks. |

### Utilities

| Skill | Usage | What It Does |
|-------|-------|-------------|
| `/terminal-color` | `/terminal-color blue` | Change Terminal.app background color to visually distinguish terminals. Supports: red, orange, yellow, green, blue, purple, pink, gray, dark, light, reset, or hex codes. |

## Installation

Copy the `agents/` and `skills/` directories into your project's `.claude/` directory:

```bash
cp -r agents/ /path/to/your/project/.claude/agents/
cp -r skills/ /path/to/your/project/.claude/skills/
```

Then use them in Claude Code from that project directory.

## Key Design Decisions

- **Reviewers run sequentially, not in parallel.** Reviewer 2 reads reviewer 1's output — this catches more issues.
- **Verification auditor runs twice** — post-implementation gate and final audit. Agents can't claim "done" without proof.
- **Single-repo plans only.** Cross-repo dependencies are listed as informational, never acted on.
- **Browser testing required.** Web changes need Playwright. Mobile changes need Maestro. No "verified" claims without runtime evidence.
- **Agents must show evidence.** Test reviewers paste raw terminal output. Code reviewers run actual builds. No summaries accepted as proof.
