{pkgs}:
pkgs.writeShellScript "dev-terminals-workspace-script" ''
  #!/bin/bash
  # Switch to workspace 3 (Dev-Terminals)
  wmctrl -s 2

  # Launch two GNOME Terminals. Tiling Shell should auto-tile them
  # side-by-side based on the "Split Half" layout for this workspace.
  # The 1s sleep gives Tiling Shell time to process each window before
  # the next arrives; the wmctrl unmaximize is a fallback in case GNOME's
  # auto-maximize fires before Tiling Shell can apply the split layout.
  ${pkgs.gnome-terminal}/bin/gnome-terminal &
  sleep 1
  wmctrl -r :ACTIVE: -b remove,maximized_vert,maximized_horz
  ${pkgs.gnome-terminal}/bin/gnome-terminal &
  sleep 1
  wmctrl -r :ACTIVE: -b remove,maximized_vert,maximized_horz
''
