{ ... }:
{
  perSystem =
    { pkgs, lib, ... }:
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
      importer = pkgs.runCommand "ont-food-data-importer" { } ''
        mkdir -p "$out"
        cp ${./importer.py} "$out/importer.py"
        cp ${./source_fixes.py} "$out/source_fixes.py"
      '';
      generate = output: ''
        python3 ${importer}/importer.py --schema ${./schema.sql} --lock ${./sources.json} \
          ${archiveArgs} --output ${output}
      '';
      database = pkgs.runCommand "ont-food-database" { nativeBuildInputs = [ pkgs.python3 ]; } ''
        mkdir -p "$out"
        ${generate ''"$out/food-data.sqlite"''}
      '';
      update = pkgs.writeShellApplication {
        name = "ont-update-food-data";
        runtimeInputs = [
          pkgs.python3
          pkgs.nix
        ];
        text = ''
          if (( $# != 0 )); then
            echo 'Run update-food-data without arguments from the repository root.' >&2
            exit 2
          fi
          exec python3 ${./.}/updater.py --root "$PWD"
        '';
      };
    in
    {
      packages.food-database = database;
      apps.update-food-data = {
        type = "app";
        program = lib.getExe update;
        meta.description = "Validate and pin the latest official USDA food releases";
      };
      checks = {
        food-data = pkgs.runCommand "ont-food-data-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          export PYTHONDONTWRITEBYTECODE=1
          python3 -m unittest discover -s ${./.}/tests -v
          touch "$out"
        '';
        food-database =
          pkgs.runCommand "ont-food-database-determinism"
            {
              nativeBuildInputs = [
                pkgs.python3
                pkgs.coreutils
              ];
            }
            ''
              ${generate "second.sqlite"}
              cmp ${database}/food-data.sqlite second.sqlite
              touch "$out"
            '';
      };
    };
}
