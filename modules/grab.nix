{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "grab";

      runtimeInputs = with pkgs; [
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
            printf 'Usage: grab {color|area|full}\n' >&2
            exit 2
            ;;
        esac
      '';
    })
  ];
}
