#!/usr/bin/env -S deno run --allow-all
// SPDX-License-Identifier: MIT OR Apache-2.0
// Laniakea CLI - Comprehensive command-line interface for workflow integration

import { parse } from "https://deno.land/std@0.208.0/flags/mod.ts";
import { join, dirname, fromFileUrl } from "https://deno.land/std@0.208.0/path/mod.ts";
import { exists } from "https://deno.land/std@0.208.0/fs/mod.ts";

const VERSION = "0.1.0";
const ROOT = dirname(dirname(fromFileUrl(import.meta.url)));

// ============================================================================
// Types
// ============================================================================

interface Config {
  server: {
    host: string;
    port: number;
    secret_key_base?: string;
  };
  database: {
    host: string;
    port: number;
    name: string;
    user: string;
    password?: string;
  };
  crdt: {
    sync_interval_ms: number;
    max_clock_drift_ms: number;
  };
  output: {
    format: "json" | "yaml" | "table" | "plain";
    color: boolean;
    verbose: boolean;
    quiet: boolean;
  };
}

interface CommandResult {
  success: boolean;
  data?: unknown;
  error?: string;
  exitCode: number;
}

// ============================================================================
// Color utilities
// ============================================================================

const colors = {
  reset: "\x1b[0m",
  bold: "\x1b[1m",
  dim: "\x1b[2m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  magenta: "\x1b[35m",
  cyan: "\x1b[36m",
};

function colorize(text: string, color: keyof typeof colors, useColor: boolean): string {
  if (!useColor) return text;
  return `${colors[color]}${text}${colors.reset}`;
}

// ============================================================================
// Output formatting
// ============================================================================

function formatOutput(data: unknown, format: Config["output"]["format"], useColor: boolean): string {
  switch (format) {
    case "json":
      return JSON.stringify(data, null, 2);
    case "yaml":
      return toYaml(data);
    case "table":
      return toTable(data, useColor);
    case "plain":
    default:
      return String(data);
  }
}

function toYaml(obj: unknown, indent = 0): string {
  const spaces = "  ".repeat(indent);
  if (obj === null || obj === undefined) return "null";
  if (typeof obj === "string") return obj.includes("\n") ? `|\n${obj.split("\n").map(l => spaces + "  " + l).join("\n")}` : obj;
  if (typeof obj === "number" || typeof obj === "boolean") return String(obj);
  if (Array.isArray(obj)) {
    return obj.map(item => `${spaces}- ${toYaml(item, indent + 1).trimStart()}`).join("\n");
  }
  if (typeof obj === "object") {
    return Object.entries(obj as Record<string, unknown>)
      .map(([k, v]) => {
        const value = toYaml(v, indent + 1);
        return typeof v === "object" && v !== null
          ? `${spaces}${k}:\n${value}`
          : `${spaces}${k}: ${value}`;
      })
      .join("\n");
  }
  return String(obj);
}

function toTable(data: unknown, useColor: boolean): string {
  if (!Array.isArray(data) || data.length === 0) {
    return formatOutput(data, "plain", useColor);
  }

  const headers = Object.keys(data[0] as Record<string, unknown>);
  const widths = headers.map(h => Math.max(h.length, ...data.map(row => String((row as Record<string, unknown>)[h] ?? "").length)));

  const separator = "+" + widths.map(w => "-".repeat(w + 2)).join("+") + "+";
  const headerRow = "|" + headers.map((h, i) => ` ${colorize(h.padEnd(widths[i]), "bold", useColor)} `).join("|") + "|";
  const rows = data.map(row =>
    "|" + headers.map((h, i) => ` ${String((row as Record<string, unknown>)[h] ?? "").padEnd(widths[i])} `).join("|") + "|"
  );

  return [separator, headerRow, separator, ...rows, separator].join("\n");
}

// ============================================================================
// Configuration loading
// ============================================================================

async function loadConfig(configPath?: string): Promise<Partial<Config>> {
  const paths = configPath
    ? [configPath]
    : [
        join(ROOT, "laniakea.json"),
        join(ROOT, "laniakea.yaml"),
        join(Deno.env.get("HOME") ?? "", ".config/laniakea/config.json"),
        join(Deno.env.get("HOME") ?? "", ".laniakea.json"),
      ];

  for (const path of paths) {
    if (await exists(path)) {
      const content = await Deno.readTextFile(path);
      return path.endsWith(".yaml") ? parseYaml(content) : JSON.parse(content);
    }
  }

  return {};
}

function parseYaml(content: string): Record<string, unknown> {
  // Simple YAML parser for basic configs
  const result: Record<string, unknown> = {};
  let currentKey = "";
  let currentIndent = 0;

  for (const line of content.split("\n")) {
    if (line.trim().startsWith("#") || !line.trim()) continue;
    const match = line.match(/^(\s*)([^:]+):\s*(.*)$/);
    if (match) {
      const [, indent, key, value] = match;
      if (value) {
        result[key.trim()] = value.trim();
      }
    }
  }

  return result;
}

function mergeConfig(base: Partial<Config>, overrides: Record<string, unknown>): Config {
  return {
    server: {
      host: (overrides.host as string) ?? base.server?.host ?? "localhost",
      port: (overrides.port as number) ?? base.server?.port ?? 4000,
      secret_key_base: (overrides.secret as string) ?? base.server?.secret_key_base,
    },
    database: {
      host: (overrides["db-host"] as string) ?? base.database?.host ?? "localhost",
      port: (overrides["db-port"] as number) ?? base.database?.port ?? 8529,
      name: (overrides["db-name"] as string) ?? base.database?.name ?? "laniakea",
      user: (overrides["db-user"] as string) ?? base.database?.user ?? "root",
      password: (overrides["db-password"] as string) ?? base.database?.password,
    },
    crdt: {
      sync_interval_ms: (overrides["sync-interval"] as number) ?? base.crdt?.sync_interval_ms ?? 100,
      max_clock_drift_ms: (overrides["max-drift"] as number) ?? base.crdt?.max_clock_drift_ms ?? 5000,
    },
    output: {
      format: (overrides.format as Config["output"]["format"]) ?? base.output?.format ?? "plain",
      color: overrides["no-color"] ? false : (overrides.color as boolean) ?? base.output?.color ?? Deno.isatty(Deno.stdout.rid),
      verbose: (overrides.verbose as boolean) ?? base.output?.verbose ?? false,
      quiet: (overrides.quiet as boolean) ?? base.output?.quiet ?? false,
    },
  };
}

// ============================================================================
// Commands
// ============================================================================

async function cmdVersion(_args: string[], config: Config): Promise<CommandResult> {
  const info = {
    version: VERSION,
    elixir: await getElixirVersion(),
    erlang: await getErlangVersion(),
    deno: Deno.version.deno,
    v8: Deno.version.v8,
    typescript: Deno.version.typescript,
  };

  console.log(formatOutput(info, config.output.format, config.output.color));
  return { success: true, data: info, exitCode: 0 };
}

async function getElixirVersion(): Promise<string> {
  try {
    const p = new Deno.Command("elixir", { args: ["--version"], stdout: "piped", stderr: "null" });
    const { stdout } = await p.output();
    const match = new TextDecoder().decode(stdout).match(/Elixir (\d+\.\d+\.\d+)/);
    return match?.[1] ?? "not found";
  } catch {
    return "not found";
  }
}

async function getErlangVersion(): Promise<string> {
  try {
    const p = new Deno.Command("erl", { args: ["-eval", "io:format(\"~s\", [erlang:system_info(otp_release)]), halt().", "-noshell"], stdout: "piped", stderr: "null" });
    const { stdout } = await p.output();
    return new TextDecoder().decode(stdout) || "not found";
  } catch {
    return "not found";
  }
}

async function cmdDoctor(_args: string[], config: Config): Promise<CommandResult> {
  const checks: Array<{ name: string; status: string; details: string }> = [];

  // Check Elixir
  const elixirVersion = await getElixirVersion();
  checks.push({
    name: "Elixir",
    status: elixirVersion !== "not found" ? "ok" : "missing",
    details: elixirVersion,
  });

  // Check Erlang/OTP
  const erlangVersion = await getErlangVersion();
  checks.push({
    name: "Erlang/OTP",
    status: erlangVersion !== "not found" ? "ok" : "missing",
    details: erlangVersion,
  });

  // Check Deno
  checks.push({
    name: "Deno",
    status: "ok",
    details: Deno.version.deno,
  });

  // Check ReScript
  try {
    const p = new Deno.Command("npx", { args: ["rescript", "-version"], stdout: "piped", stderr: "null" });
    const { stdout, success } = await p.output();
    checks.push({
      name: "ReScript",
      status: success ? "ok" : "missing",
      details: success ? new TextDecoder().decode(stdout).trim() : "not found",
    });
  } catch {
    checks.push({ name: "ReScript", status: "missing", details: "not found" });
  }

  // Check ArangoDB
  try {
    const response = await fetch(`http://${config.database.host}:${config.database.port}/_api/version`);
    const data = await response.json();
    checks.push({
      name: "ArangoDB",
      status: "ok",
      details: data.version ?? "connected",
    });
  } catch {
    checks.push({ name: "ArangoDB", status: "not running", details: `${config.database.host}:${config.database.port}` });
  }

  // Check just
  try {
    const p = new Deno.Command("just", { args: ["--version"], stdout: "piped", stderr: "null" });
    const { stdout, success } = await p.output();
    checks.push({
      name: "just",
      status: success ? "ok" : "missing",
      details: success ? new TextDecoder().decode(stdout).trim() : "not found",
    });
  } catch {
    checks.push({ name: "just", status: "missing", details: "not found" });
  }

  // Check nickel
  try {
    const p = new Deno.Command("nickel", { args: ["--version"], stdout: "piped", stderr: "null" });
    const { stdout, success } = await p.output();
    checks.push({
      name: "Nickel",
      status: success ? "ok" : "optional",
      details: success ? new TextDecoder().decode(stdout).trim() : "not found",
    });
  } catch {
    checks.push({ name: "Nickel", status: "optional", details: "not found" });
  }

  // Check Docker
  try {
    const p = new Deno.Command("docker", { args: ["--version"], stdout: "piped", stderr: "null" });
    const { stdout, success } = await p.output();
    checks.push({
      name: "Docker",
      status: success ? "ok" : "optional",
      details: success ? new TextDecoder().decode(stdout).trim().replace("Docker version ", "") : "not found",
    });
  } catch {
    checks.push({ name: "Docker", status: "optional", details: "not found" });
  }

  const allOk = checks.every(c => c.status === "ok" || c.status === "optional");

  if (config.output.format === "plain") {
    console.log(colorize("\n=== Laniakea System Check ===\n", "bold", config.output.color));
    for (const check of checks) {
      const statusColor = check.status === "ok" ? "green" : check.status === "optional" ? "yellow" : "red";
      const symbol = check.status === "ok" ? "✓" : check.status === "optional" ? "○" : "✗";
      console.log(`${colorize(symbol, statusColor, config.output.color)} ${check.name}: ${check.details}`);
    }
    console.log(allOk
      ? colorize("\nAll checks passed!", "green", config.output.color)
      : colorize("\nSome checks failed. Install missing dependencies.", "yellow", config.output.color)
    );
  } else {
    console.log(formatOutput(checks, config.output.format, config.output.color));
  }

  return { success: allOk, data: checks, exitCode: allOk ? 0 : 1 };
}

async function cmdServer(args: string[], config: Config): Promise<CommandResult> {
  const subcommand = args[0] ?? "start";

  switch (subcommand) {
    case "start": {
      const env: Record<string, string> = {
        MIX_ENV: "dev",
        PHX_HOST: config.server.host,
        PHX_PORT: String(config.server.port),
      };
      if (config.server.secret_key_base) {
        env.SECRET_KEY_BASE = config.server.secret_key_base;
      }

      if (!config.output.quiet) {
        console.log(colorize(`Starting server at http://${config.server.host}:${config.server.port}`, "cyan", config.output.color));
      }

      const p = new Deno.Command("mix", {
        args: ["phx.server"],
        cwd: join(ROOT, "server"),
        env: { ...Deno.env.toObject(), ...env },
        stdin: "inherit",
        stdout: "inherit",
        stderr: "inherit",
      });

      const { code } = await p.output();
      return { success: code === 0, exitCode: code };
    }

    case "iex": {
      const p = new Deno.Command("iex", {
        args: ["-S", "mix", "phx.server"],
        cwd: join(ROOT, "server"),
        stdin: "inherit",
        stdout: "inherit",
        stderr: "inherit",
      });

      const { code } = await p.output();
      return { success: code === 0, exitCode: code };
    }

    case "release": {
      const env = { MIX_ENV: "prod" };

      if (!config.output.quiet) {
        console.log(colorize("Building release...", "cyan", config.output.color));
      }

      const compile = new Deno.Command("mix", {
        args: ["compile"],
        cwd: join(ROOT, "server"),
        env: { ...Deno.env.toObject(), ...env },
        stdout: config.output.quiet ? "null" : "inherit",
        stderr: "inherit",
      });
      await compile.output();

      const release = new Deno.Command("mix", {
        args: ["release"],
        cwd: join(ROOT, "server"),
        env: { ...Deno.env.toObject(), ...env },
        stdout: config.output.quiet ? "null" : "inherit",
        stderr: "inherit",
      });

      const { code } = await release.output();

      if (code === 0 && !config.output.quiet) {
        console.log(colorize("Release built at server/_build/prod/rel/laniakea", "green", config.output.color));
      }

      return { success: code === 0, exitCode: code };
    }

    default:
      console.error(colorize(`Unknown server subcommand: ${subcommand}`, "red", config.output.color));
      return { success: false, error: `Unknown subcommand: ${subcommand}`, exitCode: 1 };
  }
}

async function cmdClient(args: string[], config: Config): Promise<CommandResult> {
  const subcommand = args[0] ?? "build";

  switch (subcommand) {
    case "build": {
      if (!config.output.quiet) {
        console.log(colorize("Building ReScript...", "cyan", config.output.color));
      }

      const rescript = new Deno.Command("npx", {
        args: ["rescript"],
        cwd: join(ROOT, "client"),
        stdout: config.output.quiet ? "null" : "inherit",
        stderr: "inherit",
      });

      const { code: rsCode } = await rescript.output();
      if (rsCode !== 0) {
        return { success: false, error: "ReScript build failed", exitCode: rsCode };
      }

      if (!config.output.quiet) {
        console.log(colorize("Bundling with Deno...", "cyan", config.output.color));
      }

      const bundle = new Deno.Command("deno", {
        args: ["bundle", "src/Main.mjs", "dist/laniakea.bundle.js"],
        cwd: join(ROOT, "client"),
        stdout: config.output.quiet ? "null" : "inherit",
        stderr: "inherit",
      });

      const { code } = await bundle.output();

      if (code === 0 && !config.output.quiet) {
        console.log(colorize("Client built at client/dist/", "green", config.output.color));
      }

      return { success: code === 0, exitCode: code };
    }

    case "watch": {
      const p = new Deno.Command("npx", {
        args: ["rescript", "build", "-w"],
        cwd: join(ROOT, "client"),
        stdin: "inherit",
        stdout: "inherit",
        stderr: "inherit",
      });

      const { code } = await p.output();
      return { success: code === 0, exitCode: code };
    }

    case "clean": {
      const p = new Deno.Command("npx", {
        args: ["rescript", "clean"],
        cwd: join(ROOT, "client"),
        stdout: config.output.quiet ? "null" : "inherit",
        stderr: "inherit",
      });

      const { code } = await p.output();
      return { success: code === 0, exitCode: code };
    }

    default:
      console.error(colorize(`Unknown client subcommand: ${subcommand}`, "red", config.output.color));
      return { success: false, error: `Unknown subcommand: ${subcommand}`, exitCode: 1 };
  }
}

async function cmdTest(args: string[], config: Config): Promise<CommandResult> {
  const target = args[0] ?? "all";
  const file = args[1];

  const results: Array<{ target: string; success: boolean }> = [];

  if (target === "all" || target === "server") {
    if (!config.output.quiet) {
      console.log(colorize("\n=== Server Tests ===\n", "bold", config.output.color));
    }

    const testArgs = file ? ["test", file] : ["test"];
    if (config.output.verbose) testArgs.push("--trace");

    const p = new Deno.Command("mix", {
      args: testArgs,
      cwd: join(ROOT, "server"),
      stdout: "inherit",
      stderr: "inherit",
    });

    const { code } = await p.output();
    results.push({ target: "server", success: code === 0 });
  }

  if (target === "all" || target === "client") {
    if (!config.output.quiet) {
      console.log(colorize("\n=== Client Tests ===\n", "bold", config.output.color));
    }

    const p = new Deno.Command("deno", {
      args: ["test", "--allow-net", "test/"],
      cwd: join(ROOT, "client"),
      stdout: "inherit",
      stderr: "inherit",
    });

    const { code } = await p.output();
    results.push({ target: "client", success: code === 0 });
  }

  if (target === "crdt" || target === "verify") {
    if (!config.output.quiet) {
      console.log(colorize("\n=== CRDT Verification ===\n", "bold", config.output.color));
    }

    const crdts = ["GCounter", "PNCounter", "ORSet", "LWWRegister"];
    for (const crdt of crdts) {
      const p = new Deno.Command("mix", {
        args: ["run", "-e", `:ok = Laniakea.CRDT.verify(Laniakea.CRDT.${crdt})`],
        cwd: join(ROOT, "server"),
        stdout: "piped",
        stderr: "piped",
      });

      const { code } = await p.output();
      const status = code === 0;
      results.push({ target: `crdt:${crdt}`, success: status });

      if (!config.output.quiet) {
        const symbol = status ? "✓" : "✗";
        const color = status ? "green" : "red";
        console.log(`${colorize(symbol, color, config.output.color)} ${crdt}`);
      }
    }
  }

  if (target === "property") {
    if (!config.output.quiet) {
      console.log(colorize("\n=== Property Tests ===\n", "bold", config.output.color));
    }

    const p = new Deno.Command("mix", {
      args: ["test", "--only", "property"],
      cwd: join(ROOT, "server"),
      stdout: "inherit",
      stderr: "inherit",
    });

    const { code } = await p.output();
    results.push({ target: "property", success: code === 0 });
  }

  const allPassed = results.every(r => r.success);

  if (config.output.format !== "plain") {
    console.log(formatOutput(results, config.output.format, config.output.color));
  }

  return { success: allPassed, data: results, exitCode: allPassed ? 0 : 1 };
}

async function cmdQuality(args: string[], config: Config): Promise<CommandResult> {
  const check = args[0] ?? "all";
  const results: Array<{ check: string; success: boolean }> = [];

  if (check === "all" || check === "format") {
    if (!config.output.quiet) {
      console.log(colorize("Checking formatting...", "cyan", config.output.color));
    }

    // Server format
    const serverFmt = new Deno.Command("mix", {
      args: ["format", "--check-formatted"],
      cwd: join(ROOT, "server"),
      stdout: "null",
      stderr: "piped",
    });
    const { code: sfCode } = await serverFmt.output();
    results.push({ check: "format:server", success: sfCode === 0 });

    // Client format
    const clientFmt = new Deno.Command("deno", {
      args: ["fmt", "--check"],
      cwd: join(ROOT, "client"),
      stdout: "null",
      stderr: "piped",
    });
    const { code: cfCode } = await clientFmt.output();
    results.push({ check: "format:client", success: cfCode === 0 });
  }

  if (check === "all" || check === "lint") {
    if (!config.output.quiet) {
      console.log(colorize("Running linters...", "cyan", config.output.color));
    }

    // Credo
    const credo = new Deno.Command("mix", {
      args: ["credo", "--strict"],
      cwd: join(ROOT, "server"),
      stdout: config.output.verbose ? "inherit" : "null",
      stderr: "piped",
    });
    const { code: credoCode } = await credo.output();
    results.push({ check: "lint:credo", success: credoCode === 0 });

    // Deno lint
    const denoLint = new Deno.Command("deno", {
      args: ["lint"],
      cwd: join(ROOT, "client"),
      stdout: config.output.verbose ? "inherit" : "null",
      stderr: "piped",
    });
    const { code: dlCode } = await denoLint.output();
    results.push({ check: "lint:deno", success: dlCode === 0 });
  }

  if (check === "all" || check === "typecheck") {
    if (!config.output.quiet) {
      console.log(colorize("Type checking...", "cyan", config.output.color));
    }

    // Dialyzer
    const dialyzer = new Deno.Command("mix", {
      args: ["dialyzer"],
      cwd: join(ROOT, "server"),
      stdout: config.output.verbose ? "inherit" : "null",
      stderr: "piped",
    });
    const { code: dCode } = await dialyzer.output();
    results.push({ check: "typecheck:dialyzer", success: dCode === 0 });

    // Deno check
    const denoCheck = new Deno.Command("deno", {
      args: ["check", "src/**/*.mjs"],
      cwd: join(ROOT, "client"),
      stdout: config.output.verbose ? "inherit" : "null",
      stderr: "piped",
    });
    const { code: dcCode } = await denoCheck.output();
    results.push({ check: "typecheck:deno", success: dcCode === 0 });
  }

  const allPassed = results.every(r => r.success);

  if (config.output.format === "plain" && !config.output.quiet) {
    console.log(colorize("\n=== Quality Results ===\n", "bold", config.output.color));
    for (const r of results) {
      const symbol = r.success ? "✓" : "✗";
      const color = r.success ? "green" : "red";
      console.log(`${colorize(symbol, color, config.output.color)} ${r.check}`);
    }
  } else if (config.output.format !== "plain") {
    console.log(formatOutput(results, config.output.format, config.output.color));
  }

  return { success: allPassed, data: results, exitCode: allPassed ? 0 : 1 };
}

async function cmdCrdt(args: string[], config: Config): Promise<CommandResult> {
  const subcommand = args[0] ?? "list";

  switch (subcommand) {
    case "list": {
      const crdts = [
        { name: "GCounter", description: "Grow-only counter", operations: ["increment", "value", "merge"] },
        { name: "PNCounter", description: "Positive-negative counter", operations: ["increment", "decrement", "value", "merge"] },
        { name: "ORSet", description: "Observed-remove set", operations: ["add", "remove", "contains", "elements", "merge"] },
        { name: "LWWRegister", description: "Last-writer-wins register", operations: ["set", "value", "merge"] },
      ];

      console.log(formatOutput(crdts, config.output.format, config.output.color));
      return { success: true, data: crdts, exitCode: 0 };
    }

    case "verify": {
      return cmdTest(["verify"], config);
    }

    case "bench": {
      if (!config.output.quiet) {
        console.log(colorize("Running CRDT benchmarks...", "cyan", config.output.color));
      }

      const p = new Deno.Command("mix", {
        args: ["run", "bench/crdt_bench.exs"],
        cwd: join(ROOT, "server"),
        stdout: "inherit",
        stderr: "inherit",
      });

      const { code } = await p.output();
      return { success: code === 0, exitCode: code };
    }

    default:
      console.error(colorize(`Unknown crdt subcommand: ${subcommand}`, "red", config.output.color));
      return { success: false, error: `Unknown subcommand: ${subcommand}`, exitCode: 1 };
  }
}

async function cmdDb(args: string[], config: Config): Promise<CommandResult> {
  const subcommand = args[0] ?? "status";
  const dbUrl = `http://${config.database.host}:${config.database.port}`;
  const auth = btoa(`${config.database.user}:${config.database.password ?? ""}`);

  switch (subcommand) {
    case "status": {
      try {
        const response = await fetch(`${dbUrl}/_api/version`, {
          headers: { Authorization: `Basic ${auth}` },
        });
        const data = await response.json();

        const status = {
          connected: true,
          host: config.database.host,
          port: config.database.port,
          version: data.version,
          server: data.server,
        };

        console.log(formatOutput(status, config.output.format, config.output.color));
        return { success: true, data: status, exitCode: 0 };
      } catch (e) {
        const status = {
          connected: false,
          host: config.database.host,
          port: config.database.port,
          error: String(e),
        };

        console.log(formatOutput(status, config.output.format, config.output.color));
        return { success: false, data: status, exitCode: 1 };
      }
    }

    case "setup": {
      if (!config.output.quiet) {
        console.log(colorize("Setting up database...", "cyan", config.output.color));
      }

      // Create database
      try {
        await fetch(`${dbUrl}/_api/database`, {
          method: "POST",
          headers: {
            Authorization: `Basic ${auth}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ name: config.database.name }),
        });

        if (!config.output.quiet) {
          console.log(colorize(`Created database: ${config.database.name}`, "green", config.output.color));
        }
      } catch {
        // Database might already exist
      }

      // Create collections
      const collections = ["crdts", "events", "clients", "sessions"];
      for (const collection of collections) {
        try {
          await fetch(`${dbUrl}/_db/${config.database.name}/_api/collection`, {
            method: "POST",
            headers: {
              Authorization: `Basic ${auth}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ name: collection }),
          });

          if (!config.output.quiet) {
            console.log(colorize(`Created collection: ${collection}`, "green", config.output.color));
          }
        } catch {
          // Collection might already exist
        }
      }

      return { success: true, exitCode: 0 };
    }

    case "start": {
      if (!config.output.quiet) {
        console.log(colorize("Starting ArangoDB...", "cyan", config.output.color));
      }

      const p = new Deno.Command("docker", {
        args: [
          "run", "-d",
          "--name", "laniakea-arangodb",
          "-p", `${config.database.port}:8529`,
          "-e", `ARANGO_ROOT_PASSWORD=${config.database.password ?? "laniakea"}`,
          "arangodb:latest",
        ],
        stdout: config.output.quiet ? "null" : "inherit",
        stderr: "inherit",
      });

      const { code } = await p.output();
      return { success: code === 0, exitCode: code };
    }

    case "stop": {
      const p = new Deno.Command("docker", {
        args: ["stop", "laniakea-arangodb"],
        stdout: config.output.quiet ? "null" : "inherit",
        stderr: "inherit",
      });

      await p.output();

      const rm = new Deno.Command("docker", {
        args: ["rm", "laniakea-arangodb"],
        stdout: "null",
        stderr: "null",
      });

      await rm.output();
      return { success: true, exitCode: 0 };
    }

    default:
      console.error(colorize(`Unknown db subcommand: ${subcommand}`, "red", config.output.color));
      return { success: false, error: `Unknown subcommand: ${subcommand}`, exitCode: 1 };
  }
}

