#!/usr/bin/env bash
# Format .nix files with alejandra after Write/Edit
FILE_PATH=$(jq -r '.tool_input.file_path')
if [[ "$FILE_PATH" == *.nix ]]; then
  alejandra -q "$FILE_PATH"
fi
