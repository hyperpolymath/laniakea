# Laniakea: Distributed State Architecture for Modern Web Applications

**Industry Whitepaper v1.0**

*Building offline-first, real-time collaborative applications with CRDT-based state convergence*

---

## Executive Summary

Modern web applications face a fundamental architectural tension: users expect real-time collaboration, offline functionality, and instant responsiveness — but traditional client-server architectures treat browsers as dumb terminals that must request everything from an authoritative server.

**Laniakea** is a new architectural approach that treats browsers as peer nodes in a distributed system. Using Conflict-free Replicated Data Types (CRDTs), Phoenix Channels, and capability-based adaptation, Laniakea enables:

- **Offline-first operation** — Applications work without network connectivity
- **Real-time collaboration** — Multiple users edit simultaneously without conflicts
- **Automatic conflict resolution** — No manual merge logic required
- **Adaptive performance** — System adjusts to client capabilities
- **Fault tolerance** — OTP supervision patterns everywhere

This whitepaper explains the architecture, implementation approach, and business value of Laniakea for engineering teams building the next generation of web applications.

---

## The Problem with Traditional Architecture

### The Server-Owns-Truth Model

```
┌──────────────┐                    ┌──────────────┐
│    Server    │◄───── Request ─────│   Browser    │
│  (authority) │────── Response ───►│  (terminal)  │
└──────────────┘                    └──────────────┘
```

Every mainstream web framework — React, Next.js, Angular, Vue — assumes this model:

1. Server holds authoritative state
2. Client requests state via API
3. Client renders received state
4. User actions send mutations to server
5. Server validates and updates state
6. Server pushes updates to other clients

This model has critical limitations:

| Limitation | Impact |
|------------|--------|
| **Network dependency** | Offline = broken application |
| **Latency** | Every action requires round-trip |
| **Conflict handling** | Manual implementation required |
| **Server load** | All computation happens server-side |
| **Complexity** | Optimistic updates are hard to get right |

### Real-World Costs

**Figma** spent years building custom CRDT infrastructure to enable real-time collaboration. **Linear** invested heavily in offline-first architecture. **Notion** rebuilt their sync layer multiple times.

These companies solved the problem with significant engineering investment. Most teams lack these resources and settle for degraded user experiences.

---

## The Laniakea Solution

### Browser as Peer Node

```
┌──────────────┐                    ┌──────────────┐
│ Server Node  │◄──── CRDTs ───────►│ Browser Node │
│  (has state) │◄──── Merge ───────►│  (has state) │
└──────────────┘                    └──────────────┘
```

Laniakea inverts the traditional model:

1. **State exists on all nodes** — Server and browser both have complete state
2. **Operations are local** — User actions update local state immediately
3. **Sync is eventual** — Changes propagate and merge automatically
4. **Conflicts resolve mathematically** — CRDTs guarantee convergence

### Core Components

#### 1. CRDT State Layer

All application state is stored in CRDTs — data structures that automatically merge without conflicts:

```elixir
# Server: G-Counter for likes
counter = GCounter.new()
counter = GCounter.increment(counter, "user_123")
# => %{counts: %{"user_123" => 1}, value: 1}
```

```javascript
// Client: Identical semantics
const counter = GCounter.increment(state.counter, "user_123")
// => {counts: {"user_123": 1}, value: 1}
```

When server and client have different states:

```
Server: {counts: {"alice": 3, "bob": 2}}  // value: 5
Client: {counts: {"alice": 2, "bob": 5}}  // value: 7

After merge:
Both:   {counts: {"alice": 3, "bob": 5}}  // value: 8
```

No conflicts. No manual resolution. Mathematically guaranteed convergence.

#### 2. Phoenix Channel Transport

Real-time bidirectional communication via Phoenix Channels:

```elixir
defmodule MyApp.CounterChannel do
  use Phoenix.Channel

  def join("counter:" <> id, _params, socket) do
    counter = CounterRegistry.get(id)
    {:ok, %{state: GCounter.to_map(counter)}, socket}
  end

  def handle_in("increment", %{"node_id" => node_id}, socket) do
    counter = CounterRegistry.update(socket.assigns.counter_id, fn c ->
      GCounter.increment(c, node_id)
    end)
    broadcast!(socket, "state_updated", GCounter.to_map(counter))
    {:noreply, socket}
  end
end
```

#### 3. Capability Negotiation

Clients declare their capabilities; server adapts behavior:

```elixir
def assign_profile(capabilities) do
  cond do
    # High-end device, good connection
    capabilities.has_workers and capabilities.memory_mb > 2048 ->
      %{update_frequency: 16, batch_events: false, delta_sync: true}

    # Mid-range device
    capabilities.has_workers ->
      %{update_frequency: 100, batch_events: true, delta_sync: true}

    # Low-end device
    true ->
      %{update_frequency: 1000, batch_events: true, server_render: true}
  end
end
```

Low-end clients automatically get batched updates and server-rendered HTML. High-end clients get real-time deltas at 60fps. Same codebase, adaptive performance.

---

## Implementation Architecture

### Server Stack (Elixir/Phoenix)

