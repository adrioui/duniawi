{ inputs, ... }:
{
  den.aspects.nixosHardware.nixos = {
    imports = [
      inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14
      inputs.nixos-hardware.nixosModules.common-cpu-intel
      ../hosts/t14/hardware-configuration.nix
    ];
  };
}
