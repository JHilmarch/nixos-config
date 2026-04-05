# Install phase for awesome-copilot
# Installs built DLLs and creates wrapper script

installPhase() {
  runHook preInstall

  # The build output is in the source directory
  local buildRoot="$NIX_BUILD_TOP/source"

  # Install built DLLs
  mkdir -p "$out/lib"
  local tfmDir=$(find "$buildRoot/awesome-copilot/src/McpSamples.AwesomeCopilot.HybridApp/bin/Release/" -mindepth 1 -maxdepth 1 -type d | head -1)
  cp -r "$tfmDir/"* "$out/lib/"

  # Install wrapper script
  mkdir -p "$out/bin"
  cat "@wrapperScript@" > "$out/bin/awesome-copilot"
  chmod +x "$out/bin/awesome-copilot"

  runHook postInstall
}
