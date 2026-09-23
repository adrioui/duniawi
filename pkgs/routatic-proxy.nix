# routatic-proxy release binary. The upstream Homebrew tap fails validation
# under Homebrew 7 (Aliases/oc-go-cc), so the darwin-arm64 asset from the
# release is packaged directly. Bump version and hash from the release
# checksums.txt when upgrading.
{
  stdenv,
  fetchurl,
  lib,
}:

stdenv.mkDerivation rec {
  pname = "routatic-proxy";
  version = "0.6.5";

  src = fetchurl {
    url = "https://github.com/routatic/proxy/releases/download/v${version}/routatic-proxy_darwin-arm64";
    hash = "sha256-mz4RKLuadHchKymHIXXXdW5T/NXAzxGGCoE1Yev8Wn4=";
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/routatic-proxy
    runHook postInstall
  '';

  meta = {
    description = "Proxy Claude Code requests to OpenCode Go";
    homepage = "https://github.com/routatic/proxy";
    license = lib.licenses.agpl3Only;
    mainProgram = "routatic-proxy";
    platforms = lib.platforms.darwin;
  };
}
