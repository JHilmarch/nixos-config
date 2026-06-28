{
  dconf.settings = {
    # Prevent automatic sleep/hibernate when idle on both AC and battery power.
    # Unlike modules/systemd/no-sleep.nix (which hard-blocks suspend/hibernate at
    # the systemd level via AllowSuspend/AllowHibernation = "no"), these GNOME
    # settings only stop *idle-triggered* sleep. Manual suspend, lid-close, and
    # `systemctl suspend` remain fully functional.
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
      sleep-inactive-battery-type = "nothing";
    };
  };
}
