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
