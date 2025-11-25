# CRDTs: Conflict-free Replicated Data Types

> *"Like gravity, CRDTs pull distributed state toward convergence — without any node commanding the others."*

## What Are CRDTs?

**Conflict-free Replicated Data Types** are data structures that can be replicated across multiple nodes, updated independently, and merged automatically — with a mathematical guarantee of eventual consistency.

### The Three Laws of CRDTs

For a data type to be a CRDT, its merge operation must satisfy:

| Property | Definition | Intuition |
|----------|------------|-----------|
| **Commutative** | merge(a, b) = merge(b, a) | Order of merge doesn't matter |
| **Associative** | merge(merge(a, b), c) = merge(a, merge(b, c)) | Grouping of merges doesn't matter |
| **Idempotent** | merge(a, a) = a | Merging same data twice is harmless |

These properties form a **join-semilattice**, guaranteeing that all nodes converge to the same state regardless of message ordering, duplication, or network delays.

## Why CRDTs for Laniakea?

Traditional approaches to distributed state:

| Approach | Problem |
|----------|---------|
| **Locks** | Require coordination; don't work offline |
| **Last-write-wins** | Loses data; requires synchronized clocks |
| **Manual conflict resolution** | Burden on users; error-prone |
| **Operational transforms** | Complex; hard to prove correct |

CRDTs solve these problems by making conflict resolution **automatic and mathematically correct**.

## CRDT Catalog

### Counters

#### G-Counter (Grow-only Counter)

**Use case**: View counts, like counts, increment-only metrics

```elixir
# Structure: Map of node_id -> count
# Example: %{"alice" => 3, "bob" => 2} represents total value of 5

defmodule Laniakea.CRDT.GCounter do
  defstruct counts: %{}

  def increment(%{counts: counts} = counter, node_id) do
    current = Map.get(counts, node_id, 0)
    %{counter | counts: Map.put(counts, node_id, current + 1)}
  end

  def merge(a, b) do
    all_nodes = MapSet.union(
      MapSet.new(Map.keys(a.counts)),
      MapSet.new(Map.keys(b.counts))
    )

    merged = Enum.reduce(all_nodes, %{}, fn node, acc ->
      Map.put(acc, node, max(
        Map.get(a.counts, node, 0),
        Map.get(b.counts, node, 0)
      ))
    end)

    %GCounter{counts: merged}
  end

  def value(%{counts: counts}) do
    counts |> Map.values() |> Enum.sum()
  end
end
```

