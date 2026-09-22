# SPDX-License-Identifier: MPL-2.0 OR Apache-2.0
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
  @type tag_map :: %{any() => MapSet.t(tag())}
  @type t :: %ORSet{
          elements: tag_map(),
          tombstones: tag_map(),
          version: non_neg_integer()
        }

  defstruct elements: %{}, tombstones: %{}, version: 0

  # ============================================================================
  # Constructor
  # ============================================================================

  @doc """
  Creates a new, empty OR-Set.
  """
  @spec new() :: %ORSet{elements: %{}, tombstones: %{}, version: 0}
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
  def remove(%ORSet{elements: elements, tombstones: tombstones, version: v} = _set, element) do
    observed_tags = Map.get(elements, element, MapSet.new())

    %ORSet{
      elements: elements,
      tombstones: Map.update(tombstones, element, observed_tags, &MapSet.union(&1, observed_tags)),
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
  def value(%ORSet{elements: elements, tombstones: tombstones}) do
    elements
    |> Map.keys()
    |> Enum.filter(fn elem ->
      tags = Map.get(elements, elem, MapSet.new())
      live_tags = MapSet.difference(tags, Map.get(tombstones, elem, MapSet.new()))
      MapSet.size(live_tags) > 0
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
  def contains?(%ORSet{elements: elements, tombstones: tombstones}, element) do
    elements
    |> Map.get(element, MapSet.new())
    |> MapSet.difference(Map.get(tombstones, element, MapSet.new()))
    |> MapSet.size()
    |> Kernel.>(0)
  end

  @doc """
  Compatibility alias for `contains?/2`.
  """
  @spec member?(t(), any()) :: boolean()
  def member?(%ORSet{} = set, element), do: contains?(set, element)

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
    %ORSet{
      elements: merge_tag_maps(a.elements, b.elements),
      tombstones: merge_tag_maps(a.tombstones, b.tombstones),
      version: max(a.version, b.version)
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
    %ORSet{
      elements: tag_map_delta(older.elements, newer.elements),
      tombstones: tag_map_delta(older.tombstones, newer.tombstones),
      version: newer.version
    }
  end

  # ============================================================================
  # Serialization
  # ============================================================================

  @impl Laniakea.CRDT
  @spec to_map(t()) :: map()
  def to_map(%ORSet{elements: elements, tombstones: tombstones, version: v} = set) do
    %{
      type: "or_set",
      elements: serialize_tag_map(elements),
      tombstones: serialize_tag_map(tombstones),
      version: v,
      value: value(set)
    }
  end

  @doc """
  Converts the set to its string-keyed wire representation.
  """
  @spec to_wire(t()) :: map()
  def to_wire(%ORSet{elements: elements, tombstones: tombstones, version: version} = set) do
    %{
      "type" => "or_set",
      "elements" => serialize_tag_map(elements),
      "tombstones" => serialize_tag_map(tombstones),
      "version" => version,
      "value" => value(set)
    }
  end

  @impl Laniakea.CRDT
  @spec from_wire(map()) :: t()
  def from_wire(%{"elements" => elements} = data) do
    %ORSet{
      elements: deserialize_tag_map(elements),
      tombstones: data |> Map.get("tombstones", %{}) |> deserialize_tag_map(),
      version: Map.get(data, "version", 0)
    }
  end

  defp merge_tag_maps(left, right) do
    Map.merge(left, right, fn _element, left_tags, right_tags ->
      MapSet.union(left_tags, right_tags)
    end)
  end

  defp serialize_tag_map(tag_map) do
    Map.new(tag_map, fn {element, tags} ->
      serialized_tags =
        tags
        |> MapSet.to_list()
        |> Enum.map(fn %{node: node, ts: timestamp} -> %{"node" => node, "ts" => timestamp} end)

      {element, serialized_tags}
    end)
  end

  defp deserialize_tag_map(tag_map) do
    Map.new(tag_map, fn {element, tags} ->
      parsed_tags =
        tags
        |> Enum.map(fn %{"node" => node, "ts" => timestamp} -> %{node: node, ts: timestamp} end)
        |> MapSet.new()

      {element, parsed_tags}
    end)
  end

  defp tag_map_delta(older, newer) do
    Enum.reduce(newer, %{}, fn {element, newer_tags}, acc ->
      added_tags = MapSet.difference(newer_tags, Map.get(older, element, MapSet.new()))

      if MapSet.size(added_tags) > 0 do
        Map.put(acc, element, added_tags)
      else
        acc
      end
    end)
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
