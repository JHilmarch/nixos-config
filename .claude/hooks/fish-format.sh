#!/usr/bin/env bash
# Format .fish files with fish_indent after Write/Edit
FILE_PATH=$(jq -r '.tool_input.file_path')
if [[ "$FILE_PATH" == *.fish ]]; then
  fish_indent -w "$FILE_PATH"
fi
