#!/usr/bin/env bash
# The daily sweep: keeps the Kinlia Work Board current without anyone remembering to.
# Run by launchd every morning on the owner's Mac (life.kinlia.board-sweep.plist), and
# safe to run by hand at any time.
# WHY (owner, 2026-11-25): "sweep my computer and check github for anything the interns did".
#
# Usage:  daily-sweep.sh [--dry-run]
# It does only what can be proven without judgement:
#   1. merge-sync.sh: a card whose PR merged moves forward (On Staging / On Production).
#   2. A pull request nobody has a card for gets one: open -> In Progress,
#      merged to staging since this sweep began -> On Staging. The author is named.
#   3. A folder on this Mac with edited or unpushed work and no card gets one (In Progress).
# It never moves a card backward, never archives, never touches git, and never sets
# "Passed Staging Test": that needs the team checklist, which only an open Claude session
# can read (/next and /board-sync do it).
set -u
OWNER="KindraConnect"
PROJECT_TITLE="Kinlia Work Board"
HERE="$(cd "$(dirname "$0")" && pwd)"
CACHE="${HOME}/.cache/board-sync"; mkdir -p "${CACHE}"
REPORT="${CACHE}/daily-report.txt"
# Merged PRs older than this were already sorted by hand or sit on a release roll-up card.
MERGED_SINCE="2026-11-25"
DRY=""; [ "${1:-}" = "--dry-run" ] && DRY="--dry-run"
TMP="$(mktemp -d)"; trap 'rm -rf "${TMP}"' EXIT
TODAY="$(date +%Y-%m-%d)"

area() { case "$1" in kindra) echo Backend;; KindraApp) echo Mobile;; kinlia-web) echo Web;; event_scraper) echo Scraper;; *) echo Ops;; esac; }

