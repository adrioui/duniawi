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
