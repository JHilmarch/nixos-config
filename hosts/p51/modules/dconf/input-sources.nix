{lib}:
with lib.hm.gvariant; {
  "org/gnome/desktop/input-sources" = {
    sources = [
      (mkTuple ["xkb" "se"])
      (mkTuple ["xkb" "no"])
      (mkTuple ["xkb" "gb"])
    ];
    xkb-options = ["terminate:ctrl_alt_bksp"];
  };
}
