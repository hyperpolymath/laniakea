// SPDX-License-Identifier: MIT OR Apache-2.0
// Copyright (c) 2024 Laniakea Contributors

import { assertEquals, assertThrows } from "https://deno.land/std@0.208.0/assert/mod.ts";

// Note: These tests assume ReScript has been compiled to .mjs files
// Run `npx rescript` before running tests

Deno.test("GCounter - basic operations", async (t) => {
  // Dynamic import for compiled ReScript modules
  const GCounter = await import("../src/crdt/GCounter.mjs");

  await t.step("creates empty counter with zero value", () => {
    const counter = GCounter.make();
    assertEquals(GCounter.value(counter), 0);
  });

  await t.step("increments counter", () => {
    let counter = GCounter.make();
    counter = GCounter.increment(counter, "node1");
    counter = GCounter.increment(counter, "node1");
    assertEquals(GCounter.value(counter), 2);
  });

  await t.step("increments by amount", () => {
    let counter = GCounter.make();
    counter = GCounter.incrementBy(counter, "node1", 5);
    assertEquals(GCounter.value(counter), 5);
  });

  await t.step("tracks multiple nodes", () => {
    let counter = GCounter.make();
    counter = GCounter.increment(counter, "node1");
    counter = GCounter.increment(counter, "node2");
    counter = GCounter.increment(counter, "node1");
    assertEquals(GCounter.value(counter), 3);
  });
});

Deno.test("GCounter - merge operations", async (t) => {
  const GCounter = await import("../src/crdt/GCounter.mjs");

  await t.step("merge is commutative", () => {
    let a = GCounter.incrementBy(GCounter.make(), "a", 5);
    let b = GCounter.incrementBy(GCounter.make(), "b", 3);

    const ab = GCounter.merge(a, b);
    const ba = GCounter.merge(b, a);

    assertEquals(GCounter.value(ab), GCounter.value(ba));
  });

  await t.step("merge is associative", () => {
    let a = GCounter.incrementBy(GCounter.make(), "a", 1);
    let b = GCounter.incrementBy(GCounter.make(), "b", 2);
    let c = GCounter.incrementBy(GCounter.make(), "c", 3);

    const left = GCounter.merge(GCounter.merge(a, b), c);
    const right = GCounter.merge(a, GCounter.merge(b, c));

    assertEquals(GCounter.value(left), GCounter.value(right));
  });

  await t.step("merge is idempotent", () => {
    let a = GCounter.incrementBy(GCounter.make(), "a", 5);
    assertEquals(GCounter.value(GCounter.merge(a, a)), GCounter.value(a));
  });

  await t.step("merge takes max per node", () => {
    let a = GCounter.incrementBy(GCounter.make(), "node1", 5);
    a = GCounter.incrementBy(a, "node2", 3);

    let b = GCounter.incrementBy(GCounter.make(), "node1", 3);
    b = GCounter.incrementBy(b, "node2", 7);

    const merged = GCounter.merge(a, b);
    assertEquals(GCounter.value(merged), 12); // max(5,3) + max(3,7) = 5 + 7
  });
});

Deno.test("GCounter - wire format", async (t) => {
  const GCounter = await import("../src/crdt/GCounter.mjs");

  await t.step("round-trips through wire format", () => {
    let counter = GCounter.incrementBy(GCounter.make(), "node1", 5);
    counter = GCounter.incrementBy(counter, "node2", 3);

    const wire = GCounter.toWire(counter);
    const restored = GCounter.fromWire(wire);

    assertEquals(GCounter.value(restored), GCounter.value(counter));
  });
});

Deno.test("PNCounter - basic operations", async (t) => {
  const PNCounter = await import("../src/crdt/PNCounter.mjs");

  await t.step("creates counter with zero value", () => {
    const counter = PNCounter.make();
    assertEquals(PNCounter.value(counter), 0);
  });

  await t.step("increments and decrements", () => {
    let counter = PNCounter.make();
    counter = PNCounter.incrementBy(counter, "node1", 10);
    counter = PNCounter.decrementBy(counter, "node1", 3);
    assertEquals(PNCounter.value(counter), 7);
  });

  await t.step("allows negative values", () => {
    let counter = PNCounter.make();
    counter = PNCounter.decrementBy(counter, "node1", 5);
    assertEquals(PNCounter.value(counter), -5);
  });
});

Deno.test("PNCounter - merge operations", async (t) => {
  const PNCounter = await import("../src/crdt/PNCounter.mjs");

  await t.step("merge is commutative", () => {
    let a = PNCounter.incrementBy(PNCounter.make(), "a", 5);
    let b = PNCounter.decrementBy(PNCounter.make(), "b", 3);

    const ab = PNCounter.merge(a, b);
    const ba = PNCounter.merge(b, a);

    assertEquals(PNCounter.value(ab), PNCounter.value(ba));
  });
});

