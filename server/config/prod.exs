# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

import Config

# Production endpoint configuration
config :laniakea, LaniakeaWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Production logger level
config :logger, level: :info

# Runtime configuration is in config/runtime.exs
