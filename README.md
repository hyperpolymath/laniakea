<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->

<div class="lead" wrapper="1">

**The browser isn’t a client — it’s a peer node in a distributed system
where state flows and converges.**

</div>

<figure>
![Status](https://img.shields.io/badge/status-Phase%200-blue)
</figure>

[![OpenSSF Best Practices](https://img.shields.io/badge/OpenSSF-Best_Practices-green?logo=opensourcesecurity)](https://www.bestpractices.dev/en/projects/new?repo_url=https://github.com/hyperpolymath/laniakea)
[![License: PMPL-1.0](https://img.shields.io/badge/License-MPL--2.0-blue.svg)](https://github.com/hyperpolymath/palimpsest-license) <embed
src="https://api.thegreenwebfoundation.org/greencheckimage/github.com"
data-link="https://www.thegreenwebfoundation.org/green-web-check/?url=github.com" />
![Elixir](:https://img.shields.io/badge/elixir-%3E%3D%201.15-purple)

<div id="toc">

</div>

# What is Laniakea?

Laniakea is a **transcendent architecture** for building distributed web
applications where browsers participate as peer nodes in a BEAM cluster,
not as dumb terminals receiving server pushes.

Named after the [Laniakea
Supercluster](https://en.wikipedia.org/wiki/Laniakea_Supercluster) — the
cosmic structure containing our galaxy — this project embodies the idea
that individual nodes (browsers) are part of a larger, interconnected
system where state flows and converges across vast distances.

## Core Principles

| Principle | Description |
|----|----|
| **State Convergence** | Neither server nor client "owns" state. CRDTs ensure eventual consistency without coordination. |
| **Browser as Peer** | The browser runs BEAM-compatible semantics, participating in the distributed system. |
| **Capability Negotiation** | Clients declare capabilities; servers adapt behavior (update frequency, batching, rendering). |
| **Offline-First** | Local CRDT operations continue offline; state merges upon reconnection. |
| **Progressive Enhancement** | Works with WebSocket today, WebTransport where available, full BEAM-in-browser later. |

## The Vision

    ┌─────────────────────────────────────────────────────────────┐
    │                 TRANSCENDENT ARCHITECTURE                   │
    │                                                             │
    │      Server BEAM Nodes              Browser BEAM Nodes      │
    │      ┌─────────────────┐            ┌─────────────────┐    │
    │      │ OTP Full Stack  │◄──────────►│ Isomorphic      │    │
    │      │ - Supervisors   │  Streams   │ - Local Sups    │    │
    │      │ - Distribution  │  & CRDTs   │ - CRDT Mirrors  │    │
    │      │ - CRDT Registry │            │ - UI Processes  │    │
    │      └─────────────────┘            └─────────────────┘    │
    │              │                              │               │
    │              │         State Flows          │               │
    │              └──────────────────────────────┘               │
    │                                                             │
    │            Neither "owns" — state converges.                │
    └─────────────────────────────────────────────────────────────┘

# Why Laniakea?

## The Problem with Traditional Web Architecture

| Traditional                   | Laniakea                      |
|-------------------------------|-------------------------------|
| Server owns state             | State converges across nodes  |
| Client is a dumb terminal     | Client is a BEAM peer         |
| Offline = broken              | Offline = local CRDT ops      |
| JS runtime quirks             | BEAM semantics everywhere     |
| Hope nothing crashes          | Supervision trees in browser  |
| REST/GraphQL request-response | Bidirectional streams + CRDTs |

## Why Now?

1.  **WebAssembly matured** — Threads, GC proposal, Component Model
    enable real runtimes

2.  **CRDTs went production** — Figma, Linear, Notion proved they scale

3.  **Elixir proved the model** — Discord, WhatsApp, Pinterest: millions
    of concurrent users

4.  **JS ecosystem fatigue** — Dependency sprawl, security issues,
    bundle bloat

5.  **Popcorn/AtomVM emerged** — Lightweight BEAM-in-browser is now
    tractable

# Architecture

## Phase 0: Demonstrable Now

What works today with Phoenix + ReScript + CRDTs:

    ┌─────────────────────────────────────────────────────────────┐
    │                    DEMONSTRABLE NOW                         │
    │                                                             │
    │  [Phoenix Server]              [ReScript/Elm Client]        │
    │       │                              │                      │
    │       ├── CRDT State (G-Counter)     ├── CRDT Mirror        │
    │       ├── Phoenix Channels           ├── Typed Adapters     │
    │       ├── Capability Negotiation     ├── DOM Rendering      │
    │       └── Command Bus                └── Offline Outbox     │
    │                                                             │
    │  Transport: WebSocket (today), WebTransport (where avail)   │
    └─────────────────────────────────────────────────────────────┘

## Phased Implementation

| Phase | Description | Status |
|----|----|----|
| **Phase 0** | Core demo: CRDTs + Phoenix Channels + capability negotiation | ✅ Implementable now |
| **Phase 1** | Delta-based CRDT sync, typed command/event envelopes | 🔄 In progress |
| **Phase 2** | Transport hedging (WebTransport), OTEL observability | 📋 Planned |
| **Phase 3** | Zig/Wasm runtime bridge OR Popcorn/AtomVM integration | 🔬 Research |
| **Phase 4** | Full BEAM-in-browser with supervision trees | 🌟 Vision |

## Component Overview

### Server (Elixir/Phoenix)

```elixir
# CRDT Registry - manages distributed state
defmodule Laniakea.CRDT.Registry do
  use GenServer
  # Stores CRDTs by ID, broadcasts deltas to connected clients
end

# Capability Policy - adapts to client capabilities
defmodule Laniakea.Policy do
  def assign_profile(capabilities) do
    cond do
      full_capabilities?(capabilities) -> :full_client
      partial_capabilities?(capabilities) -> :constrained_client
      true -> :minimal_client
    end
  end
end

# Command Bus - typed command processing
defmodule Laniakea.CommandBus do
  def handle(%{type: "crdt.increment", payload: p}, state) do
    # Process command, return events
  end
end
```

### Client (ReScript/Elm)

```rescript
// G-Counter CRDT - isomorphic with server
module GCounter = {
  type t = {counts: Map.String.t<int>, version: int}

  let merge = (a, b) => {
    // Commutative, associative, idempotent
    // merge(a, b) == merge(b, a)
  }
}

// Capability Probe - detect browser features
module Capabilities = {
  let probe = () => {
    hasWorkers: Worker.available(),
    hasSharedArrayBuffer: SharedArrayBuffer.available(),
    // ...
  }
}
```

### CRDTs

Laniakea uses Conflict-free Replicated Data Types for coordination-free
state convergence:

| CRDT | Use Case | Properties |
|----|----|----|
| **G-Counter** | Increment-only counters (views, likes) | Grow-only, merge = max per node |
| **PN-Counter** | Increment/decrement counters | Pair of G-Counters (positive/negative) |
| **G-Set** | Add-only sets (tags, participants) | Union on merge |
| **OR-Set** | Add/remove sets with observed-remove | Handles concurrent add/remove |
| **LWW-Register** | Last-writer-wins single values | Timestamp-based conflict resolution |
| **RGA** | Collaborative text sequences | Replicated Growable Array |

# Comparison: Laniakea vs Alternatives

## vs Traditional SPA (React/Next.js)

| Aspect | React/Next.js | Laniakea |
|----|----|----|
| **State ownership** | Server owns, client caches | State converges via CRDTs |
| **Offline support** | Requires explicit implementation | Built-in (CRDTs work offline) |
| **Type safety** | Optional (TypeScript) | Mandatory (ReScript/Elm) |
| **Concurrency model** | Single-threaded event loop | BEAM processes (browser) |
| **Error handling** | Try/catch, error boundaries | Supervision trees |
| **Real-time sync** | WebSocket + custom logic | Phoenix Channels + CRDTs |

## vs Elm

| Aspect                 | Elm                     | Laniakea                  |
|------------------------|-------------------------|---------------------------|
| **Runtime**            | Elm runtime (JS)        | BEAM semantics (browser)  |
| **Server integration** | HTTP/WebSocket (manual) | Phoenix Channels (native) |
| **State sync**         | Manual implementation   | CRDT convergence          |
| **Distribution**       | Single-page app         | Distributed peer node     |
| **Type system**        | Hindley-Milner          | Dialyzer + ReScript       |

## vs LiveView

| Aspect | Phoenix LiveView | Laniakea |
|----|----|----|
| **Rendering** | Server-rendered, diff pushed | Client renders, state converges |
| **Offline** | Requires connection | Full offline support |
| **State location** | Server owns state | State exists everywhere |
| **Latency sensitivity** | High (all actions round-trip) | Low (local operations) |
| **Scalability** | Server resources per client | Clients do local work |

## vs Lumen/Firefly (Archived)

| Aspect                | Lumen/Firefly             | Laniakea                  |
|-----------------------|---------------------------|---------------------------|
| **Approach**          | Reimplement BEAM in Rust  | Extend cluster to browser |
| **Scope**             | Full OTP reimplementation | State convergence only    |
| **Distribution**      | Not addressed             | Core feature (CRDTs)      |
| **Incremental value** | All or nothing            | Phase 0 works today       |
| **Status**            | ❌ Archived June 2024     | ✅ Active development     |

## vs Popcorn/AtomVM

Laniakea and Popcorn are **complementary**:

- **Popcorn** provides BEAM-in-browser runtime via AtomVM compiled to
  Wasm

- **Laniakea** provides the architecture for distributed state
  convergence

Future integration: Laniakea client runs on Popcorn runtime, giving us
actual OTP in browser.

# Quick Start

## Prerequisites

- Elixir \>= 1.15

- Node.js \>= 18

- PostgreSQL (optional, for persistence)

## Setup

```bash
# Clone the repository
git clone https://github.com/your-org/laniakea.git
cd laniakea

# Setup server
cd server
mix deps.get
mix ecto.setup  # if using database

# Setup client
cd ../client
npm install

# Start both (in separate terminals)
cd server && mix phx.server
cd client && npm run dev

# Open http://localhost:5173 in multiple tabs
# Click "Increment" in both — watch values converge!
```

## Demo: Collaborative Counter

1.  Open the app in two browser tabs

2.  Click "Increment" in Tab A → both tabs show updated count

3.  Disconnect Tab B from network (DevTools → Offline)

4.  Click "Increment" in Tab B → local count increases

5.  Reconnect Tab B → watch CRDTs merge, counts converge

# Project Structure

    laniakea/
    ├── server/                      # Elixir/Phoenix
    │   ├── lib/laniakea/
    │   │   ├── crdt/
    │   │   │   ├── g_counter.ex     # G-Counter implementation
    │   │   │   ├── pn_counter.ex    # PN-Counter implementation
    │   │   │   └── registry.ex      # CRDT state registry
    │   │   ├── command_bus.ex       # Typed command processing
    │   │   ├── policy.ex            # Capability negotiation
    │   │   └── application.ex       # OTP supervision tree
    │   ├── lib/laniakea_web/
    │   │   ├── channels/
    │   │   │   ├── crdt_channel.ex  # Phoenix Channel for sync
    │   │   │   └── user_socket.ex
    │   │   └── endpoint.ex
    │   └── config/
    ├── client/                      # ReScript/Elm
    │   ├── src/
    │   │   ├── crdt/
    │   │   │   └── GCounter.res     # G-Counter mirror
    │   │   ├── adapters/
    │   │   │   ├── Capabilities.res # Browser feature detection
    │   │   │   └── Command.res      # Typed command envelopes
    │   │   ├── transport/
    │   │   │   └── Channel.res      # Phoenix channel bindings
    │   │   └── Main.res             # Application entry
    │   └── index.html
    ├── schemas/                     # Shared type definitions
    │   ├── commands.proto           # Protocol buffers
    │   └── generators/              # Code generators
    ├── docs/
    │   ├── wiki/                    # Detailed documentation
    │   ├── whitepapers/             # Academic/industry papers
    │   └── comparisons/             # Framework comparisons
    └── README.adoc                  # This file

# Documentation

## Wiki

- [Home](docs/wiki/Home.md) — Overview and navigation

- [Architecture](docs/wiki/Architecture.md) — Detailed system design

- [CRDTs](docs/wiki/CRDTs.md) — Conflict-free data types explained

- [Capability Negotiation](docs/wiki/Capability-Negotiation.md) —
  Adaptive client profiles

- [Transport](docs/wiki/Transport.md) — WebSocket/WebTransport/QUIC

- [FAQ](docs/wiki/FAQ.md) — Frequently asked questions

## Whitepapers

- [Industry Whitepaper](docs/whitepapers/industry.md) — For
  practitioners

- [Academic Paper](docs/whitepapers/academic.md) — For researchers

- [Public Overview](docs/whitepapers/public.md) — For general audience

## Comparisons

- [Elm vs Next.js vs React](docs/comparisons/elm-nextjs-react.md) —
  Framework comparison

- [vs LiveView](docs/comparisons/liveview.md) — Server-rendered
  comparison

- [vs Lumen/Firefly](docs/comparisons/lumen.md) — Why we differ

# Contributing

We welcome contributions! See
<a href="CONTRIBUTING.md" class="md">CONTRIBUTING</a> for guidelines.

## Development

```bash
# Run server tests
cd server && mix test

# Run client tests
cd client && npm test

# Type check
cd server && mix dialyzer
cd client && npm run typecheck
```

# Roadmap

## 2024 Q4 - Phase 0

- [x] G-Counter CRDT implementation (server + client)

- [x] Phoenix Channel transport

- [x] Capability negotiation

- [ ] Basic demo application

- [ ] Documentation

## 2025 Q1 - Phase 1

- [ ] Delta-based CRDT sync

- [ ] More CRDT types (PN-Counter, OR-Set)

- [ ] Typed command/event envelopes

- [ ] Schema generators (Protobuf/Cap’n Proto)

## 2025 Q2 - Phase 2

- [ ] WebTransport support

- [ ] Transport hedging (race WebSocket vs WebTransport)

- [ ] OpenTelemetry integration

- [ ] Backpressure monitoring

## 2025 Q3+ - Phase 3/4

- [ ] Evaluate Popcorn/AtomVM integration

- [ ] Zig/Wasm runtime research

- [ ] Browser supervision trees

- [ ] Full distributed BEAM semantics

# Prior Art & Inspiration

- [Lumen/Firefly](https://github.com/lumen/lumen) — BEAM-to-Wasm
  compiler (archived)

- [Popcorn](https://github.com/nicklockwood/Popcorn) — AtomVM in browser

- [Hologram](https://github.com/hologram-compiler/hologram) —
  Elixir-to-JS transpiler

- [Lunatic](https://github.com/lunatic-solutions/lunatic) —
  Erlang-inspired Wasm runtime

- [Automerge](https://automerge.org/) — CRDT library

- [Yjs](https://github.com/yjs/yjs) — CRDT framework

- [Phoenix](https://www.phoenixframework.org/) — Elixir web framework

- [ReScript](https://rescript-lang.org/) — Type-safe JS compiler

# License

Dual-licensed under MIT and Apache 2.0. See [LICENSE](LICENSE) for
details.

# Acknowledgments

This project builds on decades of distributed systems research,
particularly:

- Marc Shapiro et al. — CRDT foundations

- Joe Armstrong — Erlang/OTP design

- Chris McCord — Phoenix framework

- The Elixir core team — Language and ecosystem

------------------------------------------------------------------------

> The universe is a pretty big place. If it’s just us, seems like an
> awful waste of space.
>
> — Carl Sagan

In the Laniakea architecture, your browser isn’t alone — it’s part of
something bigger.

# Architecture

See <a href="TOPOLOGY.md" class="md">TOPOLOGY</a> for a visual
architecture map and completion dashboard.
