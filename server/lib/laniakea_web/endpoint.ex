# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule LaniakeaWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :laniakea

  # Session configuration
  @session_options [
    store: :cookie,
    key: "_laniakea_key",
    signing_salt: "laniakea_salt",
    same_site: "Lax"
  ]

  # WebSocket for Phoenix Channels
  socket "/socket", LaniakeaWeb.UserSocket,
    websocket: [
      timeout: 45_000,
      compress: true
    ],
    longpoll: false

  # Serve static assets
  plug Plug.Static,
    at: "/",
    from: :laniakea,
    gzip: true,
    only: LaniakeaWeb.static_paths()

  # Code reloading in dev
  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  # CORS for API access
  plug CORSPlug,
    origin: ["http://localhost:8000", "http://localhost:5173"],
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    headers: ["Authorization", "Content-Type", "X-Request-Id"]

  plug LaniakeaWeb.Router
end
