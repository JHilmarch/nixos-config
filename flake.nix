{
  description = "Jonatan's NixOS configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nur.url = "github:nix-community/NUR";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    jeezyvim.url = "github:LGUG2Z/JeezyVim";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {self, ...}: {
    nixosConfigurations = let
      nixpkgsConfig = {
        config.allowUnfree = true;
      };
    in {
      wsl = let
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
            inputs.nur.overlays.default
            inputs.jeezyvim.overlays.default
            (_final: prev: {
              unstable = import inputs.nixpkgs-unstable {
                inherit (prev) system;
                inherit (prev.config) allowUnfree;
              };
            })
          ];
        };

        specialArgs = {
          pkgs-unstable = import inputs.nixpkgs-unstable {
            inherit system;
            config = nixpkgsConfig;
          };

          inherit inputs;
          username = "nixos";
          hostname = "wsl";
        };
      in
        inputs.nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          pkgs = nixpkgsWithOverlays;

          modules = [
            inputs.nixos-wsl.nixosModules.wsl
            ./hosts/wsl/configuration.nix
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = specialArgs;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-backup";
              home-manager.users.${specialArgs.username} = import ./hosts/${specialArgs.hostname}/home.nix;
            }
          ];
        };

      nixos-orion-7000 = let
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
                inherit (prev.config) allowUnfree;
              };
            })
          ];
        };

        specialArgs = {
          pkgs-unstable = import inputs.nixpkgs-unstable {
            inherit system;
            config = nixpkgsConfig;
          };

          inherit inputs;
          username = "jonatan";
          hostname = "nixos-orion-7000";
        };
      in
        inputs.nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          pkgs = nixpkgsWithOverlays;

          modules = [
            ./hosts/nixos-orion-7000/configuration.nix
            inputs.sops-nix.nixosModules.sops
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = specialArgs;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-backup";
              home-manager.users.${specialArgs.username} = import ./hosts/${specialArgs.hostname}/home.nix;
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
                inherit (prev.config) allowUnfree;
              };
            })
          ];
        };

        specialArgs = {
          inherit inputs system;
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
