# SPDX-License-Identifier: PMPL-1.0-or-later
# StreamData property tests verifying CRDT mathematical invariants.
#
# The three core semilattice laws (commutativity, associativity, idempotency)
# must hold for all four CRDT types under arbitrary operation sequences.

defmodule Laniakea.CRDT.PropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Laniakea.CRDT.GCounter
  alias Laniakea.CRDT.PNCounter
  alias Laniakea.CRDT.ORSet
  alias Laniakea.CRDT.LWWRegister

  # ---------------------------------------------------------------------------
  # Generators
  # ---------------------------------------------------------------------------

  # Node ID generator — short printable ASCII identifiers.
  defp node_id_gen do
    StreamData.string(:alphanumeric, min_length: 1, max_length: 8)
  end

  # Non-negative integer increment amount.
  defp amount_gen, do: StreamData.integer(1..1000)

  # Element to store in ORSet (printable strings).
  defp element_gen do
    StreamData.string(:alphanumeric, min_length: 1, max_length: 20)
  end

  # Register value (arbitrary terms represented as strings).
  defp register_value_gen do
    StreamData.string(:printable, min_length: 0, max_length: 30)
  end

  # Build a GCounter from a list of {node_id, amount} tuples.
  defp build_gcounter(ops) do
    Enum.reduce(ops, GCounter.new(), fn {nid, amt}, acc ->
      GCounter.increment(acc, nid, amt)
    end)
  end

  # Build a PNCounter from a list of {:inc | :dec, node_id, amount} tuples.
  defp build_pncounter(ops) do
    Enum.reduce(ops, PNCounter.new(), fn
      {:inc, nid, amt}, acc -> PNCounter.increment_by(acc, nid, amt)
      {:dec, nid, amt}, acc -> PNCounter.decrement_by(acc, nid, amt)
    end)
  end

  # Build an ORSet from a list of {:add | :remove, element, node_id} tuples.
  defp build_orset(ops) do
    Enum.reduce(ops, ORSet.new(), fn
      {:add, elem, nid}, acc -> ORSet.add(acc, elem, nid)
      {:remove, elem, _},  acc -> ORSet.remove(acc, elem)
    end)
  end

  # ---------------------------------------------------------------------------
  # GCounter semilattice laws
  # ---------------------------------------------------------------------------

  describe "GCounter: commutativity" do
    property "merge(a, b) == merge(b, a) in value" do
      check all ops_a <- StreamData.list_of(StreamData.tuple({node_id_gen(), amount_gen()}), min_length: 0, max_length: 10),
                ops_b <- StreamData.list_of(StreamData.tuple({node_id_gen(), amount_gen()}), min_length: 0, max_length: 10) do
        a = build_gcounter(ops_a)
        b = build_gcounter(ops_b)

        assert GCounter.value(GCounter.merge(a, b)) == GCounter.value(GCounter.merge(b, a))
      end
    end
  end

  describe "GCounter: associativity" do
    property "merge(merge(a, b), c) == merge(a, merge(b, c)) in value" do
      check all ops_a <- StreamData.list_of(StreamData.tuple({node_id_gen(), amount_gen()}), max_length: 8),
                ops_b <- StreamData.list_of(StreamData.tuple({node_id_gen(), amount_gen()}), max_length: 8),
                ops_c <- StreamData.list_of(StreamData.tuple({node_id_gen(), amount_gen()}), max_length: 8) do
        a = build_gcounter(ops_a)
        b = build_gcounter(ops_b)
        c = build_gcounter(ops_c)

        left  = GCounter.value(GCounter.merge(GCounter.merge(a, b), c))
        right = GCounter.value(GCounter.merge(a, GCounter.merge(b, c)))

        assert left == right
      end
    end
  end

  describe "GCounter: idempotency" do
    property "merge(a, a) == a in value" do
      check all ops <- StreamData.list_of(StreamData.tuple({node_id_gen(), amount_gen()}), max_length: 15) do
        a = build_gcounter(ops)
        assert GCounter.value(GCounter.merge(a, a)) == GCounter.value(a)
      end
    end
  end

  describe "GCounter: monotonicity" do
    property "incrementing never decreases value" do
      check all ops <- StreamData.list_of(StreamData.tuple({node_id_gen(), amount_gen()}), min_length: 1, max_length: 10),
                {nid, amt} <- StreamData.tuple({node_id_gen(), amount_gen()}) do
        before = build_gcounter(ops)
        after_ = GCounter.increment(before, nid, amt)

        assert GCounter.value(after_) >= GCounter.value(before)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PNCounter semilattice laws
  # ---------------------------------------------------------------------------

  defp pn_op_gen do
    StreamData.one_of([
      StreamData.tuple({StreamData.constant(:inc), node_id_gen(), amount_gen()}),
      StreamData.tuple({StreamData.constant(:dec), node_id_gen(), amount_gen()})
    ])
  end

  describe "PNCounter: commutativity" do
    property "merge(a, b) == merge(b, a) in value" do
      check all ops_a <- StreamData.list_of(pn_op_gen(), max_length: 8),
                ops_b <- StreamData.list_of(pn_op_gen(), max_length: 8) do
        a = build_pncounter(ops_a)
        b = build_pncounter(ops_b)

        assert PNCounter.value(PNCounter.merge(a, b)) == PNCounter.value(PNCounter.merge(b, a))
      end
    end
  end

  describe "PNCounter: idempotency" do
    property "merge(a, a) == a in value" do
      check all ops <- StreamData.list_of(pn_op_gen(), max_length: 12) do
        a = build_pncounter(ops)
        assert PNCounter.value(PNCounter.merge(a, a)) == PNCounter.value(a)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # ORSet semilattice laws
  # ---------------------------------------------------------------------------

  defp orset_op_gen do
    StreamData.one_of([
      StreamData.tuple({StreamData.constant(:add), element_gen(), node_id_gen()}),
      StreamData.tuple({StreamData.constant(:remove), element_gen(), node_id_gen()})
    ])
  end

  describe "ORSet: commutativity" do
    property "merge(a, b) has same elements as merge(b, a)" do
      check all ops_a <- StreamData.list_of(orset_op_gen(), max_length: 8),
                ops_b <- StreamData.list_of(orset_op_gen(), max_length: 8) do
        a = build_orset(ops_a)
        b = build_orset(ops_b)

        assert ORSet.elements(ORSet.merge(a, b)) == ORSet.elements(ORSet.merge(b, a))
      end
    end
  end

  describe "ORSet: associativity" do
    property "merge(merge(a, b), c) has same elements as merge(a, merge(b, c))" do
      check all ops_a <- StreamData.list_of(orset_op_gen(), max_length: 6),
                ops_b <- StreamData.list_of(orset_op_gen(), max_length: 6),
                ops_c <- StreamData.list_of(orset_op_gen(), max_length: 6) do
        a = build_orset(ops_a)
        b = build_orset(ops_b)
        c = build_orset(ops_c)

        left  = ORSet.elements(ORSet.merge(ORSet.merge(a, b), c))
        right = ORSet.elements(ORSet.merge(a, ORSet.merge(b, c)))

        assert left == right
      end
    end
  end

  describe "ORSet: idempotency" do
    property "merge(a, a) has same elements as a" do
      check all ops <- StreamData.list_of(orset_op_gen(), max_length: 12) do
        a = build_orset(ops)
        assert ORSet.elements(ORSet.merge(a, a)) == ORSet.elements(a)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # LWWRegister: merge determinism
  # ---------------------------------------------------------------------------

  describe "LWWRegister: last-writer-wins ordering" do
    property "higher timestamp always wins after merge" do
      check all value_a <- register_value_gen(),
                value_b <- register_value_gen(),
                ts_a    <- StreamData.integer(1..1_000_000),
                ts_b    <- StreamData.integer(1..1_000_000),
                ts_a != ts_b do
        reg = LWWRegister.new()
        r_a = LWWRegister.set_with_timestamp(reg, value_a, "node_a", ts_a)
        r_b = LWWRegister.set_with_timestamp(reg, value_b, "node_b", ts_b)

        merged = LWWRegister.merge(r_a, r_b)

        expected_value = if ts_a > ts_b, do: value_a, else: value_b
        assert LWWRegister.value(merged) == expected_value
      end
    end

    property "merge is commutative: merge(a, b) == merge(b, a) in value" do
      check all value_a <- register_value_gen(),
                value_b <- register_value_gen(),
                ts_a    <- StreamData.integer(1..1_000_000),
                ts_b    <- StreamData.integer(1..1_000_000) do
        reg = LWWRegister.new()
        r_a = LWWRegister.set_with_timestamp(reg, value_a, "node_a", ts_a)
        r_b = LWWRegister.set_with_timestamp(reg, value_b, "node_b", ts_b)

        assert LWWRegister.value(LWWRegister.merge(r_a, r_b)) ==
               LWWRegister.value(LWWRegister.merge(r_b, r_a))
      end
    end

    property "merge(a, a) == a in value (idempotency)" do
      check all value <- register_value_gen(),
                ts    <- StreamData.integer(1..1_000_000) do
        reg = LWWRegister.set_with_timestamp(LWWRegister.new(), value, "node1", ts)
        assert LWWRegister.value(LWWRegister.merge(reg, reg)) == LWWRegister.value(reg)
      end
    end
  end
end
