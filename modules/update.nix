{ ... }:

{
  system.autoUpgrade = {
    enable = true;
    channel = "https://channels.nixos.org/nixos-26.05";
    flags = [ "-I" "nixos-config=/home/qwe/nix-setup/configuration.nix" ];
    dates = "03:00";
    persistent = true;
    randomizedDelaySec = "0";
    allowReboot = false;
  };

  boot.loader.systemd-boot.configurationLimit = 5;

  nix.gc = {
    automatic = true;
    dates = "04:00";
    options = "--delete-older-than 14d";
  };
}
