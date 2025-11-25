# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

import Config

# General application configuration
config :laniakea,
  generators: [timestamp_type: :utc_datetime]

# Phoenix endpoint configuration
config :laniakea, LaniakeaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: LaniakeaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Laniakea.PubSub,
  live_view: [signing_salt: "laniakea_lv"]

# JSON library
config :phoenix, :json_library, Jason

# Logger configuration
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :node_id]

# Import environment specific config
import_config "#{config_env()}.exs"
