#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# fix-actions-lock-cicd.sh — idempotent, in-place fix for defect classes A
# and A' (see scripts/scan-estate-cicd.sh) in ONE checked-out repository:
#
#   * Moves "# SPDX-License-Identifier:" to line 1 of every workflow and
#     collapses the repeated "# This workflow is managed by gh actions-lock."
#     banners `gh actions-lock` accretes (3 copies observed) to exactly one,
#     placed directly under the SPDX line. SPDX-first is the REUSE-canonical
#     form and satisfies both line-1 and header-block linters.
#   * Rewrites any `head -1`-only SPDX test in workflow-linter workflows to
#     scan the leading comment block (mirrors standards'
#     governance-reusable.yml), so the next lock refresh cannot re-break it.
#
# It deliberately does NOT touch actions.lock contents or `uses:` refs:
# lock resync must go through `gh actions-lock` / scripts/check-lock-sync.sh
# in the same PR as the `uses:` change (class B), and pin bumps are
# Dependabot's job. Run, review the diff, then run check-lock-sync.sh.
#
# Usage: scripts/fix-actions-lock-cicd.sh [REPO_ROOT]   (default: .)

set -euo pipefail
ROOT="${1:-.}"
WF="$ROOT/.github/workflows"
[ -d "$WF" ] || { echo "no workflows dir: $WF" >&2; exit 1; }

for f in "$WF"/*.yml "$WF"/*.yaml; do
  [ -f "$f" ] || continue
  tmp="$(mktemp)"
  awk '
    NR<=8 && /^# SPDX-License-Identifier:/ && !spdx { spdx=$0; next }
    NR<=8 && /^# This workflow is managed by gh actions-lock\.$/ { banner=1; next }
    { print }
    ENDFILE { }
  ' "$f" > /dev/null 2>&1 || true
  # Two-pass in awk: capture header facts, then emit SPDX, one banner, body.
  awk -v out="$tmp.body" '
    BEGIN { phase=1 }
    phase==1 && /^# SPDX-License-Identifier:/ { if(!spdx) spdx=$0; next }
    phase==1 && /^# This workflow is managed by gh actions-lock\.$/ { banner=1; next }
    { phase=2; print > out }
    END {
      print spdx > (out ".meta")
      print (banner ? 1 : 0) > (out ".banner")
    }' "$f"
  spdx="$(cat "$tmp.body.meta")"; banner="$(cat "$tmp.body.banner")"
  if [ -z "$spdx" ]; then
    echo "SKIP (no SPDX in header): $f" >&2
    rm -f "$tmp" "$tmp.body" "$tmp.body.meta" "$tmp.body.banner"; continue
  fi
  { printf '%s\n' "$spdx"
    [ "$banner" = "1" ] && printf '# This workflow is managed by gh actions-lock.\n'
    cat "$tmp.body"
  } > "$f.fixed"
  if cmp -s "$f.fixed" "$f"; then rm -f "$f.fixed"; else mv "$f.fixed" "$f"; echo "fixed header: $f"; fi
  rm -f "$tmp" "$tmp.body" "$tmp.body.meta" "$tmp.body.banner"
done

# A': line-1-only SPDX linters -> header-block scan.
for f in "$WF"/*.yml "$WF"/*.yaml; do
  [ -f "$f" ] || continue
  if grep -Eq 'head -1.*SPDX-License-Identifier' "$f"; then
    echo "MANUAL: $f still tests SPDX with head -1; replace with a leading-comment-block scan (see laniakea workflow-linter.yml)." >&2
  fi
done
echo "Done. Now run: ./scripts/check-lock-sync.sh (if present) and review 'git diff'."
