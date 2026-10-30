{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "wl-copy";

      runtimeInputs = with pkgs; [
        bubblewrap
      ];

      text = ''
        runtime="''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}"
        socket="''${WAYLAND_DISPLAY:?WAYLAND_DISPLAY is required}"

        if [[ "$socket" == */* || ! -S "$runtime/$socket" ]]; then
          printf 'No usable Wayland socket: %s\n' "$socket" >&2
          exit 1
        fi

        exec bwrap \
          --unshare-net \
          --unshare-ipc \
          --new-session \
          --ro-bind /nix/store /nix/store \
          --dir /run/user \
          --dir "$runtime" \
          --ro-bind "$runtime/$socket" "$runtime/$socket" \
          --tmpfs /tmp \
          --dev /dev \
          --chdir / \
          --clearenv \
          --setenv PATH "${pkgs.lib.makeBinPath [
            pkgs.coreutils
            pkgs.xdg-utils
            pkgs.file
          ]}" \
          --setenv XDG_RUNTIME_DIR "$runtime" \
          --setenv WAYLAND_DISPLAY "$socket" \
          --setenv HOME /tmp \
          --setenv XDG_CACHE_HOME /tmp \
          --setenv LANG "''${LANG:-C.UTF-8}" \
          -- ${pkgs.wl-clipboard}/bin/wl-copy "$@"
      '';
    })
  ];
}
