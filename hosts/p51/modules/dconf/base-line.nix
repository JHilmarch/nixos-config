{
  lib,
  username,
}:
with lib.hm.gvariant; {
  "apps/seahorse/listing" = {
    keyrings-selected = ["openssh:///home/${username}/.ssh"];
  };

  "org/gnome/calendar" = {
    active-view = "month";
  };

  "org/gnome/clocks" = {
    world-clocks = [
      [
        (mkDictionaryEntry [
          "location"
          (mkVariant (mkTuple [
            (mkUint32 2)
            (mkVariant (mkTuple [
              "Coordinated Universal Time (UTC)"
              "@UTC"
              false
              [(mkTuple [51.4769280000000000 0.0005450000000000])]
              [(mkTuple [51.4769280000000000 0.0005450000000000])]
            ]))
          ]))
        ])
      ]
      [
        (mkDictionaryEntry [
          "location"
          (mkVariant (mkTuple [
            (mkUint32 2)
            (mkVariant (mkTuple [
              "Stockholm"
              "ESSB"
              true
              [(mkTuple [1.0358529110586345 0.31328660073298215])]
              [(mkTuple [1.0355620170322046 0.31503192998497648])]
            ]))
          ]))
        ])
      ]
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
          [(mkTuple [1.0358529110586345 0.31328660073298215])]
          [(mkTuple [1.0355620170322046 0.31503192998497648])]
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
          [(mkTuple [1.0064732078011609 0.21467549799530256])]
          [(mkTuple [1.0064732078011609 0.21467549799530256])]
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
          [(mkTuple [1.0064732078011609 0.21467549799530256])]
          [(mkTuple [1.0064732078011609 0.21467549799530256])]
        ]))
      ]))
    ];
  };

  "org/gnome/desktop/app-folders" = {
    folder-children = ["Utilities" "YaST" "Pardus"];
  };

  "org/gnome/desktop/app-folders/folders/Pardus" = {
    categories = ["X-Pardus-Apps"];
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

    categories = ["X-GNOME-Utilities"];
    name = "X-GNOME-Utilities.directory";
    translate = true;
  };

  "org/gnome/desktop/app-folders/folders/YaST" = {
    categories = ["X-SuSE-YaST"];
    name = "suse-yast.directory";
    translate = true;
  };

  "org/gnome/desktop/notifications" = {
    application-children = [
      "org-mozilla-firefox"
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

  "org/gnome/desktop/notifications/application/org-mozilla-firefox" = {
    application-id = "org.mozilla.firefox.desktop";
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
}
