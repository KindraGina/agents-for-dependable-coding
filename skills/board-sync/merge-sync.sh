#!/usr/bin/env bash
# Moves board cards when their pull request merges. Reads GitHub only (no local folders),
# so it gives the same answer from this Mac or from a GitHub Action.
# WHY (owner, 2026-11-25): "whenever a PR merges to staging or production it gets updated".
# Before this, a card moved only when someone ran /wrap or /board-sync.
#
# Usage:  merge-sync.sh [--dry-run]
# For every card whose Key is <repo>:pr:<n>:
#   PR's merge commit is on the production branch -> On Production
#   else it is on the staging branch              -> On Staging
# A card is only ever moved FORWARD. "Passed Staging Test" and "Passed Production Test"
# are set by people and the checklist, never by this script, and a card already in
# "Passed Staging Test" is not pulled back to "On Staging".
# Branch-keyed and note-keyed cards are not touched (see the comment in the loop).
set -u
OWNER="KindraConnect"
PROJECT_TITLE="Kinlia Work Board"
HERE="$(cd "$(dirname "$0")" && pwd)"

# repo : staging branch (or -) : production branch. Same table as collect.sh.
BRANCHES="kindra:develop:master
KindraApp:testflight:master
kinlia-web:staging:production
event_scraper:-:main"

DRY=""; [ "${1:-}" = "--dry-run" ] && DRY="--dry-run"
TMP="$(mktemp -d)"; trap 'rm -rf "${TMP}"' EXIT

NUMBER="$(gh project list --owner "${OWNER}" --format json \
          --jq ".projects[] | select(.title == \"${PROJECT_TITLE}\") | .number")"
[ -n "${NUMBER}" ] || { echo "board \"${PROJECT_TITLE}\" not found" >&2; exit 2; }
# MERGE_SYNC_ITEMS: a saved item list to judge instead of the live board (used to test this).
if [ -n "${MERGE_SYNC_ITEMS:-}" ]; then cp "${MERGE_SYNC_ITEMS}" "${TMP}/items.json"; else
bash "${HERE}/list-items.sh" > "${TMP}/items.json" \
  || { echo "could not read the board" >&2; exit 2; }
fi

# Order of the columns; a card never moves to a lower number.
rank() { case "$1" in "Backlog/Todo") echo 1;; "Has Plan") echo 2;; "In Progress") echo 3;;
  "On Staging") echo 4;; "Passed Staging Test") echo 5;; "On Production") echo 6;;
  "Passed Production Test") echo 7;; *) echo 0;; esac; }

# "yes" when commit $2 is contained in branch $3 of repo $1. GitHub's compare answers
# "behind" or "identical" exactly when the commit is an ancestor of the branch.
contains() {
  [ "$3" = "-" ] && { echo no; return; }
  local s; s="$(gh api "repos/${OWNER}/$1/compare/$3...$2" --jq '.status' 2>/dev/null)" || { echo unknown; return; }
  case "${s}" in behind|identical) echo yes;; ahead|diverged) echo no;; *) echo unknown;; esac
}

echo '[]' > "${TMP}/cards.json"
add_card() { jq --argjson c "$1" '. + [$c]' "${TMP}/cards.json" > "${TMP}/c2.json" && mv "${TMP}/c2.json" "${TMP}/cards.json"; }
TODAY="$(date +%Y-%m-%d)"

jq -r '.items[] | select(.key != null) | [.key, (.status // "")] | @tsv' "${TMP}/items.json" > "${TMP}/keys.tsv"
while IFS=$'\t' read -r KEY STATUS; do
  REPO="${KEY%%:*}"; REST="${KEY#*:}"; KIND="${REST%%:*}"; ID="${REST#*:}"
  LINE="$(echo "${BRANCHES}" | grep "^${REPO}:")" || continue
  STG="$(echo "${LINE}" | cut -d: -f2)"; PRD="$(echo "${LINE}" | cut -d: -f3)"

  # Only PR-keyed cards. A branch-keyed card is left to /board-sync, which can see the
  # folder on this Mac: on 2026-11-25 a preview matched the Eventtags card to PR #403, an
  # OLD merged PR from a branch of the same name, while the card's real work was a newer
  # commit that had never been pushed.
  [ "${KIND}" = "pr" ] || continue
  PR="${ID}"

  gh api "repos/${OWNER}/${REPO}/pulls/${PR}" --jq '[.merged, (.merge_commit_sha // "")] | @tsv' > "${TMP}/pr.tsv" 2>/dev/null \
    || { echo "!! ${KEY}: could not read PR #${PR}" >&2; continue; }
  IFS=$'\t' read -r MERGED SHA < "${TMP}/pr.tsv"
  [ "${MERGED}" = "true" ] && [ -n "${SHA}" ] || continue

  TARGET=""
  ON_PRD="$(contains "${REPO}" "${SHA}" "${PRD}")"
  if [ "${ON_PRD}" = "yes" ]; then TARGET="On Production"
  elif [ "${ON_PRD}" = "no" ] && [ "$(contains "${REPO}" "${SHA}" "${STG}")" = "yes" ]; then TARGET="On Staging"
  fi
  [ -n "${TARGET}" ] || continue
  [ "$(rank "${TARGET}")" -gt "$(rank "${STATUS}")" ] || continue

  CARD="$(jq -n --arg k "${KEY}" --arg s "${TARGET}" --arg d "${TODAY}" \
    '{key:$k, status:$s, last_touched:$d}')"
  add_card "${CARD}"
done < "${TMP}/keys.tsv"

if [ "$(jq 'length' "${TMP}/cards.json")" -eq 0 ]; then echo "merge-sync: every card already matches GitHub."; exit 0; fi
bash "${HERE}/apply.sh" ${DRY} "${TMP}/cards.json"
