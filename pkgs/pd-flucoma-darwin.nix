# FluCoMa (Fluid Corpus Manipulation) Pd objects, from the upstream nightly.
#
# Frontier machine-listening externals (Huddersfield / IRCAM orbit):
# real-time loudness, spectral shape, pitch and onset slicing. The LIRA-8
# glitch visuals use them as the colony's ears: arousal, brightness and
# cut triggers follow the actual sound instead of dumb envelope followers.
#
# The Mac .dmg ships universal x86_64+arm64 binaries, so it loads in the
# native-arm64 nix Pd. Unpacked with undmg; the per-object .pd_darwin
# binaries land at the store root and the Pd wrapper adds that root as a
# -path search directory (same convention as pd-else).
{
  stdenv,
  fetchurl,
  _7zz,
  lib,
}:

stdenv.mkDerivation rec {
  pname = "pd-flucoma";
  version = "nightly-2026-07-28";

  src = fetchurl {
    url = "https://github.com/flucoma/flucoma-pd/releases/download/nightly/FluCoMa-PD-Mac-nightly.dmg";
    hash = "sha256-71t9wK9xq+yyQnAAEP3VVFpyun7pulqhx71A4NYLu28=";
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
    # Archive layout varies; find the payload dir by its objects.
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
