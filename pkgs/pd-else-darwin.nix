{
  stdenv,
  fetchurl,
  lib,
  unzip,
}:

stdenv.mkDerivation rec {
  pname = "pd-else";
  version = "1.0-rc14";

  src = fetchurl {
    url = "https://github.com/porres/pd-else/releases/download/v.${version}/else-Winsow-Linux-macOS.zip";
    sha256 = "sha256-IaXKGFiwITi/73KDqLGf8axHbrFxujlNoSOCh2w0A9c=";
  };

  nativeBuildInputs = [ unzip ];

  sourceRoot = "else";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -R . $out/
    runHook postInstall
  '';

  meta = {
    description = "EL Locus Solus' Externals for Pure Data (prebuilt macOS)";
    homepage = "https://github.com/porres/pd-else";
    license = lib.licenses.wtfpl;
    platforms = lib.platforms.darwin;
  };
}
