# SPDX-License-Identifier: MPL-2.0 OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule LaniakeaWeb.CRDTController do
  use LaniakeaWeb, :controller

  alias Laniakea.Command.Bus
  alias Laniakea.CRDT.Registry

  def show(conn, %{"key" => key}) do
    case Registry.get(key) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "CRDT not found"})

      crdt ->
        json(conn, %{state: crdt.__struct__.to_map(crdt)})
    end
  end

  def increment(conn, %{"key" => key, "node_id" => node_id}) do
    execute(conn, "crdt.increment", %{"key" => key, "node_id" => node_id})
  end

  def decrement(conn, %{"key" => key, "node_id" => node_id}) do
    execute(conn, "crdt.decrement", %{"key" => key, "node_id" => node_id})
  end

  def merge(conn, %{"key" => key, "state" => state}) do
    execute(conn, "crdt.merge", %{"key" => key, "state" => state})
  end

  defp execute(conn, type, payload) do
    case Bus.execute(%{"type" => type, "payload" => payload}) do
      {:ok, result} ->
        json(conn, result)

      {:error, reason, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: Atom.to_string(reason), message: message})
    end
  end
end
