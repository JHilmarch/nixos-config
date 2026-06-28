{pkgs}:
pkgs.writeShellScript "social-workspace-script" ''
  #!/bin/bash
  # Switch to workspace 4 (Social)
  wmctrl -s 3

  # Launch Element, Signal, Discord & Slack (same as orion)
  ${pkgs.element-desktop}/bin/element-desktop && sleep 0.3 &
  ${pkgs.unstable.signal-desktop}/bin/signal-desktop && sleep 0.3 &
  ${pkgs.discord}/bin/discord && sleep 0.3 &
  ${pkgs.slack}/bin/slack &
''
