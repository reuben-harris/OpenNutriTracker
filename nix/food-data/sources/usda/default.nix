{
  pkgs,
  lib,
  shared,
}:
let
  lock = lib.importJSON ./sources.json;
  archives = lib.mapAttrs (
    name: pin:
    pkgs.fetchurl {
      name = "usda-${name}-${pin.release}.zip";
      inherit (pin) url sha256;
    }
  ) (lock.sources // (lock.auxiliary or { }));
  archiveArgs = lib.concatStringsSep " " (
    lib.mapAttrsToList (name: archive: "--archive ${name}=${archive}") archives
  );
  rawBuilder = pkgs.runCommand "ont-usda-source-reader" { } ''
    mkdir -p "$out/sources/usda"
    cp ${./importer.py} "$out/sources/usda/importer.py"
    cp ${./source_fixes.py} "$out/sources/usda/source_fixes.py"
    cp ${../../values.py} "$out/values.py"
  '';
  rawDatabase = pkgs.runCommand "ont-usda-source-records" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    mkdir -p "$out"
    PYTHONPATH=${rawBuilder} python3 -m sources.usda.importer \
      --schema ${./schema.sql} --lock ${./sources.json} ${archiveArgs} \
      --output "$out/source.sqlite"
  '';
  builder = pkgs.runCommand "ont-usda-importer" { } ''
    mkdir -p "$out/sources"
    cp -r ${./.} "$out/sources/usda"
    cp ${shared}/catalogue.py ${shared}/schema.sql ${shared}/values.py "$out/"
  '';
in
{
  inherit archives;
  nativeBuildInputs = [ pkgs.python3 ];
  generate = output: ''
    PYTHONPATH=${builder} python3 -m sources.usda.catalogue \
      --lock ${./sources.json} --raw ${rawDatabase}/source.sqlite --output ${output}
  '';
}
