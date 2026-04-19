{lib, ...}: {
  readSkillsFrom = dir:
    builtins.mapAttrs (name: _: dir + "/${name}")
    (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir));
}
