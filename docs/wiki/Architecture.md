# Laniakea Architecture

> *Like galaxies flowing toward the Great Attractor, state in Laniakea converges toward consistency — without any node claiming to be the center.*

## Overview

Laniakea is a **transcendent architecture** for distributed web applications. "Transcendent" because state transcends any single node — it exists across the entire system, converging through CRDTs rather than being owned by a central server.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         LANIAKEA ARCHITECTURE                           │
│                                                                         │
│   ┌─────────────────┐                       ┌─────────────────┐        │
│   │  Server Node A  │◄─────── CRDT ────────►│  Server Node B  │        │
│   │   (Elixir/OTP)  │        Merge          │   (Elixir/OTP)  │        │
│   └────────┬────────┘                       └────────┬────────┘        │
│            │                                         │                  │
│            │ Phoenix Channels                        │                  │
│            │ (WebSocket/WebTransport)                │                  │
│            │                                         │                  │
│   ┌────────▼────────┐                       ┌────────▼────────┐        │
│   │  Browser Node 1 │◄─────── CRDT ────────►│  Browser Node 2 │        │
│   │   (ReScript)    │        Merge          │   (ReScript)    │        │
│   └─────────────────┘                       └─────────────────┘        │
│                                                                         │
│                    All nodes are peers.                                 │
│                    State flows and converges.                           │
│                    No single point of truth.                            │
└─────────────────────────────────────────────────────────────────────────┘
```

## Core Principles

### 1. State Convergence (The Great Attractor)

In cosmology, the Great Attractor is a gravitational anomaly pulling galaxies toward it — yet no galaxy "owns" it. Similarly, in Laniakea:

- **State converges** toward consistency across all nodes
- **No node is authoritative** — convergence happens through mathematical properties
- **CRDTs guarantee** eventual consistency without coordination

```elixir
# Two nodes modify state concurrently
node_a_counter = GCounter.increment(counter, "node_a")  # {a: 1, b: 0}
node_b_counter = GCounter.increment(counter, "node_b")  # {a: 0, b: 1}

# When they merge, both reach the same state
merged = GCounter.merge(node_a_counter, node_b_counter)  # {a: 1, b: 1}
# Order doesn't matter: merge(a, b) == merge(b, a)
```

### 2. Browser as Peer (Galaxies in the Supercluster)

Just as galaxies are full citizens of the Laniakea Supercluster, browsers are full peers in the distributed system:

| Traditional Architecture | Laniakea Architecture |
|--------------------------|----------------------|
| Server owns state | State exists everywhere |
| Browser displays data | Browser computes locally |
| Offline = broken | Offline = local operations |
| Server decides | Convergence decides |

### 3. Capability Negotiation (Polynesian Navigation)

Ancient Polynesian navigators crossed the Pacific without GPS, adapting to conditions. Laniakea clients probe their environment and adapt:

```elixir
defmodule Laniakea.Policy do
  @doc """
  Assign a capability profile based on client environment.

  Full clients get real-time updates; minimal clients get server-rendered HTML.
  The system adapts rather than failing.
  """
  def assign_profile(capabilities) do
    cond do
      # Modern browser with good connectivity
      capabilities.has_workers and
      capabilities.has_sab and
      capabilities.memory_mb > 2048 and
      capabilities.connection_type in [:wifi, :ethernet] ->
        :full_client

      # Capable but constrained
      capabilities.has_workers and
      capabilities.memory_mb > 512 ->
        :constrained_client

      # Minimal capabilities (old browser, poor connection)
      true ->
        :minimal_client
    end
  end
end
```

### 4. Offline-First (Zone of Avoidance)

The Zone of Avoidance is a region of space obscured by the Milky Way's dust — we can't see through it, but we know the universe continues beyond. Network failures are Laniakea's Zone of Avoidance:

- Operations continue locally during partition
- State merges when connectivity returns
- No special "offline mode" — it's just how the system works

```rescript
// User increments counter while offline
let handleIncrement = () => {
  // Immediate local update
  let newCounter = GCounter.increment(state.counter, myNodeId)
  setState(_ => {...state, counter: newCounter})

  // Queue for sync when online
  OfflineQueue.enqueue({type: "increment", nodeId: myNodeId})
}

