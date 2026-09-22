# SPDX-License-Identifier: MPL-2.0 OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule LaniakeaWeb.CommandController do
  use LaniakeaWeb, :controller

  alias Laniakea.Command.Bus

  def execute(conn, command) do
    case Bus.execute(command) do
      {:ok, result} ->
        json(conn, result)

      {:error, reason, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: Atom.to_string(reason), message: message})
    end
  end
end
