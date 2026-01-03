{...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "*" = {
        identityFile = [
          "~/.ssh/id_ed25519_sk_23839166"
          "~/.ssh/id_ed25519_sk_23839165"
        ];
      };
    };

    extraConfig = ''
      Host github.com
        User git
        HostName github.com
        IdentitiesOnly yes
        IdentityFile ~/.ssh/id_ed25519_sk_23839166
        IdentityFile ~/.ssh/id_ed25519_sk_23839165
        # Persist connection for 60min
        ControlMaster auto
        ControlPath ~/.ssh/S.%r@%h:%p
        ControlPersist 60m
    '';
  };
}
