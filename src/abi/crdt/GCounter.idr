-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- GCounter: Formal proof that the G-Counter (Grow-only Counter) CRDT
-- satisfies the three join-semilattice laws.
--
-- A G-Counter maps node IDs to natural number counts. The merge operation
-- takes the pointwise maximum. We model this as a function from node IDs
-- to Nat and prove the laws lift from MaxNat.

%default total

module GCounter

import MaxNat
import SemilatticeLaws

||| A G-Counter state modelled as a function from node identifiers to
||| natural number counts. Using a function representation keeps proofs
||| clean — the ReScript/Elixir implementations use finite maps, but the
||| algebraic laws depend only on pointwise max behaviour.
public export
record GCount (nodeId : Type) where
  constructor MkGCount
  ||| Lookup the count for a given node. Absent nodes implicitly map to 0.
  lookup : nodeId -> Nat

||| Pointwise maximum merge for G-Counters.
public export
mergeGCount : GCount n -> GCount n -> GCount n
mergeGCount a b = MkGCount (\node => maximum (lookup a node) (lookup b node))

-- ---------------------------------------------------------------------------
-- Law 1: Commutativity
-- merge(a, b) = merge(b, a)
-- ---------------------------------------------------------------------------

||| Proof that G-Counter merge is commutative. Follows directly from
||| commutativity of `maximum` at each node.
export
gCountMergeComm : (a, b : GCount n) -> mergeGCount a b = mergeGCount b a
gCountMergeComm (MkGCount fa) (MkGCount fb) =
  -- Need to show: MkGCount (\node => max (fa node) (fb node))
  --             = MkGCount (\node => max (fb node) (fa node))
  -- This follows from funext + maxCommutative, but Idris2 has eta for
  -- records, so we rewrite under the constructor:
  let lemma : (\node => maximum (fa node) (fb node))
            = (\node => maximum (fb node) (fa node))
      lemma = funExt (\node => maxCommutative (fa node) (fb node))
  in cong MkGCount lemma

-- ---------------------------------------------------------------------------
-- Law 2: Associativity
-- merge(merge(a, b), c) = merge(a, merge(b, c))
-- ---------------------------------------------------------------------------

||| Proof that G-Counter merge is associative. Follows from associativity
||| of `maximum` at each node.
export
gCountMergeAssoc : (a, b, c : GCount n)
                -> mergeGCount (mergeGCount a b) c
                 = mergeGCount a (mergeGCount b c)
gCountMergeAssoc (MkGCount fa) (MkGCount fb) (MkGCount fc) =
  let lemma : (\node => maximum (maximum (fa node) (fb node)) (fc node))
            = (\node => maximum (fa node) (maximum (fb node) (fc node)))
      lemma = funExt (\node => maxAssociative (fa node) (fb node) (fc node))
  in cong MkGCount lemma

-- ---------------------------------------------------------------------------
-- Law 3: Idempotence
-- merge(a, a) = a
-- ---------------------------------------------------------------------------

||| Proof that G-Counter merge is idempotent. Follows from idempotence
||| of `maximum` at each node.
export
gCountMergeIdem : (a : GCount n) -> mergeGCount a a = a
gCountMergeIdem (MkGCount fa) =
  let lemma : (\node => maximum (fa node) (fa node)) = fa
      lemma = funExt (\node => maxIdempotent (fa node))
  in cong MkGCount lemma

-- ---------------------------------------------------------------------------
-- Semilattice instance
-- ---------------------------------------------------------------------------

export
Semilattice (GCount n) where
  merge = mergeGCount
  mergeComm = gCountMergeComm
  mergeAssoc = gCountMergeAssoc
  mergeIdem = gCountMergeIdem
