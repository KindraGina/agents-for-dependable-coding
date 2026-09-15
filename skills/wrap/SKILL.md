---
description: Check if anything is outstanding in this terminal before closing it.
---

# Wrap — Can I Close This Tab?

Quick check for outstanding work in the current session so the user can close the terminal with confidence.

## Instructions

Run ALL of the following checks, then give a short verdict.

### 1. Uncommitted changes

```bash
git status --short 2>/dev/null
```

If there are staged, unstaged, or untracked files that look like real work (not build artifacts), flag them.

### 2. Stashed work

```bash
git stash list 2>/dev/null
```

Flag any stashes — they're easy to forget.

### 3. Unpushed commits

```bash
git log --oneline @{upstream}..HEAD 2>/dev/null
```

Flag commits that haven't been pushed to the remote.

### 4. Background processes started this session

```bash
jobs -l 2>/dev/null
```

Flag any running background jobs (dev servers, watchers, builds).

### 5. Unfinished conversations

Review the conversation history in this session. Flag anything where:
- A question was asked but never answered (by either side)
- A topic was raised but no decision was reached
- A plan or approach was discussed but not confirmed or acted on
- The user said "let's come back to that" or similar and it never came back
- Something was deferred ("we'll handle that later") without being tracked anywhere (plan file, TODO, etc.)

Do NOT flag things that were intentionally tabled or resolved. Only flag genuinely loose threads that still need discussion.

### 6. Active branch context

```bash
git branch --show-current 2>/dev/null
```

If on a feature branch (not main/master/develop), mention it — the user may want to remember where they left off.

### 7. Skills or agents created this session are backed up

If this session created or edited anything under `~/.claude/skills/` or `~/.claude/agents/`, resolve where it actually lives:

```bash
python3 -c "import os,sys;print(os.path.realpath(sys.argv[1]))" ~/.claude/skills/<name>/SKILL.md
```

If the resolved path does NOT start with `/Users/ginalevy/claude-pipeline-agents/`, that file exists on this laptop and nowhere else. **Flag it as outstanding.** Then check the repo for uncommitted or unpushed work:

```bash
cd ~/claude-pipeline-agents && git status --short && git log --branches --not --remotes --oneline
```

**"Outside the repo" is a DEFECT, never an explanation.** Do not write "outside this repo, so nothing to commit here" and clear the session — that exact sentence is what let `/cascade-light` sit unbacked from Aug 25 to Sept 15, 2026, alongside `build-app/patterns.md` (every build-failure lesson paid for with burned EAS credits). A new skill that only exists locally is one disk failure from gone, and it is precisely the thing `/wrap` is meant to catch.

## Output

Give a one-line verdict at the top:

- **All clear — safe to close.** (nothing outstanding)
- **X thing(s) to deal with first:** (list what's outstanding, one bullet each, short)

Keep it brief. No headers, no sections — just the verdict and bullets if needed.
