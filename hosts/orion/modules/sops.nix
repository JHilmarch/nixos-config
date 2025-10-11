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
    };
  };
}
