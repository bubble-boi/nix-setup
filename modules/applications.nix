
{
  config,
  pkgs,
  ...
}:

let
  desktop = pkgs.writeShellApplication {
    name = "desktop";

    runtimeInputs = with pkgs; [
      bubblewrap
      coreutils
      jq
      fzf
      cliphist
      wl-clipboard
      hyprpicker
      grim
      slurp
      xdg-utils
      file
      config.programs.hyprland.package
    ];

    text = ''
      umask 077
      command="''${0##*/}"
      if [[ "$command" == desktop ]]; then
        command="''${1:-}"
        if (( $# > 0 )); then shift; fi
      fi
      self=$(readlink -f -- "$0")

      sandbox() {
        local mode="$1"
        shift

        local runtime="''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}"
        local socket="''${WAYLAND_DISPLAY:?WAYLAND_DISPLAY is required}"

        if [[ "$socket" == */* || ! -S "$runtime/$socket" ]]; then
          printf 'No usable Wayland socket: %s\n' "$socket" >&2
          return 1
        fi

        local -a args=(
          --unshare-net
          --unshare-ipc
          --ro-bind /nix/store /nix/store
          --dir /run/user
          --dir "$runtime"
          --chmod 0700 "$runtime"
          --ro-bind "$runtime/$socket" "$runtime/$socket"
          --tmpfs /tmp
          --dev /dev
          --chdir /
          --clearenv
          --setenv PATH "$PATH"
          --setenv LANG "''${LANG:-C.UTF-8}"
          --setenv LOCALE_ARCHIVE "${config.i18n.glibcLocales}/lib/locale/locale-archive"
          --setenv HOME /tmp
          --setenv XDG_CACHE_HOME /tmp
          --setenv XDG_CONFIG_HOME /tmp
          --setenv XDG_RUNTIME_DIR "$runtime"
          --setenv WAYLAND_DISPLAY "$socket"
        )

        if [[ "$mode" != launcher ]]; then
          args+=(--new-session)
        fi

        if [[ "$mode" == clip ]]; then
          local data="$runtime/cliphist-private"
          mkdir -p -- "$data"
          chmod 700 -- "$data"
          args+=(
            --unshare-pid
            --proc /proc
            --bind "$data" "$data"
            --setenv CLIPHIST_DB_PATH "$data/db"
          )
        elif [[ "$mode" == job ]]; then
          args+=(
            --unshare-pid
            --proc /proc
            --dev-bind-try /dev/dri /dev/dri
            --ro-bind-try /run/opengl-driver /run/opengl-driver
          )
        elif [[ "$mode" == launcher ]]; then
          args+=(
            --unshare-pid
            --proc /proc
            --setenv TERM "''${TERM:-xterm-256color}"
          )
        fi

        bwrap "''${args[@]}" -- "$@"
      }

      case "$command" in
        launcher)
          selected=$(printf '%s\n' \
            'Google Chrome' \
            'Kate' \
            'Discord' \
            'Spotify' |
            sandbox launcher fzf \
              --no-scrollbar \
              --no-info \
              --no-separator \
              --no-mouse) || exit 0

          case "$selected" in
            'Google Chrome') app=google-chrome-stable ;;
            'Kate') app=kate ;;
            'Discord') app=discord ;;
            'Spotify') app='env -u DISPLAY spotify --ozone-platform=wayland' ;;
            *) exit 0 ;;
          esac

          hyprctl -i 0 dispatch \
            "hl.dsp.exec_cmd([[$app]])"
          ;;

        clip)
          runtime="''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}"
          export CLIPHIST_DB_PATH="$runtime/cliphist-private/db"

          case "''${1:-}" in
            1|2)
              sandbox clip "$self" clip "_$1"
              ;;

            _1)
              exec wl-paste --type text --watch cliphist store
              ;;

            _2)
              exec wl-paste --type image --watch cliphist store
              ;;

            3)
              target="''${2:-}"
              if [[ ! "$target" =~ ^0x[[:xdigit:]]+$ ]]; then
                printf 'Usage: clip 3 <window-address>\n' >&2
                exit 2
              fi

              selected=$(cliphist list | fzf \
                --delimiter=$'\t' \
                --with-nth=2.. \
                --no-scrollbar \
                --no-info \
                --no-separator \
                --no-mouse) || exit 0

              [[ -n "$selected" ]] || exit 0
              printf '%s\n' "$selected" | cliphist decode | "$self" wl-copy

              class=$(hyprctl -i 0 -j clients | jq -r --arg target "$target" \
                '[.[] | select(.address == $target) | .class][0] // empty')
              [[ -n "$class" ]] || exit 0

              if [[ "$class" == "Alacritty" || "$class" == "org.alacritty.Alacritty" ]]; then
                mods="CTRL SHIFT"
              else
                mods="CTRL"
              fi

              hyprctl -i 0 dispatch \
                "hl.dsp.send_shortcut({ mods = '$mods', key = 'V', window = 'address:$target' })"
              ;;

            *)
              printf 'Usage: clip {1|2|3 <window-address>}\n' >&2
              exit 2
              ;;
          esac
          ;;

        grab)
          case "''${1:-}" in
            color|area|full)
              if [[ "$1" == color ]]; then
                picked=$(sandbox job "$self" grab _color) || exit 1
                [[ -n "$picked" ]] || exit 0
                printf '%s' "$picked" | "$self" wl-copy --type text/plain
                exit 0
              fi

              dir="$HOME/.Screenshots"
              mkdir -p -- "$dir"
              chmod 700 -- "$dir"
              output="$dir/$(date +%Y%m%d%H%M%S%N).png"

              if [[ "$1" == area ]]; then
                mode=_area
              else
                mode=_full
              fi

              if sandbox job "$self" grab "$mode" > "$output" && [[ -s "$output" ]]; then
                "$self" wl-copy --type image/png < "$output"
              else
                rm -f -- "$output"
                exit 1
              fi
              ;;

            _color)
              exec hyprpicker
              ;;

            _area)
              geometry=$(slurp) || exit 1
              [[ -n "$geometry" ]] || exit 1
              exec grim -g "$geometry" -
              ;;

            _full)
              exec grim -
              ;;

            *)
              printf 'Usage: grab {color|area|full}\n' >&2
              exit 2
              ;;
          esac
          ;;

        wl-copy)
          sandbox detached ${pkgs.wl-clipboard}/bin/wl-copy "$@"
          ;;

        *)
          printf 'Usage: desktop {launcher|clip|grab|wl-copy} ...\n' >&2
          exit 2
          ;;
      esac
    '';
  };

  desktopTools = pkgs.symlinkJoin {
    name = "desktop-tools";
    paths = [ desktop ];

    postBuild = ''
      for name in launcher clip grab wl-copy; do
        ln -s desktop "$out/bin/$name"
      done
    '';
  };
in
{
  environment.systemPackages = [ desktopTools ];
}
