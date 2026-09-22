# SPDX-License-Identifier: MPL-2.0 OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule LaniakeaWeb.ControllersTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest

  @endpoint LaniakeaWeb.Endpoint

  test "health endpoint reports an available server" do
    response = build_conn() |> get("/api/health") |> json_response(200)

    assert response["status"] == "ok"
    assert is_binary(response["version"])
  end

  test "CRDT increment endpoint creates and returns a counter" do
    key = "controller-test-#{System.unique_integer([:positive])}"

    response =
      build_conn()
      |> post("/api/crdt/#{key}/increment", %{"node_id" => "test-node"})
      |> json_response(200)

    assert response["state"]["type"] == "g_counter"
    assert response["state"]["value"] == 1
  end

  test "well-known security endpoint serves RFC 9116 contact details" do
    conn = build_conn() |> get("/.well-known/security.txt")

    assert response(conn, 200) =~ "Contact: mailto:security@laniakea.dev"
    assert Plug.Conn.get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
  end
end
