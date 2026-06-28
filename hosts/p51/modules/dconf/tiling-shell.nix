{
  "org/gnome/shell/extensions/tilingshell" = {
    layouts-json = builtins.readFile ./tilingshell-layouts.json;

    # Per-workspace default layouts. Laptop screen is the only monitor, so
    # most apps open maximized. Only Dev-Term (workspace 3) gets a 50/50
    # side-by-side split for two terminals.
    selected-layouts = [
      ["Maximized"]
      ["Maximized"]
      ["Split Half"]
      ["Maximized"]
      ["Maximized"]
    ];

    window-gap = 16;
    outer-gap = 8;
    snap-assistant-threshold = 52;
    enable-autotiling = true;
  };
}
