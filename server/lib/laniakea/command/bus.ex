# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule Laniakea.Command.Bus do
  @moduledoc """
  Command bus for processing typed commands from clients.

  Commands are validated, executed, and may trigger events. The command bus
  provides:

  - **Validation**: Type checking and business rule validation
  - **Idempotency**: Request IDs prevent duplicate processing
  - **Observability**: Telemetry events for all commands

  ## Command Envelope Format

      %{
        "type" => "crdt.increment",
        "payload" => %{"key" => "counter:123", "node_id" => "user_456"},
        "request_id" => "uuid-here",
        "timestamp" => 1699999999999
      }

  ## Supported Commands

  | Type | Payload | Description |
  |------|---------|-------------|
  | crdt.increment | key, node_id | Increment G-Counter |
  | crdt.increment_by | key, node_id, amount | Increment by amount |
  | crdt.decrement | key, node_id | Decrement PN-Counter |
  | crdt.set | key, node_id, value | Set LWW-Register |
  | crdt.add | key, node_id, element | Add to OR-Set |
  | crdt.remove | key, element | Remove from OR-Set |
  | crdt.merge | key, state | Merge incoming CRDT state |
  """

  use GenServer
  require Logger

  alias Laniakea.CRDT
  alias Laniakea.CRDT.{GCounter, PNCounter, ORSet, LWWRegister, Registry}

  @type command :: %{
          type: String.t(),
          payload: map(),
          request_id: String.t(),
          timestamp: integer()
        }

  @type result :: {:ok, map()} | {:error, atom(), String.t()}

  # ============================================================================
  # Client API
  # ============================================================================

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Executes a command and returns the result.

  ## Examples

      command = %{
        "type" => "crdt.increment",
        "payload" => %{"key" => "likes:post:1", "node_id" => "user_123"},
        "request_id" => UUID.uuid4()
      }

      {:ok, %{state: new_state}} = Bus.execute(command)
  """
  @spec execute(map()) :: result()
  def execute(command) do
    GenServer.call(__MODULE__, {:execute, command})
  end

  @doc """
  Validates a command without executing it.
  """
  @spec validate(map()) :: :ok | {:error, atom(), String.t()}
  def validate(command) do
    GenServer.call(__MODULE__, {:validate, command})
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    state = %{
      processed_requests: %{}  # request_id => timestamp (for idempotency)
    }

    Logger.info("[Command.Bus] Started")
    {:ok, state}
  end

  @impl true
  def handle_call({:execute, command}, _from, state) do
    request_id = command["request_id"]

    # Check idempotency
    if request_id && Map.has_key?(state.processed_requests, request_id) do
      {:reply, {:error, :duplicate, "Request already processed"}, state}
    else
      # Emit telemetry
      start_time = System.monotonic_time()

      result = execute_command(command)

      :telemetry.execute(
        [:laniakea, :command, :executed],
        %{duration: System.monotonic_time() - start_time},
        %{type: command["type"], request_id: request_id}
      )

      # Track processed request
      new_state =
        if request_id do
          put_in(state.processed_requests[request_id], System.system_time(:millisecond))
        else
          state
        end

      {:reply, result, new_state}
    end
  end

  def handle_call({:validate, command}, _from, state) do
    result = validate_command(command)
    {:reply, result, state}
  end

  # ============================================================================
  # Command Execution
  # ============================================================================

  defp execute_command(%{"type" => "crdt.increment", "payload" => payload}) do
    with {:ok, key} <- get_required(payload, "key"),
         {:ok, node_id} <- get_required(payload, "node_id"),
         {:ok, counter} <- Registry.get_or_create(key, GCounter) do
      new_counter = GCounter.increment(counter, node_id)
      Registry.put(key, new_counter)
      {:ok, %{state: GCounter.to_map(new_counter)}}
    end
  end

  defp execute_command(%{"type" => "crdt.increment_by", "payload" => payload}) do
    with {:ok, key} <- get_required(payload, "key"),
         {:ok, node_id} <- get_required(payload, "node_id"),
         {:ok, amount} <- get_required(payload, "amount"),
         {:ok, counter} <- Registry.get_or_create(key, GCounter) do
      new_counter = GCounter.increment_by(counter, node_id, amount)
      Registry.put(key, new_counter)
      {:ok, %{state: GCounter.to_map(new_counter)}}
    end
  end

  defp execute_command(%{"type" => "crdt.decrement", "payload" => payload}) do
    with {:ok, key} <- get_required(payload, "key"),
         {:ok, node_id} <- get_required(payload, "node_id"),
         {:ok, counter} <- Registry.get_or_create(key, PNCounter) do
      new_counter = PNCounter.decrement(counter, node_id)
      Registry.put(key, new_counter)
      {:ok, %{state: PNCounter.to_map(new_counter)}}
    end
  end

  defp execute_command(%{"type" => "crdt.set", "payload" => payload}) do
    with {:ok, key} <- get_required(payload, "key"),
         {:ok, node_id} <- get_required(payload, "node_id"),
         {:ok, value} <- get_required(payload, "value"),
         {:ok, register} <- Registry.get_or_create(key, LWWRegister) do
      new_register = LWWRegister.set(register, value, node_id)
      Registry.put(key, new_register)
      {:ok, %{state: LWWRegister.to_map(new_register)}}
    end
  end

  defp execute_command(%{"type" => "crdt.add", "payload" => payload}) do
    with {:ok, key} <- get_required(payload, "key"),
         {:ok, node_id} <- get_required(payload, "node_id"),
         {:ok, element} <- get_required(payload, "element"),
         {:ok, set} <- Registry.get_or_create(key, ORSet) do
      new_set = ORSet.add(set, element, node_id)
      Registry.put(key, new_set)
      {:ok, %{state: ORSet.to_map(new_set)}}
    end
  end

  defp execute_command(%{"type" => "crdt.remove", "payload" => payload}) do
    with {:ok, key} <- get_required(payload, "key"),
         {:ok, element} <- get_required(payload, "element") do
      case Registry.get(key) do
        nil ->
          {:error, :not_found, "CRDT not found"}

        %ORSet{} = set ->
          new_set = ORSet.remove(set, element)
          Registry.put(key, new_set)
          {:ok, %{state: ORSet.to_map(new_set)}}

        _ ->
          {:error, :invalid_operation, "Remove only supported for OR-Set"}
      end
    end
  end

  defp execute_command(%{"type" => "crdt.merge", "payload" => payload}) do
    with {:ok, key} <- get_required(payload, "key"),
         {:ok, incoming_state} <- get_required(payload, "state"),
         {:ok, incoming_crdt} <- CRDT.from_wire(incoming_state) do
      {:ok, merged} = Registry.merge(key, incoming_crdt)
      crdt_module = merged.__struct__
      {:ok, %{state: crdt_module.to_map(merged)}}
    end
  end

  defp execute_command(%{"type" => type}) do
    {:error, :unknown_command, "Unknown command type: #{type}"}
  end

  defp execute_command(_) do
    {:error, :invalid_command, "Command must have 'type' field"}
  end

  # ============================================================================
  # Validation
  # ============================================================================

  defp validate_command(%{"type" => type, "payload" => payload}) when is_map(payload) do
    case type do
      "crdt.increment" -> validate_keys(payload, ["key", "node_id"])
      "crdt.increment_by" -> validate_keys(payload, ["key", "node_id", "amount"])
      "crdt.decrement" -> validate_keys(payload, ["key", "node_id"])
      "crdt.set" -> validate_keys(payload, ["key", "node_id", "value"])
      "crdt.add" -> validate_keys(payload, ["key", "node_id", "element"])
      "crdt.remove" -> validate_keys(payload, ["key", "element"])
      "crdt.merge" -> validate_keys(payload, ["key", "state"])
      _ -> {:error, :unknown_command, "Unknown command type: #{type}"}
    end
  end

  defp validate_command(_), do: {:error, :invalid_command, "Invalid command format"}

  defp validate_keys(payload, required_keys) do
    missing = Enum.filter(required_keys, fn key -> !Map.has_key?(payload, key) end)

    case missing do
      [] -> :ok
      keys -> {:error, :missing_fields, "Missing required fields: #{inspect(keys)}"}
    end
  end

  defp get_required(payload, key) do
    case Map.get(payload, key) do
      nil -> {:error, :missing_field, "Missing required field: #{key}"}
      value -> {:ok, value}
    end
  end
end
