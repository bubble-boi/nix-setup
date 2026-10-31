
{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/clip.nix
    ./modules/grab.nix
    ./modules/wl-copy.nix
    ./modules/update.nix
    ./modules/browser.nix
    ./modules/ide.nix
    ./modules/dotfiles.nix
  ];

  users.users.qwe = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
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
    mplus-outline-fonts.githubRelease
  ];

  environment.systemPackages = with pkgs; [
    alacritty
    kdePackages.kate
    kdePackages.konsole
    git
    tmux
    mpvpaper
    bibata-cursors
  ];
}
