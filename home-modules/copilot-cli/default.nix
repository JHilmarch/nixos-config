{lib, ...}: let
  readSkillsFrom = dir:
    builtins.mapAttrs (name: _: dir + "/${name}")
    (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir));
in {
  home.file =
    lib.mapAttrs' (name: path:
      lib.nameValuePair ".copilot/skills/${name}" {
        source = path;
        recursive = true;
      })
    (readSkillsFrom ./skills);
}
