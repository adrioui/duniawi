{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  isDarwin = stdenvNoCC.hostPlatform.isDarwin;
  isLinux = stdenvNoCC.hostPlatform.isLinux;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-core";
  version = "0.1.17";

  src = fetchurl {
    url = "https://releases.herdr.dev/core/${finalAttrs.version}/${
      if isDarwin then "herdr-core-macos-aarch64.tar.gz" else "herdr-core-linux-x86_64.tar.gz"
    }";
    hash =
      if isDarwin then
        "sha256-ztvU1Nm6E4VYgZjdTTxn0mVEePM63VtkRdTQ652l/PM="
      else
        "sha256-guxEBD9olL/bcWuXm4fNpD/X+kawEE57e9k+ZNGpuHc=";
  };

  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m755 herdr-core $out/bin/herdr-core
    ln -s herdr-core $out/bin/hc

    runHook postInstall
  ''
  + lib.optionalString isLinux ''
    install -Dm644 LICENSE $out/share/licenses/herdr-core/LICENSE
    install -Dm644 THIRD-PARTY-NOTICES $out/share/licenses/herdr-core/THIRD-PARTY-NOTICES
  '';

  meta = {
    description = "Runtime that runs Herdr terminals and coding agents";
    homepage = "https://herdr.dev/core/";
    license = lib.licenses.asl20;
    mainProgram = "herdr-core";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
