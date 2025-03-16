{ lib, username, ... }:

with lib.hm.gvariant;
let
  # Unsorted dconf settings
  baseLine = {
    "apps/seahorse/listing" = {
      keyrings-selected = [ "openssh:///home/${username}/.ssh" ];
    };

    "apps/seahorse/windows/key-manager" = {
      height = 476;
      width = 600;
    };

    "org/gnome/Console" = {
      last-window-maximised = false;
      last-window-size = mkTuple [ 2548 1393 ];
    };

    "org/gnome/calendar" = {
      active-view = "month";
      window-maximized = false;
      window-size = mkTuple [ 1863 1063 ];
    };

    "org/gnome/clocks/state/window" = {
      maximized = false;
      panel-id = "timer";
      size = mkTuple [ 870 690 ];
    };

    "org/gnome/control-center" = {
      last-panel = "bluetooth";
      window-state = mkTuple [ 1557 1066 false ];
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

    "org/gnome/desktop/input-sources" = {
      sources = [
        (mkTuple [ "xkb" "se" ])
        (mkTuple [ "xkb" "no" ])
        (mkTuple [ "xkb" "gb" ])
      ];
      xkb-options = [ "terminate:ctrl_alt_bksp" ];
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

    "org/gnome/nautilus/window-state" = {
      initial-size = mkTuple [ 890 550 ];
    };

    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled = true;
      night-light-schedule-automatic = true;
    };

    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action = "interactive";
      sleep-inactive-ac-type = "nothing";
    };

    "org/gnome/shell" = {
      last-selected-power-profile = "performance";
      welcome-dialog-last-shown-version = "47.2";
    };

    "org/gnome/shell/world-clocks" = {
      locations = [];
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
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "Spotify";
      command = "spotify";
      binding = "<Super><Alt>XF86Calculator";
    };
  };
in {
  dconf.settings = lib.foldl lib.recursiveUpdate baseLine [
    configureMediaKeys
    customKeybindings
  ];
}
