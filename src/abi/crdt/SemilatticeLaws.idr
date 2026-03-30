-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- SemilatticeLaws: Shared interface and law definitions for CRDT merge
-- operations. Every state-based CRDT must form a join-semilattice under
-- its merge function, satisfying commutativity, associativity, and
-- idempotence.

module SemilatticeLaws

%default total

||| A Semilattice bundles a carrier type with a merge operation and proofs
||| that the three CRDT algebraic laws hold for all inhabitants.
public export
interface Semilattice s where
  ||| The merge (join) operation for combining two CRDT states.
  merge : s -> s -> s

  ||| Commutativity: merge(a, b) = merge(b, a)
  mergeComm : (a : s) -> (b : s) -> merge a b = merge b a

  ||| Associativity: merge(merge(a, b), c) = merge(a, merge(b, c))
  mergeAssoc : (a : s) -> (b : s) -> (c : s)
            -> merge (merge a b) c = merge a (merge b c)

  ||| Idempotence: merge(a, a) = a
  mergeIdem : (a : s) -> merge a a = a
