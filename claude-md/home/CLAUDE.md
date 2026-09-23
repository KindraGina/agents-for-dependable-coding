# Project Guide for Claude

## Your Rules

### NO MULTIPLE CHOICE QUESTIONS — EVER

**This is non-negotiable.** Do NOT use `AskUserQuestion` to present 2/3/4-option pick-lists. The user has asked for this rule repeatedly across many sessions and is tired of repeating it.

When you need user input, do ONE of these instead:
1. **Make the call yourself** — if you have enough context, decide and proceed.
2. **Ask ONE short open-ended question in plain text** — e.g. "Where are you testing this against?" Not a menu.
3. **State your recommendation in one sentence and proceed unless told otherwise.**

The ONLY exception: the user types "give me options" in the current turn. Otherwise, never.

This includes "soft" multiple choice — do not say "we could either A or B" and wait for an answer. Pick one or state your recommendation.

### Plan Mode — Do NOT auto-exit

**Before calling ExitPlanMode, always explain in plain text WHY you want to exit plan mode.** For example: "The plan is written and ready for your review — I'd like to present it for approval. After you approve, I will NOT start coding until you explicitly say 'start implementing' or similar."

This exists because ExitPlanMode triggers a plan approval flow, and the user needs to understand that approving the plan does NOT mean coding starts immediately. Coding only begins when the user explicitly says to start.

### Auto Tab & Session Naming (MANDATORY FIRST ACTION)

**This is your VERY FIRST action in EVERY conversation — before reading files, before answering questions, before anything else.** No exceptions. The user cannot find terminals without repo labels and has asked for this repeatedly.

1. **Tab title (top):** Detect the repo and branch automatically, then call `/tab-rename repo | branch`. If not inside a git repo, use `home | ~`.
2. **Session name (bottom status line):** Use `/rename` to set the topic once it's clear.

**Sequence — do this BEFORE any other work:**
```
/tab-rename <detected-repo> | <detected-branch>
```
Then once the topic is clear:
```
/rename <short topic description>
```

**Status line format:** `📍 Topic | branch | last active date`

**If you skip this, the user will not be able to find this terminal among 50+ open tabs. This causes real pain. Do it first, every time.**

## NEVER auto-invoke multi-agent skills

You may NEVER programmatically invoke `/pipeline`, `/pipeline-light`, `/critique`, `/pipeline-audit`, or any other multi-agent orchestrator skill from inside a main-session conversation unless the user EXPLICITLY named the skill in their current message.

"Continue" / "proceed" / "go ahead" / "yes" / "do it" are NOT explicit invocation of a multi-agent skill, even if the previous turn proposed it. Multi-agent skills burn tokens, modify files, and commit/push code — they need a deliberate, named invocation each time.

If you proposed running a pipeline and the user replied ambiguously, you must ASK: "Should I run `/pipeline` on [plan]? Reply with `yes /pipeline` to confirm." Do not interpret ambiguous replies.

**Exception — `/cascade`:** when the user explicitly types `/cascade`, that single named invocation authorizes the cascade's documented stages (`/finalize-plan`, `/pipeline` or `/pipeline-light`, `/critique`) for that run only. The cascade must still announce which pipeline it chose before Stage 2 so the user can override, but it does not need a fresh "yes /pipeline". This exception applies only to `/cascade` itself — no other skill or ambiguous reply inherits it.

## Pipeline Agents — Source of Truth

**THE RULE — every custom agent and skill lives in the repo. No exceptions, no list to consult.**

Everything under `~/.claude/agents/` and `~/.claude/skills/` is a **symlink** into the GitHub-connected repo at `~/claude-pipeline-agents/` (GitHub: `github.com/KindraGina/agents-for-dependable-coding`). The repo is the source of truth. Editing through the symlink IS editing the repo — no copy step needed. After editing: `cd ~/claude-pipeline-agents && git status`, then commit + push to `origin main`.

**CREATING A NEW SKILL OR AGENT — write it in the REPO, then symlink.** Never `mkdir` + `Write` directly into `~/.claude/skills/` or `~/.claude/agents/`. The correct sequence is:

```bash
mkdir -p ~/claude-pipeline-agents/skills/<name>
# write ~/claude-pipeline-agents/skills/<name>/SKILL.md
ln -s ~/claude-pipeline-agents/skills/<name> ~/.claude/skills/<name>
cd ~/claude-pipeline-agents && git add skills/<name> && git commit && git push
```

A new skill is not finished until it is committed and pushed. "It works locally" is not done.

**VERIFY, don't assume.** To check whether something is backed up, resolve it — `python3 -c "import os,sys;print(os.path.realpath(sys.argv[1]))" ~/.claude/skills/<name>/SKILL.md`. If the resolved path does not start with `/Users/ginalevy/claude-pipeline-agents/`, it is NOT backed up and that is a defect to fix immediately, not a fact to report and move past.

**Why this rule is phrased as a rule and not a list (Sept 15, 2026):** this section used to enumerate skill names. Seven skills — including `build-app`, whose `patterns.md` holds every build-failure lesson paid for with burned EAS credits — existed nowhere but this laptop. `/cascade-light` was created Aug 25 with `mkdir ~/.claude/skills/cascade-light` + `Write`, and the repo was never opened. A new skill's name is by definition absent from a hand-typed list, so the list could never catch the one case that mattered. Worse, the gap was noticed twice and waved through both times: `/wrap` reported "outside this repo, so nothing to commit here — safe to close," and commit `479aac2`'s own message said "cascade-light (outside this repo) got the same preflight locally." Both treated "not backed up" as a property of the file rather than a defect. All skills were moved into the repo and symlinked on Sept 15, 2026.

<!-- agentic-loop-detected -->
## Detected Project Info

- Runtime: Node.js






*Auto-detected by agentic-loop. Edit freely.*
