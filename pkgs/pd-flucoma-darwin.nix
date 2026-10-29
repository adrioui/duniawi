# FluCoMa (Fluid Corpus Manipulation) Pd objects.
#
# Frontier machine-listening externals (Huddersfield / IRCAM orbit):
# real-time loudness, spectral shape, pitch and onset slicing. The LIRA-8
# glitch visuals use them as the colony's ears: arousal, brightness and
# cut triggers follow the actual sound instead of dumb envelope followers.
#
# Pinned to the stable 1.0.10 tag, NOT the rolling `nightly` tag: nightly
# re-uploads under the same URL, so a fixed-output hash pinned against it
# rots and the build fails on hash mismatch.
#
# The Mac .dmg ships universal x86_64+arm64 binaries, so it loads in the
# native-arm64 nix Pd. Unpacked with _7zz; the per-object .pd_darwin
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