// When reconnected, merge with server state
let onReconnect = serverState => {
  setState(s => {
    ...s,
    counter: GCounter.merge(s.counter, serverState.counter)
  })
}
```

## Component Architecture

### Server Layer (Elixir/Phoenix)

```
┌────────────────────────────────────────────────────────────┐
│                     SERVER LAYER                           │
│                                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ CRDT Registry│  │ Command Bus  │  │   Policy     │    │
│  │              │  │              │  │              │    │
│  │ - G-Counter  │  │ - Validate   │  │ - Profile    │    │
│  │ - PN-Counter │  │ - Execute    │  │ - Throttle   │    │
│  │ - OR-Set     │  │ - Broadcast  │  │ - Batch      │    │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │
│         │                 │                 │             │
│         └─────────────────┼─────────────────┘             │
│                           │                               │
│                  ┌────────▼────────┐                      │
│                  │ Phoenix Channel │                      │
│                  │                 │                      │
│                  │ - Subscribe     │                      │
│                  │ - Receive       │                      │
│                  │ - Broadcast     │                      │
│                  └────────┬────────┘                      │
│                           │                               │
└───────────────────────────┼───────────────────────────────┘
                            │ WebSocket / WebTransport
                            ▼
```

#### CRDT Registry

Manages all CRDT instances. Each CRDT is identified by a key and can be accessed, modified, and merged.

```elixir
defmodule Laniakea.CRDT.Registry do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def update(key, fun) do
    GenServer.call(__MODULE__, {:update, key, fun})
  end

  def merge(key, remote_crdt) do
    GenServer.call(__MODULE__, {:merge, key, remote_crdt})
  end

  # GenServer callbacks...
end
```

#### Command Bus

Processes typed commands from clients. Commands are validated, executed, and may trigger events.

```elixir
defmodule Laniakea.CommandBus do
  @type command :: %{
    type: String.t(),
    payload: map(),
    request_id: String.t(),
    timestamp: integer()
  }

  def handle(%{type: "crdt.increment"} = cmd, socket) do
    with :ok <- validate(cmd),
         {:ok, new_state} <- execute(cmd),
         :ok <- broadcast(socket, new_state) do
      {:ok, new_state}
    end
  end
end
```

#### Policy Engine

Adapts server behavior based on client capabilities.

```elixir
defmodule Laniakea.Policy do
  @profiles %{
    full_client: %{
      update_frequency_ms: 16,    # ~60fps
      batch_events: false,
      delta_sync: true,
      server_render: false
    },
    constrained_client: %{
      update_frequency_ms: 100,   # ~10fps
      batch_events: true,
      delta_sync: true,
      server_render: false
    },
    minimal_client: %{
      update_frequency_ms: 1000,  # ~1fps
      batch_events: true,
      delta_sync: false,          # Full state sync
      server_render: true         # Server renders HTML
    }
  }
end
```

### Client Layer (ReScript/Elm)

```
┌────────────────────────────────────────────────────────────┐
│                     CLIENT LAYER                           │
│                                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ CRDT Mirror  │  │  Capability  │  │  Transport   │    │
│  │              │  │    Probe     │  │              │    │
│  │ - G-Counter  │  │              │  │ - Channel    │    │
│  │ - PN-Counter │  │ - Workers    │  │ - Reconnect  │    │
│  │ - OR-Set     │  │ - SAB        │  │ - Offline Q  │    │
│  └──────┬───────┘  │ - Memory     │  └──────┬───────┘    │
│         │          │ - Network    │         │             │
│         │          └──────┬───────┘         │             │
│         │                 │                 │             │
│         └─────────────────┼─────────────────┘             │
│                           │                               │
│                  ┌────────▼────────┐                      │
│                  │   Application   │                      │
│                  │                 │                      │
│                  │ - State (CRDTs) │                      │
│                  │ - UI Rendering  │                      │
│                  │ - Event Handler │                      │
│                  └─────────────────┘                      │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

#### CRDT Mirror

Client-side CRDT implementations with identical semantics to server:

