{ pkgs, ... }: {

  imports = [
    ./hardware-configuration.nix
    <home-manager/nixos>
  ];

  programs.zsh.enable = true;
  programs.hyprland.enable = true;
  programs.hyprlock.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = [ pkgs.fcitx5-mozc ];
  };

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  environment.systemPackages = with pkgs; [
    hyprpaper
    hypridle
    alacritty
    git
    tmux
    chromium
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.users."qwe" =
    import /home/qwe/my-nix-dots/home.nix;

}