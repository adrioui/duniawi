#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG="${NIX_DARWIN_CONFIG:-adri}"
FLAKE="${NIX_FLAKE_REF:-$ROOT}"
SYSTEM_REF="$FLAKE#darwinConfigurations.$CONFIG.system"
PKGS_REF="$FLAKE#darwinConfigurations.$CONFIG.pkgs"

cd "$ROOT"

usage() {
  cat <<EOF
Usage: hack/feedback_loop.sh <command> [args]

Commands:
  fast              Format Nix files and evaluate the darwin system derivation.
  check             Run the flake checks.
  dry-run           Show what the darwin system build would fetch or build.
  build             Build the darwin system into ./result.
  diff              Build and diff ./result against /run/current-system.
  packages          Print the configured system package names as JSON.
  homebrew          Print configured Homebrew brews and casks as JSON.
  package <attr>    Probe a nixpkgs package attr for this host platform.

Environment:
  NIX_DARWIN_CONFIG Defaults to adri.
  NIX_FLAKE_REF     Defaults to this repository path.
EOF
}

run() {
  printf '\n==> %s\n' "$*"
  "$@"
}

case "${1:-}" in
  fast)
    run nix fmt
    run nix eval --raw "$SYSTEM_REF.drvPath"
    printf '\n'
    ;;

  check)
    run nix flake check --print-build-logs "$FLAKE"
    ;;

  dry-run)
    run nix build --dry-run "$SYSTEM_REF"
    ;;

  build)
    run nix build "$SYSTEM_REF"
    ;;

  diff)
    run nix build "$SYSTEM_REF"

    if [[ ! -e /run/current-system ]]; then
      echo "No /run/current-system exists; skipping closure diff."
      exit 0
    fi

    run nix store diff-closures /run/current-system "$ROOT/result"
    ;;

  packages)
    run nix eval --json "$FLAKE#darwinConfigurations.$CONFIG.config.environment.systemPackages" \
      --apply 'packages: builtins.map (pkg: pkg.pname or pkg.name) packages'
    printf '\n'
    ;;

  homebrew)
    run nix eval --json "$FLAKE#darwinConfigurations.$CONFIG.config.homebrew" \
      --apply 'homebrew: { inherit (homebrew) brews casks; }'
    printf '\n'
    ;;

  package)
    attr="${2:-}"
    if [[ -z "$attr" ]]; then
      echo "Missing package attr."
      usage
      exit 2
    fi

    pkg_ref="$PKGS_REF.$attr"
    run nix eval --raw "$pkg_ref.name"

    printf '\n==> nix eval --json %s.meta.available\n' "$pkg_ref"
    available="$(nix eval --json "$pkg_ref.meta.available")"
    echo "$available"

    run nix eval --json "$pkg_ref.meta.platforms"

    if [[ "$available" != "true" ]]; then
      echo "Package is not available for this host platform; skipping build dry-run."
      exit 1
    fi

    run nix build --dry-run "$pkg_ref"
    ;;

  -h|--help|help|"")
    usage
    ;;

  *)
    echo "Unknown command: $1"
    usage
    exit 2
    ;;
esac
