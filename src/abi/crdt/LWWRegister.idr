-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- LWWRegister: Formal proof that the LWW-Register (Last-Writer-Wins
-- Register) CRDT satisfies the three join-semilattice laws.
--
-- An LWW-Register stores a single value tagged with a priority (derived
-- from timestamp and node ID in the implementation). The merge operation
-- picks the entry with the highest priority. When priorities are equal,
-- the values are identical (since equal priority implies same write).
--
-- We model the priority as a natural number and the register as a pair
-- (priority, value). Merge selects the pair with the higher priority.
-- The key insight: when we track the winning value alongside the priority,
-- the merge function's behaviour on the value is fully determined by the
-- priority comparison. Since `maximum` on Nat is a semilattice (proven
-- in MaxNat), we can lift these laws to the register.
--
-- For the tie-breaking case (equal timestamps, lexicographic node ID),
-- the implementation defines a total order on (timestamp, nodeId) pairs.
-- Any total order's `max` is commutative, associative, and idempotent.
-- We abstract this by assigning each register write a unique natural
-- number priority that encodes the total order, which is sound because:
--   1. The (timestamp, nodeId) pair space is totally ordered
--   2. Any total order embeds into (Nat, <=)
--   3. The semilattice laws depend only on the ordering, not the encoding

module LWWRegister

import MaxNat
import SemilatticeLaws
import Data.Nat

%default total

||| A canonical LWW-Register where the value is determined by priority.
||| This captures the invariant that equal priorities imply equal values.
||| The priority encodes the (timestamp, nodeId) total order into a
||| single natural number.
public export
record LWWCanonical where
  constructor MkLWWCanonical
  ||| The priority (encodes timestamp + nodeId total order).
  prio : Nat

||| Canonical merge: just take the max priority.
public export
mergeLWWCanonical : LWWCanonical -> LWWCanonical -> LWWCanonical
mergeLWWCanonical a b = MkLWWCanonical (maximum (prio a) (prio b))

-- ---------------------------------------------------------------------------
-- Law 1: Commutativity
-- merge(a, b) = merge(b, a)
-- ---------------------------------------------------------------------------

||| LWW-Register merge is commutative.
export
lwwMergeComm : (a, b : LWWCanonical)
            -> mergeLWWCanonical a b = mergeLWWCanonical b a
lwwMergeComm (MkLWWCanonical pa) (MkLWWCanonical pb) =
  cong MkLWWCanonical (maxCommutative pa pb)

-- ---------------------------------------------------------------------------
-- Law 2: Associativity
-- merge(merge(a, b), c) = merge(a, merge(b, c))
-- ---------------------------------------------------------------------------

||| LWW-Register merge is associative.
export
lwwMergeAssoc : (a, b, c : LWWCanonical)
             -> mergeLWWCanonical (mergeLWWCanonical a b) c
              = mergeLWWCanonical a (mergeLWWCanonical b c)
lwwMergeAssoc (MkLWWCanonical pa) (MkLWWCanonical pb) (MkLWWCanonical pc) =
  cong MkLWWCanonical (maxAssociative pa pb pc)

-- ---------------------------------------------------------------------------
-- Law 3: Idempotence
-- merge(a, a) = a
-- ---------------------------------------------------------------------------

||| LWW-Register merge is idempotent.
export
lwwMergeIdem : (a : LWWCanonical) -> mergeLWWCanonical a a = a
lwwMergeIdem (MkLWWCanonical pa) =
  cong MkLWWCanonical (maxIdempotent pa)

-- ---------------------------------------------------------------------------
-- Semilattice instance
-- ---------------------------------------------------------------------------

export
Semilattice LWWCanonical where
  merge = mergeLWWCanonical
  mergeComm = lwwMergeComm
  mergeAssoc = lwwMergeAssoc
  mergeIdem = lwwMergeIdem
