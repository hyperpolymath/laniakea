#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# scan-estate-beam.sh — estate-wide scan for the BEAM/Dialyzer defect classes
# that blocked hyperpolymath/laniakea PR #104 (Type Checking, job 116023124400).
#
# Defect classes (all measured on laniakea, 2026-10-14):
#   F. contract_supertype waiting to happen: mix.exs enables Dialyzer's
#      :underspecs flag while some module specifies a literal empty-struct
#      constructor as `@spec new() :: t()`. Dialyzer's success typing for
#      `def new, do: %Struct{}` is the empty struct itself, so `:: t()` is a
#      strict supertype and fails the first time Dialyzer actually runs to
#      completion (which may be years after the code was written, because an
#      earlier step in the quality chain — format, credo — kept failing
#      first). laniakea: GCounter/LWWRegister/ORSet.new/0. Fix: name the
#      exact empty type (`@type empty :: %Struct{...}`) and specify
#      `@spec new() :: empty()` — the struct literal lives in the @type, so
#      Credo's SpecWithStruct (which only inspects @spec) stays green too.
#   G. Toolchain pin behind locked deps: CI pins OTP <= 26 while mix.lock
#      contains a dependency whose code calls OTP 27+ APIs behind a runtime
#      `function_exported?` guard (db_connection 2.8.x calls
#      :proc_lib.set_label/1, added in OTP 27). Dialyzer's :unknown flag
#      reports it statically: ":proc_lib.set_label/1 is undefined or
#      private". Fix at source: align the OTP/Elixir pins with the locked
#      deps (OTP 27 / Elixir 1.17) — not a .dialyzer_ignore.exs entry.
#   H. Toolchain-blind cache keys: actions/cache entries for deps/_build/PLT
#      keyed only on hashFiles('**/mix.lock'). After a pin bump the stale
#      PLT/beams are silently restored and Dialyzer fails (or worse, passes
#      against the wrong runtime). Fix: include ELIXIR_VERSION/OTP_VERSION
#      in key and restore-keys (branch-newspaper already does this).
#   I. Workflow script injection (CodeQL actions/code-injection, Scorecard
#      DangerousWorkflow, zizmor template-injection): a `${{ ... }}`
#      context or step output interpolated inside a `run:` script. Fix:
#      pass the value through `env:` and reference the shell variable;
#      build JSON bodies with `jq --arg`, never string interpolation.
#   J. Clear-text endpoint literal (SonarCloud S5332 "Security Rating on
#      New Code" — the gate fires only when a change touches the file, so
#      a latent `http://` can sleep for years and then fail an unrelated
#      PR, exactly as boj-build.yml did on laniakea PR #104): a plain-HTTP
#      service URL hard-coded in a workflow. Fix: the endpoint is
#      deployment configuration — read it from a repo/org variable (e.g.
#      vars.BOJ_SERVER_URL, set to the HTTPS endpoint) and skip cleanly
#      when unset, instead of editing the scheme and hoping.
#
# Usage:
#   scripts/scan-estate-beam.sh [OWNER]           # scan all repos of OWNER
#   scripts/scan-estate-beam.sh OWNER/REPO ...    # scan named repos only
#
# Output: one CSV row per (repo, defect): repo,class,detail
# Requires: gh (authenticated), git, awk. Read-only: never writes to a repo.
# Per-repo work is a single shallow clone into a temp dir; set KEEP=1 to keep.

set -uo pipefail

OWNER="${SCAN_OWNER:-hyperpolymath}"
WORK="$(mktemp -d)"
[ "${KEEP:-}" = "1" ] || trap 'rm -rf "$WORK"' EXIT

# Emit one CSV row (repo,class,"detail"); double quotes in detail are swapped for single quotes.
emit() { printf '%s,%s,"%s"\n' "$1" "$2" "$(printf '%s' "$3" | tr '"' "'")"; }