async function cmdDocker(args: string[], config: Config): Promise<CommandResult> {
  const subcommand = args[0] ?? "build";

  switch (subcommand) {
    case "build": {
      if (!config.output.quiet) {
        console.log(colorize("Building Docker image...", "cyan", config.output.color));
      }

      const p = new Deno.Command("docker", {
        args: ["build", "-t", `laniakea:${VERSION}`, "."],
        cwd: ROOT,
        stdout: "inherit",
        stderr: "inherit",
      });

      const { code } = await p.output();
      return { success: code === 0, exitCode: code };
    }

    case "run": {
      const p = new Deno.Command("docker", {
        args: [
          "run", "-it", "--rm",
          "-p", `${config.server.port}:4000`,
          `laniakea:${VERSION}`,
        ],
        stdin: "inherit",
        stdout: "inherit",
        stderr: "inherit",
      });

      const { code } = await p.output();
      return { success: code === 0, exitCode: code };
    }

    case "push": {
      const registry = args[1];
      if (!registry) {
        console.error(colorize("Usage: laniakea docker push <registry>", "red", config.output.color));
        return { success: false, error: "Missing registry argument", exitCode: 1 };
      }

      const tag = new Deno.Command("docker", {
        args: ["tag", `laniakea:${VERSION}`, `${registry}/laniakea:${VERSION}`],
        stdout: "inherit",
        stderr: "inherit",
      });
      await tag.output();

      const push = new Deno.Command("docker", {
        args: ["push", `${registry}/laniakea:${VERSION}`],
        stdout: "inherit",
        stderr: "inherit",
      });

      const { code } = await push.output();
      return { success: code === 0, exitCode: code };
    }

    case "compose": {
      const action = args[1] ?? "up";
      const p = new Deno.Command("docker", {
        args: ["compose", action, ...(action === "up" ? ["-d"] : [])],
        cwd: ROOT,
        stdout: "inherit",
        stderr: "inherit",
      });

      const { code } = await p.output();
      return { success: code === 0, exitCode: code };
    }

    default:
      console.error(colorize(`Unknown docker subcommand: ${subcommand}`, "red", config.output.color));
      return { success: false, error: `Unknown subcommand: ${subcommand}`, exitCode: 1 };
  }
}

