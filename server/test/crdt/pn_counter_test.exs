# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule Laniakea.CRDT.PNCounterTest do
  use ExUnit.Case, async: true
  alias Laniakea.CRDT.PNCounter

  doctest PNCounter

  describe "new/0" do
    test "creates a counter with zero value" do
      counter = PNCounter.new()
      assert PNCounter.value(counter) == 0
    end
  end

  describe "increment/2" do
    test "increments the counter" do
      counter = PNCounter.new()
        |> PNCounter.increment("node1")
        |> PNCounter.increment("node1")

      assert PNCounter.value(counter) == 2
    end
  end

  describe "decrement/2" do
    test "decrements the counter" do
      counter = PNCounter.new()
        |> PNCounter.increment("node1", 5)
        |> PNCounter.decrement("node1", 3)

      assert PNCounter.value(counter) == 2
    end

    test "allows negative values" do
      counter = PNCounter.new()
        |> PNCounter.decrement("node1", 5)

      assert PNCounter.value(counter) == -5
    end
  end

  describe "merge/2" do
    test "merges positive and negative counters" do
      a = PNCounter.new()
        |> PNCounter.increment("node1", 10)
        |> PNCounter.decrement("node1", 3)

      b = PNCounter.new()
        |> PNCounter.increment("node2", 5)
        |> PNCounter.decrement("node2", 2)

      merged = PNCounter.merge(a, b)
      assert PNCounter.value(merged) == 10  # (10-3) + (5-2)
    end

    test "is commutative" do
      a = PNCounter.new() |> PNCounter.increment("a", 5)
      b = PNCounter.new() |> PNCounter.decrement("b", 3)

      ab = PNCounter.merge(a, b)
      ba = PNCounter.merge(b, a)

      assert PNCounter.value(ab) == PNCounter.value(ba)
    end

    test "is associative" do
      a = PNCounter.new() |> PNCounter.increment("a", 1)
      b = PNCounter.new() |> PNCounter.decrement("b", 2)
      c = PNCounter.new() |> PNCounter.increment("c", 3)

      left = PNCounter.merge(PNCounter.merge(a, b), c)
      right = PNCounter.merge(a, PNCounter.merge(b, c))

      assert PNCounter.value(left) == PNCounter.value(right)
    end

    test "is idempotent" do
      a = PNCounter.new()
        |> PNCounter.increment("a", 5)
        |> PNCounter.decrement("a", 2)

      assert PNCounter.value(PNCounter.merge(a, a)) == PNCounter.value(a)
    end
  end

  describe "to_wire/1 and from_wire/1" do
    test "round-trips correctly" do
      counter = PNCounter.new()
        |> PNCounter.increment("node1", 10)
        |> PNCounter.decrement("node1", 3)

      wire = PNCounter.to_wire(counter)
      restored = PNCounter.from_wire(wire)

      assert PNCounter.value(restored) == PNCounter.value(counter)
    end
  end

  @tag :property
  describe "CRDT laws" do
    test "verifies all laws" do
      assert :ok == Laniakea.CRDT.verify(PNCounter)
    end
  end
end
