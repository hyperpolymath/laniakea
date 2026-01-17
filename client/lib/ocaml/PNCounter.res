// SPDX-License-Identifier: MIT OR Apache-2.0
// Copyright (c) 2024 Laniakea Contributors

/**
 * PN-Counter (Positive-Negative Counter) CRDT
 *
 * Supports both increment and decrement by maintaining two G-Counters.
 */

type nodeId = string

type t = {
  positive: GCounter.t,
  negative: GCounter.t,
  version: int,
}

/** Create a new, empty PN-Counter */
let make = (): t => {
  positive: GCounter.make(),
  negative: GCounter.make(),
  version: 0,
}

/** Increment the counter */
let increment = (counter: t, nodeId: nodeId): t => {
  {
    ...counter,
    positive: GCounter.increment(counter.positive, nodeId),
    version: counter.version + 1,
  }
}

/** Increment by a specific amount */
let incrementBy = (counter: t, nodeId: nodeId, amount: int): t => {
  {
    ...counter,
    positive: GCounter.incrementBy(counter.positive, nodeId, amount),
    version: counter.version + 1,
  }
}

/** Decrement the counter */
let decrement = (counter: t, nodeId: nodeId): t => {
  {
    ...counter,
    negative: GCounter.increment(counter.negative, nodeId),
    version: counter.version + 1,
  }
}

/** Decrement by a specific amount */
let decrementBy = (counter: t, nodeId: nodeId, amount: int): t => {
  {
    ...counter,
    negative: GCounter.incrementBy(counter.negative, nodeId, amount),
    version: counter.version + 1,
  }
}

/** Get the current value (positive - negative) */
let value = (counter: t): int => {
  GCounter.value(counter.positive) - GCounter.value(counter.negative)
}

/** Get the positive count only */
let positiveValue = (counter: t): int => GCounter.value(counter.positive)

/** Get the negative count only */
let negativeValue = (counter: t): int => GCounter.value(counter.negative)

/** Merge two PN-Counters */
let merge = (a: t, b: t): t => {
  {
    positive: GCounter.merge(a.positive, b.positive),
    negative: GCounter.merge(a.negative, b.negative),
    version: Js.Math.max_int(a.version, b.version) + 1,
  }
}

/** Compute delta */
let delta = (older: t, newer: t): t => {
  {
    positive: GCounter.delta(older.positive, newer.positive),
    negative: GCounter.delta(older.negative, newer.negative),
    version: newer.version,
  }
}

// Wire format
type wireFormat = {
  @as("type") type_: string,
  positive: Js.Dict.t<int>,
  negative: Js.Dict.t<int>,
  version: int,
  value: int,
}

let toWire = (counter: t): wireFormat => {
  let posDict = Js.Dict.empty()
  let negDict = Js.Dict.empty()
  counter.positive.counts->Belt.Map.String.forEach((k, v) => Js.Dict.set(posDict, k, v))
  counter.negative.counts->Belt.Map.String.forEach((k, v) => Js.Dict.set(negDict, k, v))
  {
    type_: "pn_counter",
    positive: posDict,
    negative: negDict,
    version: counter.version,
    value: value(counter),
  }
}

let fromWire = (wire: wireFormat): t => {
  let positive =
    wire.positive
    ->Js.Dict.entries
    ->Belt.Array.map(((k, v)) => (k, v))
    ->Belt.Map.String.fromArray
  let negative =
    wire.negative
    ->Js.Dict.entries
    ->Belt.Array.map(((k, v)) => (k, v))
    ->Belt.Map.String.fromArray
  {
    positive: {counts: positive, version: 0},
    negative: {counts: negative, version: 0},
    version: wire.version,
  }
}