```rescript
module GCounter = {
  type t = {
    counts: Map.String.t<int>,
    version: int,
  }

  let empty = {counts: Map.String.empty, version: 0}

  let increment = (counter, nodeId) => {
    let current = counter.counts->Map.String.get(nodeId)->Option.getOr(0)
    {
      counts: counter.counts->Map.String.set(nodeId, current + 1),
      version: counter.version + 1,
    }
  }

  let merge = (a, b) => {
    // Commutative: merge(a, b) == merge(b, a)
    // Associative: merge(merge(a, b), c) == merge(a, merge(b, c))
    // Idempotent: merge(a, a) == a
    let allNodes = Set.String.union(
      a.counts->Map.String.keysToArray->Set.String.fromArray,
      b.counts->Map.String.keysToArray->Set.String.fromArray,
    )
    let merged = allNodes->Set.String.reduce(Map.String.empty, (acc, node) => {
      let countA = a.counts->Map.String.get(node)->Option.getOr(0)
      let countB = b.counts->Map.String.get(node)->Option.getOr(0)
      acc->Map.String.set(node, max(countA, countB))
    })
    {counts: merged, version: max(a.version, b.version) + 1}
  }

  let value = counter => {
    counter.counts->Map.String.valuesToArray->Array.reduce(0, (a, b) => a + b)
  }
}
```

#### Capability Probe

Detects browser capabilities for profile negotiation:

```rescript
module Capabilities = {
  type t = {
    hasWorkers: bool,
    hasSharedArrayBuffer: bool,
    hasWebTransport: bool,
    memoryMb: int,
    connectionType: [#wifi | #cellular | #ethernet | #unknown],
    effectiveType: [#slow2g | #_2g | #_3g | #_4g],
  }

  let probe = (): t => {
    hasWorkers: %raw(`typeof Worker !== 'undefined'`),
    hasSharedArrayBuffer: %raw(`typeof SharedArrayBuffer !== 'undefined'`),
    hasWebTransport: %raw(`typeof WebTransport !== 'undefined'`),
    memoryMb: %raw(`navigator.deviceMemory ? navigator.deviceMemory * 1024 : 2048`),
    connectionType: getConnectionType(),
    effectiveType: getEffectiveType(),
  }
}
```

### Transport Layer

The transport layer handles communication between nodes:

```
┌─────────────────────────────────────────────────────────────┐
│                    TRANSPORT LAYER                          │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Transport Coordinator                   │   │
│  │                                                     │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │   │
│  │  │  WebSocket  │  │WebTransport │  │    QUIC     │ │   │
│  │  │  (Phase 0)  │  │  (Phase 2)  │  │  (Future)   │ │   │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘ │   │
│  │         │                │                │        │   │
│  │         └────────────────┼────────────────┘        │   │
│  │                          │                         │   │
│  │                  ┌───────▼───────┐                 │   │
│  │                  │  Hedging /    │                 │   │
│  │                  │  Fallback     │                 │   │
│  │                  └───────────────┘                 │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Transport Hedging** (Phase 2): Race multiple transports, use fastest available:

```elixir
defmodule Laniakea.Transport.Coordinator do
  @doc """
  Attempt connection with multiple transports.
  First successful connection wins.
  Fall back to more reliable transport if preferred fails.
  """
  def connect(opts) do
    transports = [
      {Laniakea.Transport.WebTransport, priority: 1},
      {Laniakea.Transport.WebSocket, priority: 2}
    ]

    # Race transports, use first successful
    transports
    |> Enum.sort_by(& &1.priority)
    |> Enum.reduce_while(:no_connection, fn {transport, _}, _ ->
      case transport.connect(opts) do
        {:ok, conn} -> {:halt, {:ok, conn}}
        {:error, _} -> {:cont, :no_connection}
      end
    end)
  end
end
```

## Data Flow

### Command Flow (Client → Server)

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  User    │───►│  Local   │───►│Transport │───►│  Server  │
│  Action  │    │  CRDT    │    │  Layer   │    │CommandBus│
└──────────┘    └──────────┘    └──────────┘    └──────────┘
                     │                               │
                     │                               ▼
                     │                          ┌──────────┐
                     │                          │  CRDT    │
                     │                          │ Registry │
                     │                          └──────────┘
                     │                               │
                     ▼                               ▼
               Immediate                       Broadcast
               UI Update                       to all clients
```

