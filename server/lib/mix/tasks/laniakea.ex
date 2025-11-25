# SPDX-License-Identifier: MIT OR Apache-2.0
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

  @impl Mix.Task
  def run(args) do
    {opts, commands, _} = OptionParser.parse(args,
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

    case commands do
      [] ->
        print_help()

      ["help"] ->
        print_help()

      ["crdt.list"] ->
        cmd_crdt_list(config)

      ["crdt.verify" | rest] ->
        cmd_crdt_verify(rest, config)

      ["crdt.bench" | rest] ->
        cmd_crdt_bench(rest, config)

      ["gen.secret"] ->
        cmd_gen_secret(config)

      ["gen.uuid"] ->
        cmd_gen_uuid(config)

      ["gen.node_id"] ->
        cmd_gen_node_id(config)

      ["status"] ->
        Application.ensure_all_started(:laniakea)
        cmd_status(config)

      ["rsr" | rest] ->
        cmd_rsr(rest, config)

      [unknown | _] ->
        Mix.shell().error("Unknown command: #{unknown}")
        Mix.shell().error("Run 'mix laniakea help' for usage.")
    end
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
    modules = case args do
      [] -> [
        Laniakea.CRDT.GCounter,
        Laniakea.CRDT.PNCounter,
        Laniakea.CRDT.ORSet,
        Laniakea.CRDT.LWWRegister
      ]
      names -> Enum.map(names, &String.to_existing_atom("Elixir.Laniakea.CRDT.#{&1}"))
    end

    results = Enum.map(modules, fn module ->
      name = module |> Module.split() |> List.last()

      result = try do
        case Laniakea.CRDT.verify(module) do
          :ok -> %{name: name, status: "pass"}
          {:error, reason} -> %{name: name, status: "fail", error: inspect(reason)}
        end
      rescue
        e -> %{name: name, status: "error", error: Exception.message(e)}
      end

      unless config.quiet do
        symbol = if result.status == "pass", do: "✓", else: "✗"
        color = if result.status == "pass", do: :green, else: :red
        Mix.shell().info([color, "#{symbol} #{name}", :reset])
      end

      result
    end)

    if config.format != "plain" do
      format_output(results, config)
    end

    if Enum.all?(results, & &1.status == "pass") do
      :ok
    else
      Mix.raise("CRDT verification failed")
    end
  end

  defp cmd_crdt_bench(_args, config) do
    unless config.quiet do
      Mix.shell().info("Running CRDT benchmarks...")
    end

    benchmarks = [
      {"GCounter.increment", fn ->
        counter = Laniakea.CRDT.GCounter.new()
        Enum.reduce(1..1000, counter, fn _, c ->
          Laniakea.CRDT.GCounter.increment(c, "node1")
        end)
      end},
      {"GCounter.merge", fn ->
        a = Laniakea.CRDT.GCounter.new() |> Laniakea.CRDT.GCounter.increment("a")
        b = Laniakea.CRDT.GCounter.new() |> Laniakea.CRDT.GCounter.increment("b")
        Enum.reduce(1..1000, a, fn _, acc ->
          Laniakea.CRDT.GCounter.merge(acc, b)
        end)
      end},
      {"ORSet.add", fn ->
        set = Laniakea.CRDT.ORSet.new()
        Enum.reduce(1..1000, set, fn i, s ->
          Laniakea.CRDT.ORSet.add(s, "element_#{i}", "node1")
        end)
      end},
      {"ORSet.merge", fn ->
        a = Laniakea.CRDT.ORSet.new() |> Laniakea.CRDT.ORSet.add("item", "a")
        b = Laniakea.CRDT.ORSet.new() |> Laniakea.CRDT.ORSet.add("other", "b")
        Enum.reduce(1..1000, a, fn _, acc ->
          Laniakea.CRDT.ORSet.merge(acc, b)
        end)
      end}
    ]

    results = Enum.map(benchmarks, fn {name, fun} ->
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
    uuid = UUID.uuid4()

    if config.format == "json" do
      format_output(%{uuid: uuid}, config)
    else
      Mix.shell().info(uuid)
    end
  end

  defp cmd_gen_node_id(config) do
    uuid = UUID.uuid4() |> String.replace("-", "") |> String.slice(0, 16)
    node_id = "node_#{uuid}"

    if config.format == "json" do
      format_output(%{node_id: node_id}, config)
    else
      Mix.shell().info(node_id)
    end
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

    file_checks = Enum.map(required_files, fn file ->
      path = Path.join([File.cwd!(), "..", file])
      exists = File.exists?(path)
      %{requirement: "File: #{file}", status: if(exists, do: "pass", else: "fail")}
    end)

    checks = checks ++ file_checks

    # Type safety check
    checks = if level in ["bronze", "silver", "gold", "platinum"] do
      dialyzer_result = try do
        Mix.Task.run("dialyzer", ["--halt-exit-status"])
        "pass"
      rescue
        _ -> "fail"
      end

      checks ++ [%{requirement: "Type Safety (Dialyzer)", status: dialyzer_result}]
    else
      checks
    end

    # CRDT verification
    checks = if level in ["bronze", "silver", "gold", "platinum"] do
      crdt_result = try do
        :ok = Laniakea.CRDT.verify(Laniakea.CRDT.GCounter)
        :ok = Laniakea.CRDT.verify(Laniakea.CRDT.PNCounter)
        :ok = Laniakea.CRDT.verify(Laniakea.CRDT.ORSet)
        :ok = Laniakea.CRDT.verify(Laniakea.CRDT.LWWRegister)
        "pass"
      rescue
        _ -> "fail"
      end

      checks ++ [%{requirement: "CRDT Verification", status: crdt_result}]
    else
      checks
    end

    # Display results
    unless config.quiet do
      Mix.shell().info("\n=== RSR Compliance Check (#{level}) ===\n")

      Enum.each(checks, fn check ->
        symbol = if check.status == "pass", do: "✓", else: "✗"
        color = if check.status == "pass", do: :green, else: :red
        Mix.shell().info([color, "#{symbol} #{check.requirement}", :reset])
      end)
    end

    passed = Enum.count(checks, & &1.status == "pass")
    failed = Enum.count(checks, & &1.status == "fail")

    Mix.shell().info("\nResults: #{passed} passed, #{failed} failed")

    if config.format != "plain" do
      format_output(%{checks: checks, passed: passed, failed: failed}, config)
    end

    if failed > 0 do
      Mix.raise("RSR compliance check failed")
    end
  end

  # Formatting Helpers

  defp format_output(data, %{format: "json"}) do
    Mix.shell().info(Jason.encode!(data, pretty: true))
  end

  defp format_output(data, %{format: "table"}) when is_list(data) do
    if length(data) > 0 and is_map(hd(data)) do
      headers = data |> hd() |> Map.keys() |> Enum.map(&to_string/1)
      rows = Enum.map(data, fn row ->
        Enum.map(headers, fn h -> Map.get(row, String.to_atom(h), "") |> format_value() end)
      end)

      widths = Enum.map(0..(length(headers) - 1), fn i ->
        max(
          String.length(Enum.at(headers, i)),
          rows |> Enum.map(&Enum.at(&1, i)) |> Enum.map(&String.length/1) |> Enum.max(fn -> 0 end)
        )
      end)

      separator = "+" <> Enum.map_join(widths, "+", &String.duplicate("-", &1 + 2)) <> "+"
      header_row = "|" <> Enum.map_join(Enum.zip(headers, widths), "|", fn {h, w} ->
        " #{String.pad_trailing(h, w)} "
      end) <> "|"

      Mix.shell().info(separator)
      Mix.shell().info(header_row)
      Mix.shell().info(separator)

      Enum.each(rows, fn row ->
        row_str = "|" <> Enum.map_join(Enum.zip(row, widths), "|", fn {v, w} ->
          " #{String.pad_trailing(v, w)} "
        end) <> "|"
        Mix.shell().info(row_str)
      end)

      Mix.shell().info(separator)
    else
      Mix.shell().info(inspect(data))
    end
  end

  defp format_output(data, _config) do
    Mix.shell().info(inspect(data, pretty: true))
  end

  defp format_value(v) when is_binary(v), do: v
  defp format_value(v) when is_list(v), do: Enum.join(v, ", ")
  defp format_value(v), do: inspect(v)
end
