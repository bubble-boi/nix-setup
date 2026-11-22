{ ... }:

{
  system.autoUpgrade = {
    enable = true;
    dates = "*-*-* 03:00:00";
    randomizedDelaySec = "0";
    persistent = true;
    allowReboot = false;
    channel = "https://channels.nixos.org/nixos-26.05";
    operation = "switch";
  };

  boot.loader.systemd-boot.configurationLimit = 5;

  nix.gc = {
    automatic = true;
    dates = "04:00";
    options = "--delete-older-than 14d";
  };
}
