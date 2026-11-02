{
  lib,
  writeShellApplication,
  coreutils,
  findutils,
  gawk,
  git,
  gnugrep,
  gnused,
  jq,
  rescueIsoSha256 ? "",
}:
writeShellApplication {
  name = "device-verify";

  runtimeInputs = [
    coreutils
    findutils
    gawk
    git
    gnugrep
    gnused
    jq
  ];

  runtimeEnv = {
    DUNIAWI_RESCUE_ISO_SHA256 = rescueIsoSha256;
  };

  bashOptions = [
    "errexit"
    "errtrace"
    "nounset"
    "pipefail"
  ];

  text = builtins.readFile ../scripts/device-verify.sh;

  meta = {
    description = "t14 device acceptance gate: six layers plus declared-equals-running";
    platforms = lib.platforms.linux;
  };
}
