{ pkgs, inputs, username, ... }: {
    # Run `timedatectl list-timezones` to list timezones"
    time.timeZone = "Europe/Stockholm";

    nix = {
      settings.experimental-features = ["nix-command" "flakes"];
      extraOptions = "experimental-features = nix-command flakes";
    };
}
