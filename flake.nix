{
  description = "Jonatan's NixOS configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nur.url = "github:nix-community/NUR";
    mcp-nixos.url = "github:utensils/mcp-nixos";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {self, ...}: {
    packages.x86_64-linux = let
      system = "x86_64-linux";
      nixpkgsWithOverlays = import inputs.nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [
            # Add any insecure packages you absolutely need here
          ];
        };
        overlays = [
          (_final: prev: {
            unstable = import inputs.nixpkgs-unstable {
              inherit (prev) system;
              config = prev.config;
            };
          })
          (import ./overlays/context7)
        ];
      };
    in {
      context7 = nixpkgsWithOverlays.context7;
      default = nixpkgsWithOverlays.context7;
    };

    nixosConfigurations = let
      nixpkgsConfig = {
        config.allowUnfree = true;
      };
    in {
      nixos-orion = let
        system = "x86_64-linux";
        nixpkgsWithOverlays = import inputs.nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            permittedInsecurePackages = [
              # Add any insecure packages you absolutely need here
            ];
          };
          overlays = [
            (_final: prev: {
              unstable = import inputs.nixpkgs-unstable {
                inherit (prev) system;
                config = prev.config;
              };
            })
            (import ./overlays/context7)
          ];
        };

        specialArgs = {
          pkgs-unstable = import inputs.nixpkgs-unstable {
            inherit system;
            config = nixpkgsConfig;
          };

          inherit inputs self;
          username = "jonatan";
          hostname = "nixos-orion";
          functions = import ./functions {
            pkgs = import inputs.nixpkgs {inherit system;};
          };
        };
      in
        inputs.nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          pkgs = nixpkgsWithOverlays;

          modules = [
            ./hosts/orion/configuration.nix
            inputs.sops-nix.nixosModules.sops
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = specialArgs;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-backup";
              home-manager.users.${specialArgs.username} = import ./hosts/orion/home.nix;
            }
          ];
        };

      iso = let
        system = "x86_64-linux";
        nixpkgsWithOverlays = import inputs.nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            permittedInsecurePackages = [
              # Add any insecure packages you absolutely need here
            ];
          };
          overlays = [
            (_final: prev: {
              unstable = import inputs.nixpkgs-unstable {
                inherit (prev) system;
                config = prev.config;
              };
            })
            (import ./overlays/context7)
          ];
        };

        specialArgs = {
          inherit inputs system self;
          username = "jonatan";
          hostname = "iso";
        };
      in
        inputs.nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          pkgs = nixpkgsWithOverlays;

          modules = [
            "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
            ./hosts/iso/configuration.nix
          ];
        };
    };

    formatter.x86_64-linux = inputs.nixpkgs.legacyPackages.x86_64-linux.alejandra;
  };
}
