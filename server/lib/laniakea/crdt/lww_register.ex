# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule Laniakea.CRDT.LWWRegister do
  @moduledoc """
  A Last-Writer-Wins Register (LWW-Register) CRDT.

  LWW-Register stores a single value with a timestamp. When merging,
  the value with the highest timestamp wins. Ties are broken by
  lexicographic comparison of node IDs.

  ## Semantics

  - **Last-writer-wins**: Highest timestamp wins
  - **Deterministic tie-breaking**: Same result regardless of merge order
  - **Potential data loss**: Concurrent writes may lose updates

  ## When to Use

  LWW-Register is appropriate when:
  - You need a simple single-value store
  - Concurrent updates are rare or acceptable to lose
  - You have reasonably synchronized clocks

  Consider MV-Register if you need to preserve concurrent writes.

  ## Examples

      iex> reg = LWWRegister.new()
      iex> reg = LWWRegister.set(reg, "hello", "node1")
      iex> LWWRegister.value(reg)
      "hello"

      iex> reg = LWWRegister.set(reg, "world", "node1")
      iex> LWWRegister.value(reg)
      "world"
  """

  alias __MODULE__

  @behaviour Laniakea.CRDT

  @type node_id :: String.t()
  @type t :: %LWWRegister{
          value: any(),
          timestamp: integer(),
          node_id: node_id() | nil,
          version: non_neg_integer()
        }

  defstruct value: nil, timestamp: 0, node_id: nil, version: 0

  # ============================================================================
  # Constructor
  # ============================================================================

  @doc """
  Creates a new, empty LWW-Register.
  """
  @spec new() :: t()
  def new, do: %LWWRegister{}

  @doc """
  Creates a LWW-Register with an initial value.
  """
  @spec new(any(), node_id()) :: t()
  def new(value, node_id) do
    %LWWRegister{
      value: value,
      timestamp: System.os_time(:microsecond),
      node_id: node_id,
      version: 1
    }
  end

  # ============================================================================
  # Operations
  # ============================================================================

  @doc """
  Sets the register value.

  Uses the current system time as the timestamp.

  ## Examples

      iex> reg = LWWRegister.new() |> LWWRegister.set("hello", "node1")
      iex> LWWRegister.value(reg)
      "hello"
  """
  @spec set(t(), any(), node_id()) :: t()
  def set(%LWWRegister{version: v} = _reg, value, node_id) do
    %LWWRegister{
      value: value,
      timestamp: System.os_time(:microsecond),
      node_id: node_id,
      version: v + 1
    }
  end

  @doc """
  Sets the register value with an explicit timestamp.

  Useful for deterministic testing or when you have external timestamps.
  """
  @spec set_with_timestamp(t(), any(), node_id(), integer()) :: t()
  def set_with_timestamp(%LWWRegister{version: v} = _reg, value, node_id, timestamp) do
    %LWWRegister{
      value: value,
      timestamp: timestamp,
      node_id: node_id,
      version: v + 1
    }
  end

  # ============================================================================
  # Query
  # ============================================================================

  @doc """
  Returns the current value.

  ## Examples

      iex> reg = LWWRegister.new() |> LWWRegister.set("hello", "node1")
      iex> LWWRegister.value(reg)
      "hello"
  """
  @impl Laniakea.CRDT
  @spec value(t()) :: any()
  def value(%LWWRegister{value: v}), do: v

  @doc """
  Returns the timestamp of the current value.
  """
  @spec timestamp(t()) :: integer()
  def timestamp(%LWWRegister{timestamp: ts}), do: ts

  @doc """
  Returns the node that set the current value.
  """
  @spec node_id(t()) :: node_id() | nil
  def node_id(%LWWRegister{node_id: n}), do: n

  # ============================================================================
  # Merge
  # ============================================================================

  @doc """
  Merges two LWW-Registers.

  The register with the higher timestamp wins. In case of a tie,
  the register with the lexicographically higher node_id wins.

  ## Examples

      iex> a = LWWRegister.set_with_timestamp(LWWRegister.new(), "a", "node_a", 100)
      iex> b = LWWRegister.set_with_timestamp(LWWRegister.new(), "b", "node_b", 200)
      iex> merged = LWWRegister.merge(a, b)
      iex> LWWRegister.value(merged)
      "b"  # b has higher timestamp
  """
  @impl Laniakea.CRDT
  @spec merge(t(), t()) :: t()
  def merge(%LWWRegister{} = a, %LWWRegister{} = b) do
    winner = compare_and_select(a, b)
    %LWWRegister{winner | version: max(a.version, b.version) + 1}
  end

  defp compare_and_select(a, b) do
    cond do
      a.timestamp > b.timestamp -> a
      b.timestamp > a.timestamp -> b
      # Tie-breaker: lexicographic node_id comparison
      (a.node_id || "") >= (b.node_id || "") -> a
      true -> b
    end
  end

  # ============================================================================
  # Delta (trivial for LWW-Register)
  # ============================================================================

  @doc """
  Returns the newer state as the delta.

  For LWW-Register, the delta is just the entire newer state if it's
  actually newer, otherwise empty.
  """
  @impl Laniakea.CRDT
  @spec delta(t(), t()) :: t()
  def delta(%LWWRegister{} = older, %LWWRegister{} = newer) do
    if newer.timestamp > older.timestamp do
      newer
    else
      %LWWRegister{}
    end
  end

  # ============================================================================
  # Serialization
  # ============================================================================

  @impl Laniakea.CRDT
  @spec to_map(t()) :: map()
  def to_map(%LWWRegister{value: v, timestamp: ts, node_id: n, version: ver}) do
    %{
      type: "lww_register",
      value: v,
      timestamp: ts,
      node_id: n,
      version: ver
    }
  end

  @impl Laniakea.CRDT
  @spec from_wire(map()) :: t()
  def from_wire(%{"value" => v, "timestamp" => ts, "node_id" => n} = data) do
    %LWWRegister{
      value: v,
      timestamp: ts,
      node_id: n,
      version: Map.get(data, "version", 0)
    }
  end

  def from_wire(%{"value" => v, "timestamp" => ts} = data) do
    %LWWRegister{
      value: v,
      timestamp: ts,
      node_id: nil,
      version: Map.get(data, "version", 0)
    }
  end

  defimpl Inspect do
    def inspect(%Laniakea.CRDT.LWWRegister{value: v, timestamp: ts, node_id: n, version: ver}, _opts) do
      "#LWWRegister<#{inspect(v)}, ts=#{ts}, node=#{n || "nil"}, v#{ver}>"
    end
  end
end
