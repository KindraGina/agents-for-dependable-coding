# Agents for Dependable Coding

A team of AI agents and orchestration skills for Claude Code that automate code planning, review, testing, and verification — with layered auditing to catch both incorrect code and dishonest agent claims.

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

## How It Works

### Before the pipeline even starts

**`/finalize-plan`** — 13-check gate that proves the plan was written from reading actual code, not from memory. Catches wrong field names, wrong return types, contradictions, missing test plans. Nothing enters the pipeline without passing this.

### The full `/pipeline` flow (10 agents, sequential)

1. **Pre-flight** — refuses protected branches, checks for uncommitted entanglements, confirms the code the plan targets actually exists on this branch.
2. **Plan review loop** — 3 reviewers, each with a different lens (completeness/architecture, cross-project/data-model, production-risk/deployment). They partition the Verified References so every code claim is checked. Loops with plan-creator revisions until all 3 approve.
3. **Implementation** — plan-coder implements using strict TDD (tests first, then code, then lint, then smoke test with real data, then self-verification with pasted grep evidence).
4. **Post-implementation verification** — the "lie detector" auditor confirms everything the coder claimed actually exists in the code. Phantom file detection runs first and is terminating.
5. **Code review loop** — 2 reviewers, one auditing the other. They run the full test suite themselves, run lint themselves, and do plan-to-code verification.
6. **Test review loop** — 2 reviewers asking "could this test pass with broken code?" They independently `ls -la` every test file and paste raw terminal output.
7. **Final audit** — the verification auditor re-runs, this time checking all 9 agents' claims. Marks each HONEST or DISHONEST.

### `/pipeline-light`

Same gates and auditor, but 1 reviewer per stage instead of 2-3. About 3-4x cheaper. Good for single-file fixes under ~50 lines.

### `/cascade`

Chains finalize → pipeline (auto-chosen) → critique in one command so you don't have to invoke each step manually.

### `/critique` — Adversarial post-pipeline audit

Runs after the pipeline finishes and acts as an independent outsider who owes the pipeline nothing. Its loyalty is to the user's intent.

The key distinction: the verification-auditor (inside the pipeline) catches **lies** — agents claiming work they didn't do. `/critique` catches **bad judgment** — agents who did what they claimed, but the result is still wrong.

What it actually does, step by step:

1. **Reads the entire plan fresh** — including every override, user quote, and "must not default" marker. It's building a checklist of "what did the user actually ask for?"
2. **Reads every review and audit file** the pipeline produced — noting what issues were raised, what escalated, and what got dismissed.
3. **Phantom file check** — independently runs `ls -la` on every file the pipeline claimed to create or test. If any don't exist, automatic REJECT.
4. **Live feature verification** — if the plan has Live Verification Steps, the critique agent executes them against real data itself. If any fail, automatic REJECT ("the pipeline passed all checks but the feature doesn't actually work").
5. **Interaction-change verification gate** — if the diff touches anything a user types into or taps, and nobody actually tested it on a device/simulator, the verdict is capped at CONCERNS (cannot approve). It writes a manual test script for you instead.
6. **Plan-vs-code fidelity** — for every user override and every plan item, finds the corresponding code and verdicts it: HONORED / VIOLATED / NOT IMPLEMENTED.
7. **Process critique** — checks for dismissed escalations still open, contradictions that shipped, scope creep (files changed that weren't in the plan), decisions the coder was told to ask about but defaulted on instead, and hand-waved resolutions without evidence.

Three possible verdicts:

- **APPROVE** — plan honored, no scope creep, no contradictions, code matches plan, all interactions verified.
- **CONCERNS** — minor issues, recommend cleanup but shippable.
- **REJECT** — user intent violated, contradiction shipped, phantom files, or significant scope creep.

The critique is what makes `/cascade` a full loop: finalize (is the plan grounded?) → pipeline (build and review it) → critique (did the pipeline actually deliver what you asked for?).

### Every rule traces back to a real incident

The rules in this system weren't designed theoretically — each one exists because something went wrong without it. Phantom file detection exists because 5 agents fabricated test output for a file that never existed. The scope freeze exists because a plan grew to 1,900 lines over 10 hours and the reported bug was never fixed. The "severity is not yours to assign" rule exists because reviewers invented "release-gating" severity for an unobserved finding.

---

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
- **Edit over Write for existing files.** The plan-coder must use the Edit tool (targeted replacement) instead of Write (full overwrite) when modifying existing files. Write destroys git's diff context, making PRs show entire files as deleted+added even when most content is unchanged.
