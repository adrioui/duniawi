# Pd wrapper that adds Nix-managed external/abstraction search paths.
#
# This mirrors nixpkgs' puredata-with-plugins wrapper but takes an already
# overridden puredata package (the nixpkgs puredata build needs the SDK
# availability warning relaxed on this Darwin setup).
{
  symlinkJoin,
  puredata,
  makeWrapper,
  plugins,
}:

symlinkJoin {
  name = "puredata-with-externals-${puredata.version}";

  paths = [ puredata ] ++ plugins;

  nativeBuildInputs = [ makeWrapper ];

  postBuild = ''
    wrapProgram $out/bin/pd \
      --add-flags "${toString (map (x: "-path ${x}/") plugins)}"
  '';
}
