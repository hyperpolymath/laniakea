-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- ORSet: Formal proof that the OR-Set (Observed-Remove Set) CRDT
-- satisfies the three join-semilattice laws.
--
-- An OR-Set maps elements to sets of unique tags. The merge operation
-- takes the pointwise union of tag sets. We model tag sets as predicates
-- (tag -> Bool) and prove the laws lift from boolean OR semilattice
-- properties.

%default total

module ORSet

import SemilatticeLaws
import Data.Bool

-- ---------------------------------------------------------------------------
-- Boolean OR semilattice lemmas
-- ---------------------------------------------------------------------------

||| Boolean OR is commutative.
orComm : (a, b : Bool) -> (a || b) = (b || a)
orComm False False = Refl
orComm False True  = Refl
orComm True  False = Refl
orComm True  True  = Refl

||| Boolean OR is associative.
orAssoc : (a, b, c : Bool) -> ((a || b) || c) = (a || (b || c))
orAssoc False False False = Refl
orAssoc False False True  = Refl
orAssoc False True  False = Refl
orAssoc False True  True  = Refl
orAssoc True  False False = Refl
orAssoc True  False True  = Refl
orAssoc True  True  False = Refl
orAssoc True  True  True  = Refl

||| Boolean OR is idempotent.
orIdem : (a : Bool) -> (a || a) = a
orIdem False = Refl
orIdem True  = Refl

-- ---------------------------------------------------------------------------
-- Tag set model
--
-- We represent a set of tags as a characteristic function (tag -> Bool).
-- Union corresponds to pointwise OR. This is isomorphic to the powerset
-- lattice and avoids needing a concrete set implementation.
-- ---------------------------------------------------------------------------

||| A characteristic-function set over tag type `tag`.
public export
record TagSet (tag : Type) where
  constructor MkTagSet
  ||| Membership predicate: True iff the tag is in the set.
  member : tag -> Bool

||| Union of two tag sets (pointwise OR).
public export
tagUnion : TagSet t -> TagSet t -> TagSet t
tagUnion a b = MkTagSet (\tg => member a tg || member b tg)

tagUnionComm : (a, b : TagSet t) -> tagUnion a b = tagUnion b a
tagUnionComm (MkTagSet fa) (MkTagSet fb) =
  cong MkTagSet (funExt (\tg => orComm (fa tg) (fb tg)))

tagUnionAssoc : (a, b, c : TagSet t)
             -> tagUnion (tagUnion a b) c = tagUnion a (tagUnion b c)
tagUnionAssoc (MkTagSet fa) (MkTagSet fb) (MkTagSet fc) =
  cong MkTagSet (funExt (\tg => orAssoc (fa tg) (fb tg) (fc tg)))

tagUnionIdem : (a : TagSet t) -> tagUnion a a = a
tagUnionIdem (MkTagSet fa) =
  cong MkTagSet (funExt (\tg => orIdem (fa tg)))

-- ---------------------------------------------------------------------------
-- OR-Set model
--
-- An OR-Set maps elements to tag sets. Merge takes the pointwise union
-- of tag sets for each element. This is the product semilattice over the
-- element domain, where each factor is a TagSet semilattice.
-- ---------------------------------------------------------------------------

||| An OR-Set state: for each element, a set of unique tags identifying
||| the add operations that produced it.
public export
record ORSetState (elem : Type) (tag : Type) where
  constructor MkORSet
  ||| Lookup the tag set for a given element.
  tags : elem -> TagSet tag

||| Merge two OR-Sets by taking the pointwise union of tag sets.
public export
mergeORSet : ORSetState e t -> ORSetState e t -> ORSetState e t
mergeORSet a b = MkORSet (\el => tagUnion (tags a el) (tags b el))

-- ---------------------------------------------------------------------------
-- Law 1: Commutativity
-- ---------------------------------------------------------------------------

||| OR-Set merge is commutative.
export
orSetMergeComm : (a, b : ORSetState e t) -> mergeORSet a b = mergeORSet b a
orSetMergeComm (MkORSet fa) (MkORSet fb) =
  cong MkORSet (funExt (\el => tagUnionComm (fa el) (fb el)))

-- ---------------------------------------------------------------------------
-- Law 2: Associativity
-- ---------------------------------------------------------------------------

||| OR-Set merge is associative.
export
orSetMergeAssoc : (a, b, c : ORSetState e t)
               -> mergeORSet (mergeORSet a b) c
                = mergeORSet a (mergeORSet b c)
orSetMergeAssoc (MkORSet fa) (MkORSet fb) (MkORSet fc) =
  cong MkORSet (funExt (\el => tagUnionAssoc (fa el) (fb el) (fc el)))

-- ---------------------------------------------------------------------------
-- Law 3: Idempotence
-- ---------------------------------------------------------------------------

||| OR-Set merge is idempotent.
export
orSetMergeIdem : (a : ORSetState e t) -> mergeORSet a a = a
orSetMergeIdem (MkORSet fa) =
  cong MkORSet (funExt (\el => tagUnionIdem (fa el)))

-- ---------------------------------------------------------------------------
-- Semilattice instance
-- ---------------------------------------------------------------------------

export
Semilattice (ORSetState e t) where
  merge = mergeORSet
  mergeComm = orSetMergeComm
  mergeAssoc = orSetMergeAssoc
  mergeIdem = orSetMergeIdem
