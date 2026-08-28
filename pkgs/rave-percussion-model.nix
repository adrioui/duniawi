# IRCAM RAVE "percussion" model, fetched from the official RAVE API.
#
# The response is a TorchScript .ts archive. We keep the original filename so
# Pd's nn~ can load it by name from a -path search directory.
{
  stdenv,
  fetchurl,
  lib,
}:

stdenv.mkDerivation rec {
  pname = "rave-percussion-model";
  version = "1.0";

  src = fetchurl {
    url = "https://play.forum.ircam.fr/rave-vst-api/download_model/ircam/rave/percussion";
    sha256 = "sha256-EuBE+kzw9GH6eNxeEIJT1f+qOVYEpmqkPjqcOWfe4Pk=";
  };

  dontConfigure = true;
  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp $src $out/percussion.ts
    runHook postInstall
  '';

  meta = {
    description = "RAVE percussion model";
    homepage = "https://forum.ircam.fr/projects/detail/rave/";
    license = lib.licenses.unfree;

    platforms = lib.platforms.darwin;
  };
}
