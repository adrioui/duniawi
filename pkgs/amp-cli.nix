{
  stdenvNoCC,
  lib,
  fetchurl,
  gzip,
  makeWrapper,
  ripgrep,
  autoPatchelfHook ? null,
  glibc ? null,
  cctools ? null,
  darwin ? null,
  rcodesign ? null,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "amp-cli";
  version = "0.0.1793462430-g2650be";

  src = fetchurl {
    url = "https://static.ampcode.com/cli/${finalAttrs.version}/${
      if stdenvNoCC.hostPlatform.isDarwin then "amp-darwin-arm64.gz" else "amp-linux-x64.gz"
    }";
    hash =
      if stdenvNoCC.hostPlatform.isDarwin then
        "sha256-oqACkG+PJeBI4DVldP9AbrvZEWFzMnxkqR1MYhr5DJE="
      else
        "sha256-vi8KehFrc1Xoexbgdk1wjs4VKpPeVb+m2oyIQU1F2YY=";
  };

  nativeBuildInputs = [
    gzip
    makeWrapper
  ]
  ++ lib.optional stdenvNoCC.hostPlatform.isLinux autoPatchelfHook;

  buildInputs = lib.optional stdenvNoCC.hostPlatform.isLinux glibc;

  strictDeps = true;

  dontUnpack = true;
  dontStrip = true;
  dontFixup = stdenvNoCC.hostPlatform.isDarwin;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec/amp-cli
    gunzip -c $src > $out/libexec/amp-cli/amp
    chmod +x $out/libexec/amp-cli/amp

    makeWrapper $out/libexec/amp-cli/amp $out/bin/amp \
      --set AMP_SKIP_UPDATE_CHECK 1 \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}

    runHook postInstall
  '';

  postInstall = lib.optionalString stdenvNoCC.hostPlatform.isDarwin ''
    '${lib.getExe' cctools "${cctools.targetPrefix}install_name_tool"}' $out/libexec/amp-cli/amp \
      -change /usr/lib/libicucore.A.dylib '${lib.getLib darwin.ICU}/lib/libicucore.A.dylib'
    '${lib.getExe rcodesign}' sign --code-signature-flags linker-signed $out/libexec/amp-cli/amp
  '';

  meta = {
    description = "CLI for Amp, an agentic coding agent in research preview from Sourcegraph";
    homepage = "https://ampcode.com/";
    downloadPage = "https://ampcode.com/install";
    license = lib.licenses.unfree;
    mainProgram = "amp";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
