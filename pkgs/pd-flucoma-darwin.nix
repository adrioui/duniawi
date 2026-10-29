{
  stdenv,
  fetchurl,
  _7zz,
  lib,
}:

stdenv.mkDerivation rec {
  pname = "pd-flucoma";
  version = "1.0.10";

  src = fetchurl {
    url = "https://github.com/flucoma/flucoma-pd/releases/download/${version}/FluCoMa-PD-Mac.dmg";
    hash = "sha256-g/78an4EWceesj5lQKysxevTAJZJZzfzxaQEkoHsVC0=";
  };

  nativeBuildInputs = [ _7zz ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    7zz x "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    payload=$(dirname "$(find . -name 'fluid.loudness~.pd_darwin' | head -n 1)")
    cp -R "$payload"/. $out/
    runHook postInstall
  '';

  meta = {
    description = "FluCoMa machine-listening externals for Pure Data (universal macOS)";
    homepage = "https://www.flucoma.org/";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.darwin;
  };
}
