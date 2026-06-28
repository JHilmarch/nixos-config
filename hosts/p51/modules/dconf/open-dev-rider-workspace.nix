{pkgs}:
pkgs.writeShellScript "dev-rider-workspace-script" ''
  #!/bin/bash
  # Switch to workspace 2 (Dev-Rider)
  wmctrl -s 1

  # Launch JetBrains Rider only (maximized by tiling shell layout)
  ${pkgs.jetbrains.rider}/bin/rider &
''
