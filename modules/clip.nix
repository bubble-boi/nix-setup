{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "clip";

      runtimeInputs = with pkgs; [
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
            selected=$(cliphist list | fzf \
              --delimiter=$'\t' \
              --with-nth=2.. \
              --no-scrollbar \
              --no-info \
              --no-separator \
              --no-mouse) || exit 0

            [[ -n "$selected" ]] || exit 0

            printf '%s\n' "$selected" | cliphist decode | wl-copy
            printf '1\n' > "$2"
            ;;

          *)
            printf 'Usage: clip {1|2|3}\n' >&2
            exit 2
            ;;
        esac
      '';
    })
  ];
}
