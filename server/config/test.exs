# SPDX-License-Identifier: MPL-2.0
# Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
import Config

# Test endpoint configuration
config :laniakea, LaniakeaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_that_is_at_least_64_characters_long_for_testing",
  server: false

# Test logger level (less noise)
config :logger, level: :warning

# Initialize plugs at runtime for faster compilation
config :phoenix, :plug_init_mode, :runtime
