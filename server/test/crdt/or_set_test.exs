# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule Laniakea.CRDT.ORSetTest do
  use ExUnit.Case, async: true
  alias Laniakea.CRDT.ORSet

  doctest ORSet

  describe "new/0" do
    test "creates an empty set" do
      set = ORSet.new()
      assert ORSet.elements(set) == MapSet.new()
    end
  end

  describe "add/3" do
    test "adds an element to the set" do
      set = ORSet.new()
        |> ORSet.add("apple", "node1")

      assert ORSet.member?(set, "apple")
    end

    test "can add the same element multiple times" do
      set = ORSet.new()
        |> ORSet.add("apple", "node1")
        |> ORSet.add("apple", "node2")

      assert ORSet.member?(set, "apple")
      assert MapSet.size(ORSet.elements(set)) == 1
    end
  end

  describe "remove/2" do
    test "removes an element from the set" do
      set = ORSet.new()
        |> ORSet.add("apple", "node1")
        |> ORSet.remove("apple")

      refute ORSet.member?(set, "apple")
    end

    test "add-remove-add keeps the element" do
      set = ORSet.new()
        |> ORSet.add("apple", "node1")
        |> ORSet.remove("apple")
        |> ORSet.add("apple", "node2")

      assert ORSet.member?(set, "apple")
    end

    test "removing non-existent element is no-op" do
      set = ORSet.new() |> ORSet.remove("banana")
      assert ORSet.elements(set) == MapSet.new()
    end
  end

  describe "merge/2" do
    test "merges two sets" do
      a = ORSet.new() |> ORSet.add("apple", "node1")
      b = ORSet.new() |> ORSet.add("banana", "node2")

      merged = ORSet.merge(a, b)

      assert ORSet.member?(merged, "apple")
      assert ORSet.member?(merged, "banana")
    end

    test "concurrent add and remove - add wins" do
      # Both start empty
      a = ORSet.new() |> ORSet.add("item", "node1")
      b = ORSet.new()

      # Node2 never saw the add, so remove doesn't apply to node1's tag
      merged = ORSet.merge(a, b)
      assert ORSet.member?(merged, "item")
    end

    test "remove after seeing add removes the element" do
      # Node1 adds
      a = ORSet.new() |> ORSet.add("item", "node1")

      # Node2 sees the add then removes
      b = ORSet.merge(a, ORSet.new()) |> ORSet.remove("item")

      # After merge, item should be removed
      merged = ORSet.merge(a, b)
      refute ORSet.member?(merged, "item")
    end

    test "is commutative" do
      a = ORSet.new() |> ORSet.add("x", "a")
      b = ORSet.new() |> ORSet.add("y", "b")

      assert ORSet.elements(ORSet.merge(a, b)) == ORSet.elements(ORSet.merge(b, a))
    end

    test "is associative" do
      a = ORSet.new() |> ORSet.add("x", "a")
      b = ORSet.new() |> ORSet.add("y", "b")
      c = ORSet.new() |> ORSet.add("z", "c")

      left = ORSet.merge(ORSet.merge(a, b), c)
      right = ORSet.merge(a, ORSet.merge(b, c))

      assert ORSet.elements(left) == ORSet.elements(right)
    end

    test "is idempotent" do
      a = ORSet.new() |> ORSet.add("x", "a")
      assert ORSet.elements(ORSet.merge(a, a)) == ORSet.elements(a)
    end
  end

  describe "elements/1" do
    test "returns all elements as MapSet" do
      set = ORSet.new()
        |> ORSet.add("a", "node1")
        |> ORSet.add("b", "node1")
        |> ORSet.add("c", "node1")

      elements = ORSet.elements(set)
      assert MapSet.size(elements) == 3
      assert "a" in elements
      assert "b" in elements
      assert "c" in elements
    end
  end

  describe "to_wire/1 and from_wire/1" do
    test "round-trips correctly" do
      set = ORSet.new()
        |> ORSet.add("apple", "node1")
        |> ORSet.add("banana", "node2")

      wire = ORSet.to_wire(set)
      restored = ORSet.from_wire(wire)

      assert ORSet.elements(restored) == ORSet.elements(set)
    end
  end

  @tag :property
  describe "CRDT laws" do
    test "verifies all laws" do
      assert :ok == Laniakea.CRDT.verify(ORSet)
    end
  end
end
