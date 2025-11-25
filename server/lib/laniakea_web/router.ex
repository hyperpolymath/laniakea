# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule LaniakeaWeb.Router do
  use Phoenix.Router

  import Phoenix.Controller

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # API routes
  scope "/api", LaniakeaWeb do
    pipe_through :api

    # Health check
    get "/health", HealthController, :index

    # CRDT operations via REST (alternative to WebSocket)
    scope "/crdt" do
      get "/:key", CRDTController, :show
      post "/:key/increment", CRDTController, :increment
      post "/:key/decrement", CRDTController, :decrement
      post "/:key/merge", CRDTController, :merge
    end

    # Command endpoint
    post "/command", CommandController, :execute
  end

  # .well-known routes
  scope "/.well-known", LaniakeaWeb do
    pipe_through :api

    get "/security.txt", WellKnownController, :security
    get "/ai.txt", WellKnownController, :ai
  end
end
