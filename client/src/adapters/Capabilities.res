// SPDX-License-Identifier: MIT OR Apache-2.0
// Copyright (c) 2024 Laniakea Contributors

/**
 * Browser Capabilities Probe
 *
 * Detects browser features for capability negotiation with server.
 */

type connectionType =
  | Wifi
  | Ethernet
  | Cellular
  | Unknown

type effectiveType =
  | Slow2g
  | _2g
  | _3g
  | _4g

type t = {
  hasWorkers: bool,
  hasSharedArrayBuffer: bool,
  hasWebTransport: bool,
  memoryMb: int,
  connectionType: connectionType,
  effectiveType: effectiveType,
}

// FFI bindings
@val external hasWorkerSupport: bool = "typeof Worker !== 'undefined'"
@val external hasSABSupport: bool = "typeof SharedArrayBuffer !== 'undefined'"
@val external hasWebTransportSupport: bool = "typeof WebTransport !== 'undefined'"

@val @scope("navigator")
external deviceMemory: Js.Nullable.t<float> = "deviceMemory"

@val @scope(("navigator", "connection"))
external connectionTypeRaw: Js.Nullable.t<string> = "type"

@val @scope(("navigator", "connection"))
external effectiveTypeRaw: Js.Nullable.t<string> = "effectiveType"

let parseConnectionType = (raw: option<string>): connectionType => {
  switch raw {
  | Some("wifi") => Wifi
  | Some("ethernet") => Ethernet
  | Some("cellular") => Cellular
  | _ => Unknown
  }
}

let parseEffectiveType = (raw: option<string>): effectiveType => {
  switch raw {
  | Some("slow-2g") => Slow2g
  | Some("2g") => _2g
  | Some("3g") => _3g
  | Some("4g") => _4g
  | _ => _4g // Default to 4g if unknown
  }
}

/** Probe all capabilities */
let probe = (): t => {
  let memory =
    deviceMemory
    ->Js.Nullable.toOption
    ->Belt.Option.mapWithDefault(2048, mem => (mem *. 1024.0)->Belt.Float.toInt)

  {
    hasWorkers: hasWorkerSupport,
    hasSharedArrayBuffer: hasSABSupport,
    hasWebTransport: hasWebTransportSupport,
    memoryMb: memory,
    connectionType: connectionTypeRaw->Js.Nullable.toOption->parseConnectionType,
    effectiveType: effectiveTypeRaw->Js.Nullable.toOption->parseEffectiveType,
  }
}

// Wire format for sending to server
type wireFormat = {
  hasWorkers: bool,
  hasSharedArrayBuffer: bool,
  hasWebTransport: bool,
  memoryMb: int,
  connectionType: string,
  effectiveType: string,
}

let connectionTypeToString = (ct: connectionType): string => {
  switch ct {
  | Wifi => "wifi"
  | Ethernet => "ethernet"
  | Cellular => "cellular"
  | Unknown => "unknown"
  }
}

let effectiveTypeToString = (et: effectiveType): string => {
  switch et {
  | Slow2g => "slow-2g"
  | _2g => "2g"
  | _3g => "3g"
  | _4g => "4g"
  }
}

let toWire = (caps: t): wireFormat => {
  hasWorkers: caps.hasWorkers,
  hasSharedArrayBuffer: caps.hasSharedArrayBuffer,
  hasWebTransport: caps.hasWebTransport,
  memoryMb: caps.memoryMb,
  connectionType: connectionTypeToString(caps.connectionType),
  effectiveType: effectiveTypeToString(caps.effectiveType),
}

/** Log capabilities for debugging */
let log = (caps: t): unit => {
  Js.Console.log2("Capabilities:", toWire(caps))
}
