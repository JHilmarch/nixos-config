{ pkgs ? import <nixpkgs> {}, lib ? pkgs.lib, buildGoModule ? pkgs.buildGoModule }:

{
  sops = buildGoModule rec {
    name = "sops";
    version = "3.10.1";

    src = pkgs.fetchFromGitHub {
      owner = "mozilla";
      repo = "${name}";
      rev = "v${version}";
      sha256 = "sha256-LdsuN243oQ/L6LYgynb7Kw60alXn5IfUfhY0WaZFVCU=";
    };

    vendorHash = "sha256-I+iwimrNdKABZFP2etZTQJAXKigh+0g/Jhip86Cl5Rg=";

    doCheck = false;

    meta = {
      description = "SOPS: Secrets OPerationS, custom derivation for NixOS";
      homepage = "https://github.com/getsops/${name}/releases/tag/v${version}";
      license = lib.licenses.mpl20;
      maintainers = with lib.maintainers; [ JHilmarch ];
    };
  };
}
