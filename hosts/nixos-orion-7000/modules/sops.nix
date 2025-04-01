{ pkgs, username, hostname, ...}:{

  sops = {
    defaultSopsFile = ../../../secrets/${hostname}/secrets.yml;
    defaultSopsFormat = "yaml";
    validateSopsFiles = true;
    gnupg.sshKeyPaths = [];

    age = {
      keyFile = "/home/${username}/.config/sops/age/keys.txt";
      generateKey = false;
      sshKeyPaths = [];
    };

    # TODO: Move closer to usage
    secrets = {
      fileshare_smb_path = {};
      fileshare_smb_username = {};
      fileshare_smb_password = {};
    };
  };
}
