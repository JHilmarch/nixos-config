{
  description = "Jonatan's NixOS configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nur.url = "github:nix-community/NUR";
    mcp-nixos.url = "github:utensils/mcp-nixos";
    llm-agents.url = "github:numtide/llm-agents.nix";
    llm-agents.inputs.treefmt-nix.follows = "treefmt-nix";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
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

    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-auth = {
      url = "github:numtide/nix-auth";
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
        ];
      };

    mkPackages = system: let
      pkgs = mkPkgs system;
    in
      (pkgs.callPackages ./packages {})
      // {
        lxc-template =
          (inputs.nixpkgs.lib.nixosSystem {
            modules = [
              {nixpkgs.hostPlatform.system = system;}
              ./templates/lxc-base.nix
            ];
          })
          .config
          .system
          .build
          .tarball;
      };

    treefmtEval = forAllSystems (
      system:
        inputs.treefmt-nix.lib.evalModule (mkPkgs system) ./treefmt.nix
    );
  in {
    nix.config = {
      extra-substituters = ["https://cache.numtide.com"];
      extra-trusted-public-keys = ["niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="];
    };

    packages = forAllSystems mkPackages;

    formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);

    checks = forAllSystems (system: {
      formatting = treefmtEval.${system}.config.build.check self;
    });

    devShells = forAllSystems (
      system: let
        pkgs = mkPkgs system;
      in {
        default = pkgs.mkShell {
          packages = with pkgs; [
            alejandra
            mdformat
            biome
            treefmt
            git
            ripgrep
            jq
            inputs.nix-auth.packages.${system}.default
            sops
            age
            age-plugin-yubikey
          ];
          shellHook = ''
            echo "Welcome to the NixOS config devshell!"
            echo "Available tools: alejandra, biome, mdformat, treefmt, git, ripgrep, jq, nix-auth, sops, age, age-plugin-yubikey"
            echo ""
            echo "To authenticate with GitHub for Nix:"
            echo "  nix-auth login github"
            echo ""
            echo "To edit secrets:"
            echo "  sops secrets/<host>/secrets.yml"
          '';
        };
      }
    );

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

      nixos-p51 = let
        system = "x86_64-linux";
        specialArgs = {
          pkgs-unstable = import inputs.nixpkgs-unstable {
            inherit system;
            config = nixpkgsConfig;
          };

          inherit inputs self;
          username = "jonatan";
          hostname = "nixos-p51";
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
            ./hosts/p51/configuration.nix
            inputs.sops-nix.nixosModules.sops
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = specialArgs;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-backup";
              home-manager.users.${specialArgs.username} = import ./hosts/p51/home.nix;
            }
          ];
        };

      wsl-cab = let
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs self;
          username = "jonatan";
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
            inputs.vscode-server.nixosModules.default
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

      nixos-edge = let
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs self;
          username = "jonatan";
          hostname = "edge";
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
            }
            ./hosts/edge/configuration.nix
            inputs.sops-nix.nixosModules.sops
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = specialArgs;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-backup";
              home-manager.users.${specialArgs.username} = import ./hosts/edge/home.nix;
            }
          ];
        };

      nixos-cache = let
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs self;
          username = "jonatan";
          hostname = "cache";
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
            }
            ./hosts/cache/configuration.nix
            inputs.sops-nix.nixosModules.sops
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = specialArgs;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-backup";
              home-manager.users.${specialArgs.username} = import ./hosts/cache/home.nix;
            }
          ];
        };
    };
  };
}
