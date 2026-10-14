<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
## Summary

<!-- Briefly describe what this PR does and why. Link to related issues with "Closes #N". -->

## Changes

<!-- List the key changes introduced by this PR. -->

-

## RSR Quality Checklist

<!-- Check all that apply. PRs that fail required checks will not be merged. -->

### Required

- [ ] Tests pass (`just test` or equivalent)
- [ ] Code is formatted (`mix format --check-formatted` in `server/`, `deno fmt --check` in `client/`)
- [ ] Linter is clean (`mix credo --strict`, `deno lint`; no new warnings)
- [ ] No banned language patterns (no Python, Go, TypeScript or ReScript; JavaScript runs Bun > Deno > pnpm > npm — Bun/bunx first, Deno only where already load-bearing)
- [ ] No `unsafe` blocks without `// SAFETY:` comments
- [ ] No banned functions (`believe_me`, `unsafeCoerce`, `Obj.magic`, `Admitted`, `sorry`)
- [ ] SPDX license headers present on all new/modified source files
- [ ] No secrets, credentials, or `.env` files included
- [ ] If any `uses:` changed: `actions.lock` resynced in this same PR (`./scripts/check-lock-sync.sh` passes)

### As Applicable

- [ ] `.machine_readable/6a2/STATE.a2ml` updated (if project state changed)
- [ ] `docs/` updated for architectural decisions or user-facing changes
- [ ] `TOPOLOGY.adoc` updated (if architecture changed)
- [ ] `CHANGELOG.adoc` or release notes updated
- [ ] New dependencies reviewed for license compatibility (MPL-2.0)
- [ ] ABI changes validated (`src/abi/` Idris2 definitions and their Zig/FFI counterparts consistent)

## Testing

<!-- Describe how you tested these changes. -->

## Screenshots

<!-- If applicable, add screenshots or terminal output demonstrating the change. -->
