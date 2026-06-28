# Concrete config for hosts that store the OpenChamber UI password in a
# SOPS secret named `openchamber_ui_password`. Per-host SOPS declarations
# live at hosts/<host>/modules/sops.nix.
{config, ...}: {
  imports = [
    ./default.nix
  ];

  services.openchamber = {
    enable = true;
    uiPasswordFile = config.sops.secrets.openchamber_ui_password.path;
  };
}
