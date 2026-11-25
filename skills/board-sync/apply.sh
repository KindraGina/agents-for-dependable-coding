#!/usr/bin/env bash
# Writes cards to the Kinlia Work Board. The ONLY part of /board-sync that changes
# anything, and it changes only the project board (never git, never a repo).
# WHY a script: one card needs up to eight GitHub calls. Doing that by hand for dozens
# of cards is where duplicates and half-filled cards come from.
#
# Usage:  apply.sh [--dry-run] <cards.json>
# cards.json is an array. Each card:
#   { "key": "kindra:pr:2112",            REQUIRED - the card's identity, see SKILL.md
#     "title": "...",                     required when the card is new
#     "status": "On Staging",             one of the Status options (the board's columns)
#     "area": "Backend",                  Backend, Frontend, Website, Skills pipeline, Scraper, Ops
#     "next_action": "...", "waiting_on": "...", "where": "...",
#     "last_touched": "2026-11-21",
#     "body": "...",                      evidence for the sort; draft cards only
#     "pr_url": "https://github.com/..."  if set, the card is the real PR, not a draft
#     "new_key": "kindra:pr:2120",        re-key an existing card (branch got a PR)
#     "archive": true }                   remove a finished card from the board
# A field that is absent from a card is left exactly as it is on the board.
# The card is found by Key first, so running the same file twice changes nothing.
set -u
OWNER="KindraConnect"
PROJECT_TITLE="Kinlia Work Board"

DRY=0
if [ "${1:-}" = "--dry-run" ]; then DRY=1; shift; fi
CARDS="${1:?usage: apply.sh [--dry-run] <cards.json>}"
jq -e 'type == "array" and all(.[]; has("key"))' "${CARDS}" >/dev/null \
  || { echo "cards file must be a JSON array and every card needs a key" >&2; exit 2; }

TMP="$(mktemp -d)"; trap 'rm -rf "${TMP}"' EXIT

# Looked up by title every run so a renumbered or recreated board cannot be hit by mistake.
NUMBER="$(gh project list --owner "${OWNER}" --format json \
          --jq ".projects[] | select(.title == \"${PROJECT_TITLE}\") | .number")"
[ -n "${NUMBER}" ] || { echo "board \"${PROJECT_TITLE}\" not found (is it closed?)" >&2; exit 2; }
PROJECT_ID="$(gh project view "${NUMBER}" --owner "${OWNER}" --format json --jq '.id')"
gh project field-list "${NUMBER}" --owner "${OWNER}" --format json > "${TMP}/fields.json"
gh project item-list  "${NUMBER}" --owner "${OWNER}" --limit 1000 --format json > "${TMP}/items.json"

# GitHub's item list lags a few seconds behind a write. On 2026-11-24 a second run made
# straight after the first did not see the last card and created a twin. So every card
# this script creates is also noted locally, and a Key created in the last 10 minutes
# counts as existing even if the list has not caught up yet.
LEDGER="${HOME}/.cache/board-sync/recently-created.tsv"
mkdir -p "$(dirname "${LEDGER}")"; touch "${LEDGER}"
NOW="$(date +%s)"
recently_created() { awk -F'\t' -v k="$1" -v t="$((NOW-600))" '$2 == k && $1 > t {print $3}' "${LEDGER}" | tail -1; }

field_id()  { jq -r --arg n "$1" '.fields[] | select(.name == $n) | .id' "${TMP}/fields.json"; }
option_id() { jq -r --arg n "$1" --arg o "$2" '.fields[] | select(.name == $n) | .options[] | select(.name == $o) | .id' "${TMP}/fields.json"; }
run() { if [ "${DRY}" = "1" ]; then echo "    would run: $*"; else "$@" >/dev/null || { echo "    !! FAILED: $*" >&2; ERRORS=$((ERRORS+1)); }; fi; }

