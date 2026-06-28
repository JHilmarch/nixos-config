{lib}:
with lib.hm.gvariant; {
  # Energy settings: no idle-triggered sleep on AC or battery. Manual suspend,
  # lid-close and `systemctl suspend` remain fully functional (unlike
  # modules/systemd/no-sleep.nix which hard-blocks at the systemd level).
  "org/gnome/settings-daemon/plugins/power" = {
    power-button-action = "interactive";
    sleep-inactive-ac-type = "nothing";
    sleep-inactive-battery-type = "nothing";
  };

  # Screensaver activates after 15 minutes of inactivity (not "never" like
  # Orion, since this is a laptop — some power saving is desirable), but the
  # screen does NOT auto-lock, so no password prompt when it blanks.
  "org/gnome/desktop/session" = {
    idle-delay = mkUint32 900;
  };

  "org/gnome/desktop/screensaver" = {
    lock-enabled = false;
  };
}
