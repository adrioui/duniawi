{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs,
}:

buildNpmPackage {
  pname = "dsh";
  version = "0.1.0-rc.6";

  src = fetchurl {
    url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-0.1.0-rc.6.tgz";
    sha256 = "sha256-G4qaCtPH/q7OR5JuC9N8oVHHzPqZeVOvpf0BJheE6tw=";
  };

  # The published tarball does not include package-lock.json; keep a generated
  # lockfile next to this derivation so npmDepsHash is reproducible.
  postPatch = ''
    cp ${./dsh-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-yvKSLb3oCpmIIhkrdFPVui9Hpxz68wBLqibDAFlBfbU=";

  # dsh ships prebuilt JS; there is no build script to run.
  dontNpmBuild = true;
  # cordis-plugin-hmr requires Node internals; fixes
  # "failed to apply loader entry ... HMR: --expose-internals is required".
  postFixup = ''
    if [ -f "$out/bin/dsh" ]; then
      substituteInPlace "$out/bin/dsh" --replace-fail 'bin/node"' 'bin/node" --expose-internals'
    fi
  '';

  inherit nodejs;

  meta = {
    description = "DeepSeek Harness CLI: profile boot, plugin management, and browser UI";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    mainProgram = "dsh";
  };
}