CREATED=0; UPDATED=0; UNCHANGED=0; ARCHIVED=0; ERRORS=0
COUNT="$(jq 'length' "${CARDS}")"
i=0
while [ "${i}" -lt "${COUNT}" ]; do
  card() { jq -r --argjson i "${i}" ".[\$i] | $1 // empty" "${CARDS}"; }
  KEY="$(card .key)"; TITLE="$(card .title)"
  ITEM_ID="$(jq -r --arg k "${KEY}" '.items[] | select(.key == $k) | .id' "${TMP}/items.json" | head -1)"
  current() { jq -r --arg k "${KEY}" --arg f "$1" '.items[] | select(.key == $k) | .[$f] // empty' "${TMP}/items.json" | head -1; }

  if [ -z "${ITEM_ID}" ] && [ -n "$(recently_created "${KEY}")" ]; then
    echo "skip     ${KEY}  (created minutes ago; the board list has not caught up)"
    UNCHANGED=$((UNCHANGED+1)); i=$((i+1)); continue
  fi

  if [ "$(card .archive)" = "true" ]; then
    if [ -n "${ITEM_ID}" ]; then
      echo "archive  ${KEY}"; run gh project item-archive "${NUMBER}" --owner "${OWNER}" --id "${ITEM_ID}"
      ARCHIVED=$((ARCHIVED+1))
    fi
    i=$((i+1)); continue
  fi

  CHANGED=0
  if [ -z "${ITEM_ID}" ]; then
    [ -n "${TITLE}" ] || { echo "!! ${KEY}: new card has no title, skipped" >&2; ERRORS=$((ERRORS+1)); i=$((i+1)); continue; }
    echo "create   ${KEY}  ${TITLE}"
    if [ "${DRY}" = "1" ]; then
      ITEM_ID="(new)"
    elif [ -n "$(card .pr_url)" ]; then
      ITEM_ID="$(gh project item-add "${NUMBER}" --owner "${OWNER}" --url "$(card .pr_url)" --format json --jq '.id')"
    else
      ITEM_ID="$(gh project item-create "${NUMBER}" --owner "${OWNER}" --title "${TITLE}" --body "$(card .body)" --format json --jq '.id')"
    fi
    [ -n "${ITEM_ID}" ] || { echo "!! ${KEY}: could not create" >&2; ERRORS=$((ERRORS+1)); i=$((i+1)); continue; }
    [ "${DRY}" = "1" ] || printf '%s\t%s\t%s\n' "${NOW}" "${KEY}" "${ITEM_ID}" >> "${LEDGER}"
    CREATED=$((CREATED+1)); CHANGED=1; NEW=1
  else
    NEW=0
  fi

  set_text() { # field name, item-list json key, new value
    [ -n "$3" ] || return 0
    [ "${NEW}" = "0" ] && [ "$(current "$2")" = "$3" ] && return 0
    [ "${NEW}" = "0" ] && echo "update   ${KEY}  $1 -> $3"
    run gh project item-edit --project-id "${PROJECT_ID}" --id "${ITEM_ID}" --field-id "$(field_id "$1")" --text "$3"; CHANGED=1
  }
  set_select() {
    [ -n "$3" ] || return 0
    [ "${NEW}" = "0" ] && [ "$(current "$2")" = "$3" ] && return 0
    local opt; opt="$(option_id "$1" "$3")"
    [ -n "${opt}" ] || { echo "!! ${KEY}: \"$3\" is not a $1 option" >&2; ERRORS=$((ERRORS+1)); return 0; }
    [ "${NEW}" = "0" ] && echo "update   ${KEY}  $1 -> $3"
    run gh project item-edit --project-id "${PROJECT_ID}" --id "${ITEM_ID}" --field-id "$(field_id "$1")" --single-select-option-id "${opt}"; CHANGED=1
  }
  set_date() {
    [ -n "$3" ] || return 0
    [ "${NEW}" = "0" ] && [ "$(current "$2")" = "$3" ] && return 0
    [ "${NEW}" = "0" ] && echo "update   ${KEY}  $1 -> $3"
    run gh project item-edit --project-id "${PROJECT_ID}" --id "${ITEM_ID}" --field-id "$(field_id "$1")" --date "$3"; CHANGED=1
  }

  # An existing draft card's title and body are rewritten when the file gives different ones
  # (owner 2026-11-25: she opened a card and could not tell what it was; the body must be
  # able to be improved after the card exists). Real PR/issue cards are left alone.
  if [ "${NEW}" = "0" ]; then
    DRAFT_ID="$(jq -r --arg k "${KEY}" '.items[] | select(.key == $k) | select(.content.type == "DraftIssue") | .content.id // empty' "${TMP}/items.json" | head -1)"
    CUR_TITLE="$(jq -r --arg k "${KEY}" '.items[] | select(.key == $k) | .title // empty' "${TMP}/items.json" | head -1)"
    CUR_BODY="$(jq -r --arg k "${KEY}" '.items[] | select(.key == $k) | .content.body // empty' "${TMP}/items.json" | head -1)"
    WANT_BODY="$(card .body)"; WANT_TITLE="${TITLE:-${CUR_TITLE}}"; [ -n "${WANT_BODY}" ] || WANT_BODY="${CUR_BODY}"
    if [ -n "${DRAFT_ID}" ] && { [ "${WANT_TITLE}" != "${CUR_TITLE}" ] || [ "${WANT_BODY}" != "${CUR_BODY}" ]; }; then
      echo "update   ${KEY}  title/description"
      run gh project item-edit --id "${DRAFT_ID}" --title "${WANT_TITLE}" --body "${WANT_BODY}"; CHANGED=1
    fi
  fi

  # Key is written first: if a later call fails, the next run still finds this card
  # by Key and finishes it instead of creating a twin.
  NEW_KEY="$(card .new_key)"
  if [ "${NEW}" = "1" ]; then set_text "Key" "key" "${KEY}"; elif [ -n "${NEW_KEY}" ]; then set_text "Key" "key" "${NEW_KEY}"; fi
  # Columns are the built-in Status field (owner renamed them 2026-11-25). The six old
  # "Stage" names are still translated so a cards file written before that date sorts right.
  STATUS="$(card '.status // .stage')"
  case "${STATUS}" in
    "Inbox"|"Next up")       STATUS="Backlog/Todo" ;;
    "In progress")           STATUS="In Progress" ;;
    "Staging check owed")    STATUS="On Staging" ;;
    "Ready for production")  STATUS="Passed Staging Test" ;;
    "Done")                  STATUS="On Production" ;;
  esac
  set_select "Status" "status" "${STATUS}"
  # Areas were renamed by the owner on 2026-11-25 (Mobile -> Frontend, Web -> Website).
  AREA="$(card .area)"
  case "${AREA}" in "Mobile") AREA="Frontend" ;; "Web") AREA="Website" ;; esac
  set_select "Area" "area" "${AREA}"
  set_text "Next action" "next action" "$(card .next_action)"
  set_text "Waiting on" "waiting on" "$(card .waiting_on)"
  set_text "Where" "where" "$(card .where)"
  set_date "Last touched" "last touched" "$(card .last_touched)"

  if [ "${NEW}" = "0" ]; then
    if [ "${CHANGED}" = "1" ]; then UPDATED=$((UPDATED+1)); else UNCHANGED=$((UNCHANGED+1)); fi
  fi
  i=$((i+1))
done

echo
[ "${DRY}" = "1" ] && echo "DRY RUN - nothing was written."
echo "created: ${CREATED}   updated: ${UPDATED}   unchanged: ${UNCHANGED}   archived: ${ARCHIVED}   errors: ${ERRORS}"
# A failed GitHub call counts as an error (2026-11-25: GitHub returned 502s for several
# minutes and the summary still said "errors: 0"). The run is safe to repeat: fields that
# already hold the right value are skipped.
[ "${ERRORS}" -eq 0 ] || { echo "Some writes failed. Run the same command again to finish them." >&2; exit 1; }
