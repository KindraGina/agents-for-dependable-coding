#!/bin/bash
# Checks which git stash commands the branch guard stops ("ask") or lets through.
H="$(cd "$(dirname "$0")/.." && pwd)/hooks/kindraapp-branch-guard.sh"
fail=0
check() { # expected(ask|pass) command
  out=$(jq -n --arg c "$2" '{tool_input:{command:$c}}' | bash "$H")
  got=pass; [ -n "$out" ] && got=ask
  if [ "$got" = "$1" ]; then echo "ok   $1  $2"; else echo "FAIL want $1 got $got  $2"; fail=1; fi
}
check pass 'git stash create'
check pass 'W=$(git stash create); git merge-tree --write-tree abc ${W}'
check pass 'git stash list'
check pass 'git -C /x stash show -p'
check ask  'git stash'
check ask  'git stash pop'
check ask  'git stash apply stash@{0}'
check ask  'git stash push -m wip'
check ask  'git stash create; git stash'
check ask  'git stash list && git stash drop'
check ask  'git checkout develop'
exit $fail
