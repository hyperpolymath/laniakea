# Contributing to Laniakea

First off, thank you for considering contributing to Laniakea! It's people like you that make Laniakea such a great tool for building distributed web applications.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [TPCF Perimeter Model](#tpcf-perimeter-model)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Pull Request Process](#pull-request-process)
- [Style Guides](#style-guides)
- [Testing](#testing)
- [Documentation](#documentation)

## Code of Conduct

This project and everyone participating in it is governed by the [Laniakea Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## TPCF Perimeter Model

Laniakea uses the **Tri-Perimeter Contribution Framework (TPCF)** for graduated access:

| Perimeter | Access Level | Requirements |
|-----------|--------------|--------------|
| **P1: Core** | Full commit access | Maintainer status, proven track record |
| **P2: Trusted** | Review + merge for specific areas | Multiple accepted PRs, domain expertise |
| **P3: Community** | PR submission, issue creation | Signed CLA, follows code of conduct |

New contributors start at P3. Advancement is based on:
- Quality and quantity of contributions
- Responsiveness to feedback
- Community engagement
- Domain expertise

See [MAINTAINERS.md](MAINTAINERS.md) for current perimeter assignments.

## Getting Started

### Prerequisites

- **Elixir** >= 1.15
- **Erlang/OTP** >= 26
- **Node.js** >= 18
- **just** (command runner)
- **Nix** (optional, for reproducible builds)

### Quick Setup

```bash
# Clone the repository
git clone https://github.com/laniakea/laniakea.git
cd laniakea

# Using Nix (recommended)
nix develop

# Or manual setup
just setup

# Run tests
just test

# Start development servers
just dev
```

## Development Setup

### With Nix (Recommended)

```bash
# Enter development shell with all dependencies
nix develop

# Or use direnv for automatic activation
echo "use flake" > .envrc
direnv allow
```

### Manual Setup

```bash
# Server (Elixir)
cd server
mix deps.get
mix compile

# Client (ReScript)
cd client
npm install
npm run build
```

### Verify Setup

```bash
just doctor  # Check all dependencies and configuration
```

## Making Changes

### Branch Naming

```
<type>/<short-description>

Types:
- feat/     New feature
- fix/      Bug fix
- docs/     Documentation
- refactor/ Code refactoring
- test/     Adding tests
- chore/    Maintenance

Examples:
- feat/delta-sync-protocol
- fix/gcounter-merge-edge-case
- docs/crdt-mathematical-proofs
```

### Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Types**: feat, fix, docs, style, refactor, perf, test, build, ci, chore

**Scopes**: server, client, crdt, transport, policy, cli, docs

**Examples**:
```
feat(crdt): add OR-Set implementation with tombstone GC

Implements Observed-Remove Set with garbage collection for tombstones.
Includes mathematical proofs in docstrings.

Closes #42
```

```
fix(transport): handle WebSocket reconnection race condition

The previous implementation could miss messages during reconnection
if the server sent updates before the client fully rejoined.

Fixes #108
```

### Code Changes Checklist

Before submitting:

- [ ] Code compiles without warnings (`just build`)
- [ ] All tests pass (`just test`)
- [ ] Dialyzer passes (`just dialyzer`)
- [ ] Credo passes (`just lint`)
- [ ] ReScript type checks (`just typecheck`)
- [ ] Documentation updated if needed
- [ ] CHANGELOG.md updated for user-facing changes
- [ ] RSR compliance maintained (`just rsr-check`)

## Pull Request Process

### 1. Create the PR

```bash
# Create feature branch
git checkout -b feat/my-feature

# Make changes and commit
git add .
git commit -m "feat(scope): description"

# Push and create PR
git push -u origin feat/my-feature
```

### 2. PR Template

Your PR description should include:

```markdown
## Summary
Brief description of changes.

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Documentation update

## Testing
Describe testing performed.

## RSR Compliance
- [ ] Type safety maintained
- [ ] Memory safety (no unsafe blocks without justification)
- [ ] Tests added/updated
- [ ] Documentation updated

## Related Issues
Closes #XX
```

### 3. Review Process

1. **Automated checks** must pass (CI, linting, tests)
2. **At least one maintainer** must approve
3. **All conversations** must be resolved
4. **Squash and merge** is the default strategy

### 4. After Merge

- Delete your branch
- Update related issues
- Celebrate! 🎉

## Style Guides

### Elixir

We follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide) with these additions:

```elixir
# Use @moduledoc and @doc for all public modules/functions
@moduledoc """
G-Counter CRDT implementation.

## Mathematical Properties

The G-Counter forms a join-semilattice where:
- Partial order: a ≤ b iff ∀i: a[i] ≤ b[i]
- Join (merge): (a ⊔ b)[i] = max(a[i], b[i])
"""

# Use @spec for all public functions
@spec increment(t(), node_id()) :: t()
def increment(%GCounter{} = counter, node_id) do
  # ...
end

# Use pattern matching over conditionals
def handle_command(%{type: "increment"} = cmd), do: # ...
def handle_command(%{type: "decrement"} = cmd), do: # ...

# Prefer pipe operator for transformations
data
|> validate()
|> transform()
|> persist()
```

### ReScript

```rescript
// Use module types for complex structures
module type CRDT = {
  type t
  let empty: t
  let merge: (t, t) => t
  let value: t => 'a
}

// Document with doc comments
/**
 * Increment the counter for the given node.
 * This is a local operation - sync happens separately.
 */
let increment = (counter, nodeId) => {
  // ...
}

// Use variants for state machines
type connectionState =
  | Disconnected
  | Connecting
  | Connected(channel)
  | Reconnecting(attempt)

// Prefer pattern matching
switch state {
| Disconnected => connect()
| Connecting => wait()
| Connected(ch) => send(ch, msg)
| Reconnecting(n) if n < 5 => retry()
| Reconnecting(_) => giveUp()
}
```

### Documentation

- Use AsciiDoc (`.adoc`) for long-form documentation
- Use Markdown (`.md`) for GitHub-specific files (README, CONTRIBUTING, etc.)
- Include mathematical proofs for CRDT operations
- Provide examples for all public APIs

## Testing

### Elixir Tests

```bash
# Run all tests
just test

# Run specific test file
just test-file server/test/crdt/g_counter_test.exs

# Run with coverage
just test-coverage

# Property-based tests
just test-property
```

### ReScript Tests

```bash
# Run client tests
just test-client

# Watch mode
just test-client-watch
```

### Integration Tests

```bash
# Full integration test suite
just test-integration

# Specific scenario
just test-scenario offline-sync
```

### Writing Tests

```elixir
# Elixir: Use ExUnit with property-based testing
defmodule Laniakea.CRDT.GCounterTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  describe "merge/2" do
    property "is commutative" do
      check all a <- gcounter_generator(),
                b <- gcounter_generator() do
        assert GCounter.merge(a, b) == GCounter.merge(b, a)
      end
    end

    property "is associative" do
      check all a <- gcounter_generator(),
                b <- gcounter_generator(),
                c <- gcounter_generator() do
        assert GCounter.merge(GCounter.merge(a, b), c) ==
               GCounter.merge(a, GCounter.merge(b, c))
      end
    end

    property "is idempotent" do
      check all a <- gcounter_generator() do
        assert GCounter.merge(a, a) == a
      end
    end
  end
end
```

## Documentation

### Where to Document

| Content | Location |
|---------|----------|
| API reference | `@doc` / doc comments in code |
| Architecture | `docs/wiki/Architecture.md` |
| Tutorials | `docs/wiki/` |
| CRDT theory | `docs/wiki/CRDTs.md` |
| Changelog | `CHANGELOG.md` |
| CLI usage | `laniakea --help` |

### Documentation Standards

- Every public function needs `@doc` or doc comment
- Include type specifications (`@spec`)
- Add examples that can be run as doctests
- Document mathematical properties for CRDTs
- Keep README.adoc up to date

## Questions?

- **Discord**: [Join our server](https://discord.gg/laniakea)
- **Discussions**: [GitHub Discussions](https://github.com/laniakea/laniakea/discussions)
- **Issues**: [GitHub Issues](https://github.com/laniakea/laniakea/issues)

---

Thank you for contributing to Laniakea! Together, we're building the future of distributed web applications.
