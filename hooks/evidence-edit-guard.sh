#!/bin/bash
# PreToolUse hook (matcher Edit|Write): while this session's evidence flag is set — i.e. the
# user's LAST message was a bug report and they have not replied since — refuse edits to
# application code. The user's next message clears the flag (evidence-trigger.sh), so
# approval is "they replied", not a keyword match. Docs, plans and memory stay editable so
# the session can still write up findings.
# Honest limit: this only covers the Edit and Write tools. A session can still change files
# through Bash (sed, heredocs); in bypass mode sessions are told to prefer Bash for edits,
# so this is a strong nudge, not a wall. (2026-10-07, Leaders & hosts / PR #214 incident.)
input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // "nosession"' 2>/dev/null)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
flag="${TMPDIR:-/tmp}/claude-evidence-${session_id}.flag"
[ -f "$flag" ] || exit 0
case "$file_path" in
  */docs/*|*/.claude/*|*/memory/*|*.md) exit 0 ;;
esac
case "$file_path" in
  */src/*|*/lib/*|*/app/*|*/components/*|*/pages/*|*/priv/*|*/config/*|*/test/*|*/__tests__/*)
    cat <<JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"EVIDENCE GATE: the user's last message was a bug report and they have not replied since. No app-code edits until they approve an approach (Sites/CLAUDE.md: never start coding until we have agreed). State the verified cause, propose the fix, and wait. Blocked: $file_path"}}
JSON
    ;;
esac
exit 0
