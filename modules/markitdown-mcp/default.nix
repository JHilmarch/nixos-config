{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.markitdown-mcp;

  markitdownVersion = "0.1.4";

  python-custom = pkgs.unstable.python3.override {
    packageOverrides = final: prev: {
      mcp = prev.mcp.overridePythonAttrs (old: rec {
        version = "1.8.0";
        src = pkgs.fetchPypi {
          pname = "mcp";
          inherit version;
          hash = "sha256-Jj37cAVAtybAk/DD4EP2at7Qcw0LUfBOsKPrkAVf5Js=";
        };
        build-system =
          old.build-system
          ++ [final.uv-dynamic-versioning];
        doCheck = false;
      });
    };
  };

  markitdownSrc = pkgs.fetchFromGitHub {
    owner = "microsoft";
    repo = "markitdown";
    rev = "v${markitdownVersion}";
    hash = "sha256-WKA2eY8wY3SM9xZ7Cek5eUcJbO5q6eMDx2aTKfQnFvE=";
  };

  markitdown-mcp-python = python-custom.pkgs.buildPythonPackage {
    pname = "markitdown-mcp";
    version = markitdownVersion;
    src = "${markitdownSrc}/packages/markitdown-mcp";
    pyproject = true;
    build-system = [python-custom.pkgs.hatchling];
    dependencies = with python-custom.pkgs; [
      markitdown
      mcp
    ];
    pythonImportsCheck = ["markitdown_mcp"];
  };

  markitdown-mcp-wrapper = pkgs.writeShellScriptBin "markitdown-mcp" ''
    export PATH="${lib.makeBinPath [
      pkgs.ffmpeg
      pkgs.exiftool
    ]}:$PATH"
    export EXIFTOOL_PATH="${pkgs.exiftool}/bin/exiftool"
    export FFMPEG_PATH="${pkgs.ffmpeg}/bin/ffmpeg"
    export MARKITDOWN_ENABLE_PLUGINS="True"
    exec ${markitdown-mcp-python}/bin/markitdown-mcp "$@"
  '';
in {
  options.services.markitdown-mcp = {
    enable = lib.mkEnableOption "markitdown-mcp MCP server";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [markitdown-mcp-wrapper];
  };
}
