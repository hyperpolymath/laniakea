# SPDX-License-Identifier: MIT OR Apache-2.0
# Laniakea - Comprehensive Build System
# Run `just --list` for available recipes
# Run `just --help <recipe>` for recipe details

# ============================================================================
# CONFIGURATION
# ============================================================================

# Default recipe when just is called without arguments
default: help

# Project metadata
project := "laniakea"
version := "0.1.0"

# Directories
server_dir := "server"
client_dir := "client"
docs_dir := "docs"
schemas_dir := "schemas"

# Tools (can be overridden)
elixir := "elixir"
mix := "mix"
deno := "deno"
rescript := "rescript"
nix := "nix"
docker := "docker"
nickel := "nickel"
arango := "arangosh"

# Colors for output
red := '\033[0;31m'
green := '\033[0;32m'
yellow := '\033[0;33m'
blue := '\033[0;34m'
nc := '\033[0m'

# ============================================================================
# HELP & INFO
# ============================================================================

# Show this help message
help:
    @echo "╔═══════════════════════════════════════════════════════════════════╗"
    @echo "║                      LANIAKEA BUILD SYSTEM                        ║"
    @echo "║         Distributed state finds its way home                      ║"
    @echo "╠═══════════════════════════════════════════════════════════════════╣"
    @echo "║  Version: {{version}}                                                  ║"
    @echo "║  Run 'just --list' for all recipes                                ║"
    @echo "║  Run 'just --list --unsorted' for categorized view                ║"
    @echo "╚═══════════════════════════════════════════════════════════════════╝"
    @just --list --list-heading $'Available recipes:\n'

# Show version information
version:
    @echo "Laniakea v{{version}}"
    @echo "Server (Elixir): $(cd {{server_dir}} && {{mix}} run -e 'IO.puts(Application.spec(:laniakea, :vsn) || "dev")')"
    @echo "Client (ReScript): $(cat {{client_dir}}/rescript.json | grep version | cut -d'"' -f4)"

# Show system information and dependencies
doctor:
    @echo "{{blue}}=== System Check ==={{nc}}"
    @echo -n "Elixir: " && {{elixir}} --version | head -1 || echo "{{red}}NOT FOUND{{nc}}"
    @echo -n "Erlang/OTP: " && erl -eval 'io:format("~s~n", [erlang:system_info(otp_release)])' -noshell -s init stop || echo "{{red}}NOT FOUND{{nc}}"
    @echo -n "Deno: " && {{deno}} --version | head -1 || echo "{{red}}NOT FOUND{{nc}}"
    @echo -n "ReScript: " && {{rescript}} -version || echo "{{red}}NOT FOUND{{nc}}"
    @echo -n "Nix: " && {{nix}} --version || echo "{{yellow}}NOT FOUND (optional){{nc}}"
    @echo -n "Docker: " && {{docker}} --version || echo "{{yellow}}NOT FOUND (optional){{nc}}"
    @echo -n "Nickel: " && {{nickel}} --version || echo "{{yellow}}NOT FOUND (optional){{nc}}"
    @echo -n "ArangoDB: " && {{arango}} --version 2>/dev/null | head -1 || echo "{{yellow}}NOT FOUND (optional){{nc}}"
    @echo ""
    @echo "{{blue}}=== Project Status ==={{nc}}"
    @test -f {{server_dir}}/mix.exs && echo "{{green}}✓{{nc}} Server project found" || echo "{{red}}✗{{nc}} Server project missing"
    @test -f {{client_dir}}/rescript.json && echo "{{green}}✓{{nc}} Client project found" || echo "{{red}}✗{{nc}} Client project missing"
    @test -f flake.nix && echo "{{green}}✓{{nc}} Nix flake found" || echo "{{yellow}}○{{nc}} Nix flake missing"

# ============================================================================
# SETUP & INITIALIZATION
# ============================================================================

# Full project setup (all dependencies)
setup: setup-server setup-client
    @echo "{{green}}✓ Setup complete{{nc}}"

# Setup server dependencies
setup-server:
    @echo "{{blue}}=== Setting up server ==={{nc}}"
    cd {{server_dir}} && {{mix}} deps.get
    cd {{server_dir}} && {{mix}} compile

# Setup client dependencies
setup-client:
    @echo "{{blue}}=== Setting up client ==={{nc}}"
    cd {{client_dir}} && {{rescript}} build

