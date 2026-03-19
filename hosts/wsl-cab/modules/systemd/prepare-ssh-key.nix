{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.prepare-ssh-key;

  # Convert shell $HOME to systemd %h for ConditionPathExists
  conditionPath =
    if cfg.sshKeyPath == "$HOME/.ssh/id_ed25519"
    then "%h/.ssh/id_ed25519"
    else if lib.hasPrefix "$HOME/" cfg.sshKeyPath
    then "%h/" + (lib.removePrefix "$HOME/" cfg.sshKeyPath)
    else cfg.sshKeyPath;
in {
  options.services.prepare-ssh-key = {
    enable = lib.mkEnableOption "prepare-ssh-key service";
    sshKeyPath = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.ssh/id_ed25519";
      description = "Path to the SSH private key to prepare";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.prepare-ssh-key = {
      description = "Prepare SSH key with correct permissions and line endings";
      wantedBy = ["default.target"];
      wants = ["decrypt-secrets.service"];
      before = ["decrypt-secrets.service"];
      unitConfig = {
        ConditionPathExists = conditionPath;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Environment = "PATH=${pkgs.coreutils}/bin:${pkgs.sed}/bin:/run/current-system/sw/bin";
        ExecStart = pkgs.writeShellScript "prepare-ssh-key" ''
          set -euo pipefail

          SSH_KEY_FILE="${cfg.sshKeyPath}"

          if [ ! -f "$SSH_KEY_FILE" ]; then
            echo "SSH key not found at $SSH_KEY_FILE"
            exit 1
          fi

          # Convert CRLF to LF (Windows line endings to Unix)
          ${pkgs.sed}/bin/sed -i 's/\r$//' "$SSH_KEY_FILE"

          # Set correct permissions (read/write for owner only)
          ${pkgs.coreutils}/bin/chmod 600 "$SSH_KEY_FILE"

          echo "SSH key prepared: $SSH_KEY_FILE"
        '';
      };
    };
  };
}
