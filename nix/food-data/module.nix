{ ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      registered = lib.importJSON ./registry.json;
      shared = pkgs.runCommand "ont-catalogue-builder" { } ''
        mkdir -p "$out"
        cp ${./catalogue.py} "$out/catalogue.py"
        cp ${./schema.sql} "$out/schema.sql"
        cp ${./values.py} "$out/values.py"
      '';
      sources = lib.genAttrs registered (
        name:
        import (./sources + "/${name}/default.nix") {
          inherit pkgs lib shared;
        }
      );
      databases = lib.mapAttrs (
        name: source:
        pkgs.runCommand "ont-food-data-${name}"
          {
            inherit (source) nativeBuildInputs;
          }
          ''
            mkdir -p "$out/archives"
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (key: archive: ''ln -s ${archive} "$out/archives/${key}"'') source.archives
            )}
            ${source.generate ''"$out/food-data.sqlite"''}
          ''
      ) sources;
      generate = output: ''
        python3 ${shared}/catalogue.py \
          ${
            lib.concatStringsSep " " (
              lib.mapAttrsToList (_: database: "--source ${database}/food-data.sqlite") databases
            )
          } \
          --output ${output}
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
        text = ''exec python3 ${./.}/updater.py --root "$PWD" "$@"'';
      };
    in
    {
      packages = {
        food-database = database;
      }
      // lib.mapAttrs' (name: value: lib.nameValuePair "food-data-${name}" value) databases;
      apps.update-food-data = {
        type = "app";
        program = lib.getExe update;
        meta.description = "Validate and pin explicitly selected food database releases";
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
      }
      // lib.mapAttrs' (
        name: source:
        lib.nameValuePair "food-data-${name}" (
          pkgs.runCommand "ont-${name}-determinism"
            {
              nativeBuildInputs = source.nativeBuildInputs ++ [ pkgs.coreutils ];
            }
            ''
              ${source.generate "second.sqlite"}
              cmp ${databases.${name}}/food-data.sqlite second.sqlite
              touch "$out"
            ''
        )
      ) sources;
    };
}