async function cmdConfig(args: string[], config: Config): Promise<CommandResult> {
  const subcommand = args[0] ?? "show";

  switch (subcommand) {
    case "show": {
      console.log(formatOutput(config, config.output.format, config.output.color));
      return { success: true, data: config, exitCode: 0 };
    }

    case "validate": {
      if (!config.output.quiet) {
        console.log(colorize("Validating Nickel configuration...", "cyan", config.output.color));
      }

      const p = new Deno.Command("nickel", {
        args: ["export", "--format", "json", join(ROOT, "schemas/config.ncl")],
        stdout: "piped",
        stderr: "piped",
      });

      const { code, stdout, stderr } = await p.output();

      if (code === 0) {
        if (!config.output.quiet) {
          console.log(colorize("Configuration is valid!", "green", config.output.color));
        }
        if (config.output.verbose) {
          console.log(new TextDecoder().decode(stdout));
        }
      } else {
        console.error(colorize("Configuration validation failed:", "red", config.output.color));
        console.error(new TextDecoder().decode(stderr));
      }

      return { success: code === 0, exitCode: code };
    }

    case "export": {
      const outputPath = args[1] ?? "config.json";
      const format = args[2] ?? "json";

      const p = new Deno.Command("nickel", {
        args: ["export", "--format", format, join(ROOT, "schemas/config.ncl")],
        stdout: "piped",
        stderr: "piped",
      });

      const { code, stdout } = await p.output();

      if (code === 0) {
        await Deno.writeFile(outputPath, stdout);
        if (!config.output.quiet) {
          console.log(colorize(`Configuration exported to ${outputPath}`, "green", config.output.color));
        }
      }

      return { success: code === 0, exitCode: code };
    }

    case "generate": {
      const env = args[1] ?? "dev";

      if (!config.output.quiet) {
        console.log(colorize(`Generating ${env} configuration...`, "cyan", config.output.color));
      }

      const p = new Deno.Command("nickel", {
        args: [
          "export",
          "--format", "json",
          "--field", `environments.${env}`,
          join(ROOT, "schemas/config.ncl"),
        ],
        stdout: "piped",
        stderr: "piped",
      });

      const { code, stdout } = await p.output();

      if (code === 0) {
        const outputPath = join(ROOT, "server/config/generated.json");
        await Deno.writeFile(outputPath, stdout);
        if (!config.output.quiet) {
          console.log(colorize(`Generated configuration at ${outputPath}`, "green", config.output.color));
        }
      }

      return { success: code === 0, exitCode: code };
    }

    default:
      console.error(colorize(`Unknown config subcommand: ${subcommand}`, "red", config.output.color));
      return { success: false, error: `Unknown subcommand: ${subcommand}`, exitCode: 1 };
  }
}

