{ ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      # sqlite3 3.7.0 release hashes, also checked by the package build hook.
      pins = {
        "libsqlite3.arm.android.so" = "a42fa9d0f5c006d30b000d4904bc497705191c5d7330b178618546004295bb49";
        "libsqlite3.arm64.android.so" = "0c2d3bfc8c87abceb21ed72a4bb49964121c5fe1a8ef3848d83ba907d01b6161";
        "libsqlite3.x64.android.so" = "949965f0eba976f707ae364cdcb42c342b5f0626081f8d7f0378fb7b52848772";
        "libsqlite3.x64.linux.so" = "0f947ebe629e8d9d02d7f408bef36e056bfc63ea47e02e0d45a7bae454f04ace";
      };
      libraries = lib.mapAttrs (
        name: sha256:
        pkgs.fetchurl {
          inherit name sha256;
          url = "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.7.0/${name}";
        }
      ) pins;
      sqliteLibraries = pkgs.runCommand "ont-sqlite3-3.7.0-libraries" { } ''
        mkdir -p "$out"
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: file: ''cp ${file} "$out/${name}"'') libraries
        )}
      '';
      foodAssets = pkgs.runCommand "ont-food-app-assets" { nativeBuildInputs = [ pkgs.coreutils ]; } ''
        mkdir -p "$out"
        cp ${config.packages.food-database}/food-data.sqlite "$out/food-data.sqlite"
        sha256sum "$out/food-data.sqlite" | cut -d ' ' -f 1 > "$out/fingerprint"
      '';
    in
    {
      _module.args.foodData = { inherit foodAssets sqliteLibraries; };
      packages.food-app-assets = foodAssets;
      packages.sqlite-libraries = sqliteLibraries;
    };
}