# Setup using Nix (reproducible)
setup-nix:
    @echo "{{blue}}=== Setting up via Nix ==={{nc}}"
    {{nix}} develop --command just setup

# Initialize a new CRDT-based feature
init-crdt name type="g_counter":
    @echo "Creating CRDT: {{name}} (type: {{type}})"
    @echo "Server: {{server_dir}}/lib/laniakea/crdt/{{name}}.ex"
    @echo "Client: {{client_dir}}/src/crdt/{{name}}.res"
    @echo "TODO: Template generation not yet implemented"

# ============================================================================
# BUILD
# ============================================================================

# Build everything
build: build-server build-client
    @echo "{{green}}✓ Build complete{{nc}}"

# Build server only
build-server:
    @echo "{{blue}}=== Building server ==={{nc}}"
    cd {{server_dir}} && {{mix}} compile --warnings-as-errors

# Build client only
build-client:
    @echo "{{blue}}=== Building client ==={{nc}}"
    cd {{client_dir}} && {{rescript}} build

# Build in release mode
build-release: build-release-server build-release-client
    @echo "{{green}}✓ Release build complete{{nc}}"

# Build server release
build-release-server:
    @echo "{{blue}}=== Building server release ==={{nc}}"
    cd {{server_dir}} && MIX_ENV=prod {{mix}} release

# Build client for production
build-release-client:
    @echo "{{blue}}=== Building client release ==={{nc}}"
    cd {{client_dir}} && {{rescript}} build
    cd {{client_dir}} && {{deno}} bundle src/Main.mjs dist/laniakea.bundle.js

# Clean all build artifacts
clean: clean-server clean-client
    @echo "{{green}}✓ Clean complete{{nc}}"

# Clean server
clean-server:
    cd {{server_dir}} && {{mix}} clean
    rm -rf {{server_dir}}/_build {{server_dir}}/deps

# Clean client
clean-client:
    cd {{client_dir}} && {{rescript}} clean
    rm -rf {{client_dir}}/dist {{client_dir}}/lib

# ============================================================================
# DEVELOPMENT
# ============================================================================

# Start development servers (server + client watcher)
dev:
    @echo "{{blue}}=== Starting development ==={{nc}}"
    @echo "Server: http://localhost:4000"
    @echo "Client: watching for changes"
    @just dev-server &
    @just dev-client

# Start server in development mode
dev-server:
    cd {{server_dir}} && {{mix}} phx.server

# Start server with IEx shell
dev-server-iex:
    cd {{server_dir}} && iex -S {{mix}} phx.server

# Watch client for changes
dev-client:
    cd {{client_dir}} && {{rescript}} build -w

# Start development with Deno file server
dev-client-serve port="8000":
    cd {{client_dir}} && {{deno}} run --allow-net --allow-read jsr:@std/http/file-server --port {{port}}

# Open IEx shell with project loaded
console:
    cd {{server_dir}} && iex -S {{mix}}

# Run a specific Mix task
mix-task task:
    cd {{server_dir}} && {{mix}} {{task}}

# ============================================================================
# TESTING
# ============================================================================

# Run all tests
test: test-server test-client
    @echo "{{green}}✓ All tests passed{{nc}}"

# Run server tests
test-server:
    @echo "{{blue}}=== Server tests ==={{nc}}"
    cd {{server_dir}} && {{mix}} test

# Run server tests with coverage
test-server-coverage:
    cd {{server_dir}} && {{mix}} coveralls

# Run server tests (verbose)
test-server-verbose:
    cd {{server_dir}} && {{mix}} test --trace

# Run specific server test file
test-server-file file:
    cd {{server_dir}} && {{mix}} test {{file}}

# Run server tests matching pattern
test-server-only pattern:
    cd {{server_dir}} && {{mix}} test --only {{pattern}}

# Run client tests
test-client:
    @echo "{{blue}}=== Client tests ==={{nc}}"
    cd {{client_dir}} && {{deno}} test --allow-net test/

# Run client tests (watch mode)
test-client-watch:
    cd {{client_dir}} && {{deno}} test --allow-net --watch test/

# Run property-based tests (CRDT laws)
test-property:
    @echo "{{blue}}=== Property-based tests ==={{nc}}"
    cd {{server_dir}} && {{mix}} test --only property

# Run integration tests
test-integration:
    @echo "{{blue}}=== Integration tests ==={{nc}}"
    cd {{server_dir}} && {{mix}} test --only integration

# Run specific integration scenario
test-scenario name:
    cd {{server_dir}} && {{mix}} test --only scenario:{{name}}

