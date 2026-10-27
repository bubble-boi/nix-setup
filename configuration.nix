{ pkgs, ... }: {

  imports = [
    ./hardware-configuration.nix
  ];

  users.users.qwe = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "26.05";

  programs.zsh.enable = true;
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
    brightnessctl
    hyprpaper
    hypridle
    alacritty
    git
    tmux
    chromium

    (rustPlatform.buildRustPackage {
      pname = "tmux-sys-status";
      version = "0.1.0";
      src = ./rs-tools/tmux-sys-status-rs;
      cargoLock.lockFile =
        ./rs-tools/tmux-sys-status-rs/Cargo.lock;
    })
  ];

  # Dotfiles: back up existing regular files/directories
  system.activationScripts.backupDotfiles = {
    deps = [ "users" ];
    text = ''
      for rel in \
        .config/hypr \
        .config/alacritty \
        .config/tmux \
        .zshrc \
        .zprofile \
        .local/bin/mybin
      do
        dst="/home/qwe/$rel"

        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
          ${pkgs.coreutils}/bin/mv -- "$dst" \
            "$dst.bak.$(${pkgs.coreutils}/bin/date +%s%N)"
        fi
      done
    '';
  };

  # Dotfiles: link Nix store files to user home
  systemd.tmpfiles.rules = [
    "d /home/qwe/.config 0755 qwe users - -"
    "d /home/qwe/.local 0755 qwe users - -"
    "d /home/qwe/.local/bin 0755 qwe users - -"

    "L+ /home/qwe/.config/hypr - qwe users - ${./hypr}"
    "L+ /home/qwe/.config/alacritty - qwe users - ${./alacritty}"
    "L+ /home/qwe/.config/tmux - qwe users - ${./tmux}"
    "L+ /home/qwe/.zshrc - qwe users - ${./.zshrc}"
    "L+ /home/qwe/.zprofile - qwe users - ${./.zprofile}"
    "L+ /home/qwe/.local/bin/mybin - qwe users - ${./mybin}"
  ];

  # Wallpaper: download once if missing
  systemd.user.services.nix-wallpaper = {
    description = "Install wallpaper";
    unitConfig.ConditionUser = "qwe";
    wantedBy = [ "default.target" ];
    path = with pkgs; [ coreutils curl ];

    serviceConfig.Type = "oneshot";

    script = ''
      target="$HOME/.local/state/.current_wallpaper"

      if [ ! -s "$target" ]; then
        mkdir -p "$HOME/.local/state"
        tmp="$(mktemp "$HOME/.local/state/.wallpaper.XXXXXX")"

        if curl -fL \
          'https://unsplash.com/photos/8CPr2EMiQ1U/download?force=true' \
          -o "$tmp"; then
          mv -f "$tmp" "$target"
        else
          rm -f "$tmp"
          exit 1
        fi
      fi
    '';
  };

}
