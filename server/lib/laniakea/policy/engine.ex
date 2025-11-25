# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule Laniakea.Policy.Engine do
  @moduledoc """
  Capability-based policy engine for adaptive client behavior.

  Clients probe their capabilities (Web Workers, SharedArrayBuffer, memory,
  network type) and send them to the server. The policy engine assigns a
  profile that determines how the server interacts with that client.

  ## Profiles

  | Profile | Update Frequency | Batching | Delta Sync | Server Render |
  |---------|------------------|----------|------------|---------------|
  | full | 16ms (60fps) | No | Yes | No |
  | constrained | 100ms (10fps) | Yes | Yes | No |
  | minimal | 1000ms (1fps) | Yes | No | Yes |

  ## Example

      capabilities = %{
        has_workers: true,
        has_sab: true,
        has_webtransport: false,
        memory_mb: 4096,
        connection_type: :wifi,
        effective_type: :_4g
      }

      profile = Policy.Engine.assign_profile(capabilities)
      # => :full
  """

  use GenServer
  require Logger

  @type node_id :: String.t()
  @type profile :: :full | :constrained | :minimal
  @type capabilities :: %{
          has_workers: boolean(),
          has_sab: boolean(),
          has_webtransport: boolean(),
          memory_mb: non_neg_integer(),
          connection_type: atom(),
          effective_type: atom()
        }

  @type profile_config :: %{
          update_frequency_ms: pos_integer(),
          batch_events: boolean(),
          delta_sync: boolean(),
          server_render: boolean(),
          max_batch_size: pos_integer()
        }

  @profiles %{
    full: %{
      update_frequency_ms: 16,
      batch_events: false,
      delta_sync: true,
      server_render: false,
      max_batch_size: 1
    },
    constrained: %{
      update_frequency_ms: 100,
      batch_events: true,
      delta_sync: true,
      server_render: false,
      max_batch_size: 10
    },
    minimal: %{
      update_frequency_ms: 1000,
      batch_events: true,
      delta_sync: false,
      server_render: true,
      max_batch_size: 50
    }
  }

  # ============================================================================
  # Client API
  # ============================================================================

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Assigns a profile based on client capabilities.

  ## Examples

      iex> caps = %{has_workers: true, has_sab: true, memory_mb: 4096, connection_type: :wifi}
      iex> Policy.Engine.assign_profile(caps)
      :full
  """
  @spec assign_profile(capabilities()) :: profile()
  def assign_profile(capabilities) do
    cond do
      full_client?(capabilities) -> :full
      constrained_client?(capabilities) -> :constrained
      true -> :minimal
    end
  end

  @doc """
  Gets the configuration for a profile.
  """
  @spec get_profile_config(profile()) :: profile_config()
  def get_profile_config(profile) do
    Map.get(@profiles, profile, @profiles.minimal)
  end

  @doc """
  Registers a client with their capabilities.
  """
  @spec register_client(node_id(), capabilities()) :: {:ok, profile()}
  def register_client(node_id, capabilities) do
    GenServer.call(__MODULE__, {:register, node_id, capabilities})
  end

  @doc """
  Gets the profile for a registered client.
  """
  @spec get_client_profile(node_id()) :: {:ok, profile()} | {:error, :not_found}
  def get_client_profile(node_id) do
    GenServer.call(__MODULE__, {:get_profile, node_id})
  end

  @doc """
  Updates a client's capabilities (e.g., network change).
  """
  @spec update_capabilities(node_id(), capabilities()) :: {:ok, profile()}
  def update_capabilities(node_id, capabilities) do
    GenServer.call(__MODULE__, {:update, node_id, capabilities})
  end

  @doc """
  Unregisters a client.
  """
  @spec unregister_client(node_id()) :: :ok
  def unregister_client(node_id) do
    GenServer.cast(__MODULE__, {:unregister, node_id})
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    state = %{
      clients: %{}  # node_id => %{capabilities: ..., profile: ...}
    }

    Logger.info("[Policy.Engine] Started")
    {:ok, state}
  end

  @impl true
  def handle_call({:register, node_id, capabilities}, _from, state) do
    profile = assign_profile(capabilities)

    client_info = %{
      capabilities: capabilities,
      profile: profile,
      registered_at: DateTime.utc_now()
    }

    new_state = put_in(state.clients[node_id], client_info)

    Logger.debug("[Policy.Engine] Registered #{node_id} with profile #{profile}")

    {:reply, {:ok, profile}, new_state}
  end

  def handle_call({:get_profile, node_id}, _from, state) do
    case Map.get(state.clients, node_id) do
      nil -> {:reply, {:error, :not_found}, state}
      %{profile: profile} -> {:reply, {:ok, profile}, state}
    end
  end

  def handle_call({:update, node_id, capabilities}, _from, state) do
    profile = assign_profile(capabilities)

    case Map.get(state.clients, node_id) do
      nil ->
        client_info = %{
          capabilities: capabilities,
          profile: profile,
          registered_at: DateTime.utc_now()
        }

        new_state = put_in(state.clients[node_id], client_info)
        {:reply, {:ok, profile}, new_state}

      existing ->
        old_profile = existing.profile

        updated = %{
          existing
          | capabilities: capabilities,
            profile: profile
        }

        new_state = put_in(state.clients[node_id], updated)

        if old_profile != profile do
          Logger.info("[Policy.Engine] #{node_id} profile changed: #{old_profile} -> #{profile}")
        end

        {:reply, {:ok, profile}, new_state}
    end
  end

  @impl true
  def handle_cast({:unregister, node_id}, state) do
    new_state = %{state | clients: Map.delete(state.clients, node_id)}
    {:noreply, new_state}
  end

  # ============================================================================
  # Profile Detection
  # ============================================================================

  defp full_client?(capabilities) do
    capabilities[:has_workers] == true and
      capabilities[:has_sab] == true and
      (capabilities[:memory_mb] || 0) >= 2048 and
      good_connection?(capabilities)
  end

  defp constrained_client?(capabilities) do
    capabilities[:has_workers] == true and
      (capabilities[:memory_mb] || 0) >= 512
  end

  defp good_connection?(capabilities) do
    capabilities[:connection_type] in [:wifi, :ethernet, :_4g] or
      capabilities[:effective_type] in [:_4g]
  end
end
