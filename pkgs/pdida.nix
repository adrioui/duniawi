# PDida: a flat collection of ~390 rr_* Pure Data abstractions for generative
# music, by Rolando Rampoldi.
#
# The repository is flat (every .pd sits at the root, with no package index and
# no -lib startup file), so unpacking it to the store root and adding that root
# as a Pd -path search directory is the whole install.
{
  stdenv,
  fetchFromGitHub,
  lib,
}:

stdenv.mkDerivation {
  pname = "pdida";
  version = "unstable-2026-09-02";

  src = fetchFromGitHub {
    owner = "rrampoldi";
    repo = "PDida";
    rev = "9d91da62f51db3517525c8806193809effd29d33";
    hash = "sha256-mrYYdT0gj6/5lrgoSdeldev3mDztbN1fVgaYlz2Sj1c=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -R . $out/
    runHook postInstall
  '';

  meta = {
    description = "Pure Data abstractions for algorithmic composition (rr_* collection)";
    homepage = "https://github.com/rrampoldi/PDida";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.all;
  };
}
