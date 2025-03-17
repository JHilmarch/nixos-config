{ pkgs }:
pkgs.writeShellScript "media-workspace-script" ''
  #!/bin/bash
  # Switch to workspace 4 (Media)
  wmctrl -s 3

  # Launch Spotify
  ${pkgs.spotify}/bin/spotify &
''
