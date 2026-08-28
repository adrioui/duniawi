# IRCAM RAVE "isis" vocal model, fetched from the official RAVE API.
#
# The response is a TorchScript .ts archive. We keep the original filename so
# Pd's nn~ can load it by name from a -path search directory.
{
  stdenv,
  fetchurl,
  lib,
}:

stdenv.mkDerivation rec {
  pname = "rave-isis-model";
  version = "1.0";

  src = fetchurl {
    url = "https://play.forum.ircam.fr/rave-vst-api/download_model/ircam/rave/isis";
    sha256 = "sha256-FsVQIRLrJ82TSGkKd24dYO5PkALihV05NU11QBuMQIs=";
  };

  dontConfigure = true;
  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp $src $out/isis.ts
    runHook postInstall
  '';

  meta = {
    description = "RAVE vocal model trained on the ISiS database";
    homepage = "https://forum.ircam.fr/projects/detail/isis/";
    license = lib.licenses.unfree;

    platforms = lib.platforms.darwin;
  };
}
