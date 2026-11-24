#!/usr/bin/env bash
# Read-only fact collector for /board-sync. Prints JSON; writes nothing anywhere
# (the one exception is `git fetch`, which only refreshes remote-tracking refs).
# WHY a script and not ad-hoc commands in the skill: with ~95 worktrees the sweep
# must be identical on every run, and a script can be tested against a fixture repo
# (test_collect.sh, beside this file).
# Every variable is written ${LIKE_THIS} because zsh treats "$VAR:x" as a modifier.
#
# Usage:  collect.sh [<repo path>:<staging branch>:<production branch> ...]
#         Use "-" as the staging branch for a repo that has none.
#         With no arguments it sweeps the four Kinlia repos listed in DEFAULTS.
# Env:    BOARD_SYNC_SKIP_GH=1     skip the GitHub pull-request lookup (used by the test)
#         BOARD_SYNC_SKIP_FETCH=1  skip `git fetch` (faster, but may be stale)
set -u

# Staging/production branch names differ per repo, so they are stated here and never
# guessed. Checked 2026-11-23 with `git branch -r` in each repo.
DEFAULTS=(
  "${HOME}/Sites/kindra:develop:master"
  "${HOME}/Sites/KindraApp:testflight:master"
  "${HOME}/Sites/kinlia-web:staging:production"
  "${HOME}/Sites/event_scraper:-:main"
)

if [ "$#" -gt 0 ]; then SPECS=("$@"); else SPECS=("${DEFAULTS[@]}"); fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# true / false / null (null = that branch does not exist for this repo)
is_ancestor() { # worktree path, remote branch name
  if [ "$2" = "-" ] || ! git -C "$1" rev-parse --verify --quiet "origin/$2" >/dev/null; then
    echo null
  elif git -C "$1" merge-base --is-ancestor HEAD "origin/$2" 2>/dev/null; then
    echo true
  else
    echo false
  fi
}

ahead_of() { # worktree path, remote branch name -> commit count or null
  if [ "$2" = "-" ] || ! git -C "$1" rev-parse --verify --quiet "origin/$2" >/dev/null; then
    echo null
  else
    git -C "$1" rev-list --count "origin/$2..HEAD" 2>/dev/null || echo null
  fi
}

one_worktree() { # path, branch, staging, production -> one JSON object
  local path="$1" branch="$2" staging="$3" production="$4"
  if [ ! -d "${path}" ]; then
    # A worktree whose folder was removed by hand still shows in `git worktree list`.
    jq -n --arg path "${path}" --arg branch "${branch}" '{path:$path, branch:$branch, missing:true}'
    return
  fi
  local dirty untracked unpushed last
  dirty="$(git -C "${path}" status --short 2>/dev/null | wc -l | tr -d ' ')"
  # Untracked files are counted apart from edits to tracked files: a worktree holding
  # only stray new files (loose plan docs) is a much weaker "unfinished work" signal.
  untracked="$(git -C "${path}" status --short 2>/dev/null | command grep -c '^??')"
  if git -C "${path}" rev-parse --verify --quiet '@{upstream}' >/dev/null 2>&1; then
    unpushed="$(git -C "${path}" rev-list --count '@{upstream}..HEAD' 2>/dev/null)"
  else
    unpushed='"no-upstream"'
  fi
  last="$(git -C "${path}" log -1 --format=%cs 2>/dev/null)"
  jq -n \
    --arg path "${path}" --arg branch "${branch}" --arg last "${last}" \
    --argjson dirty "${dirty:-0}" --argjson untracked "${untracked:-0}" --argjson unpushed "${unpushed:-0}" \
    --argjson on_staging "$(is_ancestor "${path}" "${staging}")" \
    --argjson on_production "$(is_ancestor "${path}" "${production}")" \
    --argjson ahead_of_staging "$(ahead_of "${path}" "${staging}")" \
    --argjson ahead_of_production "$(ahead_of "${path}" "${production}")" \
    '{path:$path, branch:$branch, missing:false, dirty:$dirty,
      dirty_tracked:($dirty - $untracked), dirty_untracked:$untracked, unpushed:$unpushed,
      last_commit:$last, on_staging:$on_staging, on_production:$on_production,
      ahead_of_staging:$ahead_of_staging, ahead_of_production:$ahead_of_production}'
}

