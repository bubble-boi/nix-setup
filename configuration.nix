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

    interactiveShellInit = ''
      source ${pkgs.zsh-autopair}/share/zsh/zsh-autopair/autopair.zsh
    '';

    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --no-flake -I nixos-config=/home/qwe/nix-setup/configuration.nix";
    };
  };

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.displayManager.defaultSession = "plasma";

  security.pam.services.quickshell = {};

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
    (google-fonts.override { fonts = [ "Outfit" ]; })
  ];

  environment.systemPackages = with pkgs; [
    git
    tmux
    playerctl
    bibata-cursors
    quickshell
    google-chrome
    spotify
    discord
    alacritty
    kdePackages.kate
    kdePackages.konsole
    kdePackages.markdownpart
  ];
}