```
┌────────────────────────────────────────────────────────────┐
│                     ELIXIR SERVER                          │
│                                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ CRDT Registry│  │ Command Bus  │  │   Policy     │    │
│  │  (GenServer) │  │  (Validate/  │  │  (Adaptive)  │    │
│  │              │  │   Execute)   │  │              │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                            │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              Phoenix Channels                        │  │
│  │  - WebSocket (universal)                            │  │
│  │  - WebTransport (where available)                   │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              OTP Supervision                         │  │
│  │  - Automatic restart on failure                     │  │
│  │  - Isolated failure domains                         │  │
│  │  - Graceful degradation                             │  │
│  └─────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

### Client Stack (ReScript/TypeScript)

```
┌────────────────────────────────────────────────────────────┐
│                    BROWSER CLIENT                          │
│                                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ CRDT Mirror  │  │  Capability  │  │   Offline    │    │
│  │  (Isomorphic │  │    Probe     │  │    Queue     │    │
│  │   with server│  │              │  │              │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                            │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              Transport Layer                         │  │
│  │  - Phoenix Channel client                           │  │
│  │  - Automatic reconnection                           │  │
│  │  - Offline detection                                │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              UI Framework                            │  │
│  │  - ReScript/React or Elm                            │  │
│  │  - Declarative rendering                            │  │
│  │  - Type-safe state management                       │  │
│  └─────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

### Data Flow

```
User Action → Local CRDT Update → UI Update (instant)
                    ↓
              Transport Layer
                    ↓
            Server Processing → Broadcast to Other Clients
                    ↓
              CRDT Merge → UI Update (all clients converge)
```

---

## Business Value

### Reduced Development Time

| Traditional Approach | Laniakea |
|---------------------|----------|
| Build optimistic updates manually | Automatic (CRDTs) |
| Implement offline mode | Built-in |
| Write conflict resolution | Mathematical guarantee |
| Handle reconnection logic | Framework handles it |
| Build real-time sync | Phoenix Channels |

**Estimated savings**: 40-60% reduction in sync/state logic development time.

### Improved User Experience

| Metric | Traditional | Laniakea |
|--------|-------------|----------|
| Action latency | 100-500ms (RTT) | <10ms (local) |
| Offline capability | Degraded/broken | Full functionality |
| Conflict resolution | Manual/confusing | Automatic/invisible |
| Multi-device sync | Complex | Built-in |

### Operational Benefits

| Aspect | Impact |
|--------|--------|
| **Server load** | Reduced — clients do local computation |
| **Bandwidth** | Reduced — delta sync instead of full state |
| **Fault tolerance** | OTP supervision ensures recovery |
| **Scalability** | BEAM handles millions of connections |

---

## Comparison with Alternatives

### vs React/Next.js + Custom Sync

| Aspect | React/Next.js | Laniakea |
|--------|---------------|----------|
| Offline support | Manual implementation | Built-in |
| Conflict resolution | Manual implementation | Automatic (CRDTs) |
| Real-time sync | Add WebSocket + logic | Phoenix Channels |
| Type safety | Optional (TypeScript) | Mandatory (ReScript) |
| Server framework | Separate choice | Integrated (Phoenix) |

### vs Firebase/Supabase

| Aspect | Firebase/Supabase | Laniakea |
|--------|-------------------|----------|
| Vendor lock-in | High | None (self-hosted) |
| Offline support | Limited | Full CRDT support |
| Conflict resolution | Last-write-wins | Automatic merge |
| Customization | Limited | Full control |
| Cost at scale | Can be expensive | Infrastructure cost only |

### vs Phoenix LiveView

| Aspect | LiveView | Laniakea |
|--------|----------|----------|
| Offline support | None | Full |
| Client computation | Server does all | Distributed |
| Latency sensitivity | High (all actions RTT) | Low (local ops) |
| State ownership | Server | Convergent |

---

## Getting Started

### Prerequisites

- Elixir 1.15+
- Node.js 18+
- PostgreSQL (optional, for persistence)

### Quick Start

```bash
# Clone and setup
git clone https://github.com/laniakea/laniakea-starter.git
cd laniakea-starter

# Server
cd server && mix deps.get && mix phx.server

# Client (new terminal)
cd client && npm install && npm run dev

# Open http://localhost:5173 in multiple tabs
```

### Next Steps

1. **Read the architecture guide** — Understand the patterns
2. **Study the CRDT catalog** — Choose appropriate data structures
3. **Build a prototype** — Start with the counter demo
4. **Integrate gradually** — Laniakea can coexist with existing code

---

## Roadmap

| Phase | Timeline | Features |
|-------|----------|----------|
| **Phase 0** | Now | G-Counter, Phoenix Channels, capability negotiation |
| **Phase 1** | Q1 2025 | Delta sync, more CRDTs, typed envelopes |
| **Phase 2** | Q2 2025 | WebTransport, observability |
| **Phase 3** | Q3 2025 | Browser runtime (Popcorn/AtomVM) |
| **Phase 4** | 2026 | Full BEAM-in-browser |

---

## Conclusion

The web is ready for a new architectural paradigm. Users expect real-time, offline-capable, conflict-free applications. Traditional client-server architectures can't deliver this without significant custom engineering.

Laniakea provides a principled foundation for building these applications:

- **CRDTs** for automatic conflict resolution
- **Phoenix** for scalable real-time communication
- **OTP** for fault tolerance
- **Capability negotiation** for adaptive performance

The browser is no longer a dumb terminal. It's a peer node in a distributed system. Laniakea makes this vision practical.

---

## Resources

- **Documentation**: https://laniakea.dev/docs
- **GitHub**: https://github.com/laniakea/laniakea
- **Discord**: https://discord.gg/laniakea
- **Examples**: https://github.com/laniakea/examples

---

*Laniakea — Distributed state finds its way home.*