# Run CRDT verification tests
test-crdt-verify:
    @echo "{{blue}}=== CRDT Verification ==={{nc}}"
    cd {{server_dir}} && {{mix}} run -e 'Laniakea.CRDT.verify(Laniakea.CRDT.GCounter) |> IO.inspect()'
    cd {{server_dir}} && {{mix}} run -e 'Laniakea.CRDT.verify(Laniakea.CRDT.PNCounter) |> IO.inspect()'
    cd {{server_dir}} && {{mix}} run -e 'Laniakea.CRDT.verify(Laniakea.CRDT.ORSet) |> IO.inspect()'
    cd {{server_dir}} && {{mix}} run -e 'Laniakea.CRDT.verify(Laniakea.CRDT.LWWRegister) |> IO.inspect()'

# ============================================================================
# CODE QUALITY
# ============================================================================

# Run all quality checks
quality: format-check lint typecheck
    @echo "{{green}}✓ Quality checks passed{{nc}}"

# Format all code
format: format-server format-client
    @echo "{{green}}✓ Formatting complete{{nc}}"

# Format server code
format-server:
    cd {{server_dir}} && {{mix}} format

# Format client code
format-client:
    cd {{client_dir}} && {{deno}} fmt

# Check formatting without changes
format-check: format-check-server format-check-client

format-check-server:
    cd {{server_dir}} && {{mix}} format --check-formatted

format-check-client:
    cd {{client_dir}} && {{deno}} fmt --check

# Run all linters
lint: lint-server lint-client
    @echo "{{green}}✓ Linting complete{{nc}}"

# Lint server (Credo)
lint-server:
    @echo "{{blue}}=== Linting server ==={{nc}}"
    cd {{server_dir}} && {{mix}} credo --strict

# Lint client (Deno)
lint-client:
    @echo "{{blue}}=== Linting client ==={{nc}}"
    cd {{client_dir}} && {{deno}} lint

# Run type checkers
typecheck: typecheck-server typecheck-client
    @echo "{{green}}✓ Type checking complete{{nc}}"

# Type check server (Dialyzer)
typecheck-server:
    @echo "{{blue}}=== Dialyzer ==={{nc}}"
    cd {{server_dir}} && {{mix}} dialyzer

# Type check client (ReScript + Deno)
typecheck-client:
    @echo "{{blue}}=== ReScript type check ==={{nc}}"
    cd {{client_dir}} && {{rescript}} build
    cd {{client_dir}} && {{deno}} check src/**/*.mjs

# Build Dialyzer PLT (first run takes time)
dialyzer-plt:
    cd {{server_dir}} && {{mix}} dialyzer --plt

# ============================================================================
# DOCUMENTATION
# ============================================================================

# Generate all documentation
docs: docs-server docs-client
    @echo "{{green}}✓ Documentation generated{{nc}}"

# Generate server docs (ExDoc)
docs-server:
    @echo "{{blue}}=== Generating server docs ==={{nc}}"
    cd {{server_dir}} && {{mix}} docs

# Open server docs in browser
docs-server-open:
    just docs-server
    open {{server_dir}}/doc/index.html || xdg-open {{server_dir}}/doc/index.html

# Generate client docs
docs-client:
    @echo "{{blue}}=== Generating client docs ==={{nc}}"
    cd {{client_dir}} && {{deno}} doc --html src/Main.res

# Serve docs locally
docs-serve port="8080":
    cd {{server_dir}}/doc && python3 -m http.server {{port}}

# ============================================================================
# DATABASE (ArangoDB)
# ============================================================================

# Start ArangoDB (Docker)
db-start:
    @echo "{{blue}}=== Starting ArangoDB ==={{nc}}"
    {{docker}} run -d --name laniakea-arango -p 8529:8529 \
        -e ARANGO_ROOT_PASSWORD=laniakea \
        arangodb/arangodb:latest

# Stop ArangoDB
db-stop:
    {{docker}} stop laniakea-arango
    {{docker}} rm laniakea-arango

# Open ArangoDB shell
db-shell:
    {{arango}} --server.endpoint tcp://127.0.0.1:8529 --server.username root

# Create database and collections
db-setup:
    @echo "{{blue}}=== Setting up database ==={{nc}}"
    {{arango}} --server.endpoint tcp://127.0.0.1:8529 \
        --server.username root \
        --server.password laniakea \
        --javascript.execute scripts/db_setup.js

