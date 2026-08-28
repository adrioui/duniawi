# IRCAM nn~ Pd external, fetched from an upstream release tarball.
#
# The release bundles the TorchScript runtime and the Pd external in one
# directory. We flatten that directory into the store root so the Pd wrapper
# can pass it directly as a -path plugin search directory.
{
  stdenv,
  fetchurl,
  lib,
}:

stdenv.mkDerivation rec {
  pname = "nn-tilde";
  version = "1.6.0";

  src = fetchurl {
    url = "https://github.com/acids-ircam/nn_tilde/releases/download/v${version}/nn_puredata_macos_ub.tar.gz";
    sha256 = "sha256-8zOdFBk1u6Hkd6TnZ/lAq4rzBMORBDw8R2ygKXK2Kw0=";
  };

  sourceRoot = "nn_tilde";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -R . $out/
    runHook postInstall
  '';

  meta = {
    description = "nn~ Pure Data external for running TorchScript audio models (RAVE, vschaos2)";
    homepage = "https://github.com/acids-ircam/nn_tilde";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.darwin;
  };
}