scan_repo() {
  local full="$1" dir="$WORK/$(printf '%s' "$1" | tr '/' '_')"
  if ! git clone -q --depth 1 "https://github.com/$full.git" "$dir" 2>/dev/null; then
    emit "$full" "UNSCANNABLE" "shallow clone failed (empty, archived or no access)"
    return
  fi

  # F: :underspecs enabled anywhere + a `@spec new() :: t()` constructor spec.
  if grep -rq ':underspecs' --include='mix.exs' "$dir" 2>/dev/null; then
    local f
    while IFS= read -r f; do
      emit "$full" "F:spec-new-supertype-risk" "${f#"$dir"/}"
    done < <(grep -rl '@spec new() :: t()' --include='*.ex' "$dir" 2>/dev/null)
  fi

  # G: OTP <= 26 pinned in CI while mix.lock carries db_connection.
  if grep -rq '"db_connection"' --include='mix.lock' "$dir" 2>/dev/null; then
    local wf
    while IFS= read -r wf; do
      if grep -Eq "OTP_VERSION: *['\"]2[0-6](\.|['\"])|otp-version: *'?2[0-6](\.|')" "$wf" 2>/dev/null; then
        emit "$full" "G:toolchain-behind-locked-deps" "${wf#"$dir"/}"
      fi
    done < <(git -C "$dir" ls-files '.github/workflows/*' '.gitlab-ci.yml' 2>/dev/null | while IFS= read -r p; do printf '%s\n' "$dir/$p"; done)
  fi

  # H: mix deps/_build/PLT cache key without toolchain versions.
  local wf2
  while IFS= read -r wf2; do
    [ -f "$wf2" ] || continue
    if grep -E 'key:.*hashFiles\(.*mix\.lock' "$wf2" 2>/dev/null | grep -vq 'ELIXIR_VERSION\|OTP_VERSION'; then
      emit "$full" "H:toolchain-blind-cache-key" "${wf2#"$dir"/}"
    fi
  done < <(git -C "$dir" ls-files '.github/workflows/*' 2>/dev/null | while IFS= read -r p; do printf '%s\n' "$dir/$p"; done)

  # I: ${{ }} interpolation inside a run: script (inline or block scalar).
  local wf3
  while IFS= read -r wf3; do
    [ -f "$wf3" ] || continue
    awk '
      /^[[:space:]]*-?[[:space:]]*run:/ {
        line = $0
        sub(/^[[:space:]]*-?[[:space:]]*run:[[:space:]]*/, "", line)
        indent = index($0, "run:") - 1
        if (line ~ /\$\{\{/) { printf "%s:%d\n", FILENAME, NR }
        inrun = (line ~ /^[|>]/ || line == "")
        next
      }
      inrun {
        if ($0 ~ /^$/) next
        match($0, /^ */); cur = RLENGTH
        if (cur <= indent && $0 !~ /^ *$/) { inrun = 0 }
        else if ($0 ~ /\$\{\{/) { printf "%s:%d\n", FILENAME, NR }
      }
    ' "$wf3" | while IFS= read -r hit; do
      emit "$full" "I:run-interpolation" "${hit#"$dir"/}"
    done
  done < <(git -C "$dir" ls-files '.github/workflows/*' 2>/dev/null | while IFS= read -r p; do printf '%s\n' "$dir/$p"; done)

  # J: clear-text http:// service endpoint literals in workflows
  # (localhost and XML/schema namespaces are not service endpoints).
  local wf4
  while IFS= read -r wf4; do
    [ -f "$wf4" ] || continue
    grep -n 'http://' "$wf4" 2>/dev/null \
      | grep -v 'localhost\|127\.0\.0\.1\|www\.w3\.org\|schemas\.\|schema\.' \
      | while IFS= read -r hit; do
          emit "$full" "J:cleartext-endpoint-literal" "${wf4#"$dir"/}:${hit%%:*}"
        done
  done < <(git -C "$dir" ls-files '.github/workflows/*' 2>/dev/null | while IFS= read -r p; do printf '%s\n' "$dir/$p"; done)

  rm -rf "$dir"
}

printf 'repo,class,detail\n'
if [ "$#" -gt 0 ]; then
  repos=("$@")
else
  mapfile -t repos < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner')
fi
for r in "${repos[@]}"; do scan_repo "$r"; done
