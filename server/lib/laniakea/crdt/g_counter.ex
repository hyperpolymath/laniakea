# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule Laniakea.CRDT.GCounter do
  @moduledoc """
  A Grow-only Counter (G-Counter) CRDT.

  G-Counter is the simplest CRDT - it only supports increment operations.
  Each node maintains its own count, and the total value is the sum of all counts.
  Merge takes the maximum of each node's count.

  ## Mathematical Properties

  The G-Counter forms a join-semilattice where:
  - The partial order is: a ≤ b iff ∀i: a[i] ≤ b[i]
  - The join (merge) is: (a ⊔ b)[i] = max(a[i], b[i])

  This guarantees:
  - **Commutativity**: merge(a, b) = merge(b, a)
  - **Associativity**: merge(merge(a, b), c) = merge(a, merge(b, c))
  - **Idempotence**: merge(a, a) = a

  ## Examples

      iex> counter = GCounter.new()
      iex> counter = GCounter.increment(counter, "node1")
      iex> counter = GCounter.increment(counter, "node1")
      iex> counter = GCounter.increment(counter, "node2")
      iex> GCounter.value(counter)
      3

      iex> a = GCounter.new() |> GCounter.increment("alice")
      iex> b = GCounter.new() |> GCounter.increment("bob")
      iex> merged = GCounter.merge(a, b)
      iex> GCounter.value(merged)
      2

  ## Wire Format

      %{
        "type" => "g_counter",
        "counts" => %{"node_id" => count, ...},
        "version" => integer
      }
  """

  alias __MODULE__

  @behaviour Laniakea.CRDT

  @type node_id :: String.t()
  @type t :: %GCounter{
          counts: %{node_id() => non_neg_integer()},
          version: non_neg_integer()
        }

  @enforce_keys []
  defstruct counts: %{}, version: 0

  # ============================================================================
  # Constructor
  # ============================================================================

  @doc """
  Creates a new, empty G-Counter.

  ## Examples

      iex> GCounter.new()
      %GCounter{counts: %{}, version: 0}
  """
  @spec new() :: t()
  def new, do: %GCounter{}

  @doc """
  Creates a G-Counter from a map of counts.

  ## Examples

      iex> GCounter.from_map(%{"alice" => 3, "bob" => 2})
      %GCounter{counts: %{"alice" => 3, "bob" => 2}, version: 0}
  """
  @spec from_map(map()) :: t()
  def from_map(counts) when is_map(counts) do
    %GCounter{counts: counts, version: 0}
  end

  # ============================================================================
  # Operations
  # ============================================================================

  @doc """
  Increments the counter for the given node by 1.

  Each node should only increment its own count to maintain CRDT properties.

  ## Examples

      iex> counter = GCounter.new() |> GCounter.increment("node1")
      iex> counter.counts["node1"]
      1
  """
  @spec increment(t(), node_id()) :: t()
  def increment(%GCounter{counts: counts, version: v} = _counter, node_id)
      when is_binary(node_id) do
    current = Map.get(counts, node_id, 0)

    %GCounter{
      counts: Map.put(counts, node_id, current + 1),
      version: v + 1
    }
  end

  @doc """
  Increments the counter for the given node by a specific amount.

  ## Examples

      iex> counter = GCounter.new() |> GCounter.increment_by("node1", 5)
      iex> GCounter.value(counter)
      5
  """
  @spec increment_by(t(), node_id(), non_neg_integer()) :: t()
  def increment_by(%GCounter{counts: counts, version: v} = _counter, node_id, amount)
      when is_binary(node_id) and is_integer(amount) and amount >= 0 do
    current = Map.get(counts, node_id, 0)

    %GCounter{
      counts: Map.put(counts, node_id, current + amount),
      version: v + 1
    }
  end

  # ============================================================================
  # Query
  # ============================================================================

  @doc """
  Returns the total value of the counter (sum of all node counts).

  ## Examples

      iex> counter = GCounter.new()
      ...> |> GCounter.increment("a")
      ...> |> GCounter.increment("b")
      ...> |> GCounter.increment("a")
      iex> GCounter.value(counter)
      3
  """
  @impl Laniakea.CRDT
  @spec value(t()) :: non_neg_integer()
  def value(%GCounter{counts: counts}) do
    counts
    |> Map.values()
    |> Enum.sum()
  end

  @doc """
  Returns the count for a specific node.

  ## Examples

      iex> counter = GCounter.new() |> GCounter.increment_by("alice", 5)
      iex> GCounter.node_value(counter, "alice")
      5
      iex> GCounter.node_value(counter, "bob")
      0
  """
  @spec node_value(t(), node_id()) :: non_neg_integer()
  def node_value(%GCounter{counts: counts}, node_id) do
    Map.get(counts, node_id, 0)
  end

  # ============================================================================
  # Merge (The CRDT Magic)
  # ============================================================================

  @doc """
  Merges two G-Counters.

  The merge operation takes the maximum count for each node, ensuring that
  all increments from both counters are preserved.

  ## Properties

  - Commutative: merge(a, b) == merge(b, a)
  - Associative: merge(merge(a, b), c) == merge(a, merge(b, c))
  - Idempotent: merge(a, a) == a

  ## Examples

      iex> a = GCounter.new() |> GCounter.increment_by("alice", 5)
      iex> b = GCounter.new() |> GCounter.increment_by("bob", 3)
      iex> merged = GCounter.merge(a, b)
      iex> GCounter.value(merged)
      8

      iex> # Concurrent increments
      iex> a = GCounter.from_map(%{"alice" => 5, "bob" => 2})
      iex> b = GCounter.from_map(%{"alice" => 3, "bob" => 7})
      iex> merged = GCounter.merge(a, b)
      iex> merged.counts
      %{"alice" => 5, "bob" => 7}
  """
  @impl Laniakea.CRDT
  @spec merge(t(), t()) :: t()
  def merge(%GCounter{} = a, %GCounter{} = b) do
    all_nodes =
      MapSet.union(
        MapSet.new(Map.keys(a.counts)),
        MapSet.new(Map.keys(b.counts))
      )

    merged_counts =
      Enum.reduce(all_nodes, %{}, fn node, acc ->
        count_a = Map.get(a.counts, node, 0)
        count_b = Map.get(b.counts, node, 0)
        Map.put(acc, node, max(count_a, count_b))
      end)

    %GCounter{
      counts: merged_counts,
      version: max(a.version, b.version) + 1
    }
  end

  # ============================================================================
  # Delta Operations
  # ============================================================================

  @doc """
  Computes the delta between two G-Counter states.

  Returns a G-Counter containing only the counts that are higher in `newer`
  compared to `older`. Used for efficient delta synchronization.

  ## Examples

      iex> older = GCounter.from_map(%{"alice" => 3, "bob" => 2})
      iex> newer = GCounter.from_map(%{"alice" => 5, "bob" => 2, "carol" => 1})
      iex> delta = GCounter.delta(older, newer)
      iex> delta.counts
      %{"alice" => 5, "carol" => 1}
  """
  @impl Laniakea.CRDT
  @spec delta(t(), t()) :: t()
  def delta(%GCounter{} = older, %GCounter{} = newer) do
    delta_counts =
      newer.counts
      |> Enum.filter(fn {node, count} ->
        old_count = Map.get(older.counts, node, 0)
        count > old_count
      end)
      |> Map.new()

    %GCounter{counts: delta_counts, version: newer.version}
  end

  @doc """
  Applies a delta to a state. Equivalent to merge for G-Counter.

  ## Examples

      iex> state = GCounter.from_map(%{"alice" => 3})
      iex> delta = GCounter.from_map(%{"alice" => 5, "bob" => 2})
      iex> GCounter.apply_delta(state, delta)
      %GCounter{counts: %{"alice" => 5, "bob" => 2}, version: 1}
  """
  @spec apply_delta(t(), t()) :: t()
  def apply_delta(%GCounter{} = state, %GCounter{} = delta) do
    merge(state, delta)
  end

  # ============================================================================
  # Comparison
  # ============================================================================

  @doc """
  Compares two G-Counters for equality.

  Two G-Counters are equal if they have the same counts (version is ignored).

  ## Examples

      iex> a = GCounter.from_map(%{"alice" => 3})
      iex> b = GCounter.from_map(%{"alice" => 3})
      iex> GCounter.equal?(a, b)
      true
  """
  @spec equal?(t(), t()) :: boolean()
  def equal?(%GCounter{counts: a}, %GCounter{counts: b}) do
    a == b
  end

  @doc """
  Checks if counter `a` is less than or equal to counter `b` in the partial order.

  a ≤ b iff for all nodes i: a[i] ≤ b[i]

  This is useful for detecting if a state is "behind" another.

  ## Examples

      iex> a = GCounter.from_map(%{"alice" => 3, "bob" => 2})
      iex> b = GCounter.from_map(%{"alice" => 5, "bob" => 2})
      iex> GCounter.lte?(a, b)
      true

      iex> a = GCounter.from_map(%{"alice" => 3, "bob" => 5})
      iex> b = GCounter.from_map(%{"alice" => 5, "bob" => 2})
      iex> GCounter.lte?(a, b)
      false  # bob's count is higher in a
  """
  @spec lte?(t(), t()) :: boolean()
  def lte?(%GCounter{counts: a}, %GCounter{counts: b}) do
    all_nodes =
      MapSet.union(
        MapSet.new(Map.keys(a)),
        MapSet.new(Map.keys(b))
      )

    Enum.all?(all_nodes, fn node ->
      count_a = Map.get(a, node, 0)
      count_b = Map.get(b, node, 0)
      count_a <= count_b
    end)
  end

  # ============================================================================
  # Serialization
  # ============================================================================

  @doc """
  Converts the G-Counter to a map for serialization.

  ## Examples

      iex> counter = GCounter.new() |> GCounter.increment("node1")
      iex> GCounter.to_map(counter)
      %{type: "g_counter", counts: %{"node1" => 1}, version: 1, value: 1}
  """
  @impl Laniakea.CRDT
  @spec to_map(t()) :: map()
  def to_map(%GCounter{counts: counts, version: version} = counter) do
    %{
      type: "g_counter",
      counts: counts,
      version: version,
      value: value(counter)
    }
  end

  @doc """
  Creates a G-Counter from a serialized map.

  ## Examples

      iex> GCounter.from_wire(%{"counts" => %{"alice" => 3}, "version" => 5})
      %GCounter{counts: %{"alice" => 3}, version: 5}
  """
  @impl Laniakea.CRDT
  @spec from_wire(map()) :: t()
  def from_wire(%{"counts" => counts, "version" => version}) do
    %GCounter{counts: counts, version: version}
  end

  def from_wire(%{"counts" => counts}) do
    %GCounter{counts: counts, version: 0}
  end

  # ============================================================================
  # Protocol Implementations
  # ============================================================================

  defimpl Inspect do
    def inspect(%Laniakea.CRDT.GCounter{counts: counts, version: v}, _opts) do
      value = counts |> Map.values() |> Enum.sum()
      "#GCounter<value=#{value}, nodes=#{map_size(counts)}, v#{v}>"
    end
  end
end
