{ pkgs, ... }:

let
  username = "qwe";
  homeDir = "/home/${username}";
in
{
  imports = [
    ./hardware-configuration.nix
    ./modules/clip.nix
    ./modules/grab.nix
    ./modules/wl-copy.nix
    ./modules/update.nix
    ./modules/browser.nix
  ];

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "26.05";

  time.timeZone = "Asia/Tokyo";
  environment.sessionVariables.TZDIR = "/etc/zoneinfo";

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
    mpvpaper
    alacritty
    git
    tmux
    bibata-cursors
  ];

  # Relocate configuration and retain the standard NixOS path
  system.activationScripts.moveNixosConfig = {
    deps = [ "users" ];

    text = ''
      source=/etc/nixos
      target="${homeDir}/nix-setup"

      if [ -d "$source/.git" ] && [ ! -e "$target" ]; then
        mv -- "$source" "$target"
        chown -R ${username}:users -- "$target"
      fi

      if [ -d "$target/.git" ]; then
        if [ -d "$source" ] && [ ! -L "$source" ] &&
           [ -z "$(ls -A "$source")" ]; then
          rmdir -- "$source"
        fi

        if [ ! -e "$source" ] && [ ! -L "$source" ]; then
          ln -s -- "$target" "$source"
        fi
      fi
    '';
  };

  # Dotfiles: back up existing regular files/directories
  system.activationScripts.backupDotfiles = {
    deps = [ "users" ];
    text = ''
      for rel in \
        .config/hypr \
        .config/alacritty \
        .config/tmux \
        .zshrc
      do
        dst="${homeDir}/$rel"

        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
          ${pkgs.coreutils}/bin/mv -- "$dst" \
            "$dst.bak.$(${pkgs.coreutils}/bin/date +%s%N)"
        fi
      done
    '';
  };

  # Dotfiles: link Nix store files to user home
  systemd.tmpfiles.rules = [
    "d ${homeDir}/.config 0755 ${username} users - -"

    "L+ ${homeDir}/.config/hypr - ${username} users - ${./hypr}"
    "L+ ${homeDir}/.config/alacritty - ${username} users - ${./alacritty}"
    "L+ ${homeDir}/.config/tmux - ${username} users - ${./tmux}"
    "L+ ${homeDir}/.zshrc - ${username} users - ${./.zshrc}"
  ];
}
