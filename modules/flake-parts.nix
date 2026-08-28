{
  inputs,
  ...
}:
{
  imports = [ inputs.den.flakeModule ];
  systems = [ "aarch64-darwin" ];
}
