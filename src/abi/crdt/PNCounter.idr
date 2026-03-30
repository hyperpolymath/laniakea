-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- PNCounter: Formal proof that the PN-Counter (Positive-Negative Counter)
-- CRDT satisfies the three join-semilattice laws.
--
-- A PN-Counter is a pair of G-Counters (positive, negative). The merge
-- operation merges each component independently. Since the product of
-- two semilattices is itself a semilattice, the laws follow from GCounter.

%default total

module PNCounter

import GCounter
import SemilatticeLaws

||| A PN-Counter is a pair of G-Counters: one for increments (positive)
||| and one for decrements (negative). The observable value is
||| value(positive) - value(negative).
public export
record PNCount (nodeId : Type) where
  constructor MkPNCount
  ||| The G-Counter tracking positive increments.
  positive : GCount nodeId
  ||| The G-Counter tracking negative increments (decrements).
  negative : GCount nodeId

||| Merge two PN-Counters by merging each G-Counter component.
public export
mergePNCount : PNCount n -> PNCount n -> PNCount n
mergePNCount a b = MkPNCount (mergeGCount (positive a) (positive b))
                             (mergeGCount (negative a) (negative b))

-- ---------------------------------------------------------------------------
-- Law 1: Commutativity
-- ---------------------------------------------------------------------------

||| PN-Counter merge is commutative because each G-Counter component
||| merge is commutative.
export
pnCountMergeComm : (a, b : PNCount n) -> mergePNCount a b = mergePNCount b a
pnCountMergeComm a b =
  let posComm = gCountMergeComm (positive a) (positive b)
      negComm = gCountMergeComm (negative a) (negative b)
  in rewrite posComm in rewrite negComm in Refl

-- ---------------------------------------------------------------------------
-- Law 2: Associativity
-- ---------------------------------------------------------------------------

||| PN-Counter merge is associative because each G-Counter component
||| merge is associative.
export
pnCountMergeAssoc : (a, b, c : PNCount n)
                 -> mergePNCount (mergePNCount a b) c
                  = mergePNCount a (mergePNCount b c)
pnCountMergeAssoc a b c =
  let posAssoc = gCountMergeAssoc (positive a) (positive b) (positive c)
      negAssoc = gCountMergeAssoc (negative a) (negative b) (negative c)
  in rewrite posAssoc in rewrite negAssoc in Refl

-- ---------------------------------------------------------------------------
-- Law 3: Idempotence
-- ---------------------------------------------------------------------------

||| PN-Counter merge is idempotent because each G-Counter component
||| merge is idempotent.
export
pnCountMergeIdem : (a : PNCount n) -> mergePNCount a a = a
pnCountMergeIdem (MkPNCount pos neg) =
  let posIdem = gCountMergeIdem pos
      negIdem = gCountMergeIdem neg
  in rewrite posIdem in rewrite negIdem in Refl

-- ---------------------------------------------------------------------------
-- Semilattice instance
-- ---------------------------------------------------------------------------

export
Semilattice (PNCount n) where
  merge = mergePNCount
  mergeComm = pnCountMergeComm
  mergeAssoc = pnCountMergeAssoc
  mergeIdem = pnCountMergeIdem
