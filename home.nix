
{ config, pkgs, ... }:

let
  repo = "${config.home.homeDirectory}/my-nix-dots";
  link = path:
    config.lib.file.mkOutOfStoreSymlink "${repo}/${path}";
in
{
  home.stateVersion = "26.05";

  xdg.configFile = {
    "hypr".source = link "hypr";
    "alacritty".source = link "alacritty";
    "tmux".source = link "tmux";
  };

  home.file = {
    ".zshrc".source = link ".zshrc";
    ".zprofile".source = link ".zprofile";
    ".local/bin/mybin".source = link "mybin";
  };

  home.packages = [
    (pkgs.rustPlatform.buildRustPackage {
      pname = "tmux-sys-status-rs";
      version = "0.1.0";
      src = ./rs-tools/tmux-sys-status-rs;
      cargoLock.lockFile =
        ./rs-tools/tmux-sys-status-rs/Cargo.lock;
    })
  ];
}
