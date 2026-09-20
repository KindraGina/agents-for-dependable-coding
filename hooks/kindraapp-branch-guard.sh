#!/bin/bash
# Branch-change and work-discard guard for shared Claude checkouts.
# Added 2026-09-13 after a session switched Eventtags -> docs branch -> back and
# hard-reset while a /cascade was running on Eventtags in the same directory.
# Extended same day: also guards work-DISCARDING commands (restore/clean/stash/
# rebase and the path form of checkout), and is registered in kindra,
# kinlia-web, and every KindraApp checkout — not just ~/Sites/KindraApp.
# WHY: multiple concurrent Claude sessions (cascades/pipelines) can share one
# working tree. A branch switch, hard reset, restore, stash, clean, or rebase
# by one session yanks HEAD, the index, uncommitted edits, or untracked files
# out from under every other session — silently.
# Fires permissionDecision "ask" so Gina must confirm — works even in
# --dangerously-skip-permissions sessions, where allow/ask rules are bypassed
# but hooks still run.
#
# REWRITTEN 2026-09-20: the original matched guard words ANYWHERE in the
# command text, so prose inside an echo string — `echo "=== git status still
# clean of code edits ==="` — matched `git ... clean` and stopped read-only
# auditor commands constantly (cascades were interrupted several times per
# run). Guard words now count ONLY in the git-subcommand position: `git`,
# optionally followed by global flags (-C <path>, -c <kv>, --flags), then the
# subcommand. `git clean -fd` still asks; a sentence containing "git status
# still clean" does not, because "status" occupies the subcommand slot.
cmd=$(jq -r '.tool_input.command // empty')
ASK='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Branch-changing or work-discarding git command in a shared checkout - other sessions/cascades may be live. Confirm with Gina first."}}'
g() { printf '%s' "$cmd" | grep -qE -- "$1"; }

# git-subcommand anchor: `git` + any global flags (two-token -C/-c forms first
# so their arguments are consumed) + the subcommand as the FIRST non-flag word.
PRE='\bgit(\s+-C\s+\S+|\s+-c\s+\S+|\s+--?\S+)*\s+'

# Branch moves: checkout/switch in ANY form (the " -- " path-restore form
# discards uncommitted edits, so it is deliberately NOT exempt), gh pr checkout,
# reset --hard/--merge/--keep, and rebase (rewrites history under a live session).
if g "${PRE}(checkout|switch)\b" \
   || g '\bgh(\s+--?\S+)*\s+pr(\s+--?\S+)*\s+checkout\b' \
   || g "${PRE}reset\b[^|;&]*--(hard|merge|keep)" \
   || g "${PRE}rebase\b"; then
  echo "$ASK"
# git restore discards working-tree edits. Exempt only the pure unstage form:
# --staged WITHOUT --worktree/-W (that combination touches the working tree too).
elif g "${PRE}restore\b" \
     && { g '\brestore\b[^|;&]*(--worktree|\s-W\b)' || ! g '\brestore\b[^|;&]*--staged'; }; then
  echo "$ASK"
# git clean deletes untracked files (e.g. a cascade's not-yet-committed plan docs).
elif g "${PRE}clean\b"; then
  echo "$ASK"
# git stash sweeps uncommitted edits away (and pop/apply mutates the tree).
# Read-only stash list/show stay silent.
elif g "${PRE}stash\b" && ! g '\bstash\b[^|;&]*\b(list|show)\b'; then
  echo "$ASK"
fi
