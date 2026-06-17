#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG="${NIX_DARWIN_CONFIG:-adri}"
USERNAME="${NIX_HOME_MANAGER_USER:-adrifadilah}"
SYSTEM="${NIX_SYSTEM:-aarch64-darwin}"
FLAKE="${NIX_FLAKE_REF:-path:$ROOT}"
COMMON_FLAKE_FLAGS=(--show-trace --no-write-lock-file --no-update-lock-file)
SYSTEM_REF="$FLAKE#darwinConfigurations.$CONFIG.system"
HOME_ACTIVATION_REF="$FLAKE#darwinConfigurations.$CONFIG.config.home-manager.users.$USERNAME.home.activationPackage"
PKGS_REF="$FLAKE#darwinConfigurations.$CONFIG.pkgs"
CHECKS_REF_PREFIX="$FLAKE#checks.$SYSTEM"

cd "$ROOT"

usage() {
  cat <<EOF
Usage: hack/feedback_loop.sh <command> [args]

Commands:
  fast              Format Nix files and evaluate darwin + home-manager derivations.
  lint              Run repo-local checks only (nixfmt, deadnix, statix).
  check             Run all flake checks (including darwin + home-manager builds) with keep-going output.
  lock              Audit flake.lock freshness/support with flake-checker.
  dry-run           Show what the darwin system build would fetch or build.
  build             Build the darwin system into ./result.
  diff              Build and diff ./result against /run/current-system.
  packages          Print the configured system package names as JSON.
  homebrew          Print configured Homebrew brews and casks as JSON.
  package <attr>    Probe a nixpkgs package attr for this host platform.

Notes:
  Validation commands are lockfile-read-only by default. Update inputs explicitly
  with 'nix flake update' instead of through the feedback loop.

Environment:
  NIX_DARWIN_CONFIG     Defaults to adri.
  NIX_HOME_MANAGER_USER Defaults to adrifadilah.
  NIX_SYSTEM            Defaults to aarch64-darwin.
  NIX_FLAKE_REF         Defaults to path:this repository (avoids git ownership issues under sudo).
EOF
}

run() {
  printf '\n==> %s\n' "$*"
  "$@"
}

case "${1:-}" in
  fast)
    run nix fmt "${COMMON_FLAKE_FLAGS[@]}"
    run nix eval "${COMMON_FLAKE_FLAGS[@]}" --raw "$SYSTEM_REF.drvPath"
    run nix eval "${COMMON_FLAKE_FLAGS[@]}" --raw "$HOME_ACTIVATION_REF.drvPath"
    printf '\n'
    ;;

  lint)
    run nix build "${COMMON_FLAKE_FLAGS[@]}" --print-build-logs \
      "$CHECKS_REF_PREFIX.nixfmt" \
      "$CHECKS_REF_PREFIX.deadnix" \
      "$CHECKS_REF_PREFIX.statix"
    ;;

  check)
    run nix flake check "${COMMON_FLAKE_FLAGS[@]}" --keep-going --print-build-logs "$FLAKE"
    ;;

  lock)
    run nix run "${COMMON_FLAKE_FLAGS[@]}" "$PKGS_REF.flake-checker" -- "$ROOT/flake.lock"
    ;;

  dry-run)
    run nix build "${COMMON_FLAKE_FLAGS[@]}" --dry-run "$SYSTEM_REF"
    ;;

  build)
    run nix build "${COMMON_FLAKE_FLAGS[@]}" --print-build-logs "$SYSTEM_REF"
    ;;

  diff)
    run nix build "${COMMON_FLAKE_FLAGS[@]}" --print-build-logs "$SYSTEM_REF"

    if [[ ! -e /run/current-system ]]; then
      echo "No /run/current-system exists; skipping closure diff."
      exit 0
    fi

    run nix store diff-closures /run/current-system "$ROOT/result"
    ;;

  packages)
    run nix eval "${COMMON_FLAKE_FLAGS[@]}" --json "$FLAKE#darwinConfigurations.$CONFIG.config.environment.systemPackages" \
      --apply 'packages: builtins.map (pkg: pkg.pname or pkg.name) packages'
    printf '\n'
    ;;

  homebrew)
    run nix eval "${COMMON_FLAKE_FLAGS[@]}" --json "$FLAKE#darwinConfigurations.$CONFIG.config.homebrew" \
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
    run nix eval "${COMMON_FLAKE_FLAGS[@]}" --raw "$pkg_ref.name"

    printf '\n==> nix eval --json %s.meta.available\n' "$pkg_ref"
    available="$(nix eval "${COMMON_FLAKE_FLAGS[@]}" --json "$pkg_ref.meta.available")"
    echo "$available"

    run nix eval "${COMMON_FLAKE_FLAGS[@]}" --json "$pkg_ref.meta.platforms"

    if [[ "$available" != "true" ]]; then
      echo "Package is not available for this host platform; skipping build dry-run."
      exit 1
    fi

    run nix build "${COMMON_FLAKE_FLAGS[@]}" --dry-run "$pkg_ref"
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
