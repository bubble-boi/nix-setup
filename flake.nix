{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    hyprland.url = "github:hyprwm/Hyprland";

    hyprliquid = {
      url = "github:zaregototsukai/hyprliquid";
      inputs.hyprland.follows = "hyprland";
    };
  };

  outputs = { nixpkgs, hyprland, hyprliquid, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          ./configuration.nix

          hyprland.nixosModules.default

          {
            programs.hyprland.package =
              hyprland.packages.${system}.hyprland;

            environment.variables.HYPRLIQUID_DIR =
              "${hyprliquid.packages.${system}.default}";
          }
        ];
      };
    };
}
