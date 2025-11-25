# SPDX-License-Identifier: MIT OR Apache-2.0
# Laniakea Nix Flake
#
# Usage:
#   nix develop          - Enter development shell
#   nix build            - Build the project
#   nix flake check      - Run checks
#
{
  description = "Laniakea - Distributed state architecture for browser-as-peer web applications";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Rust overlay for any Rust tools
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        # Erlang/Elixir
        erlang = pkgs.erlang_26;
        elixir = pkgs.elixir_1_15;

        # Node/Deno
        deno = pkgs.deno;

        # Build tools
        just = pkgs.just;

        # Configuration
        nickel = pkgs.nickel;

        # Development tools
        devTools = with pkgs; [
          # Elixir/Erlang
          erlang
          elixir
          elixir_ls

          # Deno
          deno

          # Build tools
          just
          gnumake

          # Configuration
          nickel

          # Version control
          git
          gh

          # Database
          # arangodb  # Uncomment if available in nixpkgs

          # Utilities
          curl
          jq
          yq

          # Documentation
          asciidoctor

          # Security
          trivy

          # Formatting
          treefmt
          nixpkgs-fmt
        ];

      in
      {
        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = devTools;

          shellHook = ''
            echo "╔═══════════════════════════════════════════════════════════════════╗"
            echo "║                      LANIAKEA DEV SHELL                           ║"
            echo "║         Distributed state finds its way home                      ║"
            echo "╠═══════════════════════════════════════════════════════════════════╣"
            echo "║  Elixir:  $(elixir --version | head -1)                           "
            echo "║  Erlang:  OTP $(erl -eval 'io:format("~s", [erlang:system_info(otp_release)])' -noshell -s init stop)"
            echo "║  Deno:    $(deno --version | head -1)                             "
            echo "║  Just:    $(just --version)                                       "
            echo "╚═══════════════════════════════════════════════════════════════════╝"
            echo ""
            echo "Run 'just help' for available commands"

            # Set environment variables
            export MIX_HOME=$PWD/.nix-mix
            export HEX_HOME=$PWD/.nix-hex
            export ERL_AFLAGS="-kernel shell_history enabled"

            # Create directories
            mkdir -p $MIX_HOME
            mkdir -p $HEX_HOME

            # Install hex and rebar if not present
            if [ ! -f $MIX_HOME/archives/hex-* ]; then
              mix local.hex --force
            fi
            if [ ! -f $MIX_HOME/elixir/*/rebar3 ]; then
              mix local.rebar --force
            fi
          '';

          # Environment variables
          LANG = "en_US.UTF-8";
          ERL_AFLAGS = "-kernel shell_history enabled";
        };

        # Packages
        packages = {
          default = pkgs.stdenv.mkDerivation {
            pname = "laniakea";
            version = "0.1.0";

            src = ./.;

            buildInputs = [ erlang elixir deno ];

            buildPhase = ''
              export MIX_HOME=$PWD/.mix
              export HEX_HOME=$PWD/.hex
              mkdir -p $MIX_HOME $HEX_HOME

              mix local.hex --force
              mix local.rebar --force

              cd server
              mix deps.get --only prod
              MIX_ENV=prod mix compile
              MIX_ENV=prod mix release
            '';

            installPhase = ''
              mkdir -p $out/bin
              cp -r server/_build/prod/rel/laniakea/* $out/

              # Create wrapper script
              cat > $out/bin/laniakea <<EOF
              #!/bin/sh
              exec $out/bin/laniakea "\$@"
              EOF
              chmod +x $out/bin/laniakea
            '';

            meta = with pkgs.lib; {
              description = "Distributed state architecture for browser-as-peer web applications";
              homepage = "https://github.com/laniakea/laniakea";
              license = with licenses; [ mit asl20 ];
              maintainers = [];
            };
          };
        };

        # Checks
        checks = {
          # Format check
          format = pkgs.runCommand "check-format" { buildInputs = [ elixir deno ]; } ''
            cd ${./.}
            cd server && mix format --check-formatted
            cd ../client && deno fmt --check
            touch $out
          '';

          # Lint check (placeholder)
          lint = pkgs.runCommand "check-lint" { buildInputs = [ elixir ]; } ''
            cd ${./.}
            # cd server && mix credo --strict
            touch $out
          '';
        };

        # Apps
        apps = {
          default = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/laniakea";
          };
        };
      }
    );
}
