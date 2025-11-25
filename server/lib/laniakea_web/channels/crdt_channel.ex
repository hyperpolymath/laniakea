# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule LaniakeaWeb.CRDTChannel do
  @moduledoc """
  Phoenix Channel for CRDT synchronization.

  Clients join a topic like "crdt:counter:123" and receive updates
  whenever the CRDT state changes. Commands can be sent to modify state.

  ## Messages

  ### Client → Server

  | Event | Payload | Description |
  |-------|---------|-------------|
  | increment | %{} | Increment G-Counter |
  | increment_by | %{amount: n} | Increment by n |
  | decrement | %{} | Decrement PN-Counter |
  | set | %{value: v} | Set LWW-Register |
  | add | %{element: e} | Add to OR-Set |
  | remove | %{element: e} | Remove from OR-Set |
  | merge | %{state: s} | Merge incoming state |
  | sync | %{} | Request current state |

  ### Server → Client

  | Event | Payload | Description |
  |-------|---------|-------------|
  | state_updated | CRDT state | State changed |
  | sync_response | CRDT state | Response to sync request |
  """

  use Phoenix.Channel
  require Logger

  alias Laniakea.CRDT.{GCounter, PNCounter, ORSet, LWWRegister, Registry}
  alias Laniakea.Policy.Engine, as: Policy

  @impl true
  def join("crdt:" <> key, _params, socket) do
    node_id = socket.assigns.node_id
    profile = socket.assigns.profile

    Logger.debug("[CRDTChannel] #{node_id} joining crdt:#{key}")

    # Subscribe to updates
    Registry.subscribe(key)

    # Get or create the CRDT (default to G-Counter)
    {:ok, crdt} = Registry.get_or_create(key, GCounter)
    crdt_module = crdt.__struct__

    socket =
      socket
      |> assign(:key, key)
      |> assign(:crdt_module, crdt_module)

    # Send initial state
    reply = %{
      state: crdt_module.to_map(crdt),
      profile: Atom.to_string(profile),
      config: Policy.get_profile_config(profile)
    }

    {:ok, reply, socket}
  end

  # ============================================================================
  # Incoming Messages
  # ============================================================================

  @impl true
  def handle_in("increment", _payload, socket) do
    key = socket.assigns.key
    node_id = socket.assigns.node_id

    case Registry.update(key, fn crdt -> GCounter.increment(crdt, node_id) end) do
      {:ok, new_crdt} ->
        broadcast_state(socket, new_crdt)
        {:reply, {:ok, %{state: GCounter.to_map(new_crdt)}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("increment_by", %{"amount" => amount}, socket) do
    key = socket.assigns.key
    node_id = socket.assigns.node_id

    case Registry.update(key, fn crdt -> GCounter.increment_by(crdt, node_id, amount) end) do
      {:ok, new_crdt} ->
        broadcast_state(socket, new_crdt)
        {:reply, {:ok, %{state: GCounter.to_map(new_crdt)}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("decrement", _payload, socket) do
    key = socket.assigns.key
    node_id = socket.assigns.node_id

    # Ensure we have a PN-Counter
    {:ok, crdt} = Registry.get_or_create(key, PNCounter)

    case crdt do
      %PNCounter{} ->
        {:ok, new_crdt} = Registry.update(key, fn c -> PNCounter.decrement(c, node_id) end)
        broadcast_state(socket, new_crdt)
        {:reply, {:ok, %{state: PNCounter.to_map(new_crdt)}}, socket}

      _ ->
        {:reply, {:error, %{reason: "decrement only supported for PN-Counter"}}, socket}
    end
  end

  def handle_in("set", %{"value" => value}, socket) do
    key = socket.assigns.key
    node_id = socket.assigns.node_id

    {:ok, _} = Registry.get_or_create(key, LWWRegister)

    {:ok, new_crdt} = Registry.update(key, fn crdt ->
      LWWRegister.set(crdt, value, node_id)
    end)

    broadcast_state(socket, new_crdt)
    {:reply, {:ok, %{state: LWWRegister.to_map(new_crdt)}}, socket}
  end

  def handle_in("add", %{"element" => element}, socket) do
    key = socket.assigns.key
    node_id = socket.assigns.node_id

    {:ok, _} = Registry.get_or_create(key, ORSet)

    {:ok, new_crdt} = Registry.update(key, fn crdt ->
      ORSet.add(crdt, element, node_id)
    end)

    broadcast_state(socket, new_crdt)
    {:reply, {:ok, %{state: ORSet.to_map(new_crdt)}}, socket}
  end

  def handle_in("remove", %{"element" => element}, socket) do
    key = socket.assigns.key

    case Registry.get(key) do
      %ORSet{} = set ->
        new_set = ORSet.remove(set, element)
        Registry.put(key, new_set)
        broadcast_state(socket, new_set)
        {:reply, {:ok, %{state: ORSet.to_map(new_set)}}, socket}

      nil ->
        {:reply, {:error, %{reason: "CRDT not found"}}, socket}

      _ ->
        {:reply, {:error, %{reason: "remove only supported for OR-Set"}}, socket}
    end
  end

  def handle_in("merge", %{"state" => incoming_state}, socket) do
    key = socket.assigns.key

    case Laniakea.CRDT.from_wire(incoming_state) do
      {:ok, incoming_crdt} ->
        {:ok, merged} = Registry.merge(key, incoming_crdt)
        crdt_module = merged.__struct__
        broadcast_state(socket, merged)
        {:reply, {:ok, %{state: crdt_module.to_map(merged)}}, socket}

      {:error, _} ->
        {:reply, {:error, %{reason: "Invalid CRDT state"}}, socket}
    end
  end

  def handle_in("sync", _payload, socket) do
    key = socket.assigns.key

    case Registry.get(key) do
      nil ->
        {:reply, {:error, %{reason: "CRDT not found"}}, socket}

      crdt ->
        crdt_module = crdt.__struct__
        {:reply, {:ok, %{state: crdt_module.to_map(crdt)}}, socket}
    end
  end

  # ============================================================================
  # Broadcasts
  # ============================================================================

  @impl true
  def handle_info({:crdt_updated, _key, state}, socket) do
    push(socket, "state_updated", %{state: state})
    {:noreply, socket}
  end

  defp broadcast_state(socket, crdt) do
    crdt_module = crdt.__struct__
    broadcast_from!(socket, "state_updated", %{state: crdt_module.to_map(crdt)})
  end

  # ============================================================================
  # Termination
  # ============================================================================

  @impl true
  def terminate(_reason, socket) do
    key = socket.assigns[:key]
    node_id = socket.assigns[:node_id]

    if key, do: Registry.unsubscribe(key)
    if node_id, do: Policy.unregister_client(node_id)

    :ok
  end
end
