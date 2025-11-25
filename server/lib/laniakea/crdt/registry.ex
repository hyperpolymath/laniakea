# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule Laniakea.CRDT.Registry do
  @moduledoc """
  In-memory CRDT state registry.

  Stores CRDT instances by key and provides operations for:
  - Getting and setting CRDTs
  - Merging incoming state
  - Computing deltas for synchronization
  - Broadcasting updates to subscribers

  ## Architecture

  The registry is a GenServer that maintains a map of CRDT instances.
  It is designed to be the single source of truth on the server,
  although clients maintain their own copies that converge via CRDT merging.

  ## Persistence

  For persistence, the registry can optionally sync to ArangoDB.
  See `Laniakea.Storage.ArangoDB` for the persistence layer.

  ## Examples

      # Get or create a counter
      {:ok, counter} = Registry.get_or_create("likes:post:123", Laniakea.CRDT.GCounter)

      # Update and broadcast
      {:ok, new_counter} = Registry.update("likes:post:123", fn c ->
        Laniakea.CRDT.GCounter.increment(c, "user_456")
      end)

      # Merge incoming state from client
      {:ok, merged} = Registry.merge("likes:post:123", incoming_crdt)
  """

  use GenServer
  require Logger

  alias Laniakea.CRDT

  @type key :: String.t()
  @type state :: %{
          crdts: %{key() => CRDT.crdt()},
          subscribers: %{key() => [pid()]}
        }

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the CRDT Registry.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Gets a CRDT by key. Returns nil if not found.
  """
  @spec get(key()) :: CRDT.crdt() | nil
  def get(key), do: GenServer.call(__MODULE__, {:get, key})

  @doc """
  Gets a CRDT by key, or creates a new one if not found.
  """
  @spec get_or_create(key(), module()) :: {:ok, CRDT.crdt()}
  def get_or_create(key, crdt_module) do
    GenServer.call(__MODULE__, {:get_or_create, key, crdt_module})
  end

  @doc """
  Sets a CRDT directly. Use `update/2` for most cases.
  """
  @spec put(key(), CRDT.crdt()) :: :ok
  def put(key, crdt), do: GenServer.call(__MODULE__, {:put, key, crdt})

  @doc """
  Updates a CRDT using a function. Broadcasts the update to subscribers.
  """
  @spec update(key(), (CRDT.crdt() -> CRDT.crdt())) :: {:ok, CRDT.crdt()} | {:error, :not_found}
  def update(key, fun) when is_function(fun, 1) do
    GenServer.call(__MODULE__, {:update, key, fun})
  end

  @doc """
  Merges incoming CRDT state with existing state.
  This is the core CRDT operation - used when receiving state from clients.
  """
  @spec merge(key(), CRDT.crdt()) :: {:ok, CRDT.crdt()}
  def merge(key, incoming_crdt) do
    GenServer.call(__MODULE__, {:merge, key, incoming_crdt})
  end

  @doc """
  Computes the delta between current state and a client's last known version.
  """
  @spec delta(key(), CRDT.crdt()) :: {:ok, CRDT.crdt()} | {:error, :not_found}
  def delta(key, client_state) do
    GenServer.call(__MODULE__, {:delta, key, client_state})
  end

  @doc """
  Subscribes a process to updates for a key.
  """
  @spec subscribe(key()) :: :ok
  def subscribe(key), do: GenServer.cast(__MODULE__, {:subscribe, key, self()})

  @doc """
  Unsubscribes a process from updates for a key.
  """
  @spec unsubscribe(key()) :: :ok
  def unsubscribe(key), do: GenServer.cast(__MODULE__, {:unsubscribe, key, self()})

  @doc """
  Lists all keys in the registry.
  """
  @spec keys() :: [key()]
  def keys, do: GenServer.call(__MODULE__, :keys)

  @doc """
  Deletes a CRDT from the registry.
  """
  @spec delete(key()) :: :ok
  def delete(key), do: GenServer.call(__MODULE__, {:delete, key})

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    state = %{
      crdts: %{},
      subscribers: %{}
    }

    Logger.info("[CRDT.Registry] Started")
    {:ok, state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    crdt = Map.get(state.crdts, key)
    {:reply, crdt, state}
  end

  def handle_call({:get_or_create, key, crdt_module}, _from, state) do
    case Map.get(state.crdts, key) do
      nil ->
        new_crdt = crdt_module.new()
        new_state = put_in(state.crdts[key], new_crdt)
        {:reply, {:ok, new_crdt}, new_state}

      existing ->
        {:reply, {:ok, existing}, state}
    end
  end

  def handle_call({:put, key, crdt}, _from, state) do
    new_state = put_in(state.crdts[key], crdt)
    broadcast_update(key, crdt, state.subscribers)
    {:reply, :ok, new_state}
  end

  def handle_call({:update, key, fun}, _from, state) do
    case Map.get(state.crdts, key) do
      nil ->
        {:reply, {:error, :not_found}, state}

      current ->
        updated = fun.(current)
        new_state = put_in(state.crdts[key], updated)
        broadcast_update(key, updated, state.subscribers)
        {:reply, {:ok, updated}, new_state}
    end
  end

  def handle_call({:merge, key, incoming_crdt}, _from, state) do
    current = Map.get(state.crdts, key)
    crdt_module = incoming_crdt.__struct__

    merged =
      case current do
        nil -> incoming_crdt
        _ -> crdt_module.merge(current, incoming_crdt)
      end

    new_state = put_in(state.crdts[key], merged)
    broadcast_update(key, merged, state.subscribers)
    {:reply, {:ok, merged}, new_state}
  end

  def handle_call({:delta, key, client_state}, _from, state) do
    case Map.get(state.crdts, key) do
      nil ->
        {:reply, {:error, :not_found}, state}

      current ->
        crdt_module = current.__struct__

        if function_exported?(crdt_module, :delta, 2) do
          delta = crdt_module.delta(client_state, current)
          {:reply, {:ok, delta}, state}
        else
          # Fallback: send full state
          {:reply, {:ok, current}, state}
        end
    end
  end

  def handle_call(:keys, _from, state) do
    {:reply, Map.keys(state.crdts), state}
  end

  def handle_call({:delete, key}, _from, state) do
    new_state = %{
      state
      | crdts: Map.delete(state.crdts, key),
        subscribers: Map.delete(state.subscribers, key)
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:subscribe, key, pid}, state) do
    current_subs = Map.get(state.subscribers, key, [])
    new_subs = [pid | current_subs] |> Enum.uniq()
    new_state = put_in(state.subscribers[key], new_subs)
    {:noreply, new_state}
  end

  def handle_cast({:unsubscribe, key, pid}, state) do
    current_subs = Map.get(state.subscribers, key, [])
    new_subs = List.delete(current_subs, pid)
    new_state = put_in(state.subscribers[key], new_subs)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Clean up subscriber on process death
    new_subscribers =
      Map.new(state.subscribers, fn {key, subs} ->
        {key, List.delete(subs, pid)}
      end)

    {:noreply, %{state | subscribers: new_subscribers}}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp broadcast_update(key, crdt, subscribers) do
    pids = Map.get(subscribers, key, [])
    crdt_module = crdt.__struct__
    message = {:crdt_updated, key, crdt_module.to_map(crdt)}

    Enum.each(pids, fn pid ->
      send(pid, message)
    end)

    # Also broadcast via PubSub for Phoenix Channels
    Phoenix.PubSub.broadcast(Laniakea.PubSub, "crdt:#{key}", message)
  end
end
