# IRCAM vSchaos2 "ordinario_1024" model, fetched from the official RAVE API.
#
# The response is a TorchScript .ts archive. We keep the original filename so
# Pd's nn~ can load it by name from a -path search directory.
{
  stdenv,
  fetchurl,
  lib,
}:

stdenv.mkDerivation rec {
  pname = "vschaos2-ordinario-1024-model";
  version = "1.0";

  src = fetchurl {
    url = "https://play.forum.ircam.fr/rave-vst-api/download_model/ircam/vschaos2/ordinario_1024";
    sha256 = "sha256-XGmDIknI9Z+2FUggkEmMbGFJmqeU0Vt5pEwlsCQ8iqo=";
  };

  dontConfigure = true;
  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp $src $out/ordinario_1024.ts
    runHook postInstall
  '';

  meta = {
    description = "RAVE vSchaos2 ordinario 1024 model";
    homepage = "https://forum.ircam.fr/projects/detail/rave/";
    license = lib.licenses.unfree;

    platforms = lib.platforms.darwin;
  };
}
