# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule Laniakea.CRDT.ORSet do
  @moduledoc """
  An Observed-Remove Set (OR-Set) CRDT.

  OR-Set supports both add and remove operations on a set. Each element is
  tagged with a unique identifier (node_id + timestamp) when added. Remove
  operations only remove the tags that have been observed, allowing concurrent
  add and remove operations to be resolved deterministically.

  ## Semantics

  - **Add-wins**: If add and remove happen concurrently, the element is present
  - **Observed-remove**: Only removes tags that were observed at remove time
  - **Unique tags**: Each add creates a new tag, allowing re-add after remove

  ## Mathematical Properties

  - **Commutativity**: merge(a, b) = merge(b, a)
  - **Associativity**: merge(merge(a, b), c) = merge(a, merge(b, c))
  - **Idempotence**: merge(a, a) = a

  ## Examples

      iex> set = ORSet.new()
      iex> set = ORSet.add(set, "apple", "node1")
      iex> set = ORSet.add(set, "banana", "node1")
      iex> set = ORSet.remove(set, "apple")
      iex> ORSet.elements(set)
      ["banana"]

  ## Wire Format

      %{
        "type" => "or_set",
        "elements" => %{element => [%{node: node_id, ts: timestamp}, ...]},
        "version" => integer
      }
  """

  alias __MODULE__

  @behaviour Laniakea.CRDT

  @type node_id :: String.t()
  @type tag :: %{node: node_id(), ts: integer()}
  @type t :: %ORSet{
          elements: %{any() => MapSet.t(tag())},
          version: non_neg_integer()
        }

  defstruct elements: %{}, version: 0

  # ============================================================================
  # Constructor
  # ============================================================================

  @doc """
  Creates a new, empty OR-Set.
  """
  @spec new() :: t()
  def new, do: %ORSet{}

  # ============================================================================
  # Operations
  # ============================================================================

  @doc """
  Adds an element to the set.

  Each add operation creates a unique tag (node_id + timestamp).

  ## Examples

      iex> set = ORSet.new() |> ORSet.add("apple", "node1")
      iex> ORSet.contains?(set, "apple")
      true
  """
  @spec add(t(), any(), node_id()) :: t()
  def add(%ORSet{elements: elements, version: v} = _set, element, node_id) do
    tag = %{node: node_id, ts: System.unique_integer([:monotonic, :positive])}
    existing_tags = Map.get(elements, element, MapSet.new())
    new_tags = MapSet.put(existing_tags, tag)

    %ORSet{
      elements: Map.put(elements, element, new_tags),
      version: v + 1
    }
  end

  @doc """
  Removes an element from the set.

  Only removes tags that have been observed (are currently in the set).
  If another node concurrently adds the same element, that add will win.

  ## Examples

      iex> set = ORSet.new()
      iex> set = ORSet.add(set, "apple", "node1")
      iex> set = ORSet.remove(set, "apple")
      iex> ORSet.contains?(set, "apple")
      false
  """
  @spec remove(t(), any()) :: t()
  def remove(%ORSet{elements: elements, version: v} = _set, element) do
    %ORSet{
      elements: Map.delete(elements, element),
      version: v + 1
    }
  end

  # ============================================================================
  # Query
  # ============================================================================

  @doc """
  Returns all elements in the set.
  """
  @impl Laniakea.CRDT
  @spec value(t()) :: list()
  def value(%ORSet{elements: elements}) do
    elements
    |> Map.keys()
    |> Enum.filter(fn elem ->
      tags = Map.get(elements, elem, MapSet.new())
      MapSet.size(tags) > 0
    end)
  end

  @doc """
  Alias for value/1 - returns all elements.
  """
  @spec elements(t()) :: list()
  def elements(%ORSet{} = set), do: value(set)

  @doc """
  Checks if an element is in the set.

  ## Examples

      iex> set = ORSet.new() |> ORSet.add("apple", "node1")
      iex> ORSet.contains?(set, "apple")
      true
      iex> ORSet.contains?(set, "banana")
      false
  """
  @spec contains?(t(), any()) :: boolean()
  def contains?(%ORSet{elements: elements}, element) do
    case Map.get(elements, element) do
      nil -> false
      tags -> MapSet.size(tags) > 0
    end
  end

  @doc """
  Returns the number of elements in the set.
  """
  @spec size(t()) :: non_neg_integer()
  def size(%ORSet{} = set) do
    length(value(set))
  end

  # ============================================================================
  # Merge
  # ============================================================================

  @doc """
  Merges two OR-Sets.

  For each element, takes the union of all tags from both sets.
  An element is present if it has any tags after merge.
  """
  @impl Laniakea.CRDT
  @spec merge(t(), t()) :: t()
  def merge(%ORSet{} = a, %ORSet{} = b) do
    all_elements =
      MapSet.union(
        MapSet.new(Map.keys(a.elements)),
        MapSet.new(Map.keys(b.elements))
      )

    merged_elements =
      Enum.reduce(all_elements, %{}, fn element, acc ->
        tags_a = Map.get(a.elements, element, MapSet.new())
        tags_b = Map.get(b.elements, element, MapSet.new())
        merged_tags = MapSet.union(tags_a, tags_b)

        if MapSet.size(merged_tags) > 0 do
          Map.put(acc, element, merged_tags)
        else
          acc
        end
      end)

    %ORSet{
      elements: merged_elements,
      version: max(a.version, b.version) + 1
    }
  end

  # ============================================================================
  # Delta
  # ============================================================================

  @doc """
  Computes the delta between two OR-Set states.
  """
  @impl Laniakea.CRDT
  @spec delta(t(), t()) :: t()
  def delta(%ORSet{} = older, %ORSet{} = newer) do
    # Find elements that are new or have new tags
    delta_elements =
      Enum.reduce(newer.elements, %{}, fn {element, new_tags}, acc ->
        old_tags = Map.get(older.elements, element, MapSet.new())
        added_tags = MapSet.difference(new_tags, old_tags)

        if MapSet.size(added_tags) > 0 do
          Map.put(acc, element, added_tags)
        else
          acc
        end
      end)

    %ORSet{elements: delta_elements, version: newer.version}
  end

  # ============================================================================
  # Serialization
  # ============================================================================

  @impl Laniakea.CRDT
  @spec to_map(t()) :: map()
  def to_map(%ORSet{elements: elements, version: v} = set) do
    serialized_elements =
      Map.new(elements, fn {element, tags} ->
        serialized_tags =
          tags
          |> MapSet.to_list()
          |> Enum.map(fn %{node: n, ts: t} -> %{"node" => n, "ts" => t} end)

        {element, serialized_tags}
      end)

    %{
      type: "or_set",
      elements: serialized_elements,
      version: v,
      value: value(set)
    }
  end

  @impl Laniakea.CRDT
  @spec from_wire(map()) :: t()
  def from_wire(%{"elements" => elements} = data) do
    parsed_elements =
      Map.new(elements, fn {element, tags} ->
        parsed_tags =
          tags
          |> Enum.map(fn %{"node" => n, "ts" => t} -> %{node: n, ts: t} end)
          |> MapSet.new()

        {element, parsed_tags}
      end)

    %ORSet{
      elements: parsed_elements,
      version: Map.get(data, "version", 0)
    }
  end

  defimpl Inspect do
    def inspect(%Laniakea.CRDT.ORSet{} = set, _opts) do
      elements = Laniakea.CRDT.ORSet.elements(set)
      count = length(elements)
      preview = elements |> Enum.take(3) |> inspect()
      "#ORSet<#{count} elements, #{preview}, v#{set.version}>"
    end
  end
end
