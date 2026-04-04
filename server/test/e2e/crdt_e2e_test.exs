# SPDX-License-Identifier: PMPL-1.0-or-later
# End-to-end tests for Laniakea CRDT operations.
#
# Tests exercise the full CRDT lifecycle: creation, mutation, merge, and
# serialisation round-trips. No external services are required.

defmodule Laniakea.CRDT.E2ETest do
  use ExUnit.Case, async: true

  alias Laniakea.CRDT.GCounter
  alias Laniakea.CRDT.PNCounter
  alias Laniakea.CRDT.ORSet
  alias Laniakea.CRDT.LWWRegister

  @moduletag :e2e

  # ---------------------------------------------------------------------------
  # GCounter: create → increment → merge → query → serialise
  # ---------------------------------------------------------------------------

  describe "GCounter full lifecycle" do
    test "create, increment on multiple nodes, merge, read value" do
      node_a = GCounter.new() |> GCounter.increment("node1", 10) |> GCounter.increment("node2", 5)
      node_b = GCounter.new() |> GCounter.increment("node1", 3) |> GCounter.increment("node3", 7)

      merged = GCounter.merge(node_a, node_b)

      # node1 max = 10, node2 = 5, node3 = 7
      assert GCounter.value(merged) == 22
    end

    test "wire round-trip preserves value after increments" do
      counter =
        GCounter.new()
        |> GCounter.increment("alpha", 100)
        |> GCounter.increment("beta", 50)

      wire = GCounter.to_map(counter)
      assert is_map(wire)

      # Re-hydrate using the string-keyed wire format expected by from_wire/1.
      restored = GCounter.from_wire(%{"counts" => Map.new(wire.counts, fn {k, v} -> {k, v} end), "version" => wire.version})
      assert GCounter.value(restored) == GCounter.value(counter)
    end

    test "merging the same replica is idempotent" do
      counter = GCounter.new() |> GCounter.increment("x", 42)
      merged = GCounter.merge(counter, counter)
      assert GCounter.value(merged) == GCounter.value(counter)
    end

    test "three-way merge converges regardless of order" do
      a = GCounter.new() |> GCounter.increment("a", 1)
      b = GCounter.new() |> GCounter.increment("b", 2)
      c = GCounter.new() |> GCounter.increment("c", 3)

      ab_c = GCounter.merge(GCounter.merge(a, b), c)
      a_bc = GCounter.merge(a, GCounter.merge(b, c))

      assert GCounter.value(ab_c) == GCounter.value(a_bc)
    end
  end

  # ---------------------------------------------------------------------------
  # PNCounter: create → increment/decrement → merge → query → serialise
  # ---------------------------------------------------------------------------

  describe "PNCounter full lifecycle" do
    test "increment and decrement yield correct value" do
      counter =
        PNCounter.new()
        |> PNCounter.increment("node1")
        |> PNCounter.increment("node1")
        |> PNCounter.increment("node1")
        |> PNCounter.decrement("node1")

      assert PNCounter.value(counter) == 2
    end

    test "merge of two independent replicas converges" do
      a =
        PNCounter.new()
        |> PNCounter.increment("alice")
        |> PNCounter.increment("alice")

      b =
        PNCounter.new()
        |> PNCounter.increment("bob")
        |> PNCounter.decrement("bob")

      merged = PNCounter.merge(a, b)
      # alice: +2, bob: +1 -1 = 0 → total 2
      assert PNCounter.value(merged) == 2
    end

    test "wire serialisation round-trip" do
      counter =
        PNCounter.new()
        |> PNCounter.increment_by("node1", 10)
        |> PNCounter.decrement_by("node1", 3)

      map = PNCounter.to_map(counter)
      assert map.type == "pn_counter"

      restored = PNCounter.from_wire(%{
        "positive" => Map.new(map.positive, fn {k, v} -> {k, v} end),
        "negative" => Map.new(map.negative, fn {k, v} -> {k, v} end),
        "version" => map.version
      })

      assert PNCounter.value(restored) == PNCounter.value(counter)
    end
  end

  # ---------------------------------------------------------------------------
  # ORSet: create → add → remove → merge → query
  # ---------------------------------------------------------------------------

  describe "ORSet full lifecycle" do
    test "add, remove, query elements" do
      set =
        ORSet.new()
        |> ORSet.add("apple", "node1")
        |> ORSet.add("banana", "node2")
        |> ORSet.add("cherry", "node1")
        |> ORSet.remove("banana")

      assert ORSet.member?(set, "apple")
      refute ORSet.member?(set, "banana")
      assert ORSet.member?(set, "cherry")
    end

    test "concurrent add and remove — add wins for unseen removes" do
      a = ORSet.new() |> ORSet.add("item", "node1")
      b = ORSet.new()  # node2 never saw the add

      merged = ORSet.merge(a, b)
      assert ORSet.member?(merged, "item")
    end

    test "three-replica convergence" do
      a = ORSet.new() |> ORSet.add("x", "n1")
      b = ORSet.new() |> ORSet.add("y", "n2")
      c = ORSet.new() |> ORSet.add("z", "n3")

      ab_c = ORSet.merge(ORSet.merge(a, b), c)
      a_bc = ORSet.merge(a, ORSet.merge(b, c))

      assert ORSet.elements(ab_c) == ORSet.elements(a_bc)
    end

    test "wire round-trip preserves elements" do
      set =
        ORSet.new()
        |> ORSet.add("alpha", "n1")
        |> ORSet.add("beta", "n2")
        |> ORSet.remove("alpha")

      wire = ORSet.to_map(set)
      assert is_map(wire)
      # Re-hydrate; from_wire expects string-keyed "elements".
      restored = ORSet.from_wire(%{"elements" => Map.get(wire, :elements, %{})})

      assert ORSet.elements(restored) == ORSet.elements(set)
    end
  end

  # ---------------------------------------------------------------------------
  # LWWRegister: create → set → merge → query
  # ---------------------------------------------------------------------------

  describe "LWWRegister full lifecycle" do
    test "last write wins on concurrent updates" do
      reg = LWWRegister.new()

      # Use set_with_timestamp for deterministic control over ordering.
      reg_a = LWWRegister.set_with_timestamp(reg, "value_a", "node1", 100)
      reg_b = LWWRegister.set_with_timestamp(reg, "value_b", "node2", 200)

      merged = LWWRegister.merge(reg_a, reg_b)
      assert LWWRegister.value(merged) == "value_b"
    end

    test "equal timestamps — deterministic winner regardless of merge order" do
      reg = LWWRegister.new()
      reg_a = LWWRegister.set_with_timestamp(reg, "A", "node_a", 500)
      reg_b = LWWRegister.set_with_timestamp(reg, "B", "node_b", 500)

      merged_ab = LWWRegister.merge(reg_a, reg_b)
      merged_ba = LWWRegister.merge(reg_b, reg_a)

      # Both directions must produce the same deterministic winner.
      assert LWWRegister.value(merged_ab) == LWWRegister.value(merged_ba)
    end

    test "merge is idempotent" do
      reg = LWWRegister.set_with_timestamp(LWWRegister.new(), "hello", "node1", 1000)
      merged = LWWRegister.merge(reg, reg)
      assert LWWRegister.value(merged) == LWWRegister.value(reg)
    end

    test "wire round-trip preserves value and timestamp" do
      reg = LWWRegister.set_with_timestamp(LWWRegister.new(), "persist_me", "node1", 9999)
      wire = LWWRegister.to_map(reg)
      assert is_map(wire)
      # Re-hydrate using the string-keyed wire format.
      restored = LWWRegister.from_wire(%{
        "value"     => wire.value,
        "timestamp" => wire.timestamp,
        "node_id"   => wire.node_id
      })
      assert LWWRegister.value(restored) == "persist_me"
    end
  end
end
