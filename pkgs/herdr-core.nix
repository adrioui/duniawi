{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-core";
  version = "0.1.17";

  src = fetchurl {
    url = "https://releases.herdr.dev/core/${finalAttrs.version}/herdr-core-linux-x86_64.tar.gz";
    hash = "sha256-guxEBD9olL/bcWuXm4fNpD/X+kawEE57e9k+ZNGpuHc=";
  };

  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 herdr-core $out/bin/herdr-core
    ln -s herdr-core $out/bin/hc
    install -Dm644 LICENSE $out/share/licenses/herdr-core/LICENSE
    install -Dm644 THIRD-PARTY-NOTICES $out/share/licenses/herdr-core/THIRD-PARTY-NOTICES

    runHook postInstall
  '';

  meta = {
    description = "Runtime that runs Herdr terminals and coding agents";
    homepage = "https://herdr.dev/core/";
    license = lib.licenses.asl20;
    mainProgram = "herdr-core";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
