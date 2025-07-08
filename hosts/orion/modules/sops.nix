{ pkgs, username, hostname, self, ...}:{

  sops = {
    defaultSopsFile = "${self}/secrets/${hostname}/secrets.yml";
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
    };
  };
}
