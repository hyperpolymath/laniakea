# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule Laniakea.CRDT.GCounterTest do
  use ExUnit.Case, async: true
  alias Laniakea.CRDT.GCounter

  doctest GCounter

  describe "new/0" do
    test "creates an empty counter" do
      counter = GCounter.new()
      assert GCounter.value(counter) == 0
    end
  end

  describe "increment/2" do
    test "increments the counter for a node" do
      counter = GCounter.new()
        |> GCounter.increment("node1")
        |> GCounter.increment("node1")
        |> GCounter.increment("node1")

      assert GCounter.value(counter) == 3
    end

    test "tracks increments per node" do
      counter = GCounter.new()
        |> GCounter.increment("node1")
        |> GCounter.increment("node2")
        |> GCounter.increment("node1")

      assert GCounter.value(counter) == 3
    end
  end

  describe "increment/3" do
    test "increments by a specific amount" do
      counter = GCounter.new()
        |> GCounter.increment("node1", 5)
        |> GCounter.increment("node1", 3)

      assert GCounter.value(counter) == 8
    end

    test "rejects negative increments" do
      counter = GCounter.new()

      assert_raise ArgumentError, fn ->
        GCounter.increment(counter, "node1", -1)
      end
    end
  end

  describe "merge/2" do
    test "merges two counters taking max per node" do
      a = GCounter.new()
        |> GCounter.increment("node1", 5)
        |> GCounter.increment("node2", 3)

      b = GCounter.new()
        |> GCounter.increment("node1", 3)
        |> GCounter.increment("node2", 7)
        |> GCounter.increment("node3", 2)

      merged = GCounter.merge(a, b)
      assert GCounter.value(merged) == 14  # 5 + 7 + 2
    end

    test "is commutative" do
      a = GCounter.new() |> GCounter.increment("a", 5)
      b = GCounter.new() |> GCounter.increment("b", 3)

      assert GCounter.value(GCounter.merge(a, b)) == GCounter.value(GCounter.merge(b, a))
    end

    test "is associative" do
      a = GCounter.new() |> GCounter.increment("a", 1)
      b = GCounter.new() |> GCounter.increment("b", 2)
      c = GCounter.new() |> GCounter.increment("c", 3)

      left = GCounter.merge(GCounter.merge(a, b), c)
      right = GCounter.merge(a, GCounter.merge(b, c))

      assert GCounter.value(left) == GCounter.value(right)
    end

    test "is idempotent" do
      a = GCounter.new() |> GCounter.increment("a", 5)

      assert GCounter.value(GCounter.merge(a, a)) == GCounter.value(a)
    end
  end

  describe "to_wire/1 and from_wire/1" do
    test "round-trips correctly" do
      counter = GCounter.new()
        |> GCounter.increment("node1", 5)
        |> GCounter.increment("node2", 3)

      wire = GCounter.to_wire(counter)
      restored = GCounter.from_wire(wire)

      assert GCounter.value(restored) == GCounter.value(counter)
    end

    test "wire format has expected structure" do
      counter = GCounter.new() |> GCounter.increment("node1", 5)
      wire = GCounter.to_wire(counter)

      assert wire.type == "g_counter"
      assert wire.counts["node1"] == 5
    end
  end

  @tag :property
  describe "CRDT laws" do
    test "verifies all laws" do
      assert :ok == Laniakea.CRDT.verify(GCounter)
    end
  end
end
