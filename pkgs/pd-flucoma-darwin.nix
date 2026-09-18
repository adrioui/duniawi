










{
  stdenv,
  fetchurl,
  undmg,
  lib,
}:

stdenv.mkDerivation rec {
  pname = "pd-flucoma";
  version = "nightly-2026-07-28";

  src = fetchurl {
    url = "https://github.com/flucoma/flucoma-pd/releases/download/nightly/FluCoMa-PD-Mac-nightly.dmg";
    hash = "sha256-71t9wK9xq+yyQnAAEP3VVFpyun7pulqhx71A4NYLu28=";
  };

  nativeBuildInputs = [ undmg ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    undmg "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    # undmg layout varies; find the payload dir by its objects.
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
