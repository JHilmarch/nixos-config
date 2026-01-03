{
  pkgs,
  config,
  username,
  self,
  ...
}: {
  sops = {
    defaultSopsFile = "${self}/secrets/orion/secrets.yml";
    defaultSopsFormat = "yaml";
    validateSopsFiles = true;
    gnupg.sshKeyPaths = [];

    age = {
      keyFile = "/home/${username}/.config/sops/age/keys.txt";
      generateKey = false;
      sshKeyPaths = [];
    };

    secrets = {
      secret1 = {};
      gh_pat = {
        owner = username;
        mode = "0400";
      };
      zai_anthropic_pat = {
        owner = username;
        mode = "0400";
      };
      context7_pat = {
        owner = username;
        mode = "0400";
      };
    };

    templates."claude.env" = {
      owner = username;
      content = ''
        ANTHROPIC_AUTH_TOKEN=${config.sops.placeholder.zai_anthropic_pat}
        CONTEXT7_TOKEN=${config.sops.placeholder.context7_pat}
      '';
    };
  };
}
