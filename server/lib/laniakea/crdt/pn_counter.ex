# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule Laniakea.CRDT.PNCounter do
  @moduledoc """
  A Positive-Negative Counter (PN-Counter) CRDT.

  PN-Counter supports both increment and decrement operations by maintaining
  two G-Counters: one for positive increments and one for negative (decrements).
  The value is the difference between the positive and negative counters.

  ## Mathematical Properties

  The PN-Counter inherits semilattice properties from G-Counter:
  - **Commutativity**: merge(a, b) = merge(b, a)
  - **Associativity**: merge(merge(a, b), c) = merge(a, merge(b, c))
  - **Idempotence**: merge(a, a) = a

  ## Examples

      iex> counter = PNCounter.new()
      iex> counter = PNCounter.increment(counter, "node1")
      iex> counter = PNCounter.increment(counter, "node1")
      iex> counter = PNCounter.decrement(counter, "node1")
      iex> PNCounter.value(counter)
      1

  ## Wire Format

      %{
        "type" => "pn_counter",
        "positive" => %{"node_id" => count, ...},
        "negative" => %{"node_id" => count, ...},
        "version" => integer
      }
  """

  alias Laniakea.CRDT.GCounter
  alias __MODULE__

  @behaviour Laniakea.CRDT

  @type node_id :: String.t()
  @type t :: %PNCounter{
          positive: GCounter.t(),
          negative: GCounter.t(),
          version: non_neg_integer()
        }

  defstruct positive: %GCounter{}, negative: %GCounter{}, version: 0

  # ============================================================================
  # Constructor
  # ============================================================================

  @doc """
  Creates a new, empty PN-Counter.
  """
  @spec new() :: t()
  def new do
    %PNCounter{
      positive: GCounter.new(),
      negative: GCounter.new(),
      version: 0
    }
  end

  # ============================================================================
  # Operations
  # ============================================================================

  @doc """
  Increments the counter for the given node.

  ## Examples

      iex> counter = PNCounter.new() |> PNCounter.increment("alice")
      iex> PNCounter.value(counter)
      1
  """
  @spec increment(t(), node_id()) :: t()
  def increment(%PNCounter{positive: pos, version: v} = counter, node_id) do
    %PNCounter{
      counter
      | positive: GCounter.increment(pos, node_id),
        version: v + 1
    }
  end

  @doc """
  Increments the counter by a specific amount.
  """
  @spec increment_by(t(), node_id(), non_neg_integer()) :: t()
  def increment_by(%PNCounter{positive: pos, version: v} = counter, node_id, amount) do
    %PNCounter{
      counter
      | positive: GCounter.increment_by(pos, node_id, amount),
        version: v + 1
    }
  end

  @doc """
  Decrements the counter for the given node.

  ## Examples

      iex> counter = PNCounter.new()
      iex> counter = PNCounter.increment(counter, "alice")
      iex> counter = PNCounter.increment(counter, "alice")
      iex> counter = PNCounter.decrement(counter, "alice")
      iex> PNCounter.value(counter)
      1
  """
  @spec decrement(t(), node_id()) :: t()
  def decrement(%PNCounter{negative: neg, version: v} = counter, node_id) do
    %PNCounter{
      counter
      | negative: GCounter.increment(neg, node_id),
        version: v + 1
    }
  end

  @doc """
  Decrements the counter by a specific amount.
  """
  @spec decrement_by(t(), node_id(), non_neg_integer()) :: t()
  def decrement_by(%PNCounter{negative: neg, version: v} = counter, node_id, amount) do
    %PNCounter{
      counter
      | negative: GCounter.increment_by(neg, node_id, amount),
        version: v + 1
    }
  end

  # ============================================================================
  # Query
  # ============================================================================

  @doc """
  Returns the current value (positive - negative).

  Note: This can be negative if decrements exceed increments.

  ## Examples

      iex> counter = PNCounter.new()
      iex> counter = PNCounter.decrement(counter, "alice")
      iex> PNCounter.value(counter)
      -1
  """
  @impl Laniakea.CRDT
  @spec value(t()) :: integer()
  def value(%PNCounter{positive: pos, negative: neg}) do
    GCounter.value(pos) - GCounter.value(neg)
  end

  @doc """
  Returns the positive count only.
  """
  @spec positive_value(t()) :: non_neg_integer()
  def positive_value(%PNCounter{positive: pos}) do
    GCounter.value(pos)
  end

  @doc """
  Returns the negative count only.
  """
  @spec negative_value(t()) :: non_neg_integer()
  def negative_value(%PNCounter{negative: neg}) do
    GCounter.value(neg)
  end

  # ============================================================================
  # Merge
  # ============================================================================

  @doc """
  Merges two PN-Counters.

  Merges the positive and negative G-Counters independently.
  """
  @impl Laniakea.CRDT
  @spec merge(t(), t()) :: t()
  def merge(%PNCounter{} = a, %PNCounter{} = b) do
    %PNCounter{
      positive: GCounter.merge(a.positive, b.positive),
      negative: GCounter.merge(a.negative, b.negative),
      version: max(a.version, b.version) + 1
    }
  end

  # ============================================================================
  # Delta
  # ============================================================================

  @doc """
  Computes the delta between two PN-Counter states.
  """
  @impl Laniakea.CRDT
  @spec delta(t(), t()) :: t()
  def delta(%PNCounter{} = older, %PNCounter{} = newer) do
    %PNCounter{
      positive: GCounter.delta(older.positive, newer.positive),
      negative: GCounter.delta(older.negative, newer.negative),
      version: newer.version
    }
  end

  # ============================================================================
  # Serialization
  # ============================================================================

  @impl Laniakea.CRDT
  @spec to_map(t()) :: map()
  def to_map(%PNCounter{positive: pos, negative: neg, version: v} = counter) do
    %{
      type: "pn_counter",
      positive: pos.counts,
      negative: neg.counts,
      version: v,
      value: value(counter)
    }
  end

  @impl Laniakea.CRDT
  @spec from_wire(map()) :: t()
  def from_wire(%{"positive" => pos, "negative" => neg} = data) do
    %PNCounter{
      positive: GCounter.from_map(pos),
      negative: GCounter.from_map(neg),
      version: Map.get(data, "version", 0)
    }
  end

  defimpl Inspect do
    def inspect(%Laniakea.CRDT.PNCounter{} = pn, _opts) do
      value = Laniakea.CRDT.PNCounter.value(pn)
      pos = Laniakea.CRDT.PNCounter.positive_value(pn)
      neg = Laniakea.CRDT.PNCounter.negative_value(pn)
      "#PNCounter<value=#{value}, +#{pos}/-#{neg}, v#{pn.version}>"
    end
  end
end
