{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.services.openchamber;

  # Wrapper that loads the UI password from the SOPS-decrypted secret file and
  # exports it as OPENCHAMBER_UI_PASSWORD. The openchamber CLI does NOT support
  # a --ui-password-file flag (verified against v1.13.5 cli-args.js); only
  # --ui-password <value> and the OPENCHAMBER_UI_PASSWORD env var are accepted.
  startScript = pkgs.writeShellApplication {
    name = "openchamber-start";
    runtimeInputs = [cfg.package];
    checkPhase = "true";
    text = ''
      set -euo pipefail
      export OPENCHAMBER_UI_PASSWORD="$(cat ${toString cfg.uiPasswordFile})"
      export OPENCODE_HOST="http://localhost:${toString cfg.openCodePort}"
      export OPENCODE_SKIP_START="true"
      exec openchamber serve \
        --port ${toString cfg.port} \
        --host ${cfg.bindAddress} \
        --foreground
    '';
  };
in {
  options.services.openchamber = {
    enable = lib.mkEnableOption "OpenChamber web GUI for opencode visibility across hosts";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.local.openchamber;
      defaultText = lib.literalExpression "pkgs.local.openchamber";
      description = "OpenChamber package to use.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port on which the OpenChamber web UI listens.";
    };

    openCodePort = lib.mkOption {
      type = lib.types.port;
      default = 4095;
      description = ''
        Port on which the local opencode server listens. Used for firewall
        scoping; the actual opencode service is launched via
        programs.opencode.package (the jail-nix wrapper) and told to listen on
        this port.
      '';
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = ''
        Address OpenChamber binds to. Defaults to 0.0.0.0 for LAN exposure per
        story #84. Set to 127.0.0.1 to restrict to localhost only.
      '';
    };

    uiPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to a file containing the OpenChamber UI password (e.g. the
        SOPS-decrypted /run/secrets/openchamber_ui_password). The contents are
        read at service start and exported as OPENCHAMBER_UI_PASSWORD.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Open firewall ports for OpenChamber (cfg.port) and opencode
        (cfg.openCodePort). Scope to LAN via upstream NAT/router; for stricter
        source filtering add networking.firewall.extraInputRules manually.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.openFirewall && !config.networking.firewall.enable);
        message = "services.openchamber.openFirewall requires networking.firewall.enable = true";
      }
      {
        assertion = config.home-manager.users.${username}.programs.opencode.enable or false;
        message = "services.openchamber requires programs.opencode.enable = true for user ${username} (load home-modules/opencode and the host's opencode.nix)";
      }
      {
        assertion = username != null && username != "";
        message = "services.openchamber requires the `username` specialArg to be set on the host";
      }
    ];

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [cfg.port cfg.openCodePort];
    };

    # Systemd USER services (not system services) so the jail-nix opencode
    # wrapper has access to the user's $HOME, ssh-agent, GPG agent, and
    # SOPS-decrypted env templates. Matches the home-manager.users.${username}
    # pattern used in hosts/orion/modules/opencode.nix.
    #
    # Design decision (per #90 "Decide and document which layer owns the
    # services"): a single system module owns both the firewall and the
    # user services. The HM wrapper in home-modules/opencode/ stays untouched —
    # we just call its exported binary
    # (config.home-manager.users.${username}.programs.opencode.package) as the
    # opencode service's ExecStart.
    home-manager.users.${username} = {
      systemd.user.services.opencode = {
        Unit = {
          Description = "opencode agent server (jail-nix wrapper)";
          Documentation = "see: home-modules/opencode/default.nix";
        };
        Service = {
          # `opencode serve` runs the wrapper in server mode. The wrapper
          # already sources preSetupScripts (SOPS env templates) and configures
          # the jail on every invocation. The opencode package is exported by
          # the home-modules/opencode HM module via programs.opencode.package.
          ExecStart = "${lib.getExe config.home-manager.users.${username}.programs.opencode.package} serve --port ${toString cfg.openCodePort}";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = ["default.target"];
      };

      systemd.user.services.openchamber = {
        Unit = {
          Description = "OpenChamber web GUI for opencode visibility";
          Documentation = "https://github.com/openchamber/openchamber";
          # Requires+After so OPENCODE_HOST is reachable when openchamber starts.
          # PartOf so opencode restarts (e.g. from SOPS rotation or
          # nixos-rebuild switch) propagate to openchamber — otherwise HM
          # activation stops openchamber and never restarts it because the
          # unit file content didn't change.
          After = ["opencode.service"];
          Requires = ["opencode.service"];
          PartOf = ["opencode.service"];
        };
        Service = {
          ExecStart = lib.getExe startScript;
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = ["default.target"];
      };
    };
  };
}
