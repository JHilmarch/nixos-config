{ functions, ... }:
let
  authorizedSSHKeys = functions.ssh.getGithubKeys ({
    username = "JHilmarch";
    sha256 = "be8166d2e49794c8e2fb64a6868e55249b4f2dd7cd8ecf1e40e0323fb12a2348";
  });
in
{
  users.users.jonatan = {
    isNormalUser = true;
    description = "Jonatan Hilmarch";
    extraGroups = [ "networkmanager" "wheel" "docker" ];

    openssh.authorizedKeys.keys = authorizedSSHKeys;
  };
}
