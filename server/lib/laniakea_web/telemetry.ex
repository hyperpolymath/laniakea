# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule LaniakeaWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # Channel Metrics
      counter("phoenix.channel_joined.count",
        tags: [:channel]
      ),
      counter("phoenix.channel_handled_in.count",
        tags: [:channel, :event]
      ),

      # CRDT Metrics
      counter("laniakea.crdt.operation.count",
        tags: [:type, :operation]
      ),
      summary("laniakea.crdt.merge.duration",
        unit: {:native, :microsecond}
      ),

      # Command Bus Metrics
      counter("laniakea.command.executed.count",
        tags: [:type]
      ),
      summary("laniakea.command.executed.duration",
        unit: {:native, :microsecond}
      ),

      # Policy Metrics
      counter("laniakea.policy.client_registered.count",
        tags: [:profile]
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :megabyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      {__MODULE__, :crdt_registry_stats, []}
    ]
  end

  def crdt_registry_stats do
    keys = Laniakea.CRDT.Registry.keys()

    :telemetry.execute(
      [:laniakea, :crdt, :registry],
      %{count: length(keys)},
      %{}
    )
  end
end
