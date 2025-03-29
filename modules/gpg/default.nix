{ lib, pkgs, ... }:

with lib;

let
  keyDir = ./public-keys;
  trustedUltimateDir = keyDir + "/personal";
  trustedFullDir = keyDir + "/fully-trusted";
  trustedMarginallyDir = keyDir + "/marginally-trusted";

  listFilesInDir =
    dir:
    let
      dirAttr = builtins.readDir dir;
    in
      builtins.filter (n: dirAttr.${n} == "regular") (builtins.attrNames dirAttr);
in
{
  programs.gpg = {
    enable = true;

    mutableKeys = false;
    mutableTrust = false;
    publicKeys = [
    ]
    ++ (builtins.map (file: {
      source = trustedUltimateDir + "/${file}";
      trust = "ultimate";
    }) (listFilesInDir trustedUltimateDir))
    ++ (builtins.map (file: {
      source = trustedFullDir + "/${file}";
      trust = "full";
    }) (listFilesInDir trustedFullDir))
    ++ (builtins.map (file: {
      source = trustedMarginallyDir + "/${file}";
      trust = "marginal";
    }) (listFilesInDir trustedMarginallyDir));

    # https://raw.githubusercontent.com/drduh/config/master/gpg.conf
    settings = {
      personal-cipher-preferences = "AES256 AES192 AES";
      personal-digest-preferences = "SHA512 SHA384 SHA256";
      personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
      default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
      cert-digest-algo = "SHA512";
      s2k-digest-algo = "SHA512";
      s2k-cipher-algo = "AES256";
      charset = "utf-8";
      no-comments = true;
      no-emit-version = true;
      no-greeting = true;
      keyid-format = "0xlong";
      list-options = "show-uid-validity";
      verify-options = "show-uid-validity";
      with-fingerprint = true;
      require-cross-certification = true;
      no-symkey-cache = true;
      armor = true;
      use-agent = true;
      throw-keyids = true;
    };
  };

  services = {
    gpg-agent = {
      enable = true;
      pinentryPackage = pkgs.pinentry-gnome3;
    };
  };
}
