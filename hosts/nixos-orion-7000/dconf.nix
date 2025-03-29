{ pkgs, lib, username, ... }:

with lib.hm.gvariant;
let
  # Unsorted dconf settings
  baseLine = {
    "apps/seahorse/listing" = {
      keyrings-selected = [ "openssh:///home/${username}/.ssh" ];
    };

    "org/gnome/calendar" = {
      active-view = "month";
    };

    "org/gnome/clocks" = {
      world-clocks = [
        ([
          (mkDictionaryEntry ["location" (mkVariant (mkTuple [
            (mkUint32 2)
            (mkVariant (mkTuple [
              "Coordinated Universal Time (UTC)"
              "@UTC"
              false
              [(mkTuple [(51.4769280000000000) (0.0005450000000000)])]
              [(mkTuple [(51.4769280000000000) (0.0005450000000000)])]
            ]))
          ]))])
        ])
        ([
          (mkDictionaryEntry ["location" (mkVariant (mkTuple [
            (mkUint32 2)
            (mkVariant (mkTuple [
              "Stockholm"
              "ESSB"
              true
              [(mkTuple [(1.0358529110586345) (0.31328660073298215)])]
              [(mkTuple [(1.0355620170322046) (0.31503192998497648)])]
            ]))
          ]))])
        ])
      ];
    };

    "org/gnome/shell/world-clocks" = {
      locations = [
        (mkVariant (mkTuple [
          (mkUint32 2)
          (mkVariant (mkTuple [
            "Stockholm"
            "ESSB"
            true
            [(mkTuple [(1.0358529110586345) (0.31328660073298215)])]
            [(mkTuple [(1.0355620170322046) (0.31503192998497648)])]
          ]))
        ]))
      ];
    };

    "org/gnome/clocks/state/window" = {
      panel-id = "timer";
    };

    "org/gnome/Weather" = {
      locations = [
        (mkVariant (mkTuple [
          (mkUint32 2)
          (mkVariant (mkTuple [
            "Göteborg-Landvetter Airport"
            "ESGG"
            false
            [(mkTuple [(1.0064732078011609) (0.21467549799530256)])]
            [(mkTuple [(1.0064732078011609) (0.21467549799530256)])]
          ]))
        ]))
      ];
    };

    "org/gnome/GWeather4" = {
      temperature-units = "centigrade";
    };

    "org/gnome/shell/weather" = {
      automatic-location = true;
      locations = [
        (mkVariant (mkTuple [
          (mkUint32 2)
          (mkVariant (mkTuple [
            "Göteborg-Landvetter Airport"
            "ESGG"
            false
            [(mkTuple [(1.0064732078011609) (0.21467549799530256)])]
            [(mkTuple [(1.0064732078011609) (0.21467549799530256)])]
          ]))
        ]))
      ];
    };

    "org/gnome/desktop/app-folders" = {
      folder-children = [ "Utilities" "YaST" "Pardus" ];
    };

    "org/gnome/desktop/app-folders/folders/Pardus" = {
      categories = [ "X-Pardus-Apps" ];
      name = "X-Pardus-Apps.directory";
      translate = true;
    };

    "org/gnome/desktop/app-folders/folders/Utilities" = {
      apps = [
        "org.freedesktop.GnomeAbrt.desktop"
        "nm-connection-editor.desktop"
        "org.gnome.baobab.desktop"
        "org.gnome.Connections.desktop"
        "org.gnome.DejaDup.desktop"
        "org.gnome.DiskUtility.desktop"
        "org.gnome.Evince.desktop"
        "org.gnome.FileRoller.desktop"
        "org.gnome.font-viewer.desktop"
        "org.gnome.Loupe.desktop"
        "org.gnome.seahorse.Application.desktop"
        "org.gnome.tweaks.desktop"
        "org.gnome.Usage.desktop"
      ];

      categories = [ "X-GNOME-Utilities" ];
      name = "X-GNOME-Utilities.directory";
      translate = true;
    };

    "org/gnome/desktop/app-folders/folders/YaST" = {
      categories = [ "X-SuSE-YaST" ];
      name = "suse-yast.directory";
      translate = true;
    };

    "org/gnome/desktop/notifications" = {
      application-children = [
        "firefox"
        "element-desktop"
        "org-gnome-settings"
        "org-gnome-console"
        "spotify"
        "org-gnome-characters"
      ];
    };

    "org/gnome/desktop/notifications/application/element-desktop" = {
      application-id = "element-desktop.desktop";
    };

    "org/gnome/desktop/notifications/application/firefox" = {
      application-id = "firefox.desktop";
    };

    "org/gnome/desktop/notifications/application/org-gnome-characters" = {
      application-id = "org.gnome.Characters.desktop";
    };

    "org/gnome/desktop/notifications/application/org-gnome-console" = {
      application-id = "org.gnome.Console.desktop";
    };

    "org/gnome/desktop/notifications/application/org-gnome-settings" = {
      application-id = "org.gnome.Settings.desktop";
    };

    "org/gnome/desktop/notifications/application/spotify" = {
      application-id = "spotify.desktop";
    };

    "org/gnome/desktop/peripherals/keyboard" = {
      numlock-state = true;
    };

    "org/gnome/desktop/peripherals/touchpad" = {
      two-finger-scrolling-enabled = true;
    };

    "org/gnome/desktop/search-providers" = {
      disabled = [];
      sort-order = [
        "org.gnome.Settings.desktop"
        "org.gnome.Contacts.desktop"
        "org.gnome.Nautilus.desktop"
      ];
    };

    "org/gnome/evolution-data-server" = {
      migrated = true;
    };

    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "icon-view";
      migrated-gtk-settings = true;
      search-filter-time-type = "last_modified";
    };

    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action = "interactive";
      sleep-inactive-ac-type = "nothing";
    };

    "org/gnome/shell" = {
      disable-user-extensions = false;
      last-selected-power-profile = "performance";
      welcome-dialog-last-shown-version = "47.2";
      enabled-extensions = [
        "tilingshell@ferrarodomenico.com"
        "apps-menu@gnome-shell-extensions.gcampax.github.com"
        "places-menu@gnome-shell-extensions.gcampax.github.com"
      ];
    };

    "org/gtk/settings/file-chooser" = {
      clock-format = "24h";
    };

    "org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };

  inputSources = {
    "org/gnome/desktop/input-sources" = {
      sources = [
        (mkTuple [ "xkb" "se" ])
        (mkTuple [ "xkb" "no" ])
        (mkTuple [ "xkb" "gb" ])
      ];
      xkb-options = [ "terminate:ctrl_alt_bksp" ];
    };
  };

  nightLight = {
    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled = true;
      night-light-schedule-automatic = true;
    };
  };

  workspaceSettings = {
    "org/gnome/mutter" = {
      dynamic-workspaces = false;
      workspaces-only-on-primary = true;
    };

    "org/gnome/desktop/wm/preferences" = {
      num-workspaces = 5;
      workspace-names = [ "Main" "Dev" "Social" "Media" "Free" ];
    };
  };

  configureMediaKeys = {
    "org/gnome/settings-daemon/plugins/media-keys" = {
      play = [ "<Super>KP_Add" ];
      pause = [ "<Super>XF86AudioMute" ];
      stop = [ "<Super>KP_Subtract" ];
      next = [ "<Super>XF86AudioRaiseVolume" ];
      previous = [ "<Super>XF86AudioLowerVolume" ];
      volume-up = [ "XF86AudioRaiseVolume" ];
      volume-down = [ "XF86AudioLowerVolume" ];
      volume-mute = [ "XF86AudioMute" ];
      media = [ "<Super>XF86Calculator" ];
      mic-mute = [ "<Super>KP_Multiply" ];
      eject = [ "<Super>KP_Divide" ];
    };
  };

  customKeybindings = {
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        # For Spotify
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/start-spotify/"

        # For starting up workspaces
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/goto-workspace-1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/goto-workspace-2/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/goto-workspace-3/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/goto-workspace-4/"
      ];
    };
  };

  openMainWorkspaceScript = import ./open-main-workspace.nix { pkgs = pkgs; };
  openDevWorkspaceScript = import ./open-dev-workspace.nix { pkgs = pkgs; };
  openSocialWorkspaceScript = import ./open-social-workspace.nix { pkgs = pkgs; };
  openMediaWorkspaceScript = import ./open-media-workspace.nix { pkgs = pkgs; };

  workspaceShortcuts = {
    # Clear default Super bindings
    "org/gnome/shell/keybindings" = {
      switch-to-application-1 = [];
      switch-to-application-2 = [];
      switch-to-application-3 = [];
      switch-to-application-4 = [];
      switch-to-application-5 = [];
    };

    "org/gnome/desktop/wm/keybindings" = {
      switch-to-workspace-1 = [ "<Super>1" ];
      switch-to-workspace-2 = [ "<Super>2" ];
      switch-to-workspace-3 = [ "<Super>3" ];
      switch-to-workspace-4 = [ "<Super>4" ];
      switch-to-workspace-5 = [ "<Super>5" ];

      move-to-workspace-1 = [ "<Super><Shift>1" ];
      move-to-workspace-2 = [ "<Super><Shift>2" ];
      move-to-workspace-3 = [ "<Super><Shift>3" ];
      move-to-workspace-4 = [ "<Super><Shift>4" ];
      move-to-workspace-5 = [ "<Super><Shift>5" ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/goto-workspace-1" = {
      name = "Go to Workspace 1 and launch Main apps";
      command = "${openMainWorkspaceScript}";
      binding = "<Super><Alt>1";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/goto-workspace-2" = {
      name = "Go to Workspace 2 and launch Dev apps";
      command = "${openDevWorkspaceScript}";
      binding = "<Super><Alt>2";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/goto-workspace-3" = {
      name = "Go to Workspace 3 and launch Social apps";
      command = "${openSocialWorkspaceScript}";
      binding = "<Super><Alt>3";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/goto-workspace-4" = {
      name = "Go to Workspace 4 and launch Media apps";
      command = "${openMediaWorkspaceScript}";
      binding = "<Super><Alt>4";
    };
  };

  spotifyShortcuts = {
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/start-spotify" = {
      name = "Start Spotify";
      command = "spotify";
      binding = "<Super><Alt>XF86Calculator";
    };
  };

  tilingShellSettings = {
    "org/gnome/shell/extensions/tilingshell" = {
      layouts-json = builtins.readFile ./tilingshell-layouts.json;
      selected-layouts = [
        ["Horizontal 22 56 22"]
        ["Horizontal 22 56 22"]
        ["Horizontal 22 56 22"]
        ["Horizontal 22 56 22"]
        ["Horizontal 22-22 56 22-22"]
      ];
      window-gap = 16;
      outer-gap = 8;
      snap-assistant-threshold = 52;
      enable-autotiling = true;
    };
  };
in {
  dconf.settings = lib.foldl lib.recursiveUpdate baseLine [
    inputSources
    nightLight
    workspaceSettings
    configureMediaKeys
    customKeybindings
    workspaceShortcuts
    spotifyShortcuts
    tilingShellSettings
  ];
}
