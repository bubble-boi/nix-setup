{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    hyprland.url =
      "github:hyprwm/Hyprland/efb50993780079460b0cbed1363e2166a2de1d9f";

    hyprglass = {
      url =
        "github:hyprnux/hyprglass/7fc328064c63d9fbaaac8d8204eadf85dcdeae19";
      flake = false;
    };
  };

  outputs = { nixpkgs, hyprland, hyprglass, ... }:
    let
      system = "x86_64-linux";

      stablePkgs = nixpkgs.legacyPackages.${system};

      hyprPkgs =
        hyprland.inputs.nixpkgs.legacyPackages.${system};

      hyprlandPkg =
        hyprland.packages.${system}.hyprland.override {
          glaze-hyprland = stablePkgs.glaze.override {
            enableSSL = false;
            enableInterop = false;
          };
        };

      hyprglassPkg = hyprPkgs.gcc16Stdenv.mkDerivation {
        pname = "hyprglass";
        version = "0.11.0";

        src = hyprglass;

        nativeBuildInputs = with hyprPkgs; [
          pkg-config
          wayland-scanner
        ];

        buildInputs = [
          hyprlandPkg.dev
          hyprPkgs.pixman
          hyprPkgs.libdrm
          hyprPkgs.wayland
        ] ++ hyprlandPkg.buildInputs;

        makeFlags = [
          "HYPRGLASS_VERSION=0.11.0"
        ];

        installPhase = ''
          runHook preInstall
          install -Dm755 hyprglass.so \
            "$out/lib/hyprglass.so"
          runHook postInstall
        '';
      };
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          ./configuration.nix

          hyprland.nixosModules.default

          {
            programs.hyprland = {
              package = hyprlandPkg;
              portalPackage =
                hyprland.packages.${system}.xdg-desktop-portal-hyprland;
            };

            environment.etc."hypr/plugins/hyprglass.so".source =
              "${hyprglassPkg}/lib/hyprglass.so";
          }
        ];
      };
    };
}
