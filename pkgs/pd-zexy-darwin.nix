# zexy externals (IOhannes m zmoelnig), from the upstream Deken release.
#
# Provides control objects missing from vanilla Pd that GEM-era patches rely
# on, notably [repeat] (repeat a message N times, like [until] but passing
# through whatever comes in instead of bangs). Used by the LIRA-8 glitch
# visuals, which follow migueloliveros/GEM's GlicthObject.pd structure.
#
# Like the Gem derivation, this unpacks the prebuilt Deken package and puts
# the zexy contents at the store root. The Pd wrapper adds that root as a
# -path search directory; patches load the single-binary library with
# [declare -lib zexy], which resolves zexy.d_fat from that path.
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
    # Named .zip so stdenv's unpacker dispatches on the extension; the Deken
    # .dek suffix means nothing to it.
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
