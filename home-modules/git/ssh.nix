{
  pkgs,
  lib,
  config,
  ...
}: let
  allowedSigners = pkgs.writeText "allowed_signers" ''
    JHilmarch@users.noreply.github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbXmkI4z9yvrdcHtGxdAx41THZJsps8irUTcyEzMxo
  '';
in {
  programs = {
    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        line-numbers = true;
        side-by-side = true;
        navigate = true;
      };
    };

    git = {
      enable = true;
      package = pkgs.git;
      settings = {
        user = {
          email = "JHilmarch@users.noreply.github.com";
          name = "Jonatan Hilmarch";
          signingkey = "~/.ssh/signing_keys/id_ed25519_signing";
        };

        push = {
          default = "current";
          autoSetupRemote = true;
        };

        merge = {
          conflictstyle = "diff3";
          ff = "only";
        };

        diff = {
          colorMoved = "default";
        };

        gpg = {
          format = "ssh";
        };

        "gpg \"ssh\"" = {
          program = "${pkgs.openssh}/bin/ssh-keygen";
          allowedSignersFile = "${allowedSigners}";
        };

        commit = {
          gpgsign = true;
        };

        "credential \"https://github.com\"" = {
          helper = "!f() { echo \"password=$GITHUB_TOKEN\"; }; f";
        };

        core = {
          editor = "vim";
          hooksPath = "${config.home.homeDirectory}/.config/git/hooks";
        };
      };
    };
  };
}
