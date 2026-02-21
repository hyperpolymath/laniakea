<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- TOPOLOGY.md — Project architecture map and completion dashboard -->
<!-- Last updated: 2026-02-19 -->

# Laniakea — Project Topology

## System Architecture

```
                        ┌─────────────────────────────────────────┐
                        │              DISTRIBUTED SYSTEM         │
                        │        (BEAM Nodes / Browsers)          │
                        └──────────┬───────────────────┬──────────┘
                                   │                   │
                                   ▼                   ▼
                        ┌───────────────────┐  ┌───────────────────┐
                        │ PHOENIX SERVER    │  │ RESCRIPT CLIENT   │
                        │ (Elixir / OTP)    │  │ (Browser Peer)    │
                        └──────────┬────────┘  └──────────┬────────┘
                                   │                      │
                                   └──────────┬───────────┘
                                              │
                                              ▼
                        ┌─────────────────────────────────────────┐
                        │           STATE CONVERGENCE             │
                        │  ┌───────────┐  ┌───────────────────┐  │
                        │  │ CRDT      │  │  Phoenix          │  │
                        │  │ Registry  │◄─►  Channels         │  │
                        │  └─────┬─────┘  └────────┬──────────┘  │
                        │        │                 │              │
                        │  ┌─────▼─────┐  ┌────────▼──────────┐  │
                        │  │ Capability│  │  Command Bus      │  │
                        │  │ Policy    │  │  (Typed Envelopes)│  │
                        │  └─────┬─────┘  └────────┬──────────┘  │
                        └────────│─────────────────│──────────────┘
                                 │                 │
                                 ▼                 ▼
                        ┌─────────────────────────────────────────┐
                        │             DATA LAYER                  │
                        │  ┌───────────┐  ┌───────────────────┐  │
                        │  │ Automerge │  │  PostgreSQL       │  │
                        │  │ (Phase 1) │  │  (Persistence)    │  │
                        │  └───────────┘  └───────────────────┘  │
                        └─────────────────────────────────────────┘

                        ┌─────────────────────────────────────────┐
                        │          REPO INFRASTRUCTURE            │
                        │  Justfile Automation  .machine_readable/  │
                        │  Protobuf Schemas     0-AI-MANIFEST.a2ml  │
                        └─────────────────────────────────────────┘
```

## Completion Dashboard

```
COMPONENT                          STATUS              NOTES
─────────────────────────────────  ──────────────────  ─────────────────────────────────
CORE ARCHITECTURE (PHASE 0)
  G-Counter (Server/Client)         ██████████ 100%    Isomorphic state stable
  Phoenix Channel Transport         ██████████ 100%    Bidirectional sync verified
  Capability Negotiation            ██████████ 100%    Adaptive profiles active
  ReScript UI (Client Peer)         ██████████ 100%    Rendering from CRDT mirror

DISTRIBUTED LOGIC (PHASE 1)
  Delta-based CRDT Sync             ██████░░░░  60%    Refining network efficiency
  Typed Command Envelopes           ████████░░  80%    Protobuf validation active
  Registry (Distributed State)      ██████████ 100%    GenServer management stable

REPO INFRASTRUCTURE
  Justfile Automation               ██████████ 100%    Standard build/test tasks
  .machine_readable/                ██████████ 100%    STATE tracking active
  Documentation (Wiki)              ██████████ 100%    Detailed system design stable

─────────────────────────────────────────────────────────────────────────────
OVERALL:                            ███████░░░  ~70%   Phase 0 complete, Phase 1 active
```

## Key Dependencies

```
Capability Probe ───► Policy Engine ───► Sync Frequency ───► UI Update
     │                    │                 │                 │
     ▼                    ▼                 ▼                 ▼
CRDT Operation ────► Command Bus ─────► Converged State ──► Client Peer
```

## Update Protocol

This file is maintained by both humans and AI agents. When updating:

1. **After completing a component**: Change its bar and percentage
2. **After adding a component**: Add a new row in the appropriate section
3. **After architectural changes**: Update the ASCII diagram
4. **Date**: Update the `Last updated` comment at the top of this file

Progress bars use: `█` (filled) and `░` (empty), 10 characters wide.
Percentages: 0%, 10%, 20%, ... 100% (in 10% increments).
