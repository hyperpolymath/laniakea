# Maintainers

This document lists the maintainers of the Laniakea project and their responsibilities under the Tri-Perimeter Contribution Framework (TPCF).

## Tri-Perimeter Contribution Framework (TPCF)

Laniakea uses a graduated access model to balance openness with security:

```
┌─────────────────────────────────────────────────────────────────┐
│                        TPCF PERIMETERS                          │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  P1: CORE                                                │  │
│   │  Full commit access, release authority, security access  │  │
│   │                                                          │  │
│   │   ┌─────────────────────────────────────────────────┐   │  │
│   │   │  P2: TRUSTED                                     │   │  │
│   │   │  Review & merge for specific areas               │   │  │
│   │   │                                                  │   │  │
│   │   │   ┌─────────────────────────────────────────┐   │   │  │
│   │   │   │  P3: COMMUNITY                           │   │   │  │
│   │   │   │  PR submission, issue creation           │   │   │  │
│   │   │   │  Open to all contributors               │   │   │  │
│   │   │   └─────────────────────────────────────────┘   │   │  │
│   │   └─────────────────────────────────────────────────┘   │  │
│   └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Current Maintainers

### Perimeter 1: Core Maintainers

Core maintainers have full commit access, can cut releases, and have access to security-sensitive operations.

| Name | GitHub | Areas | Contact |
|------|--------|-------|---------|
| *Seeking maintainers* | - | All | - |

**Responsibilities:**
- Final approval on all PRs
- Release management
- Security vulnerability handling
- Architecture decisions
- Perimeter promotions

### Perimeter 2: Trusted Contributors

Trusted contributors can review and merge PRs in their areas of expertise.

| Name | GitHub | Areas | Since |
|------|--------|-------|-------|
| *Open for contributors* | - | - | - |

**Areas of Expertise:**
- `server/crdt/` — CRDT implementations (Elixir)
- `server/transport/` — Phoenix Channels, WebTransport
- `server/policy/` — Capability negotiation
- `client/crdt/` — CRDT mirrors (ReScript)
- `client/transport/` — Client-side transport
- `docs/` — Documentation
- `cli/` — CLI tooling
- `schemas/` — Nickel/CUE configurations

**Responsibilities:**
- Review PRs in assigned areas
- Mentor P3 contributors
- Propose architectural improvements
- Maintain documentation in their areas

### Perimeter 3: Community Contributors

All contributors who have signed the CLA and follow the Code of Conduct.

**Responsibilities:**
- Submit PRs following contribution guidelines
- Report issues with sufficient detail
- Participate in discussions respectfully
- Help other community members

## Becoming a Maintainer

### P3 → P2 Promotion

Requirements:
- [ ] 5+ merged PRs demonstrating quality
- [ ] Consistent engagement over 3+ months
- [ ] Deep knowledge of specific area
- [ ] Positive community interactions
- [ ] Nomination by P1 maintainer
- [ ] No Code of Conduct violations

Process:
1. P1 maintainer nominates contributor
2. Discussion period (1 week)
3. Consensus among P1 maintainers
4. Update this file and grant permissions

### P2 → P1 Promotion

Requirements:
- [ ] 6+ months as P2 contributor
- [ ] 20+ significant contributions
- [ ] Demonstrated architectural judgment
- [ ] Security training completed
- [ ] Unanimous P1 approval
- [ ] Commitment to long-term involvement

Process:
1. P1 maintainer nominates P2 contributor
2. Extended discussion (2 weeks)
3. Unanimous P1 approval required
4. Security briefing and access provisioning
5. Update this file

## Stepping Down

Maintainers may step down at any time:
1. Notify other P1 maintainers
2. Ensure knowledge transfer
3. Remove access credentials
4. Update this file
5. Move to Emeritus section

## Emeritus Maintainers

Former maintainers who have stepped down but made significant contributions:

| Name | GitHub | Period | Contributions |
|------|--------|--------|---------------|
| *None yet* | - | - | - |

## Decision Making

### Technical Decisions

- **Minor changes**: Any P2+ maintainer can approve
- **Significant changes**: Requires P1 approval
- **Breaking changes**: Requires all P1 consensus
- **Architecture changes**: RFC process, community input, P1 consensus

### Process Decisions

- **TPCF changes**: All P1 consensus
- **Code of Conduct changes**: All P1 consensus + community input
- **License changes**: All P1 consensus + legal review

## Contact

- **General**: maintainers@laniakea.dev
- **Security**: security@laniakea.dev
- **Conduct**: conduct@laniakea.dev

## Meetings

Maintainer meetings are held monthly:
- **When**: First Tuesday, 17:00 UTC
- **Where**: Discord #maintainers voice channel
- **Notes**: Published in `docs/meetings/`

Community members may request to attend as observers.

---

*This document follows the [Rhodium Standard Repository](https://github.com/rhodium-standard) TPCF guidelines.*
