# SPDX-License-Identifier: PMPL-1.0-or-later
# Benchee benchmarks for Laniakea CRDT operations.
#
# Run with:   cd server && mix run bench/crdt_bench.exs
# For HTML:   cd server && mix run bench/crdt_bench.exs  (add Benchee.Formatters.HTML)

alias Laniakea.CRDT.GCounter
alias Laniakea.CRDT.PNCounter
alias Laniakea.CRDT.ORSet
alias Laniakea.CRDT.LWWRegister

# ---------------------------------------------------------------------------
# Shared state
# ---------------------------------------------------------------------------

# Pre-built large counters for merge benchmarks.
counter_a =
  Enum.reduce(1..100, GCounter.new(), fn i, acc ->
    GCounter.increment(acc, "node#{i}", i)
  end)

counter_b =
  Enum.reduce(50..150, GCounter.new(), fn i, acc ->
    GCounter.increment(acc, "node#{i}", i * 2)
  end)

pn_a =
  Enum.reduce(1..50, PNCounter.new(), fn i, acc ->
    acc |> PNCounter.increment_by("n#{i}", i) |> PNCounter.decrement_by("n#{i}", div(i, 2))
  end)

pn_b =
  Enum.reduce(25..75, PNCounter.new(), fn i, acc ->
    PNCounter.increment_by(acc, "n#{i}", i)
  end)

set_a =
  Enum.reduce(1..50, ORSet.new(), fn i, acc ->
    ORSet.add(acc, "item_#{i}", "node1")
  end)

set_b =
  Enum.reduce(26..75, ORSet.new(), fn i, acc ->
    ORSet.add(acc, "item_#{i}", "node2")
  end)

reg = LWWRegister.set_with_timestamp(LWWRegister.new(), "benchmark_value", "node1", 12345)
reg2 = LWWRegister.set_with_timestamp(LWWRegister.new(), "other_value", "node2", 99999)

# ---------------------------------------------------------------------------
# Benchmarks
# ---------------------------------------------------------------------------

Benchee.run(
  %{
    # --- GCounter operations ---
    "GCounter.new" => fn ->
      GCounter.new()
    end,

    "GCounter.increment (single node)" => fn ->
      GCounter.increment(counter_a, "node1")
    end,

    "GCounter.increment/3 by amount" => fn ->
      GCounter.increment(counter_a, "node1", 100)
    end,

    "GCounter.merge (100-node counters)" => fn ->
      GCounter.merge(counter_a, counter_b)
    end,

    "GCounter.value (100-node counter)" => fn ->
      GCounter.value(counter_a)
    end,

    # --- PNCounter operations ---
    "PNCounter.new" => fn ->
      PNCounter.new()
    end,

    "PNCounter.increment_by" => fn ->
      PNCounter.increment_by(pn_a, "node1", 10)
    end,

    "PNCounter.decrement_by" => fn ->
      PNCounter.decrement_by(pn_a, "node1", 5)
    end,

    "PNCounter.merge (50-node counters)" => fn ->
      PNCounter.merge(pn_a, pn_b)
    end,

    "PNCounter.value" => fn ->
      PNCounter.value(pn_a)
    end,

    # --- ORSet operations ---
    "ORSet.add (to 50-element set)" => fn ->
      ORSet.add(set_a, "new_item", "node1")
    end,

    "ORSet.remove (from 50-element set)" => fn ->
      ORSet.remove(set_a, "item_25")
    end,

    "ORSet.merge (two 50-element sets)" => fn ->
      ORSet.merge(set_a, set_b)
    end,

    "ORSet.member? (hit)" => fn ->
      ORSet.member?(set_a, "item_25")
    end,

    "ORSet.member? (miss)" => fn ->
      ORSet.member?(set_a, "absent_item")
    end,

    "ORSet.elements (50 elements)" => fn ->
      ORSet.elements(set_a)
    end,

    # --- LWWRegister operations ---
    "LWWRegister.set (system time)" => fn ->
      LWWRegister.set(reg, "new_value", "node1")
    end,

    "LWWRegister.set_with_timestamp" => fn ->
      LWWRegister.set_with_timestamp(reg, "timestamped", "node1", 99999)
    end,

    "LWWRegister.merge" => fn ->
      LWWRegister.merge(reg, reg2)
    end,

    "LWWRegister.value" => fn ->
      LWWRegister.value(reg)
    end
  },
  time: 3,
  memory_time: 1,
  warmup: 1,
  print: [fast_warning: false],
  formatters: [
    Benchee.Formatters.Console
  ]
)
