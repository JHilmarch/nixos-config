{ pkgs }:
pkgs.writeShellScript "social-workspace-script" ''
  #!/bin/bash
  # Switch to workspace 3 (Social)
  wmctrl -s 2

  # Launch Element & Slack
  ${pkgs.element-desktop}/bin/element-desktop && sleep 0.3 &
  ${pkgs.signal-desktop}/bin/signal-desktop && sleep 0.3 &
  ${pkgs.discord}/bin/discord && sleep 0.3 &
  ${pkgs.slack}/bin/slack &
''
