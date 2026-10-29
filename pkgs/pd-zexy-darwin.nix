{
  stdenv,
  fetchurl,
  lib,
  unzip,
}:

stdenv.mkDerivation rec {
  pname = "pd-zexy";
  version = "2.4.1";

  src = fetchurl {
    name = "zexy-${version}.zip";
    url = "https://puredata.info/Members/zmoelnigbot/software/zexy/${version}/zexy%5Bv${version}%5D%28Darwin-amd64-32%29%28Darwin-arm64-32%29%28Linux-amd64-32%29%28Linux-arm64-32%29%28Linux-armv7-32%29%28Linux-i386-32%29%28Windows-amd64-32%29%28Windows-i386-32%29.dek";
    hash = "sha256-BVZWmczuSIPbeKHF2dIKo+lv3noX0NxtFIrMDr54lqY=";
  };

  nativeBuildInputs = [ unzip ];

  sourceRoot = "zexy";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -R . $out/
    runHook postInstall
  '';

  meta = {
    description = "zexy externals for Pure Data, incl. [repeat] (prebuilt macOS)";
    homepage = "https://git.iem.at/pd/zexy";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.darwin;
  };
}
