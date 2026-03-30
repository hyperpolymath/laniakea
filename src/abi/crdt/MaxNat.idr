-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- MaxNat: Proofs that `maximum` on natural numbers forms a semilattice.
-- This is the foundation for GCounter (pointwise max) and by extension
-- PNCounter (pair of GCounters).

%default total

module MaxNat

import Data.Nat

||| max(a, b) = max(b, a)
export
maxCommutative : (a, b : Nat) -> maximum a b = maximum b a
maxCommutative Z Z = Refl
maxCommutative Z (S k) = Refl
maxCommutative (S k) Z = Refl
maxCommutative (S j) (S k) = cong S (maxCommutative j k)

||| max(max(a, b), c) = max(a, max(b, c))
export
maxAssociative : (a, b, c : Nat) -> maximum (maximum a b) c = maximum a (maximum b c)
maxAssociative Z Z Z = Refl
maxAssociative Z Z (S k) = Refl
maxAssociative Z (S j) Z = Refl
maxAssociative Z (S j) (S k) = Refl
maxAssociative (S i) Z Z = Refl
maxAssociative (S i) Z (S k) = cong S (maxAssociative i Z k)
maxAssociative (S i) (S j) Z = cong S (maxAssociative i j Z)
maxAssociative (S i) (S j) (S k) = cong S (maxAssociative i j k)

||| max(a, a) = a
export
maxIdempotent : (a : Nat) -> maximum a a = a
maxIdempotent Z = Refl
maxIdempotent (S k) = cong S (maxIdempotent k)