{
echo "Daily board sweep ${TODAY} $(date +%H:%M)${DRY:+ (preview, nothing written)}"
echo
echo "1. Merges"
bash "${HERE}/merge-sync.sh" ${DRY} 2>&1 | grep -v 'would run' | sed 's/^/   /'

NUMBER="$(gh project list --owner "${OWNER}" --format json \
          --jq ".projects[] | select(.title == \"${PROJECT_TITLE}\") | .number")"
[ -n "${NUMBER}" ] || { echo "board not found; stopping"; exit 2; }
gh project item-list "${NUMBER}" --owner "${OWNER}" --limit 1000 --format json > "${TMP}/items.json" \
  || { echo "could not read the board; stopping"; exit 2; }
# Everything any card says about a repo, as one block of text. A PR number or a branch name
# that appears anywhere in it already has a home (often on a roll-up card), so no new card.
known() { jq -r --arg r "$1" '.items[] | select((.key // "") | startswith($r + ":"))
  | [.key, .title, (."where" // ""), (."next action" // ""), (.content.body // "")] | join(" ")' "${TMP}/items.json"; }

BOARD_SYNC_SKIP_GH=1 bash "${HERE}/collect.sh" > "${TMP}/sweep.json" 2>"${TMP}/collect.err" \
  || { echo "computer sweep failed: $(head -3 "${TMP}/collect.err")"; }
cp "${TMP}/sweep.json" "${CACHE}/last-sweep.json" 2>/dev/null

echo '[]' > "${TMP}/cards.json"
add_card() { jq --argjson c "$1" '. + [$c]' "${TMP}/cards.json" > "${TMP}/c2.json" && mv "${TMP}/c2.json" "${TMP}/cards.json"; }

# The card shapes live in jq files: bash 3.2 (the macOS default) mis-parses them inline.
cat > "${TMP}/open.jq" <<'JQ'
.[] | select(.number == $n) | {
      key: "\($repo):pr:\($n)", title: .title, status: "In Progress", area: $area,
      next_action: "Open pull request by \(.author.login): review and merge it, or say what is missing.",
      last_touched: (.updatedAt[0:10]),
      body: "Added by the daily sweep. PR \(.url) by \(.author.login) is open and had no card. The title is GitHub's; rename it in plain English."}
JQ
cat > "${TMP}/merged.jq" <<'JQ'
.[] | select(.number == $n) | {
      key: "\($repo):pr:\($n)", title: .title, status: "In Progress", area: $area,
      next_action: "Merged by \(.author.login) into \(.baseRefName). Decide what staging test it needs, or mark it passed.",
      last_touched: (.mergedAt[0:10]),
      body: "Added by the daily sweep. PR \(.url) by \(.author.login) merged into \(.baseRefName) on \(.mergedAt[0:10]) and had no card. The next sweep moves it to the column its branch proves."}
JQ
cat > "${TMP}/folder.jq" <<'JQ'
{
      key: "\($repo):branch:\(.branch)", title: "Unsaved work: \(.branch)", status: "In Progress", area: $area,
      next_action: "Open that folder: \(.dirty_tracked) edited file(s) not committed, \(.unpushed) commit(s) not pushed. Finish, save or discard.",
      where: "\($short) (\(.branch))", last_touched: .last_commit,
      body: "Added by the daily sweep from this Mac. The title is the branch name; rename it in plain English."}
JQ

for REPO in kindra KindraApp kinlia-web event_scraper; do
  known "${REPO}" > "${TMP}/known.txt"
  has_pr() { grep -q -E "(^|[^0-9A-Za-z])(${REPO}:pr:|#|pull/)$1([^0-9]|\$)" "${TMP}/known.txt"; }

  # 2. Pull requests with no card.
  gh pr list -R "${OWNER}/${REPO}" --state open --limit 100 \
     --json number,title,url,author,isDraft,updatedAt > "${TMP}/open.json" 2>/dev/null || echo '[]' > "${TMP}/open.json"
  gh pr list -R "${OWNER}/${REPO}" --state merged --limit 100 --search "merged:>=${MERGED_SINCE}" \
     --json number,title,url,author,mergedAt,baseRefName > "${TMP}/merged.json" 2>/dev/null || echo '[]' > "${TMP}/merged.json"

  for N in $(jq -r '.[].number' "${TMP}/open.json"); do
    has_pr "${N}" && continue
    add_card "$(jq --argjson n "${N}" --arg repo "${REPO}" --arg area "$(area "${REPO}")" -f "${TMP}/open.jq" "${TMP}/open.json")"
  done
  for N in $(jq -r '.[].number' "${TMP}/merged.json"); do
    has_pr "${N}" && continue
    add_card "$(jq --argjson n "${N}" --arg repo "${REPO}" --arg area "$(area "${REPO}")" -f "${TMP}/merged.jq" "${TMP}/merged.json")"
  done

  # 3. Folders on this Mac holding edited or unpushed work, with no card.
  jq -c --arg r "${REPO}" '.repos[]? | select(.name == $r) | .worktrees[]?
     | select(.missing == false and .on_production != true)
     | select(.dirty_tracked > 0 or ((.unpushed | type) == "number" and .unpushed > 0))' "${TMP}/sweep.json" 2>/dev/null > "${TMP}/wt.jsonl"
  while IFS= read -r WT; do
    [ -n "${WT}" ] || continue
    BR="$(echo "${WT}" | jq -r '.branch // ""')"; P="$(echo "${WT}" | jq -r '.path')"
    REL="${P#${HOME}}"; SHORT="~${REL}"
    [ -n "${BR}" ] || continue
    case "${BR}" in develop|master|main|staging|production|testflight) continue;; esac
    grep -q -F -e "${BR}" -e "${SHORT}" -e "${P}" "${TMP}/known.txt" && continue
    add_card "$(echo "${WT}" | jq --arg repo "${REPO}" --arg area "$(area "${REPO}")" --arg short "${SHORT}" -f "${TMP}/folder.jq")"
  done < "${TMP}/wt.jsonl"
done

echo
echo "2. New cards (pull requests and folders that had none)"
if [ "$(jq 'length' "${TMP}/cards.json")" -eq 0 ]; then echo "   none"; else
  jq -r '.[] | "   + \(.key)  \(.title)"' "${TMP}/cards.json"
  bash "${HERE}/apply.sh" ${DRY} "${TMP}/cards.json" 2>&1 | grep -v -E 'would run|^create ' | tail -3 | sed 's/^/   /'
fi
echo
echo "Not done by this sweep: reading the team checklist (Pass/Fail marks). Run /next or /board-sync for that."
} > "${TMP}/report.txt" 2>&1
cat "${TMP}/report.txt"
[ -n "${DRY}" ] || cp "${TMP}/report.txt" "${REPORT}"
