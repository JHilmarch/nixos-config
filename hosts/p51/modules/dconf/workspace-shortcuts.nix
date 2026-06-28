{pkgs}: let
  openBrowserWorkspaceScript = import ./open-browser-workspace.nix {inherit pkgs;};
  openDevRiderWorkspaceScript = import ./open-dev-rider-workspace.nix {inherit pkgs;};
  openDevTerminalsWorkspaceScript = import ./open-dev-terminals-workspace.nix {inherit pkgs;};
  openSocialWorkspaceScript = import ./open-social-workspace.nix {inherit pkgs;};
  openMediaWorkspaceScript = import ./open-media-workspace.nix {inherit pkgs;};
in {
  # Clear GNOME's default Super+N "switch-to-application-N" bindings so they
  # don't conflict with workspace switching.
  "org/gnome/shell/keybindings" = {
    switch-to-application-1 = [];
    switch-to-application-2 = [];
    switch-to-application-3 = [];
    switch-to-application-4 = [];
    switch-to-application-5 = [];
  };

  "org/gnome/desktop/wm/keybindings" = {
    switch-to-workspace-1 = ["<Super>1"];
    switch-to-workspace-2 = ["<Super>2"];
    switch-to-workspace-3 = ["<Super>3"];
    switch-to-workspace-4 = ["<Super>4"];
    switch-to-workspace-5 = ["<Super>5"];

    move-to-workspace-1 = ["<Super><Shift>1"];
    move-to-workspace-2 = ["<Super><Shift>2"];
    move-to-workspace-3 = ["<Super><Shift>3"];
    move-to-workspace-4 = ["<Super><Shift>4"];
    move-to-workspace-5 = ["<Super><Shift>5"];
  };

  "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/goto-workspace-1" = {
    name = "Go to Workspace 1 (Browser) and launch apps";
    command = "${openBrowserWorkspaceScript}";
    binding = "<Super><Alt>1";
  };

  "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/goto-workspace-2" = {
    name = "Go to Workspace 2 (Dev-Rider) and launch Rider";
    command = "${openDevRiderWorkspaceScript}";
    binding = "<Super><Alt>2";
  };

  "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/goto-workspace-3" = {
    name = "Go to Workspace 3 (Dev-Terminals) and launch terminals";
    command = "${openDevTerminalsWorkspaceScript}";
    binding = "<Super><Alt>3";
  };

  "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/goto-workspace-4" = {
    name = "Go to Workspace 4 (Social) and launch chat apps";
    command = "${openSocialWorkspaceScript}";
    binding = "<Super><Alt>4";
  };

  "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/goto-workspace-5" = {
    name = "Go to Workspace 5 (Media) and launch Spotify";
    command = "${openMediaWorkspaceScript}";
    binding = "<Super><Alt>5";
  };
}
