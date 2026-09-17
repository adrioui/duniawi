# Gem (Graphics Environment for Multimedia), from the upstream prebuilt macOS release.
#
# nixpkgs' gem package is Linux-only (it links libGL, libGLU, glew, libglut,
# libv4l and libx11) and is pinned to a 2023 upstream commit. The Deken release
# ships a darwin fat binary with its dylibs bundled under .darwin-fat/, so this
# derivation unpacks that package and puts the Gem contents at the store root.
# The Pd wrapper adds that root as a -path search directory.
#
# Gem loads its image/film/video/record/model plugins from its own directory by
# glob, so the directory has to stay intact.
{
  stdenv,
  fetchurl,
  lib,
  unzip,
}:

stdenv.mkDerivation rec {
  pname = "pd-gem";
  version = "0.95.0";

  src = fetchurl {
    # Named .zip so stdenv's unpacker dispatches on the extension; the Deken
    # .dek suffix means nothing to it.
    name = "Gem-${version}.zip";
    url = "https://puredata.info/Members/iembot/software/Gem/${version}/Gem%5Bv${version}%5D(Darwin-amd64-32)(Darwin-amd64-64)(Darwin-arm64-32)(Darwin-arm64-64).dek";
    hash = "sha256-+WTWNVcaellnlf4kwtHe/X57aYFjLAq2fWTIvrNAhmI=";
  };

  nativeBuildInputs = [ unzip ];

  sourceRoot = "Gem";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -R . $out/
    runHook postInstall
  '';

  meta = {
    description = "Graphics Environment for Multimedia for Pure Data (prebuilt macOS)";
    homepage = "https://gem.iem.at/";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.darwin;
  };
}
