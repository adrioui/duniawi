{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  ripgrep,
  wrapBuddy ? null,
}:

let
  version = "2.2.5";

  platformMap = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    aarch64-darwin = "darwin-arm64";
  };

  platform =
    platformMap.${stdenv.hostPlatform.system}
      or (throw "Unsupported OpenCode 2 platform: ${stdenv.hostPlatform.system}");

  hashes = {
    x86_64-linux = "sha256-kmkO7gemgNPLdgygK6Q4eN6eqxtOXV366HlVGMU2KPQ=";
    aarch64-linux = "sha256-+MWoIHX+3ptbBE7WyKbROtgHp+YsrqHNCoeK3vSesFM=";
    aarch64-darwin = "sha256-39gn3jKBtMPKKwv8j0vrED+mYMQZ0UihpRXENE+enAI=";
  };
in
stdenv.mkDerivation {
  pname = "opencode2";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode/cli-${platform}/-/cli-${platform}-${version}.tgz";
    hash = hashes.${stdenv.hostPlatform.system};
  };

  sourceRoot = "package";

  nativeBuildInputs = [ makeWrapper ] ++ lib.optional stdenv.hostPlatform.isLinux wrapBuddy;

  buildInputs = lib.optional stdenv.hostPlatform.isLinux stdenv.cc.cc.lib;

  wrapBuddyExtraNeeded = lib.optional stdenv.hostPlatform.isLinux "libstdc++.so.6";

  dontBuild = true;
  # Bun-compiled executable; stripping corrupts the embedded payload.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/opencode $out/bin/opencode2
    wrapProgram $out/bin/opencode2 \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}

    runHook postInstall
  '';

  meta = {
    description = "OpenCode 2 CLI";
    homepage = "https://opencode.ai";
    changelog = "https://github.com/anomalyco/opencode/commits/v2";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "opencode2";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
