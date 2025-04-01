{
  description = "Custom sops package for NixOS (x86_64-linux)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = { allowUnfree = true; };
          };

          sopsDefaultPackage = (import ./default.nix) {
            inherit (pkgs) lib;
            inherit pkgs;
            buildGoModule = pkgs.buildGoModule;
          };

          sops3_10_1Package = (import ./3.10.1.nix) {
            inherit (pkgs) lib;
            inherit pkgs;
            buildGoModule = pkgs.buildGoModule;
          };
        in
        {
          default = sopsDefaultPackage.sops;
          v3_10_1 = sops3_10_1Package.sops;
        }
      );
    };
}
