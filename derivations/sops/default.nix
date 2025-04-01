{ pkgs ? import <nixpkgs> {}, lib ? pkgs.lib, buildGoModule ? pkgs.buildGoModule }:

pkgs.callPackage ./3.10.1.nix { inherit lib pkgs buildGoModule; }