# Reset database
db-reset: db-stop db-start db-setup

# ============================================================================
# DOCKER
# ============================================================================

# Build Docker image
docker-build:
    @echo "{{blue}}=== Building Docker image ==={{nc}}"
    {{docker}} build -t laniakea:{{version}} .

# Build Docker image (no cache)
docker-build-nocache:
    {{docker}} build --no-cache -t laniakea:{{version}} .

# Run in Docker
docker-run:
    {{docker}} run -p 4000:4000 laniakea:{{version}}

# Run Docker Compose
docker-up:
    {{docker}} compose up -d

# Stop Docker Compose
docker-down:
    {{docker}} compose down

# View Docker logs
docker-logs:
    {{docker}} compose logs -f

# Push to registry
docker-push registry="ghcr.io/laniakea":
    {{docker}} tag laniakea:{{version}} {{registry}}/laniakea:{{version}}
    {{docker}} push {{registry}}/laniakea:{{version}}

# ============================================================================
# CI/CD
# ============================================================================

# Run CI checks (same as CI pipeline)
ci: quality test build
    @echo "{{green}}✓ CI checks passed{{nc}}"

# Run CI checks with coverage
ci-full: quality test-server-coverage test-client build
    @echo "{{green}}✓ Full CI checks passed{{nc}}"

# Generate CI config from template
ci-generate:
    @echo "{{blue}}=== Generating CI config ==={{nc}}"
    just --list --unsorted > .ci-recipes.txt
    @echo "CI recipes documented in .ci-recipes.txt"

# ============================================================================
# SECURITY
# ============================================================================

# Run security audit
security-audit: security-audit-server security-audit-deps
    @echo "{{green}}✓ Security audit complete{{nc}}"

# Audit server dependencies
security-audit-server:
    @echo "{{blue}}=== Auditing server deps ==={{nc}}"
    cd {{server_dir}} && {{mix}} deps.audit

# Audit all dependencies
security-audit-deps:
    @echo "{{blue}}=== Checking for vulnerabilities ==={{nc}}"
    cd {{server_dir}} && {{mix}} hex.audit

# Generate SBOM (Software Bill of Materials)
sbom:
    @echo "{{blue}}=== Generating SBOM ==={{nc}}"
    cd {{server_dir}} && {{mix}} sbom.cyclonedx > sbom.json

# ============================================================================
# RSR COMPLIANCE
# ============================================================================

# Check RSR compliance
rsr-check:
    @echo "{{blue}}=== RSR Compliance Check ==={{nc}}"
    @echo "Checking type safety..."
    @just typecheck
    @echo "Checking tests..."
    @just test
    @echo "Checking documentation..."
    @test -f README.adoc && echo "{{green}}✓{{nc}} README.adoc" || echo "{{red}}✗{{nc}} README.adoc"
    @test -f LICENSE && echo "{{green}}✓{{nc}} LICENSE" || echo "{{red}}✗{{nc}} LICENSE"
    @test -f SECURITY.md && echo "{{green}}✓{{nc}} SECURITY.md" || echo "{{red}}✗{{nc}} SECURITY.md"
    @test -f CONTRIBUTING.md && echo "{{green}}✓{{nc}} CONTRIBUTING.md" || echo "{{red}}✗{{nc}} CONTRIBUTING.md"
    @test -f CODE_OF_CONDUCT.md && echo "{{green}}✓{{nc}} CODE_OF_CONDUCT.md" || echo "{{red}}✗{{nc}} CODE_OF_CONDUCT.md"
    @test -f MAINTAINERS.md && echo "{{green}}✓{{nc}} MAINTAINERS.md" || echo "{{red}}✗{{nc}} MAINTAINERS.md"
    @test -f CHANGELOG.md && echo "{{green}}✓{{nc}} CHANGELOG.md" || echo "{{red}}✗{{nc}} CHANGELOG.md"
    @test -f .well-known/security.txt && echo "{{green}}✓{{nc}} .well-known/security.txt" || echo "{{red}}✗{{nc}} .well-known/security.txt"
    @echo "{{green}}✓ RSR compliance check complete{{nc}}"

# Full RSR verification (Bronze level)
rsr-verify-bronze: rsr-check
    @echo "{{blue}}=== RSR Bronze Verification ==={{nc}}"
    @just test-crdt-verify
    @echo "{{green}}✓ Bronze level verified{{nc}}"

# ============================================================================
# BENCHMARKING
# ============================================================================

