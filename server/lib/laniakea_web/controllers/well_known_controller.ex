# SPDX-License-Identifier: MPL-2.0 OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule LaniakeaWeb.WellKnownController do
  use LaniakeaWeb, :controller

  @security_txt """
  Contact: mailto:security@laniakea.dev
  Contact: https://github.com/hyperpolymath/laniakea/security/advisories/new
  Expires: 2027-09-22T00:00:00Z
  Preferred-Languages: en
  Policy: https://github.com/hyperpolymath/laniakea/blob/main/SECURITY.adoc
  Canonical: https://laniakea.dev/.well-known/security.txt
  """

  @ai_txt """
  # Laniakea
  # https://github.com/hyperpolymath/laniakea
  """

  def security(conn, _params), do: plain_text(conn, @security_txt)
  def ai(conn, _params), do: plain_text(conn, @ai_txt)

  defp plain_text(conn, body) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(:ok, body)
  end
end
