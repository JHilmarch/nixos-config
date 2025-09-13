{...}: {
  programs.ssh = {
    enable = true;

    extraConfig = ''
      Host *
        IdentityFile ~/.ssh/id_ed25519_sk_23839166
        IdentityFile ~/.ssh/id_ed25519_sk_23839165
      Host github.com
        User git
        HostName github.com
        IdentitiesOnly yes
       IdentityAgent none
        IdentityFile ~/.ssh/id_ed25519_sk_23839166
        IdentityFile ~/.ssh/id_ed25519_sk_23839165
        # Persist connection for 60min
        ControlMaster auto
        ControlPath ~/.ssh/S.%r@%h:%p
        ControlPersist 60m
    '';
  };
}
