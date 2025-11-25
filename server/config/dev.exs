# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

import Config

# Development endpoint configuration
config :laniakea, LaniakeaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_that_is_at_least_64_characters_long_for_security",
  watchers: []

# Development logger level
config :logger, :console, format: "[$level] $message\n"

# Development-specific settings
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
