{
  lib,
  stdenv,
  nodejs,
  makeWrapper,
}:

stdenv.mkDerivation {
  pname = "amp-deepseek-proxy";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/amp-deepseek $out/bin
    cp proxy.mjs $out/lib/amp-deepseek/proxy.mjs
    makeWrapper ${nodejs}/bin/node $out/bin/amp-deepseek-proxy \
      --add-flags "$out/lib/amp-deepseek/proxy.mjs"
    runHook postInstall
  '';

  meta = {
    description = "Minimal Amp to DeepSeek Anthropic proxy";
    license = lib.licenses.mit;
    mainProgram = "amp-deepseek-proxy";
  };
}
