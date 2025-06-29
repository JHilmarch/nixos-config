#!/usr/bin/env bash
# Reboot into Windows (one-shot) using systemd-boot

EFI_ENTRY="auto-windows"

echo "Setting next boot to: $EFI_ENTRY (one-shot)"
bootctl set-oneshot "$EFI_ENTRY"
reboot
