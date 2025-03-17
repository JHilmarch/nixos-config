{ pkgs }:
pkgs.writeShellScript "main-workspace-script" ''
  #!/bin/bash
  # Switch to workspace 1 (Main)
  wmctrl -s 0

  # Launch Calendar, Firefox, and System Monitor
  ${pkgs.gnome-calendar}/bin/gnome-calendar && sleep 0.2 &
  ${pkgs.firefox}/bin/firefox --new-window && sleep 0.2 &
  ${pkgs.gnome-system-monitor}/bin/gnome-system-monitor &
''
