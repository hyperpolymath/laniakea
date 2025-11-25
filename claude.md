# Laniakea - AI Context Document

## Project Identity

**Laniakea** is a transcendent architecture for distributed web applications where browsers participate as peer nodes in a BEAM cluster, not as dumb terminals.

**Core Thesis**: "The browser isn't a client — it's a peer node in a distributed system where state flows and converges."

**Named after**: The Laniakea Supercluster — the cosmic structure containing our galaxy, embodying interconnected nodes across vast distances.

## Architecture Overview

```
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
```

## Key Principles

1. **State Convergence** — CRDTs ensure eventual consistency without coordination
2. **Browser as Peer** — Not a dumb terminal; participates in distributed system
3. **Capability Negotiation** — Server adapts to client capabilities
4. **Offline-First** — Local CRDT operations continue offline
5. **Progressive Enhancement** — Works today, improves with platform evolution

## Technology Stack

### Server
- **Language**: Elixir
- **Framework**: Phoenix
- **Transport**: Phoenix Channels (WebSocket), WebTransport planned
- **State**: CRDTs (G-Counter, PN-Counter, OR-Set, etc.)

### Client
- **Language**: ReScript (preferred) or Elm
- **Transport**: Phoenix JS client
- **State**: Isomorphic CRDT implementations

### Shared
- **Schemas**: Protocol Buffers or Cap'n Proto
- **Contracts**: Typed command/event envelopes

## Phased Implementation

| Phase | Description | Status |
|-------|-------------|--------|
| 0 | Core demo: CRDTs + Phoenix Channels + capability negotiation | In Progress |
| 1 | Delta-based CRDT sync, typed envelopes | Planned |
| 2 | Transport hedging (WebTransport), OTEL observability | Planned |
| 3 | Zig/Wasm runtime OR Popcorn/AtomVM integration | Research |
| 4 | Full BEAM-in-browser with supervision trees | Vision |

## Key Differentiators

### vs Lumen/Firefly (Archived June 2024)
- Lumen tried to **reimplement BEAM** in Rust — drowned in compiler engineering
- Laniakea **extends the cluster** to browser — state convergence, not VM reimplementation
- Lumen: "Compile BEAM to Wasm"
- Laniakea: "Make browser a distributed peer"

### vs LiveView
- LiveView: Server owns state, client renders diffs
- Laniakea: State converges via CRDTs, both are peers
- LiveView: Offline = broken
- Laniakea: Offline = local CRDT operations

### vs Traditional SPA (React/Next.js)
- SPA: Server owns truth, client caches
- Laniakea: Neither owns; state converges
- SPA: Manual offline implementation
- Laniakea: Built-in via CRDTs

## CRDT Fundamentals

CRDTs (Conflict-free Replicated Data Types) are data structures that:
- **Commutative**: merge(a, b) = merge(b, a)
- **Associative**: merge(merge(a, b), c) = merge(a, merge(b, c))
- **Idempotent**: merge(a, a) = a

This guarantees convergence without coordination.

### G-Counter (Grow-only Counter)
```elixir
# Server (Elixir)
defmodule Laniakea.CRDT.GCounter do
  def increment(%{counts: counts} = counter, node_id) do
    current = Map.get(counts, node_id, 0)
    %{counter | counts: Map.put(counts, node_id, current + 1)}
  end

  def merge(a, b) do
    # Take max of each node's count
    all_nodes = MapSet.union(MapSet.new(Map.keys(a.counts)), MapSet.new(Map.keys(b.counts)))
    merged = Enum.reduce(all_nodes, %{}, fn node, acc ->
      Map.put(acc, node, max(Map.get(a.counts, node, 0), Map.get(b.counts, node, 0)))
    end)
    %{counts: merged}
  end

  def value(%{counts: counts}), do: counts |> Map.values() |> Enum.sum()
end
```