**Properties**:
- Increment-only (can't decrement)
- Space: O(nodes)
- Merge: O(nodes)

#### PN-Counter (Positive-Negative Counter)

**Use case**: Upvotes/downvotes, stock levels, any increment/decrement counter

```elixir
# Structure: Pair of G-Counters (positive and negative)
# Value = sum(positive) - sum(negative)

defmodule Laniakea.CRDT.PNCounter do
  defstruct positive: %GCounter{}, negative: %GCounter{}

  def increment(counter, node_id) do
    %{counter | positive: GCounter.increment(counter.positive, node_id)}
  end

  def decrement(counter, node_id) do
    %{counter | negative: GCounter.increment(counter.negative, node_id)}
  end

  def merge(a, b) do
    %PNCounter{
      positive: GCounter.merge(a.positive, b.positive),
      negative: GCounter.merge(a.negative, b.negative)
    }
  end

  def value(counter) do
    GCounter.value(counter.positive) - GCounter.value(counter.negative)
  end
end
```

**Properties**:
- Full increment/decrement support
- Space: O(2 × nodes)
- Cannot go below 0 if decrements exceed increments (value can be negative)

### Sets

#### G-Set (Grow-only Set)

**Use case**: Tags, participants, add-only collections

```elixir
defmodule Laniakea.CRDT.GSet do
  defstruct elements: MapSet.new()

  def add(set, element) do
    %{set | elements: MapSet.put(set.elements, element)}
  end

  def merge(a, b) do
    %GSet{elements: MapSet.union(a.elements, b.elements)}
  end

  def contains?(set, element) do
    MapSet.member?(set.elements, element)
  end

  def elements(set), do: set.elements
end
```

**Properties**:
- Add-only (no remove)
- Space: O(elements)
- Merge: O(elements)

#### OR-Set (Observed-Remove Set)

**Use case**: Shopping carts, to-do lists, any add/remove collection

```elixir
# Structure: Map of element -> Set of {node_id, timestamp} pairs
# An element is present if it has any (node, timestamp) pairs

defmodule Laniakea.CRDT.ORSet do
  defstruct elements: %{}  # element -> MapSet of {node_id, timestamp}

  def add(set, element, node_id) do
    timestamp = System.unique_integer([:monotonic, :positive])
    tag = {node_id, timestamp}

    existing = Map.get(set.elements, element, MapSet.new())
    new_elements = Map.put(set.elements, element, MapSet.put(existing, tag))

    %{set | elements: new_elements}
  end

  def remove(set, element) do
    # Remove all observed tags for this element
    %{set | elements: Map.delete(set.elements, element)}
  end

  def merge(a, b) do
    all_elements = MapSet.union(
      MapSet.new(Map.keys(a.elements)),
      MapSet.new(Map.keys(b.elements))
    )

    merged = Enum.reduce(all_elements, %{}, fn element, acc ->
      tags_a = Map.get(a.elements, element, MapSet.new())
      tags_b = Map.get(b.elements, element, MapSet.new())
      merged_tags = MapSet.union(tags_a, tags_b)

      if MapSet.size(merged_tags) > 0 do
        Map.put(acc, element, merged_tags)
      else
        acc
      end
    end)

    %ORSet{elements: merged}
  end

  def contains?(set, element) do
    Map.has_key?(set.elements, element) and
      MapSet.size(Map.get(set.elements, element)) > 0
  end

  def elements(set) do
    set.elements
    |> Map.keys()
    |> Enum.filter(&contains?(set, &1))
  end
end
```

**Properties**:
- Add and remove supported
- Concurrent add+remove: add wins (element is present)
- Space: O(elements × operations)
- May need garbage collection for long-lived sets

### Registers

#### LWW-Register (Last-Writer-Wins Register)

**Use case**: User profile fields, settings, single-value state

```elixir
defmodule Laniakea.CRDT.LWWRegister do
  defstruct value: nil, timestamp: 0, node_id: nil

  def set(register, value, node_id) do
    timestamp = System.os_time(:microsecond)
    %LWWRegister{value: value, timestamp: timestamp, node_id: node_id}
  end

  def merge(a, b) do
    cond do
      a.timestamp > b.timestamp -> a
      b.timestamp > a.timestamp -> b
      # Tie-breaker: lexicographic node_id comparison
      a.node_id >= b.node_id -> a
      true -> b
    end
  end

  def value(register), do: register.value
end
```

**Properties**:
- Simple single-value storage
- Requires synchronized clocks (or logical timestamps)
- Concurrent writes: one wins, one loses
- Space: O(1)

#### MV-Register (Multi-Value Register)

**Use case**: When you need to preserve concurrent writes for manual resolution

```elixir
defmodule Laniakea.CRDT.MVRegister do
  defstruct values: []  # List of {value, vector_clock}

  def set(register, value, node_id) do
    # Increment vector clock and set new value
    # Dominated values are removed
    # ...
  end

  def merge(a, b) do
    # Keep all non-dominated values from both
    # ...
  end

  def values(register) do
    # Returns list of concurrent values
    Enum.map(register.values, fn {v, _vc} -> v end)
  end
end
```

**Properties**:
- Preserves all concurrent writes
- Application must resolve multiple values
- More complex than LWW but no data loss

### Sequences

#### RGA (Replicated Growable Array)

**Use case**: Collaborative text editing, ordered lists

```elixir
defmodule Laniakea.CRDT.RGA do
  @moduledoc """
  Replicated Growable Array for collaborative text editing.
  Each character has a unique ID (node_id, sequence).
  Insert operations specify position by referencing existing IDs.
  """

  defstruct elements: [], tombstones: MapSet.new()

  # Complex implementation - see full docs
end
```

**Properties**:
- Supports insert/delete at any position
- Maintains total order across nodes
- Used by Automerge, Yjs
- More complex to implement correctly

## Delta-CRDTs

For efficiency, Laniakea uses **delta-CRDTs** — instead of sending full state, we send only the changes (deltas).

### Delta Sync Protocol

```
┌──────────────┐                        ┌──────────────┐
│   Client A   │                        │    Server    │
│              │                        │              │
│ State: v5    │────── delta(v3→v5) ───►│ State: v7    │
│              │                        │              │
│              │◄───── delta(v5→v7) ────│              │
│              │                        │              │
│ State: v7    │                        │ State: v7    │
└──────────────┘                        └──────────────┘
```

```elixir
defmodule Laniakea.CRDT.GCounter.Delta do
  @doc """
  Compute delta between two G-Counter states.
  Returns only the counts that increased from `old` to `new`.
  """
  def delta(old, new) do
    delta_counts =
      new.counts
      |> Enum.filter(fn {node, count} ->
        old_count = Map.get(old.counts, node, 0)
        count > old_count
      end)
      |> Map.new()

    %GCounter{counts: delta_counts}
  end

  @doc """
  Apply a delta to a state.
  Equivalent to merge but semantically indicates incremental update.
  """
  def apply_delta(state, delta) do
    GCounter.merge(state, delta)
  end
end
```

### Benefits of Delta Sync

| Full State Sync | Delta Sync |
|-----------------|------------|
| Send entire CRDT | Send only changes |
| O(state size) bandwidth | O(delta size) bandwidth |
| Simple to implement | More complex bookkeeping |
| Good for initial sync | Good for incremental updates |

## Client Implementation (ReScript)

```rescript
module GCounter = {
  type t = {
    counts: Map.String.t<int>,
    version: int,
  }

  let empty = {counts: Map.String.empty, version: 0}

  let increment = (counter, nodeId) => {
    let current = counter.counts->Map.String.get(nodeId)->Option.getOr(0)
    {
      counts: counter.counts->Map.String.set(nodeId, current + 1),
      version: counter.version + 1,
    }
  }

  let merge = (a, b) => {
    let allNodes = Set.String.union(
      a.counts->Map.String.keysToArray->Set.String.fromArray,
      b.counts->Map.String.keysToArray->Set.String.fromArray,
    )

    let merged = allNodes->Set.String.reduce(Map.String.empty, (acc, node) => {
      let countA = a.counts->Map.String.get(node)->Option.getOr(0)
      let countB = b.counts->Map.String.get(node)->Option.getOr(0)
      acc->Map.String.set(node, Js.Math.max_int(countA, countB))
    })

    {
      counts: merged,
      version: Js.Math.max_int(a.version, b.version) + 1,
    }
  }

  let value = counter => {
    counter.counts
    ->Map.String.valuesToArray
    ->Array.reduce(0, (a, b) => a + b)
  }

  // Delta computation
  let delta = (old, new) => {
    let deltaCounts =
      new.counts
      ->Map.String.toArray
      ->Array.filter(((node, count)) => {
        let oldCount = old.counts->Map.String.get(node)->Option.getOr(0)
        count > oldCount
      })
      ->Map.String.fromArray

    {counts: deltaCounts, version: new.version}
  }
}
```

## Choosing the Right CRDT

| Need | CRDT | Example |
|------|------|---------|
| Count things (add only) | G-Counter | Page views |
| Count things (add/subtract) | PN-Counter | Inventory |
| Collect items (add only) | G-Set | Tags |
| Collect items (add/remove) | OR-Set | Cart items |
| Single value | LWW-Register | Username |
| Single value (preserve concurrency) | MV-Register | Conflict resolution |
| Ordered list | RGA | Collaborative text |
| Key-value store | OR-Map | User preferences |

## CRDT Limitations

CRDTs aren't magic. They have constraints:

### What CRDTs Can't Do

1. **Invariants across multiple values** — Can't enforce "balance >= 0" across accounts
2. **Strong consistency** — By design, they're eventually consistent
3. **Efficient deletion** — Tombstones can accumulate (garbage collection needed)
4. **Arbitrary operations** — Not all operations can be made commutative

### When Not to Use CRDTs

- **Financial transactions** — Use consensus protocols
- **Sequential workflows** — Use event sourcing or state machines
- **Small data, fast network** — Simple request-response may suffice
- **Strong consistency requirements** — Use Raft/Paxos

## Further Reading

- [A comprehensive study of CRDTs](https://hal.inria.fr/inria-00555588/document) — Shapiro et al.
- [CRDTs: The Hard Parts](https://martin.kleppmann.com/2020/07/06/crdt-hard-parts-hydra.html) — Martin Kleppmann
- [Automerge](https://automerge.org/) — CRDT library for JS
- [Yjs](https://yjs.dev/) — High-performance CRDT framework
- [Local-First Software](https://www.inkandswitch.com/local-first/) — Ink & Switch manifesto
