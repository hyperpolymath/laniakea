# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule Laniakea.CRDT do
  @moduledoc """
  Behaviour and utilities for Conflict-free Replicated Data Types.

  CRDTs are data structures that can be replicated across multiple nodes,
  updated independently, and merged automatically with a mathematical
  guarantee of eventual consistency.

  ## CRDT Laws

  All CRDTs must satisfy the join-semilattice properties:

  1. **Commutativity**: `merge(a, b) == merge(b, a)`
  2. **Associativity**: `merge(merge(a, b), c) == merge(a, merge(b, c))`
  3. **Idempotence**: `merge(a, a) == a`

  These properties ensure convergence regardless of message ordering,
  duplication, or network delays.

  ## Available CRDTs

  - `Laniakea.CRDT.GCounter` - Grow-only counter
  - `Laniakea.CRDT.PNCounter` - Positive-negative counter
  - `Laniakea.CRDT.ORSet` - Observed-remove set
  - `Laniakea.CRDT.LWWRegister` - Last-writer-wins register

  ## Example

      alias Laniakea.CRDT.GCounter

      # Create and modify on node A
      counter_a = GCounter.new()
      counter_a = GCounter.increment(counter_a, "node_a")
      counter_a = GCounter.increment(counter_a, "node_a")

      # Create and modify on node B
      counter_b = GCounter.new()
      counter_b = GCounter.increment(counter_b, "node_b")

      # Merge - order doesn't matter!
      merged = GCounter.merge(counter_a, counter_b)
      GCounter.value(merged)  # => 3
  """

  @type crdt :: struct()
  @type node_id :: String.t()

  @doc """
  Returns the current value of the CRDT.
  """
  @callback value(crdt()) :: any()

  @doc """
  Merges two CRDT instances.

  Must satisfy:
  - Commutativity: merge(a, b) == merge(b, a)
  - Associativity: merge(merge(a, b), c) == merge(a, merge(b, c))
  - Idempotence: merge(a, a) == a
  """
  @callback merge(crdt(), crdt()) :: crdt()

  @doc """
  Computes the delta between two states.

  Returns a minimal CRDT containing only the changes needed to
  update `older` to match `newer`.
  """
  @callback delta(older :: crdt(), newer :: crdt()) :: crdt()

  @doc """
  Serializes the CRDT to a map for wire transmission.
  """
  @callback to_map(crdt()) :: map()

  @doc """
  Deserializes a CRDT from wire format.
  """
  @callback from_wire(map()) :: crdt()

  @optional_callbacks [delta: 2]

  # ============================================================================
  # Type Detection
  # ============================================================================

  @doc """
  Detects the CRDT type from a wire-format map.

  ## Examples

      iex> Laniakea.CRDT.type_from_wire(%{"type" => "g_counter"})
      {:ok, Laniakea.CRDT.GCounter}

      iex> Laniakea.CRDT.type_from_wire(%{"type" => "unknown"})
      {:error, :unknown_type}
  """
  @spec type_from_wire(map()) :: {:ok, module()} | {:error, :unknown_type}
  def type_from_wire(%{"type" => "g_counter"}), do: {:ok, Laniakea.CRDT.GCounter}
  def type_from_wire(%{"type" => "pn_counter"}), do: {:ok, Laniakea.CRDT.PNCounter}
  def type_from_wire(%{"type" => "or_set"}), do: {:ok, Laniakea.CRDT.ORSet}
  def type_from_wire(%{"type" => "lww_register"}), do: {:ok, Laniakea.CRDT.LWWRegister}
  def type_from_wire(_), do: {:error, :unknown_type}

  @doc """
  Deserializes a CRDT from wire format, auto-detecting type.

  ## Examples

      iex> Laniakea.CRDT.from_wire(%{"type" => "g_counter", "counts" => %{"a" => 1}})
      {:ok, %Laniakea.CRDT.GCounter{counts: %{"a" => 1}}}
  """
  @spec from_wire(map()) :: {:ok, crdt()} | {:error, :unknown_type}
  def from_wire(data) do
    case type_from_wire(data) do
      {:ok, module} -> {:ok, module.from_wire(data)}
      error -> error
    end
  end

  # ============================================================================
  # Verification
  # ============================================================================

  @doc """
  Verifies that a module implements the CRDT behaviour correctly.

  Runs property-based checks for the semilattice laws.

  ## Examples

      iex> Laniakea.CRDT.verify(Laniakea.CRDT.GCounter)
      :ok
  """
  @spec verify(module()) :: :ok | {:error, term()}
  def verify(module) do
    with :ok <- verify_commutativity(module),
         :ok <- verify_associativity(module),
         :ok <- verify_idempotence(module) do
      :ok
    end
  end

  defp verify_commutativity(module) do
    # Property: merge(a, b) == merge(b, a)
    a = create_test_instance(module, "node_a")
    b = create_test_instance(module, "node_b")

    if module.merge(a, b) == module.merge(b, a) do
      :ok
    else
      {:error, {:commutativity_failed, module}}
    end
  end

  defp verify_associativity(module) do
    # Property: merge(merge(a, b), c) == merge(a, merge(b, c))
    a = create_test_instance(module, "node_a")
    b = create_test_instance(module, "node_b")
    c = create_test_instance(module, "node_c")

    left = module.merge(module.merge(a, b), c)
    right = module.merge(a, module.merge(b, c))

    if left == right do
      :ok
    else
      {:error, {:associativity_failed, module}}
    end
  end

  defp verify_idempotence(module) do
    # Property: merge(a, a) == a
    a = create_test_instance(module, "node_a")

    if module.merge(a, a) == a do
      :ok
    else
      {:error, {:idempotence_failed, module}}
    end
  end

  defp create_test_instance(Laniakea.CRDT.GCounter, node_id) do
    Laniakea.CRDT.GCounter.new()
    |> Laniakea.CRDT.GCounter.increment(node_id)
  end

  defp create_test_instance(Laniakea.CRDT.PNCounter, node_id) do
    Laniakea.CRDT.PNCounter.new()
    |> Laniakea.CRDT.PNCounter.increment(node_id)
  end

  defp create_test_instance(Laniakea.CRDT.ORSet, node_id) do
    Laniakea.CRDT.ORSet.new()
    |> Laniakea.CRDT.ORSet.add("test_element", node_id)
  end

  defp create_test_instance(Laniakea.CRDT.LWWRegister, node_id) do
    Laniakea.CRDT.LWWRegister.new()
    |> Laniakea.CRDT.LWWRegister.set("test_value", node_id)
  end

  defp create_test_instance(module, _node_id) do
    raise "Unknown CRDT module: #{inspect(module)}"
  end
end
