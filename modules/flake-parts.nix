{
  inputs,
  ...
}:
{
  imports = [ inputs.den.flakeModule ];
  systems = [
    "aarch64-darwin"
    "x86_64-linux"
  ];
}
