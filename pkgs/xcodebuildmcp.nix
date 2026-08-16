# XcodeBuild MCP — MCP server + CLI for Xcode/iOS/macOS projects.
# https://github.com/getsentry/XcodeBuildMCP
#
# Source is pinned in flake.nix. `src/version.ts` is upstream-gitignored and
# generated at build time, so it is reconstructed from the checked-in
# package.json fields instead of running upstream's npx-based generator.
{
  buildNpmPackage,
  lib,
  nodejs,
  src,
}:

buildNpmPackage {
  pname = "xcodebuildmcp";
  version = "2.7.0"; # keep in sync with upstream package.json

  inherit src nodejs;

  npmDepsHash = "sha256-PWvpblzfn0yM6hRmdJXzcqyegsytBRZGr0vJQYWdcuA=";

  # Upstream's `build` script delegates to wireit, which needs npx; build the
  # equivalent tsup target directly with the dev deps still installed.
  npmBuildScript = "build:tsup";
  npmBuildFlags = [
    "--"
    "--config"
    "tsup.config.ts"
  ];

  prePatch = ''
    cat > src/version.ts <<'TS'
    export const version = "2.7.0";
    export const iOSTemplateVersion = "v1.0.8";
    export const macOSTemplateVersion = "v1.0.5";
    export const packageName = "xcodebuildmcp";
    export const repositoryOwner = "getsentry";
    export const repositoryName = "XcodeBuildMCP";
    TS
  '';

  meta = {
    description = "Model Context Protocol server and CLI for Xcode projects";
    homepage = "https://github.com/getsentry/XcodeBuildMCP";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
    mainProgram = "xcodebuildmcp";
  };
}
