{ pkgs, lib, ... }:

{
  nixpkgs.config.allowUnfreePredicate = pkg:
    lib.getName pkg == "google-chrome";

  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "browser";

      runtimeInputs = [ pkgs.hyprland ];

      text = ''
        exec hyprctl dispatch \
          'hl.dsp.exec_cmd("${pkgs.google-chrome}/bin/google-chrome-stable")'
      '';
    })
  ];
}
