# Elm vs Next.js vs React: Comprehensive Comparison

## Overview

This document provides an exhaustive comparison of Elm, Next.js, and React — and explains why Laniakea takes a fundamentally different approach that transcends all three.

## Executive Summary

| Aspect | Elm | React | Next.js | **Laniakea** |
|--------|-----|-------|---------|--------------|
| **Type** | Functional language | UI library | React framework | Distributed architecture |
| **Philosophy** | Correctness via types | Components + hooks | Full-stack React | Browser as BEAM peer |
| **State** | Centralized (Model) | Component/global | Server + client | CRDT convergence |
| **Offline** | Manual | Manual | Manual | Built-in (CRDTs) |

---

## Detailed Comparison Table

### Core Identity

| Aspect | Elm | React | Next.js |
|--------|-----|-------|---------|
| **Type** | Functional programming language | JavaScript UI library | Full-stack React framework |
| **Created by** | Evan Czaplicki (2012) | Meta/Facebook (2013) | Vercel (2016) |
| **License** | BSD-3-Clause | MIT | MIT |
| **Primary goal** | No runtime exceptions | Declarative UI components | Production React apps |
| **Paradigm** | Pure functional | Functional-ish (hooks) | Hybrid (SSR + CSR) |

### Language & Type System

| Aspect | Elm | React | Next.js |
|--------|-----|-------|---------|
| **Language** | Elm (custom) | JavaScript/TypeScript | JavaScript/TypeScript |
| **Type system** | Hindley-Milner (sound) | Optional (TypeScript) | Optional (TypeScript) |
| **Null safety** | No null/undefined | Runtime nulls | Runtime nulls |
| **Type inference** | Full | Partial (TS) | Partial (TS) |
| **Compile-time guarantees** | Strong | Weak-moderate | Weak-moderate |
| **Runtime exceptions** | Impossible* | Common | Common |

*Elm guarantees no runtime exceptions in pure Elm code; JS interop can introduce them.

### Architecture

| Aspect | Elm | React | Next.js |
|--------|-----|-------|---------|
| **Architecture pattern** | The Elm Architecture (TEA) | Component-based | Pages + App Router |
| **State management** | Single Model | useState/useReducer/Redux/etc. | React state + Server state |
| **Data flow** | Unidirectional | Unidirectional (recommended) | Bidirectional (Server Actions) |
| **Side effects** | Cmd/Sub (managed) | useEffect (unmanaged) | useEffect + Server Actions |
| **Rendering** | Virtual DOM | Virtual DOM (Fiber) | SSR + CSR + ISR + SSG |

### Development Experience

| Aspect | Elm | React | Next.js |
|--------|-----|-------|---------|
| **Learning curve** | Steep (new language) | Moderate | Moderate-steep |
| **Error messages** | Exceptional (famous for quality) | Variable (depends on tooling) | Variable |
| **Debugging** | Time-travel debugger | React DevTools | React DevTools + Next.js tools |
| **Hot reload** | Yes (elm-live) | Yes (Fast Refresh) | Yes (Fast Refresh) |
| **IDE support** | Good (elm-language-server) | Excellent | Excellent |
| **Build tooling** | elm make (simple) | Webpack/Vite/etc. | Built-in (Turbopack) |

### Performance

| Aspect | Elm | React | Next.js |
|--------|-----|-------|---------|
| **Bundle size** | Small (~29KB gzipped) | ~42KB (React + ReactDOM) | Varies (includes React) |
| **Virtual DOM** | Custom (fast) | Fiber (optimized) | Fiber (optimized) |
| **SSR** | Limited | Via frameworks | Native |
| **Code splitting** | Manual | Via bundler | Automatic |
| **Tree shaking** | Excellent (dead code elimination) | Good | Good |

### Ecosystem

| Aspect | Elm | React | Next.js |
|--------|-----|-------|---------|
| **Package manager** | elm packages | npm/yarn/pnpm | npm/yarn/pnpm |
| **Package count** | ~1,500 | ~2,000,000+ | React ecosystem |
| **UI libraries** | elm-ui, elm-css | Material-UI, Chakra, etc. | All React libraries |
| **Testing** | elm-test | Jest, Testing Library | Jest, Playwright |
| **Community size** | Small but dedicated | Massive | Large |
| **Job market** | Niche | Huge | Large |

### Real-time & Offline

| Aspect | Elm | React | Next.js |
|--------|-----|-------|---------|
| **WebSocket support** | Via ports | Via libraries | Via libraries |
| **Real-time updates** | Manual implementation | Manual implementation | Manual implementation |
| **Offline support** | Manual (Service Workers) | Manual (Service Workers) | Manual (Service Workers) |
| **State sync** | Not built-in | Not built-in | Not built-in |
| **Optimistic updates** | Manual | Manual (TanStack Query, SWR) | Server Actions (partial) |

### Server Integration

| Aspect | Elm | React | Next.js |
|--------|-----|-------|---------|
| **Server rendering** | Limited (elm-pages) | Via frameworks | Native SSR/SSG/ISR |
| **API routes** | None (frontend only) | None (frontend only) | Built-in |
| **Database access** | Via API calls | Via API calls | Direct (Server Components) |
| **Full-stack** | No | No | Yes |
| **Edge runtime** | No | Via frameworks | Native |

