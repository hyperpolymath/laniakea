// SPDX-License-Identifier: MIT OR Apache-2.0
// Copyright (c) 2024 Laniakea Contributors

/**
 * LWW-Register (Last-Writer-Wins Register) CRDT
 *
 * Simple single-value storage where highest timestamp wins.
 */

type nodeId = string

type t<'a> = {
  value: option<'a>,
  timestamp: int,
  nodeId: option<nodeId>,
  version: int,
}

/** Create a new, empty register */
let make = (): t<'a> => {
  value: None,
  timestamp: 0,
  nodeId: None,
  version: 0,
}

/** Create with initial value */
let makeWith = (value: 'a, nodeId: nodeId): t<'a> => {
  value: Some(value),
  timestamp: Js.Date.now()->Belt.Float.toInt,
  nodeId: Some(nodeId),
  version: 1,
}

/** Set the register value */
let set = (reg: t<'a>, value: 'a, nodeId: nodeId): t<'a> => {
  {
    value: Some(value),
    timestamp: Js.Date.now()->Belt.Float.toInt,
    nodeId: Some(nodeId),
    version: reg.version + 1,
  }
}

/** Set with explicit timestamp (for testing) */
let setWithTimestamp = (reg: t<'a>, value: 'a, nodeId: nodeId, timestamp: int): t<'a> => {
  {
    value: Some(value),
    timestamp,
    nodeId: Some(nodeId),
    version: reg.version + 1,
  }
}

/** Get the current value */
let value = (reg: t<'a>): option<'a> => reg.value

/** Get timestamp */
let timestamp = (reg: t<'a>): int => reg.timestamp

/** Get node ID */
let nodeId = (reg: t<'a>): option<nodeId> => reg.nodeId

/** Merge two registers - highest timestamp wins */
let merge = (a: t<'a>, b: t<'a>): t<'a> => {
  let winner = if a.timestamp > b.timestamp {
    a
  } else if b.timestamp > a.timestamp {
    b
  } else {
    // Tie-breaker: lexicographic node ID comparison
    let aNode = a.nodeId->Belt.Option.getWithDefault("")
    let bNode = b.nodeId->Belt.Option.getWithDefault("")
    if aNode >= bNode {
      a
    } else {
      b
    }
  }

  {
    ...winner,
    version: Js.Math.max_int(a.version, b.version) + 1,
  }
}

// Wire format (generic value as JSON)
type wireFormat<'a> = {
  @as("type") type_: string,
  value: Js.Nullable.t<'a>,
  timestamp: int,
  @as("node_id") nodeId: Js.Nullable.t<string>,
  version: int,
}

let toWire = (reg: t<'a>): wireFormat<'a> => {
  type_: "lww_register",
  value: reg.value->Js.Nullable.fromOption,
  timestamp: reg.timestamp,
  nodeId: reg.nodeId->Js.Nullable.fromOption,
  version: reg.version,
}

let fromWire = (wire: wireFormat<'a>): t<'a> => {
  value: wire.value->Js.Nullable.toOption,
  timestamp: wire.timestamp,
  nodeId: wire.nodeId->Js.Nullable.toOption,
  version: wire.version,
}
