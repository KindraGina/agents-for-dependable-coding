#!/bin/bash
# UserPromptSubmit hook: when the prompt looks like a bug report, inject the /evidence
# rule so the session audits its own cause claim before stating one.
# Backed up in ~/claude-pipeline-agents/hooks; referenced from ~/.claude/settings.json.
# Widen the pattern list whenever a guessed cause slips past it (2026-10-07).
prompt=$(cat | jq -r '.prompt // ""' 2>/dev/null)
pattern='what happened to|why (is|isn.t|did|does|doesn.t|are|aren.t|was|were)|missing|not showing|not appear|disappear|broken|doesn.t work|does not work|stopped working|went wrong|not working|no longer|used to'
if echo "$prompt" | grep -qiE "$pattern"; then
  cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"EVIDENCE RULE (auto-triggered, bug-report prompt): Before you state ANY cause for this problem, follow ~/.claude/skills/evidence/SKILL.md. Ask what the user did just before the bug. Build the Claim / Status / Proof table. Every cause must be Verified (pasted code, log, request, or the user's words), or rewritten as 'I haven't confirmed this' with the next check named, or 'I don't know yet'. A fresh load that works for you is NOT proof of why it failed for the user. Do not write, commit, or open a PR for a fix until the user approves."}}
JSON
fi
exit 0
