{ pkgs }:
pkgs.writeShellScript "dev-workspace-script" ''
  #!/bin/bash
  # Switch to workspace 2 (Dev)
  wmctrl -s 1

  # Launch Rider, Console, and Firefox
  ${pkgs.jetbrains.rider}/bin/rider && sleep 0.3 &
  ${pkgs.gnome-terminal}/bin/gnome-terminal && sleep 0.3 &
  ${pkgs.firefox}/bin/firefox --new-window &
''