one_repo() { # spec -> one JSON object
  local spec="$1" production staging repo rest
  # Split from the right so a repo path may itself contain a colon-free space or dash.
  production="${spec##*:}"; rest="${spec%:*}"
  staging="${rest##*:}";    repo="${rest%:*}"

  if ! git -C "${repo}" rev-parse --git-dir >/dev/null 2>&1; then
    jq -n --arg path "${repo}" '{path:$path, error:"not a git repository"}'
    return
  fi
  [ "${BOARD_SYNC_SKIP_FETCH:-0}" = "1" ] || git -C "${repo}" fetch --quiet origin 2>/dev/null

  # --- worktrees: parse the porcelain listing (blank line ends each record) ---
  local wfile="${TMP}/wt.$$.${RANDOM}.jsonl" wpath="" wbranch=""
  : > "${wfile}"
  while IFS= read -r line || [ -n "${line}" ]; do
    case "${line}" in
      "worktree "*) wpath="${line#worktree }"; wbranch="(detached)" ;;
      "branch "*)   wbranch="${line#branch refs/heads/}" ;;
      "bare")       wpath="" ;;
      "")           [ -n "${wpath}" ] && one_worktree "${wpath}" "${wbranch}" "${staging}" "${production}" >> "${wfile}"; wpath="" ;;
    esac
  done < <(git -C "${repo}" worktree list --porcelain; echo)

  # --- merges that reached staging but are not on production yet ---
  local sfile="${TMP}/st.$$.${RANDOM}.jsonl"
  : > "${sfile}"
  if [ "${staging}" != "-" ] \
     && git -C "${repo}" rev-parse --verify --quiet "origin/${staging}" >/dev/null \
     && git -C "${repo}" rev-parse --verify --quiet "origin/${production}" >/dev/null; then
    # %x1f (unit separator) cannot appear in a commit subject, so it is a safe delimiter.
    # WHY not `--merges --first-parent`: that missed four known-unreleased backend PRs on
    # 2026-11-23. A squash merge is one ordinary commit named "... (#N)", and a PR merged
    # into a branch that was itself merged later is not on the first-parent line. So every
    # commit is read, and one is kept if it is a merge or its subject names a PR.
    git -C "${repo}" log "origin/${production}..origin/${staging}" \
        --format='%h%x1f%cs%x1f%P%x1f%s' 2>/dev/null \
      | jq -R 'split("\u001f")
               | {sha:.[0], date:.[1], merge:((.[2] | split(" ") | length) > 1), subject:.[3]}
               | .pr = ((.subject | capture("(?:^Merge (?:pull request|PR) #|\\(#)(?<n>[0-9]+)") | .n | tonumber) // null)
               | select(.merge or .pr != null)' >> "${sfile}"
  fi

  # --- open pull requests (GitHub) ---
  local url nwo prs='[]'
  url="$(git -C "${repo}" remote get-url origin 2>/dev/null)"
  nwo="$(printf '%s' "${url}" | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##')"
  if [ "${BOARD_SYNC_SKIP_GH:-0}" != "1" ] && printf '%s' "${url}" | command grep -q 'github\.com'; then
    prs="$(gh pr list -R "${nwo}" --state open --limit 200 \
            --json number,title,headRefName,baseRefName,updatedAt,isDraft,url 2>/dev/null || echo '[]')"
    [ -n "${prs}" ] || prs='[]'
  fi

  jq -n \
    --arg path "${repo}" --arg name "$(basename "${repo}")" --arg nwo "${nwo}" \
    --arg staging "${staging}" --arg production "${production}" \
    --argjson stashes "$(git -C "${repo}" stash list 2>/dev/null | wc -l | tr -d ' ')" \
    --argjson prs "${prs}" \
    --slurpfile worktrees "${wfile}" --slurpfile staged "${sfile}" \
    '{name:$name, path:$path, github:$nwo,
      staging_branch:(if $staging == "-" then null else $staging end),
      production_branch:$production, stashes:$stashes,
      open_prs:$prs, staged_not_released:$staged, worktrees:$worktrees}'
}

RFILE="${TMP}/repos.jsonl"
: > "${RFILE}"
for spec in "${SPECS[@]}"; do one_repo "${spec}" >> "${RFILE}"; done

jq -n --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --slurpfile repos "${RFILE}" \
  '{collected_at:$at, repos:$repos}'
