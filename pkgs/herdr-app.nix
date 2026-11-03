{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  libgcc,
  libglvnd,
  libxcb,
  libxkbcommon,
  makeDesktopItem,
  vulkan-loader,
  wayland,
}:

let
  desktopItem = makeDesktopItem {
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
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-app";
  version = "0.1.12";

  src = fetchurl {
    url = "https://releases.herdr.dev/app/${finalAttrs.version}/herdr-app-linux-x86_64.tar.gz";
    hash = "sha256-omXmySXEh0WEBnQf+gnS+g09S9QBo07YwBwzYQjlfB8=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    libgcc
    libxcb
    libxkbcommon
  ];

  runtimeDependencies = [
    libglvnd
    vulkan-loader
    wayland
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
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
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
