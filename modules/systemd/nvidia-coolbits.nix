{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.systemdNvidiaCoolbits;
in {
  options.services.systemdNvidiaCoolbits = {
    enable = lib.mkEnableOption "Enable NVIDIA CoolBits (fan control and optional overclocking)";
    value = lib.mkOption {
      type = lib.types.str; # keep as string to embed directly in xorg.conf.d
      default = "12"; # 4 = fan, 8 = OC, 12 = fan+OC
      example = "4";
      description = ''
        CoolBits value to configure in Xorg. Common values:
        - 4: Enable fan control only
        - 8: Enable overclocking controls only
        - 12: Enable both fan control and overclocking (4 + 8)
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.xserver.enable or false;
        message = "services.systemdNvidiaCoolbits requires services.xserver.enable = true";
      }
      {
        assertion = lib.elem "nvidia" (config.services.xserver.videoDrivers or []);
        message = "services.systemdNvidiaCoolbits requires services.xserver.videoDrivers to include \"nvidia\"";
      }
    ];

    environment.etc."X11/xorg.conf.d/20-nvidia-coolbits.conf".text = ''
      Section "Device"
          Identifier "Nvidia Card"
          Driver "nvidia"
          Option "Coolbits" "${cfg.value}"
      EndSection
    '';
  };
}
