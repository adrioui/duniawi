{
  stdenv,
  fetchurl,
  lib,
  raveIsisModel,
  ravePercussionModel,
  vschaos2Model,
}:

stdenv.mkDerivation rec {
  pname = "nn-tilde-max";
  version = "1.6.0";

  src = fetchurl {
    url = "https://github.com/acids-ircam/nn_tilde/releases/download/v${version}/nn_max_msp_macos_ub.tar.gz";
    sha256 = "057a4yvi1ycc6cc41s4gr8w0dl4jaz5nafn7fad6afncvs3g9n8m";
  };

  sourceRoot = "nn_tilde";

  nativeBuildInputs = [
    raveIsisModel
    ravePercussionModel
    vschaos2Model
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -R . $out/
    mkdir -p $out/models
    cp ${raveIsisModel}/isis.ts $out/models/
    cp ${ravePercussionModel}/percussion.ts $out/models/
    cp ${vschaos2Model}/ordinario_1024.ts $out/models/
    runHook postInstall
  '';

  meta = {
    description = "nn~ Max/MSP external for running TorchScript audio models (RAVE, vschaos2)";
    homepage = "https://github.com/acids-ircam/nn_tilde";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.darwin;
  };
}
