# Install phase for awesome-copilot
# Installs built DLLs and creates wrapper script

installPhase() {
  runHook preInstall

  # The build output is in the source directory
  local buildRoot="$NIX_BUILD_TOP/source"

  # Install built DLLs
  mkdir -p "$out/lib"
  cp -r "$buildRoot/awesome-copilot/src/McpSamples.AwesomeCopilot.HybridApp/bin/Release/net9.0/"* "$out/lib/"

  # Install wrapper script
  mkdir -p "$out/bin"
  cat "@wrapperScript@" > "$out/bin/awesome-copilot"
  chmod +x "$out/bin/awesome-copilot"

  runHook postInstall
}
