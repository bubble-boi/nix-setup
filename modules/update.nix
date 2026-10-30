{ pkgs, ... }:

let
  flakeDir = "/home/qwe/nix-setup";
  flakeRef = "path:${flakeDir}";

  updateFlake = pkgs.writeShellScript "update-flake" ''
    set -euo pipefail

    ${pkgs.util-linux}/bin/runuser -u qwe -- \
      ${pkgs.nix}/bin/nix \
        --extra-experimental-features "nix-command flakes" \
        flake update nixpkgs \
        --flake "${flakeRef}"
  '';

  pruneGenerations = pkgs.writeShellScript "prune-nixos-generations" ''
    set -euo pipefail

    ${pkgs.nix}/bin/nix-env \
      --profile /nix/var/nix/profiles/system \
      --delete-generations +3
  '';
in
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.autoUpgrade = {
    enable = true;
    flake = "${flakeRef}#nixos";
    upgrade = false;
    dates = "03:00";
    randomizedDelaySec = "0";
    allowReboot = false;
  };

  systemd.services.nixos-upgrade.serviceConfig = {
    ExecStartPre = updateFlake;
    ExecStartPost = pruneGenerations;
  };

  boot.loader.systemd-boot.configurationLimit = 3;

  nix.gc = {
    automatic = true;
    dates = "04:00";
  };
}
