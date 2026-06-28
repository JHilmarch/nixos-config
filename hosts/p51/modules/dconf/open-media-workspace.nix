{pkgs}:
pkgs.writeShellScript "media-workspace-script" ''
  #!/bin/bash
  # Switch to workspace 5 (Media)
  wmctrl -s 4

  # Launch Spotify
  ${pkgs.spotify}/bin/spotify &
''
