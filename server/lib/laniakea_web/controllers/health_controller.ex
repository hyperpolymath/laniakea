# SPDX-License-Identifier: MPL-2.0 OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule LaniakeaWeb.HealthController do
  use LaniakeaWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok", version: to_string(Application.spec(:laniakea, :vsn) || "dev")})
  end
end