### Error Handling

| Aspect | Elm | React | Next.js |
|--------|-----|-------|---------|
| **Approach** | Maybe/Result types | try/catch + Error Boundaries | try/catch + Error Boundaries |
| **Unhandled errors** | Compiler prevents | Runtime crash | Runtime crash |
| **Error boundaries** | Not needed | Component-level | Component-level |
| **Partial failures** | Type-safe handling | Manual handling | Manual handling |

---

## Pros and Cons

### Elm

#### Pros
- **No runtime exceptions** — Compiler catches all errors
- **Excellent error messages** — Best-in-class developer experience
- **Enforced architecture** — TEA provides consistency
- **Refactoring confidence** — Types guarantee correctness
- **Small bundles** — Aggressive dead code elimination
- **Time-travel debugging** — Built into the language

#### Cons
- **Learning curve** — New language, new paradigm
- **JS interop friction** — Ports add complexity
- **Small ecosystem** — Fewer packages, smaller community
- **Limited SSR** — Not designed for server rendering
- **Job market** — Few production deployments
- **Elm 0.19 stagnation** — Slow language evolution

### React

#### Pros
- **Massive ecosystem** — Library for everything
- **Job market** — Abundant opportunities
- **Flexibility** — Use any state management, styling, etc.
- **Community** — Extensive resources, tutorials, support
- **Meta backing** — Well-funded, active development
- **Incremental adoption** — Can be added to existing apps

#### Cons
- **Decision fatigue** — Too many choices
- **Runtime errors** — No compile-time safety guarantees
- **Bundle size** — Can grow large with dependencies
- **Complexity creep** — useEffect foot-guns
- **Breaking changes** — Class → Hooks → Server Components
- **No architecture** — Teams must establish patterns

### Next.js

#### Pros
- **Full-stack** — Frontend + backend in one
- **Performance** — SSR, SSG, ISR, edge runtime
- **DX** — Great tooling, fast refresh
- **Vercel integration** — Seamless deployment
- **File-based routing** — Intuitive page structure
- **React Server Components** — Reduced client JS

#### Cons
- **Vendor lock-in risk** — Optimized for Vercel
- **Complexity** — Many rendering modes to understand
- **App Router learning curve** — Significant paradigm shift
- **Bundle size** — Can be heavy
- **Upgrade churn** — Frequent breaking changes
- **Not truly offline** — Still requires server for many features

---

## Why Laniakea Transcends All Three

The comparison above highlights a fundamental limitation shared by Elm, React, and Next.js:

**They all treat the browser as a client that requests state from a server.**

### The Traditional Model

```
┌──────────────┐                    ┌──────────────┐
│    Server    │◄───── Request ─────│   Browser    │
│  (owns state)│────── Response ───►│  (displays)  │
└──────────────┘                    └──────────────┘
                  Server owns truth.
                  Browser is a terminal.
```

### The Laniakea Model

```
┌──────────────┐                    ┌──────────────┐
│ Server Node  │◄──── CRDTs ───────►│ Browser Node │
│  (has state) │◄──── Merge ───────►│  (has state) │
└──────────────┘                    └──────────────┘
                  State converges.
                  Both are peers.
```

### Comparison: Traditional vs Laniakea

| Aspect | Elm/React/Next.js | Laniakea |
|--------|-------------------|----------|
| **State ownership** | Server owns | State converges |
| **Browser role** | Display terminal | Distributed peer |
| **Offline behavior** | Broken/degraded | Full local operations |
| **Conflict resolution** | Manual/optimistic | CRDTs (automatic) |
| **Architecture** | Client-server | Distributed cluster |
| **Real-time sync** | Manual WebSocket | Built-in (Phoenix Channels) |
| **Error handling** | Try/catch | Supervision trees |
| **Concurrency** | Single-threaded | BEAM processes |

### What Each Framework Gets Right (and Laniakea Incorporates)

| Framework | Insight | Laniakea Adoption |
|-----------|---------|-------------------|
| **Elm** | Type safety prevents errors | ReScript (sound types) on client |
| **Elm** | Managed side effects | Command bus with typed envelopes |
| **Elm** | Unidirectional data flow | CRDT operations are immutable |
| **React** | Declarative UI | ReScript JSX / Elm-like rendering |
| **React** | Component composition | Modular CRDT + UI components |
| **Next.js** | Server rendering | Capability-based server rendering fallback |
| **Next.js** | Edge deployment | BEAM nodes at edge |

### Why Not Just Use [Framework] + [Library]?

You could try to bolt CRDTs and offline support onto Elm, React, or Next.js:

- **Elm + Automerge**: Possible but awkward (Elm → JS interop → Automerge)
- **React + Yjs**: Works but no server convergence story
- **Next.js + custom CRDTs**: Possible but fights the framework

Laniakea is designed from the ground up for distributed state convergence. The architecture assumes:

