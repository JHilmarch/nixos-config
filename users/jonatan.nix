{
  functions,
  pkgs,
  ...
}: let
  authorizedSSHKeys = functions.ssh.getGithubKeys {
    username = "JHilmarch";
    sha256 = "1zxj95jlhabgbaxvvhlhwvxlr6xn00ldx6yaz3sdga55wbcnsw34";
  };
in {
  users.users.jonatan = {
    isNormalUser = true;
    description = "Jonatan Hilmarch";
    extraGroups = ["wheel" "networkmanager"];
    openssh.authorizedKeys.keys = authorizedSSHKeys;
    shell = pkgs.fish;
  };
}
