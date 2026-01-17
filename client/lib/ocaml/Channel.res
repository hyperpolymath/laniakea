// SPDX-License-Identifier: MIT OR Apache-2.0
// Copyright (c) 2024 Laniakea Contributors

/**
 * Phoenix Channel Transport
 *
 * WebSocket-based transport for communicating with Phoenix server.
 */

// Phoenix Socket types (external bindings)
module Phoenix = {
  type socket
  type channel
  type push

  @module("phoenix") @new
  external makeSocket: (string, 'params) => socket = "Socket"

  @send external connect: socket => unit = "connect"
  @send external disconnect: socket => unit = "disconnect"
  @send external channel: (socket, string, 'params) => channel = "channel"

  @send external join: channel => push = "join"
  @send external leave: channel => push = "leave"
  @send external push: (channel, string, 'payload) => push = "push"
  @send external on: (channel, string, 'payload => unit) => unit = "on"
  @send external off: (channel, string) => unit = "off"

  @send external receive: (push, string, 'response => unit) => push = "receive"
}

type connectionState =
  | Disconnected
  | Connecting
  | Connected
  | Reconnecting(int) // attempt number

type t = {
  mutable socket: option<Phoenix.socket>,
  mutable channel: option<Phoenix.channel>,
  mutable state: connectionState,
  nodeId: string,
  capabilities: Capabilities.t,
}

type config = {
  url: string,
  nodeId: string,
  capabilities: Capabilities.t,
}

/** Create a new channel connection */
let make = (config: config): t => {
  socket: None,
  channel: None,
  state: Disconnected,
  nodeId: config.nodeId,
  capabilities: config.capabilities,
}

/** Connect to the server */
let connect = (conn: t, url: string): unit => {
  conn.state = Connecting

  let params = {
    "node_id": conn.nodeId,
    "capabilities": Capabilities.toWire(conn.capabilities),
  }

  let socket = Phoenix.makeSocket(url, {"params": params})
  Phoenix.connect(socket)
  conn.socket = Some(socket)
  conn.state = Connected
}

/** Join a CRDT channel */
let joinCrdt = (conn: t, key: string, ~onState: 'state => unit, ~onUpdate: 'state => unit): unit => {
  switch conn.socket {
  | None => Js.Console.error("Cannot join channel: not connected")
  | Some(socket) =>
    let topic = "crdt:" ++ key
    let channel = Phoenix.channel(socket, topic, Js.Obj.empty())

    channel
    ->Phoenix.join
    ->Phoenix.receive("ok", response => {
      Js.Console.log2("Joined", topic)
      onState(response)
    })
    ->Phoenix.receive("error", err => {
      Js.Console.error2("Failed to join", err)
    })
    ->ignore

    // Listen for state updates
    Phoenix.on(channel, "state_updated", payload => {
      onUpdate(payload)
    })

    conn.channel = Some(channel)
  }
}

/** Send increment command */
let increment = (conn: t): unit => {
  switch conn.channel {
  | None => Js.Console.error("No channel")
  | Some(channel) =>
    channel
    ->Phoenix.push("increment", Js.Obj.empty())
    ->Phoenix.receive("ok", _ => ())
    ->Phoenix.receive("error", err => Js.Console.error2("Increment failed", err))
    ->ignore
  }
}

/** Send increment_by command */
let incrementBy = (conn: t, amount: int): unit => {
  switch conn.channel {
  | None => Js.Console.error("No channel")
  | Some(channel) =>
    channel
    ->Phoenix.push("increment_by", {"amount": amount})
    ->Phoenix.receive("ok", _ => ())
    ->Phoenix.receive("error", err => Js.Console.error2("Increment failed", err))
    ->ignore
  }
}

/** Send decrement command */
let decrement = (conn: t): unit => {
  switch conn.channel {
  | None => Js.Console.error("No channel")
  | Some(channel) =>
    channel
    ->Phoenix.push("decrement", Js.Obj.empty())
    ->Phoenix.receive("ok", _ => ())
    ->Phoenix.receive("error", err => Js.Console.error2("Decrement failed", err))
    ->ignore
  }
}

/** Send merge command (for offline sync) */
let merge = (conn: t, state: 'a): unit => {
  switch conn.channel {
  | None => Js.Console.error("No channel")
  | Some(channel) =>
    channel
    ->Phoenix.push("merge", {"state": state})
    ->Phoenix.receive("ok", _ => Js.Console.log("Merge successful"))
    ->Phoenix.receive("error", err => Js.Console.error2("Merge failed", err))
    ->ignore
  }
}

/** Request current state */
let sync = (conn: t, callback: 'state => unit): unit => {
  switch conn.channel {
  | None => Js.Console.error("No channel")
  | Some(channel) =>
    channel
    ->Phoenix.push("sync", Js.Obj.empty())
    ->Phoenix.receive("ok", response => callback(response))
    ->Phoenix.receive("error", err => Js.Console.error2("Sync failed", err))
    ->ignore
  }
}

/** Leave channel */
let leave = (conn: t): unit => {
  switch conn.channel {
  | Some(channel) =>
    Phoenix.leave(channel)->ignore
    conn.channel = None
  | None => ()
  }
}

/** Disconnect socket */
let disconnect = (conn: t): unit => {
  leave(conn)
  switch conn.socket {
  | Some(socket) =>
    Phoenix.disconnect(socket)
    conn.socket = None
    conn.state = Disconnected
  | None => ()
  }
}

/** Get current state */
let getState = (conn: t): connectionState => conn.state
