# SPDX-License-Identifier: MPL-2.0
# Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
import Config

# Production endpoint configuration
config :laniakea, LaniakeaWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Production logger level
config :logger, level: :info

# Runtime configuration is in config/runtime.exs
