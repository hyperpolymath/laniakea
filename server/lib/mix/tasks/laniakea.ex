# SPDX-License-Identifier: MPL-2.0 OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule Mix.Tasks.Laniakea do
  @moduledoc """
  Laniakea CLI Mix task for server-side operations.

  ## Usage

      mix laniakea <command> [options]

  ## Commands

      crdt.list       List available CRDT types
      crdt.verify     Verify CRDT implementations
      crdt.bench      Run CRDT benchmarks
      gen.secret      Generate a Phoenix secret key
      gen.uuid        Generate a UUID
      gen.node_id     Generate a node ID
      status          Show server status
      rsr             Check RSR compliance

  ## Options

      --format FORMAT   Output format (json, table, plain)
      --verbose         Enable verbose output
      --quiet           Suppress non-essential output

  ## Examples

      mix laniakea crdt.list --format json
      mix laniakea crdt.verify
      mix laniakea gen.secret
      mix laniakea rsr --verbose
  """

  use Mix.Task

  @shortdoc "Laniakea CLI for server operations"

  alias Laniakea.CRDT.{GCounter, LWWRegister, ORSet, PNCounter}

  @impl Mix.Task
  def run(args) do
    {opts, commands, _} =
      OptionParser.parse(args,
        strict: [
          format: :string,
          verbose: :boolean,
          quiet: :boolean,
          help: :boolean
        ],
        aliases: [
          f: :format,
          v: :verbose,
          q: :quiet,
          h: :help
        ]
      )

    config = %{
      format: Keyword.get(opts, :format, "plain"),
      verbose: Keyword.get(opts, :verbose, false),
      quiet: Keyword.get(opts, :quiet, false)
    }

    dispatch(commands, config)
  end

  defp dispatch([], _config), do: print_help()
  defp dispatch(["help"], _config), do: print_help()
  defp dispatch(["crdt.list"], config), do: cmd_crdt_list(config)
  defp dispatch(["crdt.verify" | rest], config), do: cmd_crdt_verify(rest, config)
  defp dispatch(["crdt.bench" | rest], config), do: cmd_crdt_bench(rest, config)
  defp dispatch(["gen.secret"], config), do: cmd_gen_secret(config)
  defp dispatch(["gen.uuid"], config), do: cmd_gen_uuid(config)
  defp dispatch(["gen.node_id"], config), do: cmd_gen_node_id(config)
  defp dispatch(["rsr" | rest], config), do: cmd_rsr(rest, config)

  defp dispatch(["status"], config) do
    case Application.ensure_all_started(:laniakea) do
      {:ok, _started} -> cmd_status(config)
      {:error, reason} -> Mix.raise("Unable to start Laniakea: #{inspect(reason)}")
    end
  end

  defp dispatch([unknown | _], _config) do
    Mix.shell().error("Unknown command: #{unknown}")
    Mix.shell().error("Run 'mix laniakea help' for usage.")
  end

  defp print_help do
    Mix.shell().info(@moduledoc)
  end

  # CRDT Commands

  defp cmd_crdt_list(config) do
    crdts = [
      %{
        name: "GCounter",
        module: "Laniakea.CRDT.GCounter",
        description: "Grow-only counter",
        operations: ["new", "increment", "value", "merge"]
      },
      %{
        name: "PNCounter",
        module: "Laniakea.CRDT.PNCounter",
        description: "Positive-negative counter",
        operations: ["new", "increment", "decrement", "value", "merge"]
      },
      %{
        name: "ORSet",
        module: "Laniakea.CRDT.ORSet",
        description: "Observed-remove set",
        operations: ["new", "add", "remove", "member?", "elements", "merge"]
      },
      %{
        name: "LWWRegister",
        module: "Laniakea.CRDT.LWWRegister",
        description: "Last-writer-wins register",
        operations: ["new", "set", "value", "merge"]
      }
    ]

    format_output(crdts, config)
  end

  defp cmd_crdt_verify(args, config) do
    modules =
      case args do
        [] ->
          [
            GCounter,
            PNCounter,
            ORSet,
            LWWRegister
          ]

        names ->
          Enum.map(names, &String.to_existing_atom("Elixir.Laniakea.CRDT.#{&1}"))
      end

    results = Enum.map(modules, &verify_module(&1, config))

    if config.format != "plain" do
      format_output(results, config)
    end

    if Enum.all?(results, &(&1.status == "pass")) do
      :ok
    else
      Mix.raise("CRDT verification failed")
    end
  end

  defp verify_module(module, config) do
    name = module |> Module.split() |> List.last()
    result = run_verification(module, name)

    unless config.quiet do
      symbol = if result.status == "pass", do: "✓", else: "✗"
      color = if result.status == "pass", do: :green, else: :red
      Mix.shell().info([color, "#{symbol} #{name}", :reset])
    end

    result
  end

  defp run_verification(module, name) do
    case Laniakea.CRDT.verify(module) do
      :ok -> %{name: name, status: "pass"}
      {:error, reason} -> %{name: name, status: "fail", error: inspect(reason)}
    end
  rescue
    e -> %{name: name, status: "error", error: Exception.message(e)}
  end

  defp cmd_crdt_bench(_args, config) do
    unless config.quiet do
      Mix.shell().info("Running CRDT benchmarks...")
    end

    benchmarks = [
      {"GCounter.increment",
       fn ->
         counter = GCounter.new()

         Enum.reduce(1..1000, counter, fn _, c ->
           GCounter.increment(c, "node1")
         end)
       end},
      {"GCounter.merge",
       fn ->
         a = GCounter.new() |> GCounter.increment("a")
         b = GCounter.new() |> GCounter.increment("b")

         Enum.reduce(1..1000, a, fn _, acc ->
           GCounter.merge(acc, b)
         end)
       end},
      {"ORSet.add",
       fn ->
         set = ORSet.new()

         Enum.reduce(1..1000, set, fn i, s ->
           ORSet.add(s, "element_#{i}", "node1")
         end)
       end},
      {"ORSet.merge",
       fn ->
         a = ORSet.new() |> ORSet.add("item", "a")
         b = ORSet.new() |> ORSet.add("other", "b")

         Enum.reduce(1..1000, a, fn _, acc ->
           ORSet.merge(acc, b)
         end)
       end}
    ]

    results =
      Enum.map(benchmarks, fn {name, fun} ->
        {time, _} = :timer.tc(fun)
        per_op = time / 1000

        unless config.quiet do
          Mix.shell().info("#{name}: #{Float.round(per_op, 2)}μs/op")
        end

        %{name: name, time_us: time, per_op_us: Float.round(per_op, 2)}
      end)

    if config.format != "plain" do
      format_output(results, config)
    end
  end

  # Generator Commands

  defp cmd_gen_secret(config) do
    secret = :crypto.strong_rand_bytes(64) |> Base.encode16(case: :lower)

    if config.format == "json" do
      format_output(%{secret: secret}, config)
    else
      Mix.shell().info(secret)
    end
  end

  defp cmd_gen_uuid(config) do
    uuid = uuid4()

    if config.format == "json" do
      format_output(%{uuid: uuid}, config)
    else
      Mix.shell().info(uuid)
    end
  end

  defp cmd_gen_node_id(config) do
    uuid = uuid4() |> String.replace("-", "") |> String.slice(0, 16)
    node_id = "node_#{uuid}"

    if config.format == "json" do
      format_output(%{node_id: node_id}, config)
    else
      Mix.shell().info(node_id)
    end
  end

  defp uuid4 do
    <<first::32, second::16, third::16, fourth::16, fifth::48>> = :crypto.strong_rand_bytes(16)

    third = Bitwise.bor(Bitwise.band(third, 0x0FFF), 0x4000)
    fourth = Bitwise.bor(Bitwise.band(fourth, 0x3FFF), 0x8000)

    [
      hex(first, 8),
      hex(second, 4),
      hex(third, 4),
      hex(fourth, 4),
      hex(fifth, 12)
    ]
    |> Enum.join("-")
  end

  defp hex(value, width) do
    value
    |> Integer.to_string(16)
    |> String.pad_leading(width, "0")
  end

  # Status Command

  defp cmd_status(config) do
    status = %{
      version: Application.spec(:laniakea, :vsn) |> to_string(),
      otp_release: :erlang.system_info(:otp_release) |> to_string(),
      elixir_version: System.version(),
      node: Node.self(),
      uptime_seconds: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000),
      memory: %{
        total: :erlang.memory(:total),
        processes: :erlang.memory(:processes),
        atom: :erlang.memory(:atom),
        ets: :erlang.memory(:ets)
      },
      process_count: :erlang.system_info(:process_count),
      scheduler_count: :erlang.system_info(:schedulers_online)
    }

    format_output(status, config)
  end

  # RSR Command

  defp cmd_rsr(args, config) do
    level = List.first(args) || "check"

    checks = []

    # Required files check
    required_files = [
      "README.adoc",
      "LICENSE",
      "SECURITY.md",
      "CONTRIBUTING.md",
      "CODE_OF_CONDUCT.md",
      "MAINTAINERS.md",
      "CHANGELOG.md"
    ]

    file_checks =
      Enum.map(required_files, fn file ->
        path = Path.join([File.cwd!(), "..", file])
        exists = File.exists?(path)
        %{requirement: "File: #{file}", status: if(exists, do: "pass", else: "fail")}
      end)

    checks = checks ++ file_checks

    checks = checks ++ typed_checks(level)

    print_rsr_results(checks, level, config)

    passed = Enum.count(checks, &(&1.status == "pass"))
    failed = Enum.count(checks, &(&1.status == "fail"))

    Mix.shell().info("\nResults: #{passed} passed, #{failed} failed")

    if config.format != "plain" do
      format_output(%{checks: checks, passed: passed, failed: failed}, config)
    end

    if failed > 0 do
      Mix.raise("RSR compliance check failed")
    end
  end

  defp typed_checks(level) when level in ["bronze", "silver", "gold", "platinum"] do
    [
      %{requirement: "Type Safety (Dialyzer)", status: dialyzer_status()},
      %{requirement: "CRDT Verification", status: crdt_suite_status()}
    ]
  end

  defp typed_checks(_level), do: []

  defp dialyzer_status do
    Mix.Task.run("dialyzer", ["--halt-exit-status"])
    "pass"
  rescue
    _ -> "fail"
  end

  defp crdt_suite_status do
    :ok = Laniakea.CRDT.verify(GCounter)
    :ok = Laniakea.CRDT.verify(PNCounter)
    :ok = Laniakea.CRDT.verify(ORSet)
    :ok = Laniakea.CRDT.verify(LWWRegister)
    "pass"
  rescue
    _ -> "fail"
  end

  defp print_rsr_results(checks, level, config) do
    unless config.quiet do
      Mix.shell().info("\n=== RSR Compliance Check (#{level}) ===\n")

      Enum.each(checks, &print_rsr_check/1)
    end
  end

  defp print_rsr_check(check) do
    symbol = if check.status == "pass", do: "✓", else: "✗"
    color = if check.status == "pass", do: :green, else: :red
    Mix.shell().info([color, "#{symbol} #{check.requirement}", :reset])
  end

  # Formatting Helpers

  defp format_output(data, %{format: "json"}) do
    Mix.shell().info(Jason.encode!(data, pretty: true))
  end

  defp format_output(data, %{format: "table"}) when is_list(data) do
    if match?([_ | _], data) and is_map(hd(data)) do
      headers = data |> hd() |> Map.keys() |> Enum.map(&to_string/1)
      rows = table_rows(data, headers)
      widths = column_widths(headers, rows)
      separator = "+" <> Enum.map_join(widths, "+", &String.duplicate("-", &1 + 2)) <> "+"

      Mix.shell().info(separator)
      Mix.shell().info(render_row(headers, widths))
      Mix.shell().info(separator)
      Enum.each(rows, fn row -> Mix.shell().info(render_row(row, widths)) end)
      Mix.shell().info(separator)
    else
      Mix.shell().info(inspect(data))
    end
  end

  defp format_output(data, _config) do
    Mix.shell().info(inspect(data, pretty: true))
  end

  defp table_rows(data, headers) do
    Enum.map(data, fn row ->
      Enum.map(headers, fn h ->
        Map.get(row, String.to_existing_atom(h), "") |> format_value()
      end)
    end)
  end

  defp column_widths(headers, rows) do
    headers
    |> Enum.with_index()
    |> Enum.map(fn {header, i} ->
      cell_lengths = Enum.map(rows, fn row -> String.length(Enum.at(row, i)) end)
      max(String.length(header), Enum.max(cell_lengths, fn -> 0 end))
    end)
  end

  defp render_row(cells, widths) do
    "|" <>
      Enum.map_join(Enum.zip(cells, widths), "|", fn {v, w} ->
        " #{String.pad_trailing(v, w)} "
      end) <> "|"
  end

  defp format_value(v) when is_binary(v), do: v
  defp format_value(v) when is_list(v), do: Enum.join(v, ", ")
  defp format_value(v), do: inspect(v)
end
