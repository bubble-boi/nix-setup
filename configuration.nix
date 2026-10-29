
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
    bibata-cursors

    (rustPlatform.buildRustPackage {
      pname = "tmux-sys-status";
      version = "0.1.0";
      src = ./rs-tools/tmux-sys-status-rs;
      cargoLock.lockFile =
        ./rs-tools/tmux-sys-status-rs/Cargo.lock;
    })

    (writeShellApplication {
      name = "clip";

      runtimeInputs = [
        bubblewrap
        wl-clipboard
        cliphist
        fzf
        alacritty
        hyprland
        jq
        coreutils
        xdg-utils
      ];

      text = ''
        umask 077
        runtime="''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}"
        data="$runtime/cliphist-private"
        export CLIPHIST_DB_PATH="$data/db"

        case "''${1:-}" in
          1|2)
            socket="''${WAYLAND_DISPLAY:?WAYLAND_DISPLAY is required}"
            if [[ "$socket" == */* || ! -S "$runtime/$socket" ]]; then
              printf 'No usable Wayland socket: %s\n' "$socket" >&2
              exit 1
            fi
            mkdir -p -- "$data"
            chmod 700 -- "$data"
            self=$(readlink -f -- "$0")

            exec bwrap \
              --unshare-net \
              --unshare-pid \
              --unshare-ipc \
              --new-session \
              --ro-bind /nix/store /nix/store \
              --dir /run/user \
              --dir "$runtime" \
              --chmod 0700 "$runtime" \
              --ro-bind "$runtime/$socket" "$runtime/$socket" \
              --bind "$data" "$data" \
              --tmpfs /tmp \
              --proc /proc \
              --dev /dev \
              --clearenv \
              --setenv PATH "$PATH" \
              --setenv LANG "''${LANG:-C.UTF-8}" \
              --setenv HOME /tmp \
              --setenv XDG_RUNTIME_DIR "$runtime" \
              --setenv XDG_CACHE_HOME /tmp \
              --setenv XDG_CONFIG_HOME /tmp \
              --setenv WAYLAND_DISPLAY "$socket" \
              --setenv CLIPHIST_DB_PATH "$data/db" \
              -- "$self" "_$1"
            ;;

          _1)
            exec wl-paste --type text --watch cliphist store
            ;;

          _2)
            exec wl-paste --type image --watch cliphist store
            ;;

          3)
            active=$(hyprctl activewindow -j)
            target=$(jq -r '.address // empty' <<< "$active")
            class=$(jq -r '.class // empty' <<< "$active")
            [[ "$target" =~ ^0x[[:xdigit:]]+$ ]] || exit 1

            marker=$(mktemp "$runtime/clip-selected.XXXXXXXX")
            trap 'rm -f -- "$marker"' EXIT

            alacritty --title Clipboard -e "$0" _select "$marker" || true
            [[ -s "$marker" ]] || exit 0

            if [[ "$class" == "Alacritty" || "$class" == "org.alacritty.Alacritty" ]]; then
              mods="CTRL SHIFT"
            else
              mods="CTRL"
            fi

            hyprctl dispatch \
              "hl.dsp.send_shortcut({ mods = '$mods', key = 'V', window = 'address:$target' })"
            ;;

          _select)
            selected=$(cliphist list -fields id,mime,preview | fzf \
              --delimiter=$'\t' \
              --with-nth=3..) || exit 0
            [[ -n "$selected" ]] || exit 0

            id=$(printf '%s\n' "$selected" | cut -f 1)
            mime=$(printf '%s\n' "$selected" | cut -f 2)

            if [[ "$mime" == */* ]]; then
              printf '%s\n' "$id" | cliphist decode | wl-copy --type "$mime"
            else
              printf '%s\n' "$id" | cliphist decode | wl-copy
            fi
            printf '1\n' > "$2"
            ;;

          *)
            printf 'Usage: clip {1|2|3}\n' >&2
            exit 2
            ;;
        esac
      '';
    })

    (writeShellApplication {
      name = "xx";

      runtimeInputs = [
        bubblewrap
        hyprpicker
        grim
        slurp
        wl-clipboard
        coreutils
      ];

      text = ''
        umask 077

        case "''${1:-}" in
          color|area|full)
            runtime="''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}"
            socket="''${WAYLAND_DISPLAY:?WAYLAND_DISPLAY is required}"

            if [[ "$socket" == */* || ! -S "$runtime/$socket" ]]; then
              printf 'No usable Wayland socket: %s\n' "$socket" >&2
              exit 1
            fi

            self=$(readlink -f -- "$0")

            run_sandbox() {
              bwrap \
                --unshare-net \
                --unshare-pid \
                --unshare-ipc \
                --new-session \
                --ro-bind /nix/store /nix/store \
                --dir /run/user \
                --dir "$runtime" \
                --ro-bind "$runtime/$socket" "$runtime/$socket" \
                --tmpfs /tmp \
                --proc /proc \
                --dev /dev \
                --clearenv \
                --setenv PATH "$PATH" \
                --setenv LANG "''${LANG:-C.UTF-8}" \
                --setenv HOME /tmp \
                --setenv XDG_RUNTIME_DIR "$runtime" \
                --setenv WAYLAND_DISPLAY "$socket" \
                -- "$self" "$1"
            }

            if [[ "$1" == color ]]; then
              picked=$(run_sandbox _color) || exit 1
              [[ -n "$picked" ]] || exit 0
              printf '%s' "$picked" | wl-copy --type text/plain
              exit 0
            fi

            dir="$HOME/.Screenshots"
            mkdir -p -- "$dir"
            chmod 700 -- "$dir"
            file="$dir/$(date +%Y%m%d%H%M%S%N).png"

            if [[ "$1" == area ]]; then
              mode=_area
            else
              mode=_full
            fi

            if run_sandbox "$mode" > "$file" && [[ -s "$file" ]]; then
              wl-copy --type image/png < "$file"
            else
              rm -f -- "$file"
              exit 1
            fi
            ;;

          _color)
            sleep 0.2
            exec hyprpicker
            ;;

          _area)
            geom=$(slurp) || exit 1
            [[ -n "$geom" ]] || exit 1
            exec grim -g "$geom" -
            ;;

          _full)
            sleep 0.5
            exec grim -
            ;;

          *)
            printf 'Usage: xx {color|area|full}\n' >&2
            exit 2
            ;;
        esac
      '';
    })
  ];

  # Relocate configuration and retain the standard NixOS path
  system.activationScripts.moveNixosConfig = {
    deps = [ "users" ];

    text = ''
      source=/etc/nixos
      target=/home/qwe/nix-setup

      if [ -d "$source/.git" ] && [ ! -e "$target" ]; then
        mv -- "$source" "$target"
        chown -R qwe:users -- "$target"
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
        .zshrc \
        .zprofile
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

    "L+ /home/qwe/.config/hypr - qwe users - ${./hypr}"
    "L+ /home/qwe/.config/alacritty - qwe users - ${./alacritty}"
    "L+ /home/qwe/.config/tmux - qwe users - ${./tmux}"
    "L+ /home/qwe/.zshrc - qwe users - ${./.zshrc}"
    "L+ /home/qwe/.zprofile - qwe users - ${./.zprofile}"
  ];

  # Wallpaper: download once if missing
  systemd.user.services.nix-wallpaper = {
    description = "Install wallpaper";
    unitConfig.ConditionUser = "qwe";
    wantedBy = [ "default.target" ];
    path = with pkgs; [ coreutils curl ];

    serviceConfig.Type = "oneshot";

    script = ''
      target="$HOME/.current_wallpaper"

      if [ ! -s "$target" ]; then
        mkdir -p "$HOME/"
        tmp="$(mktemp "$HOME/.wallpaper.XXXXXX")"

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
