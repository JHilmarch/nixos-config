{
  "org/gnome/mutter" = {
    dynamic-workspaces = false;
    workspaces-only-on-primary = true;

    # scale-monitor-framebuffer and xwayland-native-scaling work on Intel.
    # HDR features (hdr-metadata, autohdr) omitted — P51's Kaby Lake iGPU
    # does not support HDR output.
    experimental-features = [
      "scale-monitor-framebuffer"
      "xwayland-native-scaling"
    ];
  };

  "org/gnome/desktop/wm/preferences" = {
    num-workspaces = 5;
    workspace-names = ["Browser" "Dev-Rider" "Dev-Term" "Social" "Media"];
  };
}
