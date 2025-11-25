# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule Laniakea.CRDT.LWWRegisterTest do
  use ExUnit.Case, async: true
  alias Laniakea.CRDT.LWWRegister

  doctest LWWRegister

  describe "new/0" do
    test "creates an empty register" do
      reg = LWWRegister.new()
      assert LWWRegister.value(reg) == nil
    end
  end

  describe "set/3" do
    test "sets the value" do
      reg = LWWRegister.new() |> LWWRegister.set("hello", "node1")
      assert LWWRegister.value(reg) == "hello"
    end

    test "overwrites previous value" do
      reg = LWWRegister.new()
        |> LWWRegister.set("first", "node1")
        |> LWWRegister.set("second", "node1")

      assert LWWRegister.value(reg) == "second"
    end
  end

  describe "set_with_timestamp/4" do
    test "sets value with explicit timestamp" do
      reg = LWWRegister.new()
        |> LWWRegister.set_with_timestamp("value", "node1", 12345)

      assert LWWRegister.value(reg) == "value"
      assert LWWRegister.timestamp(reg) == 12345
    end
  end

  describe "merge/2" do
    test "keeps value with higher timestamp" do
      a = LWWRegister.new() |> LWWRegister.set_with_timestamp("older", "node1", 100)
      b = LWWRegister.new() |> LWWRegister.set_with_timestamp("newer", "node2", 200)

      merged = LWWRegister.merge(a, b)
      assert LWWRegister.value(merged) == "newer"
    end

    test "uses node_id as tiebreaker for equal timestamps" do
      a = LWWRegister.new() |> LWWRegister.set_with_timestamp("a_value", "node_a", 100)
      b = LWWRegister.new() |> LWWRegister.set_with_timestamp("b_value", "node_b", 100)

      merged_ab = LWWRegister.merge(a, b)
      merged_ba = LWWRegister.merge(b, a)

      # Should be deterministic (lexicographic comparison)
      assert LWWRegister.value(merged_ab) == LWWRegister.value(merged_ba)
    end

    test "is commutative" do
      a = LWWRegister.new() |> LWWRegister.set_with_timestamp("a", "n1", 100)
      b = LWWRegister.new() |> LWWRegister.set_with_timestamp("b", "n2", 200)

      assert LWWRegister.value(LWWRegister.merge(a, b)) == LWWRegister.value(LWWRegister.merge(b, a))
    end

    test "is associative" do
      a = LWWRegister.new() |> LWWRegister.set_with_timestamp("a", "n1", 100)
      b = LWWRegister.new() |> LWWRegister.set_with_timestamp("b", "n2", 200)
      c = LWWRegister.new() |> LWWRegister.set_with_timestamp("c", "n3", 150)

      left = LWWRegister.merge(LWWRegister.merge(a, b), c)
      right = LWWRegister.merge(a, LWWRegister.merge(b, c))

      assert LWWRegister.value(left) == LWWRegister.value(right)
    end

    test "is idempotent" do
      a = LWWRegister.new() |> LWWRegister.set_with_timestamp("value", "n1", 100)

      assert LWWRegister.value(LWWRegister.merge(a, a)) == LWWRegister.value(a)
    end
  end

  describe "to_wire/1 and from_wire/1" do
    test "round-trips correctly" do
      reg = LWWRegister.new()
        |> LWWRegister.set_with_timestamp("test_value", "node1", 12345)

      wire = LWWRegister.to_wire(reg)
      restored = LWWRegister.from_wire(wire)

      assert LWWRegister.value(restored) == LWWRegister.value(reg)
      assert LWWRegister.timestamp(restored) == LWWRegister.timestamp(reg)
    end

    test "handles nil value" do
      reg = LWWRegister.new()
      wire = LWWRegister.to_wire(reg)
      restored = LWWRegister.from_wire(wire)

      assert LWWRegister.value(restored) == nil
    end
  end

  @tag :property
  describe "CRDT laws" do
    test "verifies all laws" do
      assert :ok == Laniakea.CRDT.verify(LWWRegister)
    end
  end
end
