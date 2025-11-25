# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.x.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

**DO NOT** create a public GitHub issue for security vulnerabilities.

Instead, please use one of these methods:

1. **Email**: security@laniakea.dev
2. **Security Advisory**: [Create a private security advisory](https://github.com/laniakea/laniakea/security/advisories/new)

### What to Include

Please include as much of the following information as possible:

- Type of vulnerability (e.g., XSS, CRDT desync, injection, etc.)
- Full paths of source files related to the vulnerability
- Location of the affected source code (tag/branch/commit or direct URL)
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact assessment

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Resolution Target**: Within 90 days (depending on severity)

### Severity Levels

| Level | Description | Response Time |
|-------|-------------|---------------|
| Critical | Remote code execution, CRDT state corruption | 24 hours |
| High | Authentication bypass, data exposure | 48 hours |
| Medium | Denial of service, information disclosure | 7 days |
| Low | Minor issues with limited impact | 30 days |

### Safe Harbor

We support responsible disclosure and will not pursue legal action against researchers who:

- Make a good faith effort to avoid privacy violations, data destruction, or service interruption
- Only interact with accounts you own or with explicit permission
- Do not exploit vulnerabilities beyond what is necessary to demonstrate the issue
- Report vulnerabilities promptly and provide reasonable time for remediation

### Security Measures in Laniakea

#### CRDT Security

- All CRDT operations are validated before application
- Node IDs are cryptographically verified
- Delta sync includes integrity checks
- Merge operations cannot corrupt state (mathematical guarantee)

#### Transport Security

- TLS 1.3 required for all connections
- Phoenix Channels use secure WebSocket (wss://)
- Token-based authentication with expiration
- Rate limiting on all endpoints

#### Server Security

- OTP supervision prevents cascade failures
- Input validation on all commands
- SQL injection prevention (Ecto parameterized queries)
- CORS properly configured

#### Client Security

- Content Security Policy headers
- XSS prevention (ReScript escapes by default)
- No eval() or dynamic code execution
- Subresource Integrity for CDN resources

### Dependency Security

We regularly audit dependencies:

```bash
# Elixir
mix deps.audit

# JavaScript
npm audit

# Full security scan
just security-audit
```

### Security-Related Configuration

See `.well-known/security.txt` for machine-readable security information.

## Acknowledgments

We thank the following researchers for responsibly disclosing vulnerabilities:

*No vulnerabilities reported yet.*

---

*This security policy follows the [Rhodium Standard Repository](https://github.com/rhodium-standard) guidelines.*
