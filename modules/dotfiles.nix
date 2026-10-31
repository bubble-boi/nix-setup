
{ lib, pkgs, ... }:

let
  username = "qwe";
  homeDir = "/home/${username}";

  dotfiles = {
    ".config/hypr" = ../hypr;
    ".config/alacritty" = ../alacritty;
    ".config/tmux" = ../tmux;
    ".zshrc" = builtins.path {
      path = ../.zshrc;
      name = "zshrc";
    };
  };
in
{
  system.activationScripts.linkDotfiles = {
    deps = [ "users" ];

    text = ''
      ${pkgs.util-linux}/bin/runuser -u ${username} -- \
        ${pkgs.bash}/bin/bash <<'DOTFILES'
      set -euo pipefail

      configDir="${homeDir}/.config"

      if [ ! -d "${homeDir}" ]; then
        echo "Home directory does not exist: ${homeDir}" >&2
        exit 1
      fi

      if [ -L "$configDir" ]; then
        echo "Symlink not allowed: $configDir" >&2
        exit 1
      fi

      if [ -e "$configDir" ] && [ ! -d "$configDir" ]; then
        echo "Not a directory: $configDir" >&2
        exit 1
      fi

      if [ ! -d "$configDir" ]; then
        ${pkgs.coreutils}/bin/mkdir -m 0755 -- "$configDir"
      fi

      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: source: ''
          dst=${lib.escapeShellArg "${homeDir}/${name}"}
          src=${lib.escapeShellArg "${source}"}

          if [ -L "$dst" ] &&
             [ "$(${pkgs.coreutils}/bin/readlink -- "$dst")" = "$src" ]; then
            :
          else
            if [ -L "$dst" ]; then
              case "$(${pkgs.coreutils}/bin/readlink -- "$dst")" in
                /nix/store/*)
                  ${pkgs.coreutils}/bin/rm -- "$dst"
                  ;;
                *)
                  ${pkgs.coreutils}/bin/mv -- "$dst" \
                    "$dst.bak.$(${pkgs.coreutils}/bin/date +%s%N)"
                  ;;
              esac
            elif [ -e "$dst" ]; then
              ${pkgs.coreutils}/bin/mv -- "$dst" \
                "$dst.bak.$(${pkgs.coreutils}/bin/date +%s%N)"
            fi

            ${pkgs.coreutils}/bin/ln -s -- "$src" "$dst"
          fi
        '') dotfiles
      )}
      DOTFILES
    '';
  };
}
