#!/bin/bash
# UserPromptSubmit hook: when the prompt looks like a bug report, inject the /evidence
# rule so the session audits its own cause claim before stating one, AND set a per-session
# flag file that evidence-edit-guard.sh (PreToolUse Edit|Write) reads to refuse app-code
# edits until the user's NEXT message. Any later, non-bug prompt clears the flag — that is
# the approval gate: "no app edits until you have replied", with no keyword guessing about
# what counts as approval.
# Known limit: a bug report that also says "fix it" keeps the flag until the next message.
# Backed up in ~/claude-pipeline-agents/hooks; referenced from ~/.claude/settings.json.
# Widen the pattern list whenever a guessed cause slips past it (2026-10-07).
input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null)
session_id=$(printf '%s' "$input" | jq -r '.session_id // "nosession"' 2>/dev/null)
flag="${TMPDIR:-/tmp}/claude-evidence-${session_id}.flag"
pattern='what happened to|why (is|isn.t|did|does|doesn.t|are|aren.t|was|were)|missing|not showing|not appear|disappear|broken|doesn.t work|does not work|stopped working|went wrong|not working|no longer|used to'
if echo "$prompt" | grep -qiE "$pattern"; then
  date +%s > "$flag"
  cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"EVIDENCE RULE (auto-triggered, bug-report prompt): Before you state ANY cause for this problem, follow ~/.claude/skills/evidence/SKILL.md. Ask what the user did just before the bug. Build the Claim / Status / Proof table. Every cause must be Verified (pasted code, log, request, or the user's words), or rewritten as 'I haven't confirmed this' with the next check named, or 'I don't know yet'. A fresh load that works for you is NOT proof of why it failed for the user. Do not write, commit, or open a PR for a fix until the user approves — app-code edits are blocked by evidence-edit-guard.sh until the user's next message."}}
JSON
else
  rm -f "$flag"
fi
exit 0
