{config, ...}: {
  home.file.".config/git/hooks/commit-msg" = {
    source = ./../../hooks/commit-msg;
    executable = true;
  };
}
