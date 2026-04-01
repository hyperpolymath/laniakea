# PROOF-NEEDS.md — laniakea

## Current State

- **src/abi/*.idr**: NO
- **Dangerous patterns**: 0
- **LOC**: ~8,800 (Elixir)
- **ABI layer**: Missing

## What Needs Proving

| Component | What | Why |
|-----------|------|-----|
| CRDT convergence | G-Counter, PN-Counter, LWW-Register, OR-Set converge correctly | CRDTs MUST converge — this is their fundamental invariant |
| CRDT merge commutativity | merge(a, b) == merge(b, a) for all CRDT types | Non-commutative merge breaks distributed consistency |
| CRDT merge idempotence | merge(a, a) == a | Duplicate messages must not corrupt state |
| CRDT merge associativity | merge(a, merge(b, c)) == merge(merge(a, b), c) | Required for correct multi-node convergence |
| Policy engine decisions | Policy evaluation is deterministic and total | Inconsistent policy decisions across nodes break system |
| Command bus ordering | Commands are delivered in causal order | Out-of-order commands corrupt CRDT state |

## Recommended Prover

**Idris2** — CRDT algebraic properties (commutativity, associativity, idempotence) are ideal for dependent types. Alternatively **Agda** for the abstract algebra proofs, with Idris2 for the ABI layer.

## Priority

**HIGH** — CRDTs are mathematically defined structures. If merge operations don't satisfy their algebraic laws, the entire distributed system fails silently. These are textbook proofs that SHOULD exist.
