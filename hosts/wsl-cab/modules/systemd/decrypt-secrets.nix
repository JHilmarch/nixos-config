{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.decrypt-secrets;
  hostname = config.networking.hostName;

  # Convert shell $HOME to systemd %h for ConditionPathExists
  conditionPath =
    if cfg.sshKeyPath == "$HOME/.ssh/id_ed25519"
    then "%h/.ssh/id_ed25519"
    else if lib.hasPrefix "$HOME/" cfg.sshKeyPath
    then "%h/" + (lib.removePrefix "$HOME/" cfg.sshKeyPath)
    else cfg.sshKeyPath;
in {
  options.services.decrypt-secrets = {
    enable = lib.mkEnableOption "decrypt-secrets service";
    sshKeyPath = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.ssh/id_ed25519";
      description = "Path to the SSH private key used for decryption";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.decrypt-secrets = {
      description = "Decrypt secrets using SSH key";
      wantedBy = ["default.target"];
      unitConfig = {
        ConditionPathExists = conditionPath;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Environment = "PATH=${pkgs.coreutils}/bin:${pkgs.openssh}/bin:${pkgs.sops}/bin:/run/current-system/sw/bin";
        ExecStart = pkgs.writeShellScript "decrypt-secrets" ''
          set -euo pipefail

          SECRETS_DIR=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/secrets
          ${pkgs.coreutils}/bin/mkdir -p "$SECRETS_DIR"

          SECRETS_FILE="/etc/nixos/secrets/${hostname}/secrets.yml"

          if [ ! -f "$SECRETS_FILE" ]; then
            echo "Secrets file not found at $SECRETS_FILE"
            echo "Make sure the secrets are included in the tarball during build"
            exit 1
          fi

          SSH_KEY_FILE="${cfg.sshKeyPath}"

          if [ ! -f "$SSH_KEY_FILE" ]; then
            echo "SSH key not found at $SSH_KEY_FILE"
            exit 1
          fi

          # Decrypt secrets using sops with age via SSH key
          export SOPS_AGE_SSH_PRIVATE_KEY_FILE="$SSH_KEY_FILE"
          ${pkgs.sops}/bin/sops --decrypt --extract '["gh_personal_pat"]' "$SECRETS_FILE" > "$SECRETS_DIR/gh_personal_pat"
          ${pkgs.sops}/bin/sops --decrypt --extract '["gh_work_pat"]' "$SECRETS_FILE" > "$SECRETS_DIR/gh_work_pat"

          ${pkgs.coreutils}/bin/chmod 0400 "$SECRETS_DIR"/* 2>/dev/null || true
        '';
      };
    };
  };
}
