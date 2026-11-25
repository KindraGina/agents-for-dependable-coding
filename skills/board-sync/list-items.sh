#!/usr/bin/env bash
# Reads every card on the board, cheaply. Prints the same JSON shape as
# `gh project item-list --format json` ({"items":[{id,title,status,area,key,...,content}]}),
# so the other scripts read it unchanged.
# WHY (2026-11-25): `gh project item-list` asks GitHub for far more than a card's fields.
# Measured on the 212-card board: one read cost 304 of the 5,000 points GitHub allows per
# hour, shared by every terminal. About 16 reads emptied the hour's allowance, which cut
# off /wrap in other terminals mid-card. This asks only for what the board skills use.
#
# Usage:  list-items.sh > items.json      exit 3 = GitHub refused or the read is incomplete
set -u
PROJECT_ID="${BOARD_PROJECT_ID:-PVT_kwDOAdN4bc4BtCUB}"
TMP="$(mktemp -d)"; trap 'rm -rf "${TMP}"' EXIT

cat > "${TMP}/q.graphql" <<'GQL'
query($id: ID!, $after: String) {
  node(id: $id) { ... on ProjectV2 { items(first: 100, after: $after) {
    pageInfo { hasNextPage endCursor }
    nodes {
      id
      fieldValues(first: 20) { nodes {
        __typename
        ... on ProjectV2ItemFieldTextValue { text field { ... on ProjectV2FieldCommon { name } } }
        ... on ProjectV2ItemFieldDateValue { date field { ... on ProjectV2FieldCommon { name } } }
        ... on ProjectV2ItemFieldSingleSelectValue { name field { ... on ProjectV2FieldCommon { name } } }
      } }
      content {
        __typename
        ... on DraftIssue { id title body }
        ... on Issue { id title body number url }
        ... on PullRequest { id title body number url }
      }
    }
  } } }
}
GQL

# One card in the shape gh prints: field names lower-cased, Title lifted to .title.
cat > "${TMP}/shape.jq" <<'JQ'
[ .[] | .data.node.items.nodes[] |
  ( [ .fieldValues.nodes[] | select(.field.name != null)
      | { key: (.field.name | ascii_downcase), value: (.text // .date // .name) } ]
    | from_entries ) as $f
  | ($f + { id: .id,
            title: ($f.title // .content.title // ""),
            content: ((.content // {}) | { id, title, body, number, url, type: .__typename }
                      | with_entries(select(.value != null))) })
] | { items: ., totalCount: length }
JQ

AFTER=""; : > "${TMP}/pages.jsonl"
while :; do
  if [ -n "${AFTER}" ]; then
    gh api graphql -F id="${PROJECT_ID}" -f after="${AFTER}" -f query="$(cat "${TMP}/q.graphql")" > "${TMP}/page.json" 2>"${TMP}/err.txt"
  else
    gh api graphql -F id="${PROJECT_ID}" -f query="$(cat "${TMP}/q.graphql")" > "${TMP}/page.json" 2>"${TMP}/err.txt"
  fi
  RC=$?
  if [ "${RC}" -ne 0 ] || ! jq -e '.data.node.items.nodes | type == "array"' "${TMP}/page.json" >/dev/null 2>&1; then
    echo "could not read the board: $(head -2 "${TMP}/err.txt") $(jq -r '.errors[0].message // empty' "${TMP}/page.json" 2>/dev/null)" >&2
    exit 3
  fi
  jq -c '.' "${TMP}/page.json" >> "${TMP}/pages.jsonl"
  [ "$(jq -r '.data.node.items.pageInfo.hasNextPage' "${TMP}/page.json")" = "true" ] || break
  AFTER="$(jq -r '.data.node.items.pageInfo.endCursor' "${TMP}/page.json")"
done
jq -s -f "${TMP}/shape.jq" "${TMP}/pages.jsonl"
