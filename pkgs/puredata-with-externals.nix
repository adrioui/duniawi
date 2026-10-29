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
