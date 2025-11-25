# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule LaniakeaWeb.UserSocket do
  use Phoenix.Socket
  require Logger

  # Channel routes
  channel "crdt:*", LaniakeaWeb.CRDTChannel

  @impl true
  def connect(%{"node_id" => node_id, "capabilities" => capabilities}, socket, _connect_info) do
    # Parse capabilities
    parsed_caps = parse_capabilities(capabilities)

    # Assign profile
    profile = Laniakea.Policy.Engine.assign_profile(parsed_caps)
    {:ok, _} = Laniakea.Policy.Engine.register_client(node_id, parsed_caps)

    Logger.info("[UserSocket] Connected: #{node_id} with profile #{profile}")

    socket =
      socket
      |> assign(:node_id, node_id)
      |> assign(:capabilities, parsed_caps)
      |> assign(:profile, profile)

    {:ok, socket}
  end

  def connect(%{"node_id" => node_id}, socket, _connect_info) do
    # No capabilities provided - assign minimal profile
    Logger.info("[UserSocket] Connected without capabilities: #{node_id}")

    socket =
      socket
      |> assign(:node_id, node_id)
      |> assign(:profile, :minimal)

    {:ok, socket}
  end

  def connect(_params, _socket, _connect_info) do
    # Reject connections without node_id
    :error
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.node_id}"

  defp parse_capabilities(caps) when is_map(caps) do
    %{
      has_workers: Map.get(caps, "hasWorkers", false),
      has_sab: Map.get(caps, "hasSharedArrayBuffer", false),
      has_webtransport: Map.get(caps, "hasWebTransport", false),
      memory_mb: Map.get(caps, "memoryMb", 512),
      connection_type: parse_connection_type(Map.get(caps, "connectionType")),
      effective_type: parse_effective_type(Map.get(caps, "effectiveType"))
    }
  end

  defp parse_capabilities(_), do: %{}

  defp parse_connection_type("wifi"), do: :wifi
  defp parse_connection_type("ethernet"), do: :ethernet
  defp parse_connection_type("cellular"), do: :cellular
  defp parse_connection_type(_), do: :unknown

  defp parse_effective_type("4g"), do: :_4g
  defp parse_effective_type("3g"), do: :_3g
  defp parse_effective_type("2g"), do: :_2g
  defp parse_effective_type("slow-2g"), do: :slow_2g
  defp parse_effective_type(_), do: :unknown
end
