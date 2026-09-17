# RAVE "water" model, from the Intelligent Instruments Lab model collection.
#
# The response is a TorchScript .ts archive. Pd's nn~ resolves models by bare
# filename inside a -path search directory, so the store hash prefix must not
# end up on the installed name.
{
  stdenv,
  fetchurl,
  lib,
}:

stdenv.mkDerivation rec {
  pname = "rave-water-model";
  version = "1.0";

  src = fetchurl {
    url = "https://huggingface.co/Intelligent-Instruments-Lab/rave-models/resolve/main/water_pondbrain_b2048_r48000_z16.ts";
    sha256 = "sha256-kJCIgfcfr/XrhCo2cHiBjPaMjznNczaZ4I/8L3Zd5lg=";
  };

  dontConfigure = true;
  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp $src $out/water_pondbrain_b2048_r48000_z16.ts
    runHook postInstall
  '';

  meta = {
    description = "RAVE model trained on water recordings (mono, 48kHz)";
    homepage = "https://huggingface.co/Intelligent-Instruments-Lab/rave-models";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}