async function cmdRsr(args: string[], config: Config): Promise<CommandResult> {
  const level = args[0] ?? "check";
  const results: Array<{ requirement: string; status: string }> = [];

  // Check required files
  const requiredFiles = [
    "README.adoc",
    "LICENSE",
    "SECURITY.md",
    "CONTRIBUTING.md",
    "CODE_OF_CONDUCT.md",
    "MAINTAINERS.md",
    "CHANGELOG.md",
    ".well-known/security.txt",
  ];

  if (!config.output.quiet) {
    console.log(colorize("\n=== RSR Compliance Check ===\n", "bold", config.output.color));
  }

  // File checks
  for (const file of requiredFiles) {
    const filePath = join(ROOT, file);
    const fileExists = await exists(filePath);
    results.push({
      requirement: `File: ${file}`,
      status: fileExists ? "pass" : "fail",
    });
  }

  // Type safety (Dialyzer)
  if (level === "bronze" || level === "silver" || level === "gold" || level === "platinum") {
    const dialyzer = new Deno.Command("mix", {
      args: ["dialyzer", "--halt-exit-status"],
      cwd: join(ROOT, "server"),
      stdout: "null",
      stderr: "null",
    });
    const { code } = await dialyzer.output();
    results.push({ requirement: "Type Safety (Dialyzer)", status: code === 0 ? "pass" : "fail" });
  }

  // Tests pass
  if (level === "bronze" || level === "silver" || level === "gold" || level === "platinum") {
    const tests = new Deno.Command("mix", {
      args: ["test"],
      cwd: join(ROOT, "server"),
      stdout: "null",
      stderr: "null",
    });
    const { code } = await tests.output();
    results.push({ requirement: "Tests Pass", status: code === 0 ? "pass" : "fail" });
  }

  // CRDT verification
  if (level === "bronze" || level === "silver" || level === "gold" || level === "platinum") {
    const crdts = ["GCounter", "PNCounter", "ORSet", "LWWRegister"];
    let allVerified = true;

    for (const crdt of crdts) {
      const verify = new Deno.Command("mix", {
        args: ["run", "-e", `:ok = Laniakea.CRDT.verify(Laniakea.CRDT.${crdt})`],
        cwd: join(ROOT, "server"),
        stdout: "null",
        stderr: "null",
      });
      const { code } = await verify.output();
      if (code !== 0) allVerified = false;
    }

    results.push({ requirement: "CRDT Verification", status: allVerified ? "pass" : "fail" });
  }

  // Format check
  if (level === "silver" || level === "gold" || level === "platinum") {
    const format = new Deno.Command("mix", {
      args: ["format", "--check-formatted"],
      cwd: join(ROOT, "server"),
      stdout: "null",
      stderr: "null",
    });
    const { code } = await format.output();
    results.push({ requirement: "Code Formatting", status: code === 0 ? "pass" : "fail" });
  }

  // Lint check
  if (level === "gold" || level === "platinum") {
    const credo = new Deno.Command("mix", {
      args: ["credo", "--strict"],
      cwd: join(ROOT, "server"),
      stdout: "null",
      stderr: "null",
    });
    const { code } = await credo.output();
    results.push({ requirement: "Linting (Credo)", status: code === 0 ? "pass" : "fail" });
  }

  // Security audit
  if (level === "platinum") {
    results.push({ requirement: "Security Audit", status: "manual" });
    results.push({ requirement: "Performance Benchmarks", status: "manual" });
  }

  // Display results
  const passed = results.filter(r => r.status === "pass").length;
  const failed = results.filter(r => r.status === "fail").length;
  const manual = results.filter(r => r.status === "manual").length;

  if (config.output.format === "plain") {
    for (const r of results) {
      const symbol = r.status === "pass" ? "✓" : r.status === "fail" ? "✗" : "○";
      const color = r.status === "pass" ? "green" : r.status === "fail" ? "red" : "yellow";
      console.log(`${colorize(symbol, color, config.output.color)} ${r.requirement}`);
    }

    console.log(colorize(`\nResults: ${passed} passed, ${failed} failed, ${manual} manual`,
      failed === 0 ? "green" : "yellow", config.output.color));
  } else {
    console.log(formatOutput({ results, summary: { passed, failed, manual } }, config.output.format, config.output.color));
  }

  return { success: failed === 0, data: results, exitCode: failed === 0 ? 0 : 1 };
}

