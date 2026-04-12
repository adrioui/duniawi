{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
  makeWrapper,
}:

buildNpmPackage rec {
  pname = "humanlayer";
  version = "0.20.0";

  src = fetchFromGitHub {
    owner = "humanlayer";
    repo = "humanlayer";
    rev = "5486c0ce95b12cfc2597c7e0e3233c608446d1fd";
    hash = "sha256-x2ajarft++/BL+3ygdtb7v94Mpsbeq0aZ840knTAxZY=";
  };

  sourceRoot = "${src.name}/hlyr";

  npmDepsHash = "sha256-TKGWkVksC1dgtCN00x8UC56JFpWHlIIBa7/gtdWQlPk=";

  nativeBuildInputs = [ makeWrapper ];

  # Skip the prepack script (copies .claude); we install templates manually.
  npmPackFlags = [ "--ignore-scripts" ];

  # Just run the build
  buildPhase = ''
    runHook preBuild
    npm run build
    runHook postBuild
  '';

  # Install manually since the default npm install has issues
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/humanlayer
    cp -r dist $out/lib/humanlayer/
    cp package.json $out/lib/humanlayer/

    # Claude Code templates (used by `humanlayer claude init`)
    cp -r ${src}/.claude $out/lib/humanlayer/

    # Copy node_modules for runtime dependencies
    cp -r node_modules $out/lib/humanlayer/

    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/humanlayer \
      --add-flags "$out/lib/humanlayer/dist/index.js"

    runHook postInstall
  '';

  meta = {
    description = "HumanLayer CLI - thoughts system and developer tools";
    homepage = "https://github.com/humanlayer/humanlayer";
    license = lib.licenses.asl20;
    maintainers = [ ];
    mainProgram = "humanlayer";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
}
