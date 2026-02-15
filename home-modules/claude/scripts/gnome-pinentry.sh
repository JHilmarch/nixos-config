#!/bin/sh

# Setup GNOME pinentry for Claude Code
#
# This script configures a separate GPG home directory for Claude Code with the
# GNOME pinentry GUI. This keeps the default TTY pinentry for while providing a
# graphical pinentry for Claude Code GPG operations.
#
# The script:
# - Ensures DISPLAY is set for GUI pinentry
# - Creates a Claude-specific GPG home (~/.gnupg-claude)
# - Symlinks private keys and keyring data from the main GPG home
# - Creates gpg-agent.conf with the GNOME pinentry program
# - Sets GNUPGHOME to point to the Claude-specific directory
#
# Usage: gnome-pinentry.sh <pinentry-package-path>

# shellcheck disable=SC2089
# shellcheck disable=SC2090

PINENTRY_PKG="$1"

if [ -z "$PINENTRY_PKG" ]; then
  echo "Error: Pinentry package path not provided" >&2
  echo "Usage: gnome-pinentry.sh <pinentry-package-path>" >&2
  exit 1
fi

if [ ! -d "$PINENTRY_PKG" ]; then
  echo "Error: Pinentry package not found: $PINENTRY_PKG" >&2
  exit 1
fi

[ -z "$DISPLAY" ] && export DISPLAY=:0

export GNUPGHOME="''${GNUPGHOME:-$HOME/.gnupg}"
CLAUDE_GNUPG="$HOME/.gnupg-claude"

mkdir -p "$CLAUDE_GNUPG"

if [ ! -L "$CLAUDE_GNUPG/private-keys-v1.d" ]; then
  ln -sf "$GNUPGHOME/private-keys-v1.d" "$CLAUDE_GNUPG/private-keys-v1.d"
fi

for f in pubring.kbx trustdb.gpg sshcontrol; do
  if [ -f "$GNUPGHOME/$f" ] && [ ! -e "$CLAUDE_GNUPG/$f" ]; then
    ln -sf "$GNUPGHOME/$f" "$CLAUDE_GNUPG/$f"
  fi
done

cat > "$CLAUDE_GNUPG/gpg-agent.conf" << EOF
pinentry-program $PINENTRY_PKG/bin/pinentry-gnome3
EOF

export GNUPGHOME="$CLAUDE_GNUPG"
