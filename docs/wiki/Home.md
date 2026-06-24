<!--
SPDX-License-Identifier: MPL-2.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# Laniakea Wiki

> *"Laniakea"* — Hawaiian for "immeasurable heaven" — the supercluster containing our Milky Way galaxy.

Welcome to the Laniakea documentation wiki. This is the comprehensive guide to understanding, using, and contributing to the Laniakea distributed architecture.

## The Cosmological Metaphor

Laniakea's naming isn't accidental. The architecture mirrors the structure of our cosmic home:

| Cosmic Concept | Laniakea Equivalent |
|----------------|---------------------|
| **The Great Attractor** | CRDTs pulling state toward convergence without any node "owning" truth |
| **Galaxies flowing toward a center they can't see** | Clients and servers converging on state without central authority |
| **Supercluster containing clusters** | Mesh of browser nodes + server nodes forming a coherent whole |
| **Polynesian navigators** | Finding your way to consistent state across vast network distances |
| **Zone of Avoidance** | Network failures you can't see through, but the system handles anyway |

**Tagline**: *Distributed state finds its way home.*

---

## Quick Navigation

### Getting Started
- [Quick Start Guide](Quick-Start.md) — Get running in 5 minutes
- [Installation](Installation.md) — Detailed setup instructions
- [First Application](First-Application.md) — Build your first Laniakea app

### Core Concepts
- [Architecture Overview](Architecture.md) — The transcendent architecture explained
- [CRDTs](CRDTs.md) — Conflict-free Replicated Data Types
- [Capability Negotiation](Capability-Negotiation.md) — Adaptive client profiles
- [Transport Layer](Transport.md) — Phoenix Channels, WebTransport, QUIC

### Implementation
- [Server Guide (Elixir)](Server-Guide.md) — Phoenix + OTP patterns
- [Client Guide (ReScript)](Client-Guide.md) — Browser implementation
- [Schema Design](Schema-Design.md) — Typed command/event envelopes
- [Testing](Testing.md) — Testing distributed systems

### Reference
- [API Reference](API-Reference.md) — Complete API documentation
- [CRDT Catalog](CRDT-Catalog.md) — Available CRDT types
- [Configuration](Configuration.md) — All configuration options
- [Glossary](Glossary.md) — Terms and definitions

### Community
- [FAQ](FAQ.md) — Frequently asked questions
- [Contributing](Contributing.md) — How to contribute
- [Roadmap](Roadmap.md) — Where we're going
- [Comparisons](Comparisons.md) — vs LiveView, Lumen, React, etc.

---

## Why Laniakea Exists

The web has been built on a lie: **the server owns the truth.**

Every framework — from jQuery to React to Next.js — assumes a client-server relationship where:
- The server is authoritative
- The client is a display terminal
- Offline means broken
- Conflicts require manual resolution

But distributed systems research has known better for decades. CRDTs, vector clocks, and eventual consistency have been production-ready in databases. The BEAM has run millions of concurrent distributed processes at WhatsApp and Discord.

**Laniakea asks: What if we applied these ideas to the browser?**

The result is an architecture where:
- **State converges** — Neither server nor client "owns" it
- **Browsers are peers** — Full participants in the distributed system
- **Offline works** — Local operations continue; merge on reconnect
- **Conflicts resolve automatically** — CRDTs guarantee convergence

---

## The Phases

Laniakea is built incrementally. Each phase adds capability while remaining useful:

### Phase 0: Core Demo ✅
*Works today with Phoenix + ReScript*

- G-Counter CRDT (server + client)
- Phoenix Channel transport
- Capability negotiation
- Basic demo application

### Phase 1: Production Foundation 🔄
*Delta sync + typed envelopes*

- Delta-based CRDT synchronization
- More CRDT types (PN-Counter, OR-Set, LWW-Register)
- Protobuf/Cap'n Proto schemas
- Schema code generators

### Phase 2: Transport Optimization 📋
*WebTransport + observability*

- WebTransport support
- Transport hedging (race protocols)
- OpenTelemetry integration
- Backpressure monitoring

### Phase 3: Browser Runtime 🔬
*BEAM semantics in browser*

- Evaluate Popcorn/AtomVM integration
- Zig/Wasm runtime research
- Process supervision in browser
- Full OTP semantics

### Phase 4: Full Transcendence 🌟
*Browser as true BEAM node*

- Browser joins BEAM cluster
- Distributed supervision trees
- Hot code reload
- Complete parity

---

## Quick Example

```elixir
# Server: Define a counter CRDT
defmodule MyApp.Counter do
  alias Laniakea.CRDT.GCounter

  def increment(counter, node_id) do
    GCounter.increment(counter, node_id)
  end

  def merge(a, b) do
    GCounter.merge(a, b)  # Commutative, associative, idempotent
  end

  def value(counter) do
    GCounter.value(counter)  # Sum of all node counts
  end
end
```

```rescript
// Client: Mirror implementation
module Counter = {
  let increment = (counter, nodeId) => {
    GCounter.increment(counter, nodeId)
  }

  let merge = (a, b) => {
    GCounter.merge(a, b)  // Same semantics as server
  }
}

// Usage
let handleClick = () => {
  // Local operation (instant)
  let newCounter = Counter.increment(state.counter, myNodeId)
  setState(_ => {...state, counter: newCounter})

  // Sync to server (async)
  Channel.push("increment", {"node_id": myNodeId})
}

// On reconnect: merge server state
let onSync = serverCounter => {
  setState(s => {...s, counter: Counter.merge(s.counter, serverCounter)})
}
```

Open two browser tabs. Click "increment" in both. Watch the counts converge.

---

## Getting Help

- **Documentation**: You're here!
- **Discussions**: [GitHub Discussions](https://github.com/laniakea/laniakea/discussions)
- **Chat**: [Discord Server](https://discord.gg/laniakea)
- **Issues**: [GitHub Issues](https://github.com/laniakea/laniakea/issues)

---

*"The universe is under no obligation to make sense to you."* — Neil deGrasse Tyson

*But distributed state can make sense. That's what Laniakea is for.*
