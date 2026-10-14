#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# scan-estate-cicd.sh — estate-wide scan for the CI/CD defect classes that
# blocked hyperpolymath/laniakea PR #98 (dependabot "actions" group bump).
#
# Defect classes (all measured on laniakea, 2026-10-14):
#   A. SPDX not on line 1: `gh actions-lock` inserts
#      "# This workflow is managed by gh actions-lock." at line 1 (often 3x),
#      pushing "# SPDX-License-Identifier:" to line 2. Any workflow linter
#      that tests `head -1` then fails EVERY managed workflow, forever.
#   B. actions.lock desync: Dependabot rewrites `uses:` in workflow YAML but
#      cannot update .github/workflows/actions.lock dependency records
#      (e.g. haskell-actions/setup v2.12.1 in YAML vs v2.12.0 in the lock,
#      landed by laniakea PR #96 and inherited by PR #98). Both the local
#      Lock Sync Gate and standards' "Actions lockfile verify" go red.
#   C. Bypassable Dependabot hold: a bare `ignore: [github/codeql-action]`
#      with no `versions:` constraint is bypassed by SHA-form re-bumps, so
#      the "held" action is bumped anyway (laniakea PR #98; nexia-list#101).
#   D. Stale pin comments: a SHA bump that leaves "# v<old>" next to the new
#      SHA (PR #98 left "# v4.38.0 (4.38.1 blocked...)" on a v4.38.3 SHA).
#   E. CLAUDE.md language-policy drift: listing Deno under "### BANNED"
#      fails standards' check-language-policy.sh (Deno is tier 2 since the
#      owner ruling of 2026-10-14; Bun tier 1, pnpm 3, npm 4).
#
# Usage:
#   scripts/scan-estate-cicd.sh [OWNER]           # scan all repos of OWNER
#   scripts/scan-estate-cicd.sh OWNER/REPO ...    # scan named repos only
#
# Output: one CSV row per (repo, defect): repo,class,detail
# Requires: gh (authenticated), jq, git. Read-only: never writes to a repo.
# Per-repo work is a single shallow clone into a temp dir; set KEEP=1 to keep.

set -uo pipefail

OWNER="${SCAN_OWNER:-hyperpolymath}"
WORK="$(mktemp -d)"
[ "${KEEP:-}" = "1" ] || trap 'rm -rf "$WORK"' EXIT

emit() { printf '%s,%s,"%s"\n' "$1" "$2" "$(printf '%s' "$3" | tr '"' "'")"; }

scan_repo() {
  local full="$1" dir="$WORK/$(printf '%s' "$1" | tr '/' '_')"
  if ! git clone -q --depth 1 "https://github.com/$full.git" "$dir" 2>/dev/null; then
    emit "$full" "UNSCANNABLE" "shallow clone failed (empty, archived or no access)"
    return
  fi
  local wf="$dir/.github/workflows" f first
  if [ -d "$wf" ]; then
    for f in "$wf"/*.yml "$wf"/*.yaml; do
      [ -f "$f" ] || continue
      first="$(head -1 "$f")"
      # A: banner (duplicated or not) ahead of the SPDX line
      if [ "$first" = "# This workflow is managed by gh actions-lock." ]; then
        emit "$full" "A:spdx-not-line-1" "${f#"$dir"/}"
      fi
      if [ "$(grep -c '^# This workflow is managed by gh actions-lock\.$' "$f")" -gt 1 ]; then
        emit "$full" "A:duplicate-actions-lock-banner" "${f#"$dir"/}"
      fi
      # A': a line-1-only SPDX linter re-creates class A on every lock refresh
      if grep -Eq 'head -1.*SPDX|SPDX.*head -1' "$f"; then
        emit "$full" "A:line-1-spdx-linter" "${f#"$dir"/}"
      fi
      # D: stale hold/blocked comments left on a re-pinned SHA (PR #98 left
      # "# v4.38.0 (4.38.1 blocked estate-wide...)" on a v4.38.3 SHA).
      grep -E 'uses:.*@[0-9a-f]{40}[[:space:]]+#.*(blocked|HOLD|do not bump)' "$f" \
        | while IFS= read -r line; do emit "$full" "D:stale-hold-comment-on-pin" "$line"; done || true
    done
    # B: lock/YAML sync (reuse the repo's own checker when present)
    if [ -f "$wf/actions.lock" ]; then
      if [ -x "$dir/scripts/check-lock-sync.sh" ]; then
        (cd "$dir" && ./scripts/check-lock-sync.sh >/dev/null 2>&1) \
          || emit "$full" "B:actions-lock-desync" "scripts/check-lock-sync.sh failed"
      fi
    elif grep -rqE 'uses:[[:space:]]*[^[:space:]][^[:space:]]*@' "$wf" 2>/dev/null; then
      emit "$full" "B:no-actions-lock" "workflows use external actions but no actions.lock"
    fi
  fi
  # C: bare codeql-action ignore with no versions constraint
  if [ -f "$dir/.github/dependabot.yml" ] \
     && grep -A3 'dependency-name: "github/codeql-action"' "$dir/.github/dependabot.yml" \
        | grep -qv 'versions:' \
     && grep -q 'dependency-name: "github/codeql-action"' "$dir/.github/dependabot.yml"; then
    # Only a finding if the entry sits under an `ignore:` block.
    if awk '/ignore:/{i=1} /dependency-name: "github\/codeql-action"/{if(i)found=1} END{exit !found}' \
         "$dir/.github/dependabot.yml"; then
      emit "$full" "C:bypassable-codeql-hold" ".github/dependabot.yml"
    fi
  fi
  # E: Deno listed as banned in a CLAUDE.md policy table
  local claude
  while IFS= read -r claude; do
    if awk '/^### /{banned=($0 ~ /^### BANNED/)} banned && /^\|[[:space:]]*\*{0,2}Deno\*{0,2}[[:space:]]*\|/{found=1} END{exit !found}' "$claude"; then
      emit "$full" "E:deno-listed-as-banned" "${claude#"$dir"/}"
    fi
  done < <(git -C "$dir" ls-files '*CLAUDE.md' 2>/dev/null | while IFS= read -r p; do printf '%s\n' "$dir/$p"; done)
  rm -rf "$dir"
}

printf 'repo,class,detail\n'
if [ "$#" -gt 0 ]; then
  repos=("$@")
else
  mapfile -t repos < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner')
fi
for r in "${repos[@]}"; do scan_repo "$r"; done
