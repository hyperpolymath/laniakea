# PROOF-NEEDS.md — laniakea

## Current State (Updated 2026-04-11)

- **src/abi/crdt/*.idr**: 6 files (see below) — all CRDT algebraic proofs done
- **Dangerous patterns**: 0
- **LOC**: ~8,800 (Elixir)
- **ABI layer**: Present — CRDT semilattice laws + 4 CRDT implementations

## Completed Proofs

| File | What it proves |
|------|---------------|
| `src/abi/crdt/SemilatticeLaws.idr` | Semilattice interface: merge commutativity + associativity + idempotence for all CRDT types |
| `src/abi/crdt/MaxNat.idr` | MaxNat semilattice (max of two naturals satisfies all 3 laws) |
| `src/abi/crdt/GCounter.idr` | G-Counter: vector of MaxNat values, implements Semilattice |
| `src/abi/crdt/PNCounter.idr` | PN-Counter: two G-Counters (increments + decrements), implements Semilattice |
| `src/abi/crdt/LWWRegister.idr` | LWW-Register: last-write-wins with timestamp ordering |
| `src/abi/crdt/ORSet.idr` | OR-Set: observed-remove set with unique tags, implements Semilattice |

## What Still Needs Proving

| Component | What | Why |
|-----------|------|-----|
| Policy engine decisions | Policy evaluation is deterministic and total | Inconsistent policy decisions across nodes break system |
| Command bus ordering | Commands are delivered in causal order | Out-of-order commands corrupt CRDT state |

The above are P2 and require deeper modeling of the Elixir policy engine and Phoenix PubSub command bus.

## Recommended Prover

**Idris2** — Already in use; CRDT properties proved constructively.

## Priority

**LOW** (was HIGH) — CRDT algebraic proofs complete 2026-04-11. Remaining items are higher-effort policy/ordering proofs at lower priority.
