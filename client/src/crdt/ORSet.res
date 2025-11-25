// SPDX-License-Identifier: MIT OR Apache-2.0
// Copyright (c) 2024 Laniakea Contributors

/**
 * OR-Set (Observed-Remove Set) CRDT
 *
 * Supports add and remove operations. Add-wins on concurrent operations.
 */

type nodeId = string

type tag = {
  node: nodeId,
  ts: int,
}

type t = {
  elements: Belt.Map.String.t<Belt.Set.t<tag>>,
  version: int,
}

// Tag comparison for Set
module TagCmp = Belt.Id.MakeComparable({
  type t = tag
  let cmp = (a, b) => {
    let nodeCmp = compare(a.node, b.node)
    if nodeCmp != 0 {
      nodeCmp
    } else {
      compare(a.ts, b.ts)
    }
  }
})

let emptyTagSet = Belt.Set.make(~id=module(TagCmp))

/** Create a new, empty OR-Set */
let make = (): t => {
  elements: Belt.Map.String.empty,
  version: 0,
}

/** Generate a unique timestamp */
let generateTs = (): int => {
  Js.Date.now()->Belt.Float.toInt
}

/** Add an element to the set */
let add = (set: t, element: string, nodeId: nodeId): t => {
  let tag = {node: nodeId, ts: generateTs()}
  let existingTags =
    set.elements->Belt.Map.String.get(element)->Belt.Option.getWithDefault(emptyTagSet)
  let newTags = existingTags->Belt.Set.add(tag)
  {
    elements: set.elements->Belt.Map.String.set(element, newTags),
    version: set.version + 1,
  }
}

/** Remove an element (removes all observed tags) */
let remove = (set: t, element: string): t => {
  {
    elements: set.elements->Belt.Map.String.remove(element),
    version: set.version + 1,
  }
}

/** Check if element is in set */
let contains = (set: t, element: string): bool => {
  switch set.elements->Belt.Map.String.get(element) {
  | None => false
  | Some(tags) => Belt.Set.size(tags) > 0
  }
}

/** Get all elements */
let elements = (set: t): array<string> => {
  set.elements
  ->Belt.Map.String.keysToArray
  ->Belt.Array.keep(elem => contains(set, elem))
}

/** Alias for elements */
let value = elements

/** Get size */
let size = (set: t): int => elements(set)->Belt.Array.length

/** Merge two OR-Sets */
let merge = (a: t, b: t): t => {
  let aKeys = a.elements->Belt.Map.String.keysToArray->Belt.Set.String.fromArray
  let bKeys = b.elements->Belt.Map.String.keysToArray->Belt.Set.String.fromArray
  let allElements = Belt.Set.String.union(aKeys, bKeys)

  let mergedElements = allElements->Belt.Set.String.reduce(Belt.Map.String.empty, (acc, element) => {
    let tagsA = a.elements->Belt.Map.String.get(element)->Belt.Option.getWithDefault(emptyTagSet)
    let tagsB = b.elements->Belt.Map.String.get(element)->Belt.Option.getWithDefault(emptyTagSet)
    let mergedTags = Belt.Set.union(tagsA, tagsB)

    if Belt.Set.size(mergedTags) > 0 {
      acc->Belt.Map.String.set(element, mergedTags)
    } else {
      acc
    }
  })

  {
    elements: mergedElements,
    version: Js.Math.max_int(a.version, b.version) + 1,
  }
}

// Wire format (simplified - tags as array of objects)
type tagWire = {
  node: string,
  ts: int,
}

type wireFormat = {
  @as("type") type_: string,
  elements: Js.Dict.t<array<tagWire>>,
  version: int,
  value: array<string>,
}

let toWire = (set: t): wireFormat => {
  let elementsDict = Js.Dict.empty()
  set.elements->Belt.Map.String.forEach((element, tags) => {
    let tagsArray = tags->Belt.Set.toArray->Belt.Array.map(t => {node: t.node, ts: t.ts})
    Js.Dict.set(elementsDict, element, tagsArray)
  })
  {
    type_: "or_set",
    elements: elementsDict,
    version: set.version,
    value: elements(set),
  }
}
