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
      name = "nzfoodfiles-${name}-${pin.release}.msi";
      inherit (pin) url sha256;
    }
  ) lock.sources;
  builder = pkgs.runCommand "ont-nzfoodfiles-importer" { } ''
    mkdir -p "$out/sources"
    cp -r ${./.} "$out/sources/nzfoodfiles"
    cp ${shared}/catalogue.py ${shared}/schema.sql ${shared}/values.py "$out/"
  '';
in
{
  inherit archives;
  nativeBuildInputs = [
    pkgs.python3
    pkgs._7zz
  ];
  generate = output: ''
    PYTHONPATH=${builder} python3 -m sources.nzfoodfiles.importer \
      --lock ${./sources.json} \
      ${
        lib.concatStringsSep " " (
          lib.mapAttrsToList (name: archive: "--archive ${name}=${archive}") archives
        )
      } \
      --output ${output}
  '';
}
