{ pkgs }:
pkgs.writeShellScript "main-workspace-script" ''
  #!/bin/bash
  # Switch to workspace 1 (Main)
  wmctrl -s 0

  # Launch 1Password, Calendar, Firefox & Geary
  ${pkgs._1password-gui}/bin/1password && sleep 0.3 &
  ${pkgs.gnome-calendar}/bin/gnome-calendar && sleep 0.3 &
  ${pkgs.geary}/bin/geary && sleep 0.3 &
  ${pkgs.firefox}/bin/firefox -url \
    "https://planner.cloud.microsoft/webui/mytasks/assignedtome/view/board?tid=8b21d9cf-fc02-4ed2-aae6-3c2fc6ca5c1f" \
    "https://outlook.office.com/mail/" \
    "https://teams.microsoft.com/v2/" \
    "https://mail.proton.me/" \
    "https://calendar.proton.me/" --new-window &
''
