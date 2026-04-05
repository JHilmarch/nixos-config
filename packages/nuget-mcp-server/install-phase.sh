# Install phase for nuget-mcp-server
# Extracts the linux-x64 RID package and installs wrapper script

installPhase() {
  runHook preInstall

  mkdir -p $out/bin $out/lib/mcp-nuget

  # Extract the linux-x64 RID package (contains all DLLs)
  unzip @fetchedRidPkg@ 'tools/net10.0/linux-x64/*' -d $out/lib/mcp-nuget

  # Flatten tools/net10.0/linux-x64 -> lib/mcp-nuget
  mv $out/lib/mcp-nuget/tools/net10.0/linux-x64/* $out/lib/mcp-nuget/
  rm -rf $out/lib/mcp-nuget/tools

  # Install wrapper script
  cat "@wrapperScript@" > "$out/bin/mcp-nuget"
  chmod +x "$out/bin/mcp-nuget"

  runHook postInstall
}