```rescript
// Client (ReScript) - isomorphic implementation
module GCounter = {
  type t = {counts: Map.String.t<int>, version: int}

  let merge = (a, b) => {
    let allNodes = Set.String.union(
      a.counts->Map.String.keysToArray->Set.String.fromArray,
      b.counts->Map.String.keysToArray->Set.String.fromArray
    )
    let merged = allNodes->Set.String.reduce(Map.String.empty, (acc, node) => {
      let countA = a.counts->Map.String.get(node)->Option.getOr(0)
      let countB = b.counts->Map.String.get(node)->Option.getOr(0)
      acc->Map.String.set(node, max(countA, countB))
    })
    {counts: merged, version: max(a.version, b.version) + 1}
  }
}
```

## Capability Negotiation

Clients probe their capabilities and server assigns a profile:

```elixir
defmodule Laniakea.Policy do
  @profiles %{
    full_client: %{
      update_frequency: 16,      # 60fps
      batch_events: false,
      server_render: false
    },
    constrained_client: %{
      update_frequency: 100,     # 10fps
      batch_events: true,
      server_render: false
    },
    minimal_client: %{
      update_frequency: 1000,    # 1fps
      batch_events: true,
      server_render: true        # Server sends HTML
    }
  }

  def assign_profile(capabilities) do
    cond do
      capabilities.has_workers and capabilities.has_sab and capabilities.memory_mb > 2048 ->
        :full_client
      capabilities.has_workers and capabilities.memory_mb > 512 ->
        :constrained_client
      true ->
        :minimal_client
    end
  end
end
```

## Project Structure

```
laniakea/
├── server/                      # Elixir/Phoenix
│   ├── lib/laniakea/
│   │   ├── crdt/               # CRDT implementations
│   │   ├── command_bus.ex      # Typed command processing
│   │   ├── policy.ex           # Capability negotiation
│   │   └── application.ex      # OTP supervision tree
│   └── lib/laniakea_web/
│       └── channels/           # Phoenix Channels
├── client/                      # ReScript/Elm
│   ├── src/
│   │   ├── crdt/              # CRDT mirrors
│   │   ├── adapters/          # Browser feature detection
│   │   └── transport/         # Channel bindings
├── schemas/                     # Shared type definitions
├── docs/
│   ├── wiki/                   # Detailed documentation
│   ├── whitepapers/           # Papers for different audiences
│   └── comparisons/           # Framework comparisons
└── README.adoc
```

## Related Projects

- **Popcorn/AtomVM** — BEAM-in-browser via AtomVM compiled to Wasm (active, complementary)
- **Hologram** — Elixir-to-JS transpiler (active, different approach)
- **Lumen/Firefly** — BEAM-to-Wasm compiler (archived June 2024)
- **Lunatic** — Erlang-inspired Wasm runtime (semi-active, server-side)

## When Helping with This Project

### Do
- Maintain isomorphic semantics between server and client CRDTs
- Ensure CRDT operations are commutative, associative, and idempotent
- Keep capability profiles adaptable
- Consider offline scenarios in all features
- Use typed envelopes for commands/events
- Follow OTP patterns on server side

### Don't
- Assume server owns state (it's convergent)
- Ignore offline scenarios
- Skip typing (ReScript/Dialyzer are mandatory)
- Mix concerns between transport and state
- Over-engineer early phases (Phase 0 should be minimal)

### Code Style
- **Elixir**: Follow community style guide, use Dialyzer types
- **ReScript**: Prefer modules over classes, use variants for states
- **Both**: Document CRDT mathematical properties in docstrings

## Key Files to Understand

1. `server/lib/laniakea/crdt/g_counter.ex` — Reference CRDT implementation
2. `server/lib/laniakea/policy.ex` — Capability negotiation logic
3. `server/lib/laniakea_web/channels/crdt_channel.ex` — Transport layer
4. `client/src/crdt/GCounter.res` — Client-side CRDT mirror
5. `client/src/adapters/Capabilities.res` — Browser feature detection

## Glossary

- **CRDT**: Conflict-free Replicated Data Type
- **G-Counter**: Grow-only counter (increment-only)
- **PN-Counter**: Positive-Negative counter (increment/decrement)
- **OR-Set**: Observed-Remove Set
- **Delta**: Incremental CRDT update (more efficient than full state)
- **Capability Profile**: Adaptive configuration based on client features
- **Transcendent**: State that exists across nodes without central ownership