Deno.test("ORSet - basic operations", async (t) => {
  const ORSet = await import("../src/crdt/ORSet.mjs");

  await t.step("creates empty set", () => {
    const set = ORSet.make();
    assertEquals(ORSet.elements(set).length, 0);
  });

  await t.step("adds elements", () => {
    let set = ORSet.make();
    set = ORSet.add(set, "apple", "node1");
    set = ORSet.add(set, "banana", "node1");

    assertEquals(ORSet.contains(set, "apple"), true);
    assertEquals(ORSet.contains(set, "banana"), true);
  });

  await t.step("removes elements", () => {
    let set = ORSet.make();
    set = ORSet.add(set, "apple", "node1");
    set = ORSet.remove(set, "apple");

    assertEquals(ORSet.contains(set, "apple"), false);
  });

  await t.step("add-remove-add keeps element", () => {
    let set = ORSet.make();
    set = ORSet.add(set, "apple", "node1");
    set = ORSet.remove(set, "apple");
    set = ORSet.add(set, "apple", "node2");

    assertEquals(ORSet.contains(set, "apple"), true);
  });
});

Deno.test("ORSet - merge operations", async (t) => {
  const ORSet = await import("../src/crdt/ORSet.mjs");

  await t.step("merge combines elements", () => {
    let a = ORSet.add(ORSet.make(), "apple", "node1");
    let b = ORSet.add(ORSet.make(), "banana", "node2");

    const merged = ORSet.merge(a, b);

    assertEquals(ORSet.contains(merged, "apple"), true);
    assertEquals(ORSet.contains(merged, "banana"), true);
  });

  await t.step("merge is commutative", () => {
    let a = ORSet.add(ORSet.make(), "x", "a");
    let b = ORSet.add(ORSet.make(), "y", "b");

    const ab = ORSet.merge(a, b);
    const ba = ORSet.merge(b, a);

    const abElements = ORSet.elements(ab).sort();
    const baElements = ORSet.elements(ba).sort();

    assertEquals(abElements, baElements);
  });
});

Deno.test("LWWRegister - basic operations", async (t) => {
  const LWWRegister = await import("../src/crdt/LWWRegister.mjs");

  await t.step("creates empty register", () => {
    const reg = LWWRegister.make();
    assertEquals(LWWRegister.value(reg), undefined);
  });

  await t.step("sets value", () => {
    let reg = LWWRegister.make();
    reg = LWWRegister.set(reg, "hello", "node1");
    assertEquals(LWWRegister.value(reg), "hello");
  });

  await t.step("overwrites value", () => {
    let reg = LWWRegister.make();
    reg = LWWRegister.set(reg, "first", "node1");
    reg = LWWRegister.set(reg, "second", "node1");
    assertEquals(LWWRegister.value(reg), "second");
  });
});

Deno.test("LWWRegister - merge operations", async (t) => {
  const LWWRegister = await import("../src/crdt/LWWRegister.mjs");

  await t.step("keeps higher timestamp value", () => {
    let a = LWWRegister.setWithTimestamp(LWWRegister.make(), "older", "n1", 100);
    let b = LWWRegister.setWithTimestamp(LWWRegister.make(), "newer", "n2", 200);

    const merged = LWWRegister.merge(a, b);
    assertEquals(LWWRegister.value(merged), "newer");
  });

  await t.step("merge is commutative", () => {
    let a = LWWRegister.setWithTimestamp(LWWRegister.make(), "a", "n1", 100);
    let b = LWWRegister.setWithTimestamp(LWWRegister.make(), "b", "n2", 200);

    const ab = LWWRegister.merge(a, b);
    const ba = LWWRegister.merge(b, a);

    assertEquals(LWWRegister.value(ab), LWWRegister.value(ba));
  });

  await t.step("uses node_id as tiebreaker", () => {
    let a = LWWRegister.setWithTimestamp(LWWRegister.make(), "a_value", "node_a", 100);
    let b = LWWRegister.setWithTimestamp(LWWRegister.make(), "b_value", "node_b", 100);

    const ab = LWWRegister.merge(a, b);
    const ba = LWWRegister.merge(b, a);

    // Should be deterministic
    assertEquals(LWWRegister.value(ab), LWWRegister.value(ba));
  });
});

Deno.test("LWWRegister - wire format", async (t) => {
  const LWWRegister = await import("../src/crdt/LWWRegister.mjs");

  await t.step("round-trips through wire format", () => {
    let reg = LWWRegister.setWithTimestamp(LWWRegister.make(), "test", "node1", 12345);

    const wire = LWWRegister.toWire(reg);
    const restored = LWWRegister.fromWire(wire);

    assertEquals(LWWRegister.value(restored), LWWRegister.value(reg));
    assertEquals(LWWRegister.timestamp(restored), LWWRegister.timestamp(reg));
  });
});