1. User clicks "increment"
2. Local CRDT is updated immediately (optimistic)
3. Command is sent to server via transport
4. Server validates and processes command
5. Server updates CRDT registry
6. Server broadcasts updated state to all connected clients

### Sync Flow (Server → Client)

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Server  │───►│Transport │───►│  Client  │───►│  Merge   │
│Broadcast │    │  Layer   │    │ Receives │    │  CRDTs   │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
                                                     │
                                                     ▼
                                               ┌──────────┐
                                               │UI Update │
                                               └──────────┘
```

### Offline / Reconnect Flow

```
┌──────────────────────────────────────────────────────────────┐
│                     OFFLINE OPERATION                        │
│                                                              │
│   1. User performs action while offline                      │
│   2. Local CRDT updates immediately                          │
│   3. Command queued in offline outbox                        │
│                                                              │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐             │
│   │  Action  │───►│  Local   │───►│ Offline  │             │
│   │          │    │  CRDT    │    │  Queue   │             │
│   └──────────┘    └──────────┘    └──────────┘             │
│                                                              │
└──────────────────────────────────────────────────────────────┘

                    ┌──────────────────┐
                    │ Network Returns  │
                    └────────┬─────────┘
                             │
                             ▼

┌──────────────────────────────────────────────────────────────┐
│                     RECONNECTION                             │
│                                                              │
│   1. Flush offline queue to server                           │
│   2. Receive server state                                    │
│   3. Merge server state with local state                     │
│   4. UI reflects converged state                             │
│                                                              │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐             │
│   │  Queue   │───►│  Server  │───►│  Merge   │──► UI       │
│   │  Flush   │    │  State   │    │  CRDTs   │             │
│   └──────────┘    └──────────┘    └──────────┘             │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Supervision Tree (Server)

```elixir
defmodule Laniakea.Application do
  use Application

  def start(_type, _args) do
    children = [
      # CRDT state registry
      {Laniakea.CRDT.Registry, name: Laniakea.CRDT.Registry},

      # Command processing
      {Laniakea.CommandBus, name: Laniakea.CommandBus},

      # Phoenix endpoint (channels)
      LaniakeaWeb.Endpoint,

      # Telemetry (observability)
      {Laniakea.Telemetry, name: Laniakea.Telemetry}
    ]

    opts = [strategy: :one_for_one, name: Laniakea.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## Future: Browser Supervision (Phase 4)

When running BEAM in browser (via Popcorn/AtomVM or Zig runtime):

```
┌─────────────────────────────────────────────────────────────┐
│                  BROWSER SUPERVISION TREE                   │
│                                                             │
│                    ┌─────────────┐                          │
│                    │  Browser    │                          │
│                    │ Supervisor  │                          │
│                    └──────┬──────┘                          │
│                           │                                 │
│           ┌───────────────┼───────────────┐                │
│           │               │               │                │
│     ┌─────▼─────┐  ┌──────▼─────┐  ┌─────▼─────┐         │
│     │   CRDT    │  │ Transport  │  │    UI     │         │
│     │ Supervisor│  │ Supervisor │  │ Supervisor│         │
│     └─────┬─────┘  └──────┬─────┘  └─────┬─────┘         │
│           │               │               │                │
│     ┌─────▼─────┐  ┌──────▼─────┐  ┌─────▼─────┐         │
│     │ G-Counter │  │  Channel   │  │ Component │         │
│     │  Process  │  │  Process   │  │  Process  │         │
│     └───────────┘  └────────────┘  └───────────┘         │
│                                                             │
│     If any process crashes, supervisor restarts it.        │
│     Browser has same fault tolerance as server.            │
└─────────────────────────────────────────────────────────────┘
```

---

## Summary

Laniakea's architecture is built on three insights:

1. **State should converge, not be owned** — CRDTs make this mathematically guaranteed
2. **Browsers are capable compute nodes** — They deserve to be peers, not terminals
3. **Network failure is normal** — Design for partition, not against it

The result is an architecture that:
- Works offline by default
- Handles conflicts automatically
- Adapts to client capabilities
- Scales from mobile to desktop to server
- Provides the fault tolerance of OTP in every node

*Like the galaxies of our supercluster, nodes in Laniakea don't need to see each other to flow toward the same destination. The math ensures they'll arrive together.*
