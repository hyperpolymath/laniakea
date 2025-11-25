# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

import Config

# Runtime configuration for production
if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :laniakea, LaniakeaWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ArangoDB configuration (optional persistence)
  if System.get_env("ARANGO_URL") do
    config :laniakea, Laniakea.Storage.ArangoDB,
      url: System.get_env("ARANGO_URL"),
      database: System.get_env("ARANGO_DATABASE") || "laniakea",
      username: System.get_env("ARANGO_USERNAME"),
      password: System.get_env("ARANGO_PASSWORD")
  end
end
