# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule Laniakea.Application do
  @moduledoc """
  OTP Application for Laniakea.

  Starts the supervision tree with:
  - CRDT Registry (state storage)
  - Command Bus (command processing)
  - Policy Engine (capability negotiation)
  - Phoenix Endpoint (HTTP + WebSocket)
  - Telemetry (observability)
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Telemetry supervisor
      LaniakeaWeb.Telemetry,

      # CRDT state registry
      {Laniakea.CRDT.Registry, name: Laniakea.CRDT.Registry},

      # Command processing
      {Laniakea.Command.Bus, name: Laniakea.Command.Bus},

      # Policy engine for capability negotiation
      {Laniakea.Policy.Engine, name: Laniakea.Policy.Engine},

      # PubSub for Phoenix Channels
      {Phoenix.PubSub, name: Laniakea.PubSub},

      # Phoenix Endpoint (HTTP + WebSocket)
      LaniakeaWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Laniakea.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      # Log startup info
      log_startup_info()
      {:ok, pid}
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    LaniakeaWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp log_startup_info do
    require Logger

    Logger.info("""

    ╔═══════════════════════════════════════════════════════════════════╗
    ║                         LANIAKEA                                  ║
    ║         Distributed state finds its way home                      ║
    ╠═══════════════════════════════════════════════════════════════════╣
    ║  Version:    #{Application.spec(:laniakea, :vsn) || "dev"}
    ║  CRDTs:      G-Counter, PN-Counter, OR-Set, LWW-Register
    ║  Transport:  Phoenix Channels (WebSocket)
    ║  Policy:     Capability-based adaptation
    ╚═══════════════════════════════════════════════════════════════════╝
    """)
  end
end
