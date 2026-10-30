{ pkgs, ... }:

{
  system.autoUpgrade = {
    enable = true;
    dates = "03:00";
    randomizedDelaySec = "0";
    allowReboot = false;
  };

  boot.loader.systemd-boot.configurationLimit = 3;

  systemd.services.nixos-upgrade.serviceConfig.ExecStartPost =
    "${pkgs.writeShellScript "prune-nixos-generations" ''
      set -e
      ${pkgs.nix}/bin/nix-env \
        --profile /nix/var/nix/profiles/system \
        --delete-generations +3
    ''}";

  nix.gc = {
    automatic = true;
    dates = "04:00";
  };
}
