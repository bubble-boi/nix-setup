{ config, pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "ide";

      runtimeInputs = [
        config.programs.hyprland.package
        pkgs.coreutils
      ];

      text = ''
        cmd="${pkgs.kdePackages.kate}/bin/kate"

        for arg in "$@"; do
          path=$(realpath -m -- "$arg")
          printf -v escaped '%q' "$path"
          cmd+=" $escaped"
        done

        cmd="''${cmd//\\/\\\\}"
        cmd="''${cmd//\"/\\\"}"

        exec hyprctl -i 0 dispatch \
          "hl.dsp.exec_cmd(\"$cmd\")"
      '';
    })
  ];
}

