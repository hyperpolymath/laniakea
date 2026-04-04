# TEST-NEEDS.md — laniakea

## CRG Grade: C — ACHIEVED 2026-04-04

> Generated 2026-03-29 by punishing audit.

## Current State

| Category     | Count | Notes |
|-------------|-------|-------|
| Unit tests   | 5     | Elixir: g_counter, lww_register, or_set, pn_counter + client crdt_test.mjs |
| Integration  | 0     | None |
| E2E          | 0     | None |
| Benchmarks   | 0     | None |

**Source modules:** ~37 source files. Client: 7 ReScript modules (GCounter, LWWRegister, ORSet, PNCounter, Channel, Capabilities, Main). Server: ~16 Elixir modules.

## What's Missing

### P2P (Property-Based) Tests
- [ ] CRDT convergence: property tests proving GCounter, PNCounter, ORSet, LWWRegister converge under arbitrary operation sequences
- [ ] CRDT commutativity: property tests for operation commutativity
- [ ] Channel reliability: arbitrary message ordering property tests

### E2E Tests
- [ ] Full sync cycle: client create -> modify -> sync -> server merge -> client receive
- [ ] Multi-client: 3+ clients modifying same CRDT and converging
- [ ] Network partition: split-brain scenario and recovery
- [ ] Capabilities: capability negotiation and enforcement round-trip

### Aspect Tests
- **Security:** No tests for capability enforcement, unauthorized operation rejection, data integrity across sync
- **Performance:** No sync latency benchmarks, no CRDT operation throughput measurements
- **Concurrency:** ZERO. A CRDT system with no concurrency tests is a fundamental failure
- **Error handling:** No tests for network disconnection, malformed sync messages, version conflicts

### Build & Execution
- [ ] `mix test` for server
- [ ] Deno/ReScript test for client
- [ ] Combined client+server integration

### Benchmarks Needed
- [ ] CRDT merge operation latency (per type)
- [ ] Sync round-trip time
- [ ] State size growth vs operation count
- [ ] Convergence time under high contention

### Self-Tests
- [ ] CRDT invariant self-check (monotonicity, convergence)
- [ ] Channel health monitoring
- [ ] Capability set consistency

## Priority

**CRITICAL.** A CRDT-based sync system with 5 unit tests and ZERO concurrency tests. CRDTs exist specifically for concurrent distributed systems — testing them without concurrency is like testing a boat on dry land. The 4 CRDT type tests are a start but need property-based testing to be meaningful.

## FAKE-FUZZ ALERT

- `tests/fuzz/placeholder.txt` is a scorecard placeholder inherited from rsr-template-repo — it does NOT provide real fuzz testing
- Replace with an actual fuzz harness (see rsr-template-repo/tests/fuzz/README.adoc) or remove the file
- Priority: P2 — creates false impression of fuzz coverage
