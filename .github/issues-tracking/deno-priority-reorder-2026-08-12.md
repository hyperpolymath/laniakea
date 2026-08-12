# Issue: Update JavaScript Runtime Priority Order - Bun > Deno > pnpm > npm

**Status**: ✅ RESOLVED  
**Date**: 2026-08-12  
**Related**: standards#67, standards#253  
**Supersedes**: Previous "Deno first" policy  

## Summary

Updated the estate-wide JavaScript/TypeScript runtime priority order from "Deno first, always" to **Bun > Deno > pnpm > npm** across all policy documents and AI guidance.

## Changes Made

### 1. rhodium-standard-repositories/spec/LANGUAGE-POLICY.adoc

**JavaScript / Node Ecosystem Policy** (lines 400-420):
- Changed from:
  1. Deno first, always
  2. pnpm as the Node-runtime fallback
  3. No other JavaScript runtimes (Bun was banned)
  
- Changed to:
  1. **Bun first** - Default for all new work
  2. **Deno second** - Grandfathered, no migration required
  3. **pnpm** - Node-runtime fallback only
  4. **npm** - Last resort

**Banned Languages Table** (lines 282-287):
- Removed Bun from banned list
- Updated rationale to reflect that previous assessment ("too young, moves too fast") was superseded 2026-07-29

### 2. AI Instruction Files

**ai-instruction/opus.md**:
- Updated architectural defaults from "Deno first" to "Bun first then Deno then pnpm then npm"

**ai-instruction/sonnet.md**:
- Updated architectural defaults from "Deno first" to "Bun first then Deno then pnpm then npm"

### 3. cccp README

**rhodium-standard-repositories/satellites/cccp/README.adoc**:
- Updated Post-JavaScript Liberation section to reflect current priority

## Files Modified

### hyper-repos/standards
- rhodium-standard-repositories/spec/LANGUAGE-POLICY.adoc
- ai-instruction/opus.md
- ai-instruction/sonnet.md
- rhodium-standard-repositories/satellites/cccp/README.adoc

### worktrees/standards-debtfile
- rhodium-standard-repositories/spec/LANGUAGE-POLICY.adoc
- ai-instruction/opus.md
- ai-instruction/sonnet.md
- rhodium-standard-repositories/satellites/cccp/README.adoc

### hyper-repos/standards/.claude/worktrees (nix-references-clause, a2ml-design)
- rhodium-standard-repositories/spec/LANGUAGE-POLICY.adoc
- ai-instruction/opus.md
- ai-instruction/sonnet.md

## Grandfather Clause

**Existing Deno projects are grandfathered and need not migrate.**

The policy explicitly states:
> "Existing Deno projects are *grandfathered* and need not migrate; prefer it over pnpm/npm when Bun genuinely cannot be used."

This means:
- ✅ New projects: Use Bun
- ✅ Existing Deno projects: May stay on Deno
- ✅ Migration from Deno to Bun: Optional, not required
- ✅ New Deno projects: Only when Bun genuinely cannot be used

## Current Deno Usage

As of 2026-08-12:
- **34 repositories** have root-level `deno.json` files
- **89 repositories** have `deno.lock` files
- **~245 additional** `deno.json` files in subdirectories

See `/home/hyperpolymath/developer/dev-notes/deno-audit-2026-08-12.md` for complete audit details.

## Migration Assessment

If opportunistic migration from Deno to Bun is desired in the future:

| Complexity | Repos | Effort | Notes |
|------------|-------|--------|-------|
| Simple | ~25 | 1-2 hours each | TypeScript-only, no Deno-specific APIs |
| Medium | ~8 | 4-8 hours each | Some Deno APIs used |
| Complex | ~1 | 16-24 hours | Heavy Deno-specific features (FFI, etc.) |

**Total estimated effort**: 73-138 hours for full migration (not required by policy)

## Blockers to Bun Adoption

1. **Deno FFI**: Repos using Deno's foreign function interface cannot easily migrate
2. **Deno-specific ecosystem**: Some JSR packages may not have Bun equivalents
3. **Team familiarity**: Migration requires learning curve

## Recommendation

✅ **Do NOT launch a formal Deno→Bun migration campaign**

Instead:
- Use Bun for all new projects (policy)
- Allow existing Deno projects to stay on Deno (grandfather clause)
- Migrate opportunistically when:
  - Team is already working in the repo
  - Migration aligns with other planned work
  - Bun offers clear advantages for that specific use case

## Verification

Run these commands to verify the changes:

```bash
# No "Deno first" should remain in policy files
grep -r "Deno first" hyper-repos/standards/ worktrees/standards-debtfile/ 2>/dev/null
grep -r "Deno first" hyper-repos/standards/.claude/worktrees/ 2>/dev/null
# Should return no results

# Verify priority order
grep -A5 "JavaScript.*Node Ecosystem" \
  hyper-repos/standards/rhodium-standard-repositories/spec/LANGUAGE-POLICY.adoc
# Should show: 1. Bun, 2. Deno, 3. pnpm, 4. npm
```

## Related Issues

- standards#67 - npm-avoidant: package-lock.json must never be tracked
- standards#68 - .editorconfig/.claude must not be tracked
- standards#252 - ReScript → AffineScript migration
- standards#253 - npm → Deno migration (substantially complete)
- standards#254 - JavaScript → AffineScript migration

## Closing Criteria

- [x] All policy documents updated with new priority order
- [x] Grandfather clause explicitly stated
- [x] AI guidance updated
- [x] Audit of current Deno usage completed
- [x] Migration assessment documented
- [x] Verification commands provided
