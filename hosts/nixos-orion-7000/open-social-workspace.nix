{ pkgs }:
pkgs.writeShellScript "social-workspace-script" ''
  #!/bin/bash
  # Switch to workspace 3 (Social)
  wmctrl -s 2

  # Launch Element & Slack
  ${pkgs.element-desktop}/bin/element-desktop &
  ${pkgs.slack}/bin/slack &
''
