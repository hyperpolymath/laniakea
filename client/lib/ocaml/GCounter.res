// SPDX-License-Identifier: MIT OR Apache-2.0
// Copyright (c) 2024 Laniakea Contributors

/**
 * G-Counter (Grow-only Counter) CRDT
 *
 * Isomorphic implementation matching server-side Elixir.
 *
 * ## Mathematical Properties
 * - Commutativity: merge(a, b) = merge(b, a)
 * - Associativity: merge(merge(a, b), c) = merge(a, merge(b, c))
 * - Idempotence: merge(a, a) = a
 */

type nodeId = string

type t = {
  counts: Belt.Map.String.t<int>,
  version: int,
}

/** Create a new, empty G-Counter */
let make = (): t => {
  counts: Belt.Map.String.empty,
  version: 0,
}

/** Create from a map of counts */
let fromMap = (counts: Belt.Map.String.t<int>): t => {
  counts,
  version: 0,
}

/** Increment the counter for a node */
let increment = (counter: t, nodeId: nodeId): t => {
  let current = counter.counts->Belt.Map.String.get(nodeId)->Belt.Option.getWithDefault(0)
  {
    counts: counter.counts->Belt.Map.String.set(nodeId, current + 1),
    version: counter.version + 1,
  }
}

/** Increment by a specific amount */
let incrementBy = (counter: t, nodeId: nodeId, amount: int): t => {
  let current = counter.counts->Belt.Map.String.get(nodeId)->Belt.Option.getWithDefault(0)
  {
    counts: counter.counts->Belt.Map.String.set(nodeId, current + amount),
    version: counter.version + 1,
  }
}

/** Get the total value (sum of all node counts) */
let value = (counter: t): int => {
  counter.counts->Belt.Map.String.valuesToArray->Belt.Array.reduce(0, (a, b) => a + b)
}

/** Get the count for a specific node */
let nodeValue = (counter: t, nodeId: nodeId): int => {
  counter.counts->Belt.Map.String.get(nodeId)->Belt.Option.getWithDefault(0)
}

/**
 * Merge two G-Counters
 *
 * Takes the maximum count for each node, ensuring all increments
 * from both counters are preserved.
 */
let merge = (a: t, b: t): t => {
  let aKeys = a.counts->Belt.Map.String.keysToArray->Belt.Set.String.fromArray
  let bKeys = b.counts->Belt.Map.String.keysToArray->Belt.Set.String.fromArray
  let allNodes = Belt.Set.String.union(aKeys, bKeys)

  let mergedCounts = allNodes->Belt.Set.String.reduce(Belt.Map.String.empty, (acc, node) => {
    let countA = a.counts->Belt.Map.String.get(node)->Belt.Option.getWithDefault(0)
    let countB = b.counts->Belt.Map.String.get(node)->Belt.Option.getWithDefault(0)
    acc->Belt.Map.String.set(node, Js.Math.max_int(countA, countB))
  })

  {
    counts: mergedCounts,
    version: Js.Math.max_int(a.version, b.version) + 1,
  }
}

/** Compute delta between two states (for efficient sync) */
let delta = (older: t, newer: t): t => {
  let deltaCounts =
    newer.counts
    ->Belt.Map.String.toArray
    ->Belt.Array.keep(((node, count)) => {
      let oldCount = older.counts->Belt.Map.String.get(node)->Belt.Option.getWithDefault(0)
      count > oldCount
    })
    ->Belt.Map.String.fromArray

  {counts: deltaCounts, version: newer.version}
}

/** Check equality (ignoring version) */
let equal = (a: t, b: t): bool => {
  Belt.Map.String.eq(a.counts, b.counts, (x, y) => x == y)
}

/** Check if a <= b in the partial order */
let lte = (a: t, b: t): bool => {
  let aKeys = a.counts->Belt.Map.String.keysToArray->Belt.Set.String.fromArray
  let bKeys = b.counts->Belt.Map.String.keysToArray->Belt.Set.String.fromArray
  let allNodes = Belt.Set.String.union(aKeys, bKeys)

  allNodes->Belt.Set.String.every(node => {
    let countA = a.counts->Belt.Map.String.get(node)->Belt.Option.getWithDefault(0)
    let countB = b.counts->Belt.Map.String.get(node)->Belt.Option.getWithDefault(0)
    countA <= countB
  })
}

// Wire format serialization
type wireFormat = {
  @as("type") type_: string,
  counts: Js.Dict.t<int>,
  version: int,
  value: int,
}

/** Convert to wire format for transmission */
let toWire = (counter: t): wireFormat => {
  let countsDict = Js.Dict.empty()
  counter.counts->Belt.Map.String.forEach((k, v) => {
    Js.Dict.set(countsDict, k, v)
  })
  {
    type_: "g_counter",
    counts: countsDict,
    version: counter.version,
    value: value(counter),
  }
}

/** Parse from wire format */
let fromWire = (wire: wireFormat): t => {
  let counts =
    wire.counts
    ->Js.Dict.entries
    ->Belt.Array.map(((k, v)) => (k, v))
    ->Belt.Map.String.fromArray

  {
    counts,
    version: wire.version,
  }
}
