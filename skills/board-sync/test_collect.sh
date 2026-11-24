#!/usr/bin/env bash
# Proof test for collect.sh. Builds a throwaway repo with one worktree per kind of
# loose end, runs the collector on it, and checks the JSON field by field.
# WHY a fixture and not the real repos: the real repos change every hour, so a test
# against them could never say what the right answer is.
# Run: bash test_collect.sh        (exit 0 = all pass)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
COLLECT="${HERE}/collect.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
PASS=0; FAIL=0

g() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=master "$@" >/dev/null 2>&1; }

# --- fixture -----------------------------------------------------------------
g init --bare "${TMP}/origin.git"
g clone "${TMP}/origin.git" "${TMP}/main"
M="${TMP}/main"
echo base > "${M}/base.txt"; g -C "${M}" add .; g -C "${M}" commit -m base
g -C "${M}" push -u origin master
g -C "${M}" branch develop; g -C "${M}" push -u origin develop

mkwt() { # name branch
  g -C "${M}" worktree add -b "$2" "${TMP}/$1" master
  echo "$1" > "${TMP}/$1/$1.txt"; g -C "${TMP}/$1" add .; g -C "${TMP}/$1" commit -m "work $1"
}

# A: pushed, then one uncommitted file
mkwt wtA feat-a; g -C "${TMP}/wtA" push -u origin feat-a; echo x > "${TMP}/wtA/dirty.txt"
# B: pushed, then one more commit that is not pushed
mkwt wtB feat-b; g -C "${TMP}/wtB" push -u origin feat-b
echo y > "${TMP}/wtB/more.txt"; g -C "${TMP}/wtB" add .; g -C "${TMP}/wtB" commit -m "unpushed"
# C: merged into develop only
mkwt wtC feat-c; g -C "${TMP}/wtC" push -u origin feat-c
# D: merged into develop AND master
mkwt wtD feat-d; g -C "${TMP}/wtD" push -u origin feat-d
# E: committed, never pushed (no upstream)
mkwt wtE feat-e
# F: branch name with a slash, folder name with a space
mkwt "wt F space" "fix/with-slash"; g -C "${TMP}/wt F space" push -u origin "fix/with-slash"

# G: pushed, then an edit to a file git already tracks (real work, unlike a stray new file)
mkwt wtG feat-g; g -C "${TMP}/wtG" push -u origin feat-g; echo changed >> "${TMP}/wtG/base.txt"

# merges happen in a second clone so the fixture's own local branches stay behind
g clone "${TMP}/origin.git" "${TMP}/merger"; X="${TMP}/merger"
# Order mirrors a real release: D reaches develop, develop is released to master,
# and only then C reaches develop. So C is "on staging, not released" and D is live.
g -C "${X}" checkout develop
g -C "${X}" merge --no-ff origin/feat-d -m "Merge pull request #8 from feat-d"
g -C "${X}" push origin develop
g -C "${X}" checkout master
g -C "${X}" merge --no-ff develop -m "Release develop to master"
g -C "${X}" push origin master
g -C "${X}" checkout develop
g -C "${X}" merge --no-ff origin/feat-c -m "Merge pull request #7 from feat-c"
g -C "${X}" push origin develop

# one stash in the main checkout
echo z >> "${M}/base.txt"; g -C "${M}" stash

# --- run ---------------------------------------------------------------------
OUT="${TMP}/out.json"
BOARD_SYNC_SKIP_GH=1 bash "${COLLECT}" "${M}:develop:master" > "${OUT}" 2> "${TMP}/err.txt"
RC=$?

check() { # description, jq filter that must print "true"
  local got
  got="$(jq -r "$2" "${OUT}" 2>/dev/null)"
  if [ "${got}" = "true" ]; then PASS=$((PASS+1)); echo "  ok    $1"
  else FAIL=$((FAIL+1)); echo "  FAIL  $1   (got: ${got:-nothing})"; fi
}
wt() { echo ".repos[0].worktrees[] | select(.branch==\"$1\")"; }

echo "collector exit code: ${RC}"
check "output is JSON with one repo"            '(.repos | length) == 1'
check "all 8 worktrees listed"                  '(.repos[0].worktrees | length) == 8'
check "A: one uncommitted file"                 "$(wt feat-a) | .dirty == 1"
check "A: nothing unpushed"                     "$(wt feat-a) | .unpushed == 0"
check "B: one unpushed commit"                  "$(wt feat-b) | .unpushed == 1"
check "B: clean"                                "$(wt feat-b) | .dirty == 0"
check "A: the dirty file is untracked"          "$(wt feat-a) | .dirty_untracked == 1 and .dirty_tracked == 0"
check "G: one tracked edit, no untracked"       "$(wt feat-g) | .dirty_tracked == 1 and .dirty_untracked == 0 and .dirty == 1"
check "C: on staging branch"                    "$(wt feat-c) | .on_staging == true"
check "C: NOT on production branch"             "$(wt feat-c) | .on_production == false"
check "D: on production branch"                 "$(wt feat-d) | .on_production == true"
check "E: no upstream reported"                 "$(wt feat-e) | .unpushed == \"no-upstream\""
check "E: not on staging"                       "$(wt feat-e) | .on_staging == false"
check "E: one commit ahead of production"       "$(wt feat-e) | .ahead_of_production == 1"
check "F: slash branch kept whole"              "$(wt fix/with-slash) | .branch == \"fix/with-slash\""
check "F: path with a space kept whole"         "$(wt fix/with-slash) | .path | endswith(\"/wt F space\")"
check "main checkout: branch master"            '.repos[0].worktrees[0].branch == "master"'
check "repo: one stash"                         '.repos[0].stashes == 1'
check "repo: staging and production names"      '.repos[0].staging_branch == "develop" and .repos[0].production_branch == "master"'
check "repo: one merge on staging not released" '(.repos[0].staged_not_released | length) == 1'
check "repo: that merge is feat-c"              '.repos[0].staged_not_released[0].subject | test("feat-c")'
check "every worktree has a last_commit date"   '[.repos[0].worktrees[].last_commit | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")] | all'

echo
echo "passed: ${PASS}   failed: ${FAIL}"
[ "${FAIL}" -eq 0 ] && [ "${RC}" -eq 0 ]
