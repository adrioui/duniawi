{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook ? null,
  libgcc ? null,
  libglvnd ? null,
  libxcb ? null,
  libxkbcommon ? null,
  makeDesktopItem ? null,
  vulkan-loader ? null,
  wayland ? null,
}:

let
  isDarwin = stdenvNoCC.hostPlatform.isDarwin;
  isLinux = stdenvNoCC.hostPlatform.isLinux;

  desktopItem =
    if isLinux then
      makeDesktopItem {
        name = "herdr-app";
        desktopName = "Herdr";
        comment = "Desktop app for terminals and coding agents";
        exec = "herdr-app";
        icon = "herdr-app";
        categories = [
          "Development"
          "Utility"
        ];
        startupNotify = true;
      }
    else
      null;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-app";
  version = "0.1.12";

  src = fetchurl {
    url = "https://releases.herdr.dev/app/${finalAttrs.version}/${
      if isDarwin then "herdr-app-macos-aarch64.tar.gz" else "herdr-app-linux-x86_64.tar.gz"
    }";
    hash =
      if isDarwin then
        "sha256-AGpPaECaeVSNGqbF+Z2okRt9FJEO8qxr0aPc5jTKXQM="
      else
        "sha256-omXmySXEh0WEBnQf+gnS+g09S9QBo07YwBwzYQjlfB8=";
  };

  sourceRoot = if isDarwin then "." else "herdr-app";

  nativeBuildInputs = lib.optional isLinux autoPatchelfHook;

  buildInputs = lib.optionals isLinux [
    libgcc
    libxcb
    libxkbcommon
  ];

  runtimeDependencies = lib.optionals isLinux [
    libglvnd
    vulkan-loader
    wayland
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = isDarwin;
  dontFixup = isDarwin;

  installPhase =
    if isDarwin then
      ''
        runHook preInstall

        mkdir -p $out/Applications $out/bin
        cp -R Herdr.app $out/Applications/Herdr.app
        ln -s $out/Applications/Herdr.app/Contents/MacOS/Herdr $out/bin/herdr-app

        runHook postInstall
      ''
    else
      ''
        runHook preInstall

        install -Dm755 herdr-app $out/bin/herdr-app
        install -Dm644 herdr-app.svg $out/share/icons/hicolor/scalable/apps/herdr-app.svg
        install -Dm644 ${desktopItem}/share/applications/herdr-app.desktop $out/share/applications/herdr-app.desktop
        install -Dm644 LICENSE $out/share/licenses/herdr-app/LICENSE
        install -Dm644 THIRD-PARTY-NOTICES $out/share/licenses/herdr-app/THIRD-PARTY-NOTICES

        runHook postInstall
      '';

  meta = {
    description = "Desktop app for terminals and coding agents";
    homepage = "https://herdr.dev/";
    downloadPage = "https://herdr.dev/download/";
    license = lib.licenses.asl20;
    mainProgram = "herdr-app";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