1. State exists on multiple nodes
2. Nodes can be offline
3. State will eventually converge
4. Neither side is authoritative

This is fundamentally different from "add offline support to a client-server app."

---

## Decision Framework

### Choose Elm When:
- You prioritize correctness above all else
- Your team can invest in learning a new language
- You don't need SSR or complex server integration
- You want guaranteed no runtime exceptions
- You're building a SPA with clear boundaries

### Choose React When:
- You need maximum ecosystem/hiring flexibility
- You're incrementally adding interactivity to existing apps
- Your team knows JavaScript/TypeScript
- You need specific libraries only available in React
- You want the most options for every decision

### Choose Next.js When:
- You need full-stack in one framework
- SEO and initial load performance are critical
- You want built-in SSR/SSG/ISR
- You're okay with Vercel's direction
- You want a "batteries included" React experience

### Choose Laniakea When:
- **Offline-first is a requirement, not an afterthought**
- **Real-time collaboration is core to your app**
- **You want the browser to be a true peer, not a terminal**
- **You value BEAM's supervision and fault tolerance**
- **You're building the next Figma, Linear, or Notion**

---

## Technical Deep Dive: State Management Comparison

### Elm: The Elm Architecture

```elm
-- Model (centralized state)
type alias Model = { count : Int }

-- Msg (all possible events)
type Msg = Increment | Decrement

-- Update (pure state transitions)
update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        Increment -> ({ model | count = model.count + 1 }, Cmd.none)
        Decrement -> ({ model | count = model.count - 1 }, Cmd.none)

-- View (pure rendering)
view : Model -> Html Msg
view model =
    div []
        [ button [ onClick Decrement ] [ text "-" ]
        , text (String.fromInt model.count)
        , button [ onClick Increment ] [ text "+" ]
        ]
```

**Pros**: Predictable, debuggable, type-safe
**Cons**: All state is local; no built-in sync

### React: Hooks + Context

```jsx
// State (local or lifted)
const [count, setCount] = useState(0);

// Event handlers (side effects mixed with state)
const increment = () => setCount(c => c + 1);
const decrement = () => setCount(c => c - 1);

// Render
return (
  <div>
    <button onClick={decrement}>-</button>
    <span>{count}</span>
    <button onClick={increment}>+</button>
  </div>
);
```

**Pros**: Familiar, flexible
**Cons**: Side effects can be anywhere; no sync

### Next.js: Server Actions

```jsx
// Server Action
async function increment() {
  'use server';
  await db.counter.increment();
  revalidatePath('/');
}

// Client Component
export default function Counter({ count }) {
  return (
    <form action={increment}>
      <span>{count}</span>
      <button type="submit">+</button>
    </form>
  );
}
```

**Pros**: Server state automatically synced
**Cons**: Requires server; no offline; optimistic updates are manual

### Laniakea: CRDT Convergence

```elixir
# Server (Elixir)
def handle_in("increment", %{"node_id" => node_id}, socket) do
  counter = Registry.get(:counter)
  new_counter = GCounter.increment(counter, node_id)
  Registry.put(:counter, new_counter)
  broadcast!(socket, "state_updated", GCounter.to_map(new_counter))
  {:noreply, socket}
end
```

```rescript
// Client (ReScript)
let increment = (counter, nodeId) => {
  let newCounter = GCounter.increment(counter, nodeId)
  // Local state updates immediately
  setState(_ => newCounter)
  // Async sync to server
  Channel.push("increment", {"node_id": nodeId})
}

// On reconnect, merge states
let onStateReceived = serverState => {
  setState(localState => GCounter.merge(localState, serverState))
}
```

**Pros**: Works offline; automatic conflict resolution; local-first
**Cons**: CRDTs have constraints (not all operations are CRDT-able)

---

## Conclusion

Elm, React, and Next.js are all excellent tools for their intended purposes:

- **Elm** excels at bulletproof SPAs
- **React** excels at flexible UI composition
- **Next.js** excels at full-stack React applications

But they all share a fundamental assumption: **the server owns truth**.

Laniakea challenges this assumption. By treating the browser as a peer node in a distributed system, using CRDTs for conflict-free state convergence, and building on BEAM's proven distributed systems foundation, Laniakea enables a new class of applications:

- **Collaborative editing** (like Figma, but with supervision trees)
- **Offline-first apps** (that actually work offline)
- **Real-time systems** (with proper backpressure and fault tolerance)
- **Edge-native applications** (where "edge" includes the browser)

The future isn't about picking the best client framework. It's about recognizing that the browser is a capable compute node that deserves to participate in distributed systems as a first-class citizen.

---

## Further Reading

- [CRDTs: The Hard Parts](https://martin.kleppmann.com/2020/07/06/crdt-hard-parts-hydra.html) — Martin Kleppmann
- [Local-First Software](https://www.inkandswitch.com/local-first/) — Ink & Switch
- [The Elm Architecture](https://guide.elm-lang.org/architecture/) — Elm Guide
- [Why Phoenix](https://www.phoenixframework.org/) — Phoenix Framework
- [Popcorn: Elixir in the Browser](https://popcorn.swmansion.com/) — Software Mansion
