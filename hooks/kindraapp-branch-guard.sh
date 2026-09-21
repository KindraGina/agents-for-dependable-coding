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

# 2026-09-20, second false-positive class: agents write review/audit documents
# via bash heredocs, and those documents QUOTE dangerous git commands verbatim
# as pasted evidence (the repo rules require it). Heredoc bodies are DATA the
# shell never executes — strip them before matching, so only executed text is
# inspected. Handles <<TAG, <<-TAG, <<'TAG', <<"TAG"; the terminator may be
# tab-indented (<<- form). A real git command before/after a heredoc, or on
# the heredoc's opening line itself, is still seen.
cmd_exec=$(printf '%s\n' "$cmd" | awk '
  strip {
    line=$0; sub(/^\t+/, "", line)
    if (line == tag) strip=0
    next
  }
  /<<-?[ \t]*["'"'"']?[A-Za-z_]/ {
    rest=$0
    sub(/.*<<-?[ \t]*/, "", rest)
    sub(/^["'"'"']/, "", rest)
    tag=""
    for (i=1; i<=length(rest); i++) {
      c=substr(rest, i, 1)
      if (c ~ /[A-Za-z0-9_]/) tag=tag c; else break
    }
    if (tag != "") strip=1
    print; next
  }
  { print }
')
# 2026-09-20, third false-positive class: guard words inside QUOTED STRING
# ARGUMENTS — a lesson-learner dedup grep like  grep -n "git stash\|stash" ...
# carries "git stash" as a search pattern, and commit messages / sed exprs do
# the same. Quoted spans are data handed to a program, not commands the shell
# runs, so strip them before matching (double-quoted spans first — they may
# contain apostrophes — then single-quoted, whose bodies never contain escapes
# by shell semantics). A real dangerous command's subcommand is never inside
# the quotes (`git checkout "my branch"` keeps `git checkout` outside), so
# stripping cannot hide it. The one true execution-inside-quotes form,
# `bash|sh|zsh -c "git checkout ..."`, is caught by the backstop below, which
# re-checks the UNSTRIPPED text whenever a shell -c invocation is present.
cmd_exec=$(printf '%s' "$cmd_exec" | sed -E 's/"(\\.|[^"\\])*"//g' | sed -E "s/'[^']*'//g")
g() { printf '%s' "$cmd_exec" | grep -qE -- "$1"; }
graw() { printf '%s' "$cmd" | grep -qE -- "$1"; }

# git-subcommand anchor: `git` + any global flags (two-token -C/-c forms first
# so their arguments are consumed) + the subcommand as the FIRST non-flag word.
PRE='\bgit(\s+-C\s+\S+|\s+-c\s+\S+|\s+--?\S+)*\s+'

# Backstop: shell -c executes its quoted argument. If the command invokes
# bash/sh/zsh -c AND the raw (unstripped) text contains a guarded git
# subcommand, ask — quote-stripping must not hide a real execution.
if graw '\b(bash|sh|zsh)\s+(-[A-Za-z]+\s+)*-c\b' \
   && { graw "${PRE}(checkout|switch|rebase|clean|stash)\b" || graw "${PRE}reset\b[^|;&]*--(hard|merge|keep)" || graw "${PRE}restore\b"; }; then
  echo "$ASK"
  exit 0
fi

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
