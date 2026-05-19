{username, ...}: {
  home-manager.users.${username} = {
    modules.copilot-cli = {
      enable = true;
    };
  };
}