async function cmdGen(args: string[], config: Config): Promise<CommandResult> {
  const type = args[0];

  switch (type) {
    case "secret": {
      const bytes = new Uint8Array(64);
      crypto.getRandomValues(bytes);
      const secret = Array.from(bytes).map(b => b.toString(16).padStart(2, "0")).join("");
      console.log(secret);
      return { success: true, data: secret, exitCode: 0 };
    }

    case "uuid": {
      const uuid = crypto.randomUUID();
      console.log(uuid);
      return { success: true, data: uuid, exitCode: 0 };
    }

    case "node-id": {
      const uuid = crypto.randomUUID();
      const nodeId = `node_${uuid.replace(/-/g, "").substring(0, 16)}`;
      console.log(nodeId);
      return { success: true, data: nodeId, exitCode: 0 };
    }

    default:
      console.error(colorize("Usage: laniakea gen <secret|uuid|node-id>", "red", config.output.color));
      return { success: false, error: "Unknown generator type", exitCode: 1 };
  }
}

async function cmdStats(_args: string[], config: Config): Promise<CommandResult> {
  const stats: Record<string, unknown> = {};

  // Count Elixir lines
  try {
    const p = new Deno.Command("find", {
      args: [join(ROOT, "server/lib"), "-name", "*.ex", "-exec", "wc", "-l", "{}", "+"],
      stdout: "piped",
      stderr: "null",
    });
    const { stdout } = await p.output();
    const output = new TextDecoder().decode(stdout);
    const match = output.match(/(\d+)\s+total/);
    stats.elixirLines = match ? parseInt(match[1]) : 0;
  } catch {
    stats.elixirLines = 0;
  }

  // Count ReScript lines
  try {
    const p = new Deno.Command("find", {
      args: [join(ROOT, "client/src"), "-name", "*.res", "-exec", "wc", "-l", "{}", "+"],
      stdout: "piped",
      stderr: "null",
    });
    const { stdout } = await p.output();
    const output = new TextDecoder().decode(stdout);
    const match = output.match(/(\d+)\s+total/);
    stats.rescriptLines = match ? parseInt(match[1]) : 0;
  } catch {
    stats.rescriptLines = 0;
  }

  // Count CRDTs
  stats.crdtCount = 4;
  stats.crdtTypes = ["GCounter", "PNCounter", "ORSet", "LWWRegister"];

  // Count tests
  try {
    const p = new Deno.Command("find", {
      args: [join(ROOT, "server/test"), "-name", "*_test.exs"],
      stdout: "piped",
      stderr: "null",
    });
    const { stdout } = await p.output();
    const files = new TextDecoder().decode(stdout).trim().split("\n").filter(f => f);
    stats.testFileCount = files.length;
  } catch {
    stats.testFileCount = 0;
  }

  // Count dependencies
  try {
    const mixLock = await Deno.readTextFile(join(ROOT, "server/mix.lock"));
    stats.elixirDeps = (mixLock.match(/"[^"]+": \{/g) || []).length;
  } catch {
    stats.elixirDeps = 0;
  }

  stats.version = VERSION;

  console.log(formatOutput(stats, config.output.format, config.output.color));
  return { success: true, data: stats, exitCode: 0 };
}

// ============================================================================
// Help
// ============================================================================

function printHelp(useColor: boolean): void {
  const c = (text: string, color: keyof typeof colors) => colorize(text, color, useColor);

  console.log(`
${c("Laniakea CLI", "bold")} v${VERSION}
${c("Distributed CRDT-based web architecture", "dim")}

${c("USAGE:", "yellow")}
    laniakea [OPTIONS] <COMMAND> [ARGS]

${c("COMMANDS:", "yellow")}
    ${c("version", "green")}              Show version information
    ${c("doctor", "green")}               Check system dependencies
    ${c("server", "green")} <CMD>         Server operations (start, iex, release)
    ${c("client", "green")} <CMD>         Client operations (build, watch, clean)
    ${c("test", "green")} [TARGET]        Run tests (all, server, client, crdt, property)
    ${c("quality", "green")} [CHECK]      Run quality checks (all, format, lint, typecheck)
    ${c("crdt", "green")} <CMD>           CRDT operations (list, verify, bench)
    ${c("db", "green")} <CMD>             Database operations (status, setup, start, stop)
    ${c("docker", "green")} <CMD>         Docker operations (build, run, push, compose)
    ${c("config", "green")} <CMD>         Configuration (show, validate, export, generate)
    ${c("rsr", "green")} [LEVEL]          RSR compliance check (check, bronze, silver, gold, platinum)
    ${c("gen", "green")} <TYPE>           Generate values (secret, uuid, node-id)
    ${c("stats", "green")}                Show project statistics

${c("OPTIONS:", "yellow")}
    ${c("-h, --help", "cyan")}            Show this help message
    ${c("-V, --version", "cyan")}         Show version
    ${c("-v, --verbose", "cyan")}         Enable verbose output
    ${c("-q, --quiet", "cyan")}           Suppress non-essential output
    ${c("--config", "cyan")} <PATH>       Path to config file
    ${c("--format", "cyan")} <FMT>        Output format (json, yaml, table, plain)
    ${c("--no-color", "cyan")}            Disable colored output
    ${c("--color", "cyan")}               Force colored output

${c("SERVER OPTIONS:", "yellow")}
    ${c("--host", "cyan")} <HOST>         Server host (default: localhost)
    ${c("--port", "cyan")} <PORT>         Server port (default: 4000)
    ${c("--secret", "cyan")} <KEY>        Phoenix secret key base

${c("DATABASE OPTIONS:", "yellow")}
    ${c("--db-host", "cyan")} <HOST>      Database host (default: localhost)
    ${c("--db-port", "cyan")} <PORT>      Database port (default: 8529)
    ${c("--db-name", "cyan")} <NAME>      Database name (default: laniakea)
    ${c("--db-user", "cyan")} <USER>      Database user (default: root)
    ${c("--db-password", "cyan")} <PASS>  Database password

${c("CRDT OPTIONS:", "yellow")}
    ${c("--sync-interval", "cyan")} <MS>  Sync interval in milliseconds
    ${c("--max-drift", "cyan")} <MS>      Max clock drift in milliseconds

${c("ENVIRONMENT VARIABLES:", "yellow")}
    LANIAKEA_CONFIG       Path to configuration file
    LANIAKEA_HOST         Server host
    LANIAKEA_PORT         Server port
    SECRET_KEY_BASE       Phoenix secret key
    ARANGO_HOST           ArangoDB host
    ARANGO_PORT           ArangoDB port
    ARANGO_PASSWORD       ArangoDB password

${c("EXAMPLES:", "yellow")}
    ${c("# Start development server", "dim")}
    laniakea server start

    ${c("# Run all tests with JSON output", "dim")}
    laniakea --format json test all

    ${c("# Check RSR platinum compliance", "dim")}
    laniakea rsr platinum

    ${c("# Build and push Docker image", "dim")}
    laniakea docker build && laniakea docker push ghcr.io/myorg

    ${c("# Generate configuration for production", "dim")}
    laniakea config generate prod

    ${c("# Run quality checks quietly", "dim")}
    laniakea -q quality all

${c("WORKFLOW INTEGRATION:", "yellow")}
    ${c("# CI pipeline", "dim")}
    laniakea -q --format json quality all && laniakea -q test all

    ${c("# Pre-commit hook", "dim")}
    laniakea -q quality format lint

    ${c("# Release verification", "dim")}
    laniakea rsr platinum && laniakea server release

${c("MORE INFO:", "yellow")}
    Documentation: https://laniakea.dev/docs
    Repository:    https://github.com/laniakea/laniakea
    Issues:        https://github.com/laniakea/laniakea/issues
`);
}

// ============================================================================
// Main
// ============================================================================

async function main(): Promise<number> {
  const args = parse(Deno.args, {
    boolean: ["help", "version", "verbose", "quiet", "color", "no-color"],
    string: ["config", "format", "host", "secret", "db-host", "db-name", "db-user", "db-password"],
    default: {
      format: "plain",
    },
    alias: {
      h: "help",
      V: "version",
      v: "verbose",
      q: "quiet",
    },
    "--": true,
  });

  // Early exits
  if (args.version) {
    console.log(`laniakea ${VERSION}`);
    return 0;
  }

  const useColor = args["no-color"] ? false : args.color ?? Deno.isatty(Deno.stdout.rid);

  if (args.help || args._.length === 0) {
    printHelp(useColor);
    return 0;
  }

  // Load and merge config
  const fileConfig = await loadConfig(args.config);
  const config = mergeConfig(fileConfig, args as Record<string, unknown>);

  // Route command
  const command = String(args._[0]);
  const commandArgs = args._.slice(1).map(String);

  let result: CommandResult;

  switch (command) {
    case "version":
      result = await cmdVersion(commandArgs, config);
      break;
    case "doctor":
      result = await cmdDoctor(commandArgs, config);
      break;
    case "server":
      result = await cmdServer(commandArgs, config);
      break;
    case "client":
      result = await cmdClient(commandArgs, config);
      break;
    case "test":
      result = await cmdTest(commandArgs, config);
      break;
    case "quality":
      result = await cmdQuality(commandArgs, config);
      break;
    case "crdt":
      result = await cmdCrdt(commandArgs, config);
      break;
    case "db":
      result = await cmdDb(commandArgs, config);
      break;
    case "docker":
      result = await cmdDocker(commandArgs, config);
      break;
    case "config":
      result = await cmdConfig(commandArgs, config);
      break;
    case "rsr":
      result = await cmdRsr(commandArgs, config);
      break;
    case "gen":
      result = await cmdGen(commandArgs, config);
      break;
    case "stats":
      result = await cmdStats(commandArgs, config);
      break;
    default:
      console.error(colorize(`Unknown command: ${command}`, "red", useColor));
      console.error(`Run 'laniakea --help' for usage information.`);
      return 1;
  }

  return result.exitCode;
}

// Run
Deno.exit(await main());
