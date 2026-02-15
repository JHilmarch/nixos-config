{
  config,
  pkgs,
  self,
  username,
  ...
}: {
  home-manager.users.${username} = {
    modules.claude.preSetupScripts = [
      "${self}/home-modules/claude/scripts/secrets-sops.sh ${config.sops.templates."claude.env".path}"
      "${self}/home-modules/claude/scripts/gnome-pinentry.sh ${pkgs.pinentry-gnome3}"
    ];

    modules.claude.runtimeInputs = [pkgs.pinentry-gnome3];
  };
}
