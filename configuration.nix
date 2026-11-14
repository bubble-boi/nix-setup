{ pkgs, lib, ... }:

{
  imports =
    [ ./hardware-configuration.nix ]
    ++ map
      (name: ./modules + "/${name}")
      (builtins.filter
        (name: builtins.match ".*\\.nix" name != null)
        (builtins.attrNames (builtins.readDir ./modules)));

  nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (lib.getName pkg) [
      "google-chrome"
      "spotify"
      "discord"
    ];

  users.users.qwe = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };

  networking.networkmanager.enable = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
    ];
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "26.05";

  time.timeZone = "Asia/Tokyo";

  programs.zsh = {
    enable = true;
    syntaxHighlighting.enable = true;

    loginShellInit = ''
      if [[ "$(tty)" == "/dev/tty1" ]] && [[ -z "$WAYLAND_DISPLAY" ]]; then
        exec start-hyprland
      fi
    '';

    interactiveShellInit = ''
      source ${pkgs.zsh-autopair}/share/zsh/zsh-autopair/autopair.zsh


      float_app() {
        hyprctl -i 0 dispatch \
          "hl.dsp.exec_cmd([[$1]], {
            float = true,
            size = {
              [[(monitor_w*0.5)]],
              [[(monitor_h*0.5)]],
            },
            center = true,
          })"
      }

      swayimg() {
        local target="''${1:-.}"
        target="''${target:A}"
        float_app "swayimg ''${(q)target}"
      }
    '';

    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake path:/home/qwe/nix-setup#nixos";
    };
  };

  programs.hyprland.enable = true;
  programs.hyprlock.enable = true;

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Make Qt plugins provided by system packages discoverable (e.g. MarkdownPart).
  qt.enable = true;

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";

    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
    ];
  };

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.profont
    mplus-outline-fonts.githubRelease
  ];

  environment.systemPackages = with pkgs; [
    git
    tmux
    bibata-cursors
    swayimg
    quickshell
    google-chrome
    spotify
    discord
    alacritty
    hyprpaper
    kdePackages.kate
    kdePackages.konsole
    kdePackages.markdownpart
  ];
}
