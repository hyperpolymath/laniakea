# SPDX-License-Identifier: MIT OR Apache-2.0
# Laniakea Configuration Schema (Nickel)
#
# This file defines the configuration schema for Laniakea.
# Use `nickel export config.ncl` to generate JSON/YAML config.

# ============================================================================
# TYPE CONTRACTS
# ============================================================================

let Port = std.contract.from_predicate (fun x => x >= 1 && x <= 65535) in
let PositiveInt = std.contract.from_predicate (fun x => x > 0) in
let NonEmptyString = std.contract.from_predicate (fun x => std.string.length x > 0) in

let Profile = std.contract.from_predicate (fun x =>
  x == "full" || x == "constrained" || x == "minimal"
) in

let LogLevel = std.contract.from_predicate (fun x =>
  x == "debug" || x == "info" || x == "warning" || x == "error"
) in

let Environment = std.contract.from_predicate (fun x =>
  x == "dev" || x == "test" || x == "prod"
) in

# ============================================================================
# CONFIGURATION RECORDS
# ============================================================================

let ServerConfig = {
  host | NonEmptyString | default = "localhost",
  port | Port | default = 4000,
  secret_key_base | NonEmptyString | optional,
  check_origin | Bool | default = true,
  code_reloader | Bool | default = false,
} in

let CRDTConfig = {
  # Default CRDT types for auto-creation
  default_counter_type | NonEmptyString | default = "g_counter",
  default_set_type | NonEmptyString | default = "or_set",
  default_register_type | NonEmptyString | default = "lww_register",

  # Delta sync settings
  delta_sync_enabled | Bool | default = true,
  delta_batch_size | PositiveInt | default = 100,

  # Garbage collection (for tombstones)
  gc_enabled | Bool | default = true,
  gc_interval_ms | PositiveInt | default = 60000,
} in

let PolicyConfig = {
  # Profile configurations
  profiles = {
    full = {
      update_frequency_ms | PositiveInt = 16,
      batch_events | Bool = false,
      delta_sync | Bool = true,
      server_render | Bool = false,
      max_batch_size | PositiveInt = 1,
    },
    constrained = {
      update_frequency_ms | PositiveInt = 100,
      batch_events | Bool = true,
      delta_sync | Bool = true,
      server_render | Bool = false,
      max_batch_size | PositiveInt = 10,
    },
    minimal = {
      update_frequency_ms | PositiveInt = 1000,
      batch_events | Bool = true,
      delta_sync | Bool = false,
      server_render | Bool = true,
      max_batch_size | PositiveInt = 50,
    },
  },

  # Capability thresholds
  thresholds = {
    full_client_memory_mb | PositiveInt = 2048,
    constrained_client_memory_mb | PositiveInt = 512,
  },
} in

let TransportConfig = {
  # WebSocket
  websocket = {
    enabled | Bool = true,
    timeout_ms | PositiveInt = 45000,
    compress | Bool = true,
  },

  # WebTransport (future)
  webtransport = {
    enabled | Bool = false,
    port | Port | optional,
  },

  # Long polling (fallback)
  longpoll = {
    enabled | Bool = false,
    window_ms | PositiveInt = 10000,
  },
} in

let ArangoDBConfig = {
  enabled | Bool | default = false,
  url | NonEmptyString | default = "http://localhost:8529",
  database | NonEmptyString | default = "laniakea",
  username | NonEmptyString | optional,
  password | NonEmptyString | optional,

  # Collections
  collections = {
    crdts | NonEmptyString = "crdts",
    events | NonEmptyString = "events",
    clients | NonEmptyString = "clients",
  },

  # Connection pool
  pool_size | PositiveInt | default = 10,
} in

let TelemetryConfig = {
  enabled | Bool | default = true,

  # OpenTelemetry
  otel = {
    enabled | Bool = false,
    endpoint | NonEmptyString | optional,
    service_name | NonEmptyString = "laniakea",
  },

  # Metrics
  metrics = {
    enabled | Bool = true,
    port | Port | default = 9568,
  },
} in

let LoggingConfig = {
  level | LogLevel | default = "info",
  format | NonEmptyString | default = "$time $metadata[$level] $message\n",
  metadata | Array NonEmptyString | default = ["request_id", "node_id"],
} in

# ============================================================================
# ENVIRONMENT CONFIGURATIONS
# ============================================================================

let DevConfig = {
  environment = "dev",

  server = ServerConfig & {
    code_reloader = true,
    check_origin = false,
  },

  crdt = CRDTConfig,
  policy = PolicyConfig,
  transport = TransportConfig,

  database = ArangoDBConfig & {
    enabled = false,
  },

  telemetry = TelemetryConfig & {
    otel.enabled = false,
  },

  logging = LoggingConfig & {
    level = "debug",
  },
} in

let TestConfig = {
  environment = "test",

  server = ServerConfig & {
    port = 4002,
  },

  crdt = CRDTConfig,
  policy = PolicyConfig,
  transport = TransportConfig,

  database = ArangoDBConfig & {
    enabled = false,
  },

  telemetry = TelemetryConfig & {
    enabled = false,
  },

  logging = LoggingConfig & {
    level = "warning",
  },
} in

let ProdConfig = {
  environment = "prod",

  server = ServerConfig & {
    host = "%{PHX_HOST}",
    port = 4000,
    secret_key_base = "%{SECRET_KEY_BASE}",
    check_origin = true,
    code_reloader = false,
  },

  crdt = CRDTConfig & {
    gc_enabled = true,
    gc_interval_ms = 300000,
  },

  policy = PolicyConfig,

  transport = TransportConfig & {
    websocket.timeout_ms = 60000,
  },

  database = ArangoDBConfig & {
    enabled = true,
    url = "%{ARANGO_URL}",
    username = "%{ARANGO_USERNAME}",
    password = "%{ARANGO_PASSWORD}",
    pool_size = 20,
  },

  telemetry = TelemetryConfig & {
    otel = {
      enabled = true,
      endpoint = "%{OTEL_ENDPOINT}",
    },
  },

  logging = LoggingConfig & {
    level = "info",
  },
} in

# ============================================================================
# EXPORTS
# ============================================================================

{
  # Export specific environment
  dev = DevConfig,
  test = TestConfig,
  prod = ProdConfig,

  # Default export
  default = DevConfig,

  # Type contracts (for schema validation)
  contracts = {
    ServerConfig,
    CRDTConfig,
    PolicyConfig,
    TransportConfig,
    ArangoDBConfig,
    TelemetryConfig,
    LoggingConfig,
  },
}