# Run benchmarks
bench: bench-server bench-client

# Run server benchmarks
bench-server:
    @echo "{{blue}}=== Server benchmarks ==={{nc}}"
    cd {{server_dir}} && {{mix}} run bench/crdt_bench.exs

# Run client benchmarks
bench-client:
    @echo "{{blue}}=== Client benchmarks ==={{nc}}"
    cd {{client_dir}} && {{deno}} bench bench/

# Benchmark CRDT operations
bench-crdt:
    @echo "{{blue}}=== CRDT Operation Benchmarks ==={{nc}}"
    cd {{server_dir}} && {{mix}} run -e '
      Benchee.run(%{
        "GCounter.increment" => fn -> Laniakea.CRDT.GCounter.new() |> Laniakea.CRDT.GCounter.increment("node") end,
        "GCounter.merge" => fn ->
          a = Laniakea.CRDT.GCounter.new() |> Laniakea.CRDT.GCounter.increment("a")
          b = Laniakea.CRDT.GCounter.new() |> Laniakea.CRDT.GCounter.increment("b")
          Laniakea.CRDT.GCounter.merge(a, b)
        end
      })
    '

# ============================================================================
# RELEASE
# ============================================================================

# Create a new release
release version: build-release
    @echo "{{blue}}=== Creating release {{version}} ==={{nc}}"
    git tag -a v{{version}} -m "Release v{{version}}"
    @echo "{{green}}✓ Release v{{version}} created{{nc}}"
    @echo "Run 'git push origin v{{version}}' to publish"

# Publish to Hex.pm
publish-hex:
    @echo "{{blue}}=== Publishing to Hex.pm ==={{nc}}"
    cd {{server_dir}} && {{mix}} hex.publish

# Publish dry run
publish-hex-dry:
    cd {{server_dir}} && {{mix}} hex.publish --dry-run

# ============================================================================
# CONFIGURATION
# ============================================================================

# Validate Nickel configuration
config-validate:
    @echo "{{blue}}=== Validating configuration ==={{nc}}"
    {{nickel}} export {{schemas_dir}}/config.ncl > /dev/null && echo "{{green}}✓{{nc}} config.ncl valid"

# Export configuration to JSON
config-export output="config.json":
    {{nickel}} export {{schemas_dir}}/config.ncl > {{output}}
    @echo "{{green}}✓{{nc}} Exported to {{output}}"

# Generate config from Nickel
config-generate env="dev":
    {{nickel}} export {{schemas_dir}}/config.ncl --field {{env}} > {{server_dir}}/config/generated.json

# ============================================================================
# UTILITIES
# ============================================================================

# Generate a secret key
gen-secret:
    cd {{server_dir}} && {{mix}} phx.gen.secret

# Generate UUID
gen-uuid:
    @{{deno}} eval "console.log(crypto.randomUUID())"

# Count lines of code
loc:
    @echo "{{blue}}=== Lines of Code ==={{nc}}"
    @find {{server_dir}}/lib -name "*.ex" | xargs wc -l | tail -1 | awk '{print "Elixir: " $1}'
    @find {{client_dir}}/src -name "*.res" | xargs wc -l | tail -1 | awk '{print "ReScript: " $1}'

# Show project statistics
stats:
    @echo "{{blue}}=== Project Statistics ==={{nc}}"
    @just loc
    @echo ""
    @echo "Server deps: $(cd {{server_dir}} && {{mix}} deps | wc -l)"
    @echo "CRDTs: $(ls {{server_dir}}/lib/laniakea/crdt/*.ex 2>/dev/null | wc -l)"
    @echo "Tests: $(find {{server_dir}}/test -name "*_test.exs" | wc -l)"

# Watch for changes and run tests
watch:
    cd {{server_dir}} && {{mix}} test.watch

# Open project in VS Code
code:
    code .

# ============================================================================
# NIX
# ============================================================================

# Enter Nix development shell
nix-shell:
    {{nix}} develop

# Build with Nix
nix-build:
    {{nix}} build

# Run Nix checks
nix-check:
    {{nix}} flake check

# Update Nix flake
nix-update:
    {{nix}} flake update

# ============================================================================
# ALIASES (shortcuts)
# ============================================================================

# Alias: build
b: build

# Alias: test
t: test

# Alias: dev
d: dev

# Alias: format
f: format

# Alias: lint
l: lint

# Alias: quality
q: quality

# Alias: console
c: console
