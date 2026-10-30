{ config, pkgs, ... }:

let
  flakeDir = "/home/qwe/nix-setup";
  flakeRef = "path:${flakeDir}#nixos";

  upgradeScript = pkgs.writeShellScript "upgrade-nixos" ''
    set -euo pipefail

    cd "${flakeDir}"

    exec 9>/run/lock/nixos-flake-update.lock
    ${pkgs.util-linux}/bin/flock -n 9

    backup=$(${pkgs.coreutils}/bin/mktemp)
    ${pkgs.coreutils}/bin/cp -p flake.lock "$backup"

    cleanup() {
      status=$?

      if [ "$status" -ne 0 ]; then
        echo "Update failed. Restoring flake.lock"
        ${pkgs.coreutils}/bin/cp -p "$backup" flake.lock
      fi

      ${pkgs.coreutils}/bin/rm -f "$backup"
    }

    trap cleanup EXIT

    echo "Updating all flake inputs"

    ${pkgs.util-linux}/bin/runuser -u qwe -- \
      ${pkgs.nix}/bin/nix flake update \
        --flake "path:${flakeDir}"

    echo "Building NixOS"

    ${pkgs.nix}/bin/nix build \
      "path:${flakeDir}#nixosConfigurations.nixos.config.system.build.toplevel" \
      --no-link

    echo "Switching NixOS"

    ${config.system.build.nixos-rebuild}/bin/nixos-rebuild \
      switch --flake "${flakeRef}"

    echo "Pruning old generations"

    ${pkgs.nix}/bin/nix-env \
      --profile /nix/var/nix/profiles/system \
      --delete-generations +3 || true
  '';
in
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.autoUpgrade.enable = false;

  systemd.services.nixos-upgrade = {
    description = "Update all NixOS flake inputs";

    restartIfChanged = false;
    stopIfChanged = false;

    serviceConfig = {
      Type = "oneshot";
      ExecStart = upgradeScript;
      TimeoutStartSec = "infinity";
    };
  };

  systemd.timers.nixos-upgrade = {
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnCalendar = "*-*-* 03:00:00";
      Persistent = true;
      RandomizedDelaySec = "0";
    };
  };

  boot.loader.systemd-boot.configurationLimit = 3;

  nix.gc = {
    automatic = true;
    dates = "04:00";
  };
}
