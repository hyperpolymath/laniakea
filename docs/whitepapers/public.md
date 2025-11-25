# Laniakea: Making Web Apps Work Everywhere

**A Plain-Language Guide**

*How we're building apps that work offline, sync automatically, and never lose your work*

---

## What's the Problem?

You know that frustrating moment when you're on a plane, in a subway tunnel, or just have spotty wifi, and the app you're using stops working? You might see:

- "Unable to connect"
- A spinning loading icon that never stops
- Your changes getting lost when you finally reconnect

This happens because most web apps are built with a simple assumption: **your browser has to constantly talk to a server**. Every time you click a button, type some text, or make a change, it needs to send that change to a server and wait for a response.

```
Your Browser ──────► Server ──────► Your Browser
    "I clicked!"     "Got it!"      "OK, updated!"
```

If that connection breaks, the app breaks too.

---

## What is Laniakea?

Laniakea (pronounced lan-ee-uh-KAY-uh) is a new way of building web apps that don't have this problem.

**The key idea**: Instead of your browser constantly asking a server "what should I show?", both your browser and the server keep their own copy of the information. When they can talk, they sync up. When they can't, they both keep working independently.

```
Your Browser has: "Count = 5"
Server has: "Count = 5"

You go offline...

You click +1: Your browser shows "Count = 6"
Someone else clicks +1: Server shows "Count = 6"

You come back online...

Browser & Server sync: Both now show "Count = 7"
Nobody's clicks were lost!
```

---

## How Does It Work?

### Smart Data Structures

The secret sauce is something called **CRDTs** (don't worry about what that stands for). These are special ways of storing data that can be combined without conflicts.

Think of it like this:

**Regular data** is like a whiteboard where only one person can write at a time. If two people try to write at the same time, someone's work gets erased.

**CRDT data** is like a voting booth. Everyone puts their vote in, and when we count them up, all votes are included. It doesn't matter what order the votes came in.

### Real-World Example

Imagine a "Like" button on a post:

**Old way**:
1. You click "Like"
2. Your browser sends "Add my like" to server
3. Server says "OK, there are now 43 likes"
4. Your browser shows 43

If step 2 fails (bad connection), nothing happens. You're stuck.

**Laniakea way**:
1. You click "Like"
2. Your browser immediately shows your like (now 43)
3. In the background, your browser syncs with server when possible
4. Server merges all likes together
5. Everyone eventually sees the same count

You see your action immediately. Your like is never lost. Everyone ends up with the same number.

---

## What's the Name About?

Laniakea is the name of the galaxy supercluster that contains our Milky Way. It's Hawaiian for "immeasurable heaven."

We chose this name because:

1. **Everything flows together** — In the Laniakea supercluster, galaxies are all flowing toward a common point. In our system, data flows together from all users into a consistent state.

2. **No center** — There's no "central" galaxy in Laniakea. Similarly, our apps don't have a central "source of truth" — everyone's browser is equally valid.

3. **It just works** — Gravity doesn't need anyone to coordinate it. Similarly, our data syncs automatically without needing a referee.

---

## What Kind of Apps Can Use This?

Laniakea is especially good for:

### Collaborative Apps
Multiple people editing the same thing at the same time
- Document editors
- Whiteboards
- Project management tools

### Offline-First Apps
Apps that need to work without internet
- Note-taking apps
- Field data collection
- Mobile apps in areas with spotty coverage

### Real-Time Apps
Apps where instant updates matter
- Chat applications
- Live dashboards
- Gaming

---

## How Does This Compare to What Exists?

### vs. Google Docs

Google Docs works offline (sort of), but uses a complex system called "operational transformation" that requires a central server to coordinate. If Google's servers go down, nobody can edit together.

Laniakea doesn't need a coordinator. Everyone can keep working and sync up later.

### vs. Regular Web Apps (Facebook, Twitter, etc.)

Most web apps require constant internet. Go offline and you see cached pages that you can't interact with.

Laniakea apps keep working offline. Your actions queue up and sync when you're back online.

### vs. Native Mobile Apps

Native apps (like the Notes app on your phone) work offline, but syncing is often fragile. You've probably seen "conflicting copies" of a note.

Laniakea's sync is designed from the ground up. Conflicts resolve automatically.

---

## Is This Ready to Use?

Laniakea is being built in phases:

### Now: Phase 0 ✅
Basic counters and simple data types work. You can build a "like button" or "voting app" today.

### Coming Soon: Phase 1
More complex data types — lists you can add and remove from, text you can edit.

### Later: Phase 2+
Advanced features — works with even slower connections, detailed monitoring.

### Future
The full vision — your browser becomes as powerful as a server.

---

## Who's Building This?

Laniakea is an open-source project. That means:

- **Free to use** — Anyone can use it without paying
- **Open code** — You can see exactly how it works
- **Community-driven** — Anyone can contribute improvements

---

## Want to Learn More?

### For Regular Users
Just keep using apps! As developers adopt Laniakea, the apps you use will naturally get better at working offline and syncing between devices.

### For Developers
Check out our [technical documentation](../wiki/Home.md) to learn how to build with Laniakea.

### For Everyone
Star us on GitHub if you think offline-first apps are important!

---

## The Big Picture

The internet wasn't designed to be always-on. Connections drop. Phones go into tunnels. Wifi cuts out.

For too long, we've built apps that pretend the internet is always available, and then break when it isn't.

Laniakea is part of a movement toward "local-first" software — apps that work on your device first, and sync to the cloud second. Your data, your device, your control.

The future of the web isn't about being connected all the time. It's about being resilient when you're not.

---

*Laniakea — Distributed state finds its way home.*

---

## Glossary

**Browser**: The app you use to visit websites (Chrome, Firefox, Safari)

**Server**: A computer run by a company that stores data and runs apps

**Sync**: When two copies of data are made to match each other

**Offline**: When you don't have internet access

**CRDT**: A special kind of data that can be combined without conflicts (the technical magic behind Laniakea)

**Open Source**: Software where the code is freely available for anyone to use and modify
