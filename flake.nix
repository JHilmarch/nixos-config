{
  description = "Jonatan's NixOS configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nur.url = "github:nix-community/NUR";
    mcp-nixos.url = "github:utensils/mcp-nixos";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {self, ...}: let
    inherit (inputs.nixpkgs) lib;

    forAllSystems = lib.genAttrs lib.systems.flakeExposed;

    mkPkgs = system:
      import inputs.nixpkgs {
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
              system = prev.stdenv.hostPlatform.system;
              config = prev.config;
            };
          })
          (import ./overlays/awesome-copilot)
          (import ./overlays/nuget-mcp-server)
          (import ./overlays/azure-mcp-server)
          (import ./overlays/github-mcp-server)
        ];
      };

    mkPackages = system: let
      pkgs = mkPkgs system;
    in
      pkgs.callPackages ./packages {};
  in {
    packages = forAllSystems mkPackages;

    formatter = forAllSystems (system: inputs.nixpkgs.legacyPackages.${system}.alejandra);

    nixosConfigurations = let
      nixpkgsConfig = {
        config.allowUnfree = true;
      };
    in {
      nixos-orion = let
        system = "x86_64-linux";
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
          specialArgs = specialArgs;
          modules = [
            {
              nixpkgs.hostPlatform.system = system;
              nixpkgs.overlays = [
                (_final: prev: {
                  local = self.packages.${prev.stdenv.hostPlatform.system};
                })
              ];
            }
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

      wsl-cab = let
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs self;
          username = "tux";
          hostname = "wsl-cab";
        };
      in
        inputs.nixpkgs.lib.nixosSystem {
          specialArgs = specialArgs;
          modules = [
            {
              nixpkgs.hostPlatform.system = system;
              nixpkgs.overlays = [
                (_final: prev: {
                  local = self.packages.${prev.stdenv.hostPlatform.system};
                })
              ];
            }
            inputs.nixos-wsl.nixosModules.wsl
            ./hosts/wsl-cab/configuration.nix
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = specialArgs;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-backup";
              home-manager.users.${specialArgs.username} = import ./hosts/wsl-cab/home.nix;
            }
          ];
        };

      iso = let
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs self;
          username = "jonatan";
          hostname = "iso";
        };
      in
        inputs.nixpkgs.lib.nixosSystem {
          specialArgs = specialArgs;
          pkgs = mkPkgs system;

          modules = [
            {
              nixpkgs.hostPlatform.system = system;
            }
            "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
            ./hosts/iso/configuration.nix
          ];
        };
    };
  };
}
