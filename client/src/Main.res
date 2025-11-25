// SPDX-License-Identifier: MIT OR Apache-2.0
// Copyright (c) 2024 Laniakea Contributors

/**
 * Laniakea Client Entry Point
 *
 * Provides the main API for browser applications.
 */

module CRDT = {
  module GCounter = GCounter
  module PNCounter = PNCounter
  module ORSet = ORSet
  module LWWRegister = LWWRegister
}

module Adapters = {
  module Capabilities = Capabilities
}

module Transport = {
  module Channel = Channel
}

// Re-export common functions
let probeCapabilities = Capabilities.probe
let makeGCounter = GCounter.make
let makePNCounter = PNCounter.make
let makeORSet = ORSet.make

// Generate a unique node ID
let generateNodeId = (): string => {
  let timestamp = Js.Date.now()->Belt.Float.toInt
  let random = Js.Math.random_int(0, 999999)
  `node_${timestamp->Belt.Int.toString}_${random->Belt.Int.toString}`
}

// Initialize the client
type client = {
  nodeId: string,
  capabilities: Capabilities.t,
  connection: Channel.t,
}

let init = (~serverUrl: string): client => {
  let nodeId = generateNodeId()
  let capabilities = Capabilities.probe()

  Js.Console.log("=== Laniakea Client ===")
  Js.Console.log2("Node ID:", nodeId)
  Capabilities.log(capabilities)

  let config: Channel.config = {
    url: serverUrl,
    nodeId,
    capabilities,
  }

  let connection = Channel.make(config)
  Channel.connect(connection, serverUrl ++ "/socket")

  {
    nodeId,
    capabilities,
    connection,
  }
}

// Demo: Counter application
module CounterDemo = {
  type state = {
    mutable counter: GCounter.t,
    mutable client: option<client>,
  }

  let state: state = {
    counter: GCounter.make(),
    client: None,
  }

  let start = (serverUrl: string): unit => {
    let client = init(~serverUrl)
    state.client = Some(client)

    // Join counter channel
    Channel.joinCrdt(
      client.connection,
      "demo:counter",
      ~onState=response => {
        Js.Console.log2("Initial state:", response)
        // Parse and set state
      },
      ~onUpdate=response => {
        Js.Console.log2("State updated:", response)
        // Merge with local state
      },
    )
  }

  let increment = (): unit => {
    switch state.client {
    | None => Js.Console.error("Not initialized")
    | Some(client) =>
      // Local update (optimistic)
      state.counter = GCounter.increment(state.counter, client.nodeId)
      Js.Console.log2("Local value:", GCounter.value(state.counter))

      // Sync to server
      Channel.increment(client.connection)
    }
  }

  let getValue = (): int => GCounter.value(state.counter)
}

// Entry point for browser
Js.Console.log("Laniakea Client loaded")
Js.Console.log("Use Laniakea.init(~serverUrl) to connect")
