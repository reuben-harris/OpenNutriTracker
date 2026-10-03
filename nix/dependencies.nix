{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    let
      lock = lib.importJSON (
        pkgs.runCommand "ont-pubspec-lock-json" {
          nativeBuildInputs = [ pkgs.yq ];
        } ''yq . ${../pubspec.lock} > "$out"''
      );
      hosted = lib.filterAttrs (_: package: package.source == "hosted") lock.packages;
      healthPatch = inputs.health-compat.lib.healthPatch;
      archives = lib.mapAttrs (
        name: package:
        pkgs.fetchurl {
          name = "${name}-${package.version}.tar.gz";
          url = "${package.description.url}/api/archives/${name}-${package.version}.tar.gz";
          sha256 = package.description.sha256;
        }
      ) hosted;
    in
    {
      _module.args.dependencies = {
        pubCache =
          assert healthPatch.validateVersion hosted.health.version;
          pkgs.runCommand "ont-pub-cache" { nativeBuildInputs = [ pkgs.patch ]; } ''
            mkdir -p "$out/hosted/pub.dev" "$out/hosted-hashes/pub.dev"
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: package: ''
                mkdir -p "$out/hosted/pub.dev/${name}-${package.version}"
                tar xf ${archives.${name}} -C "$out/hosted/pub.dev/${name}-${package.version}"
                printf '%s' '${package.description.sha256}' > "$out/hosted-hashes/pub.dev/${name}-${package.version}.sha256"
              '') hosted
            )}
            patch --batch --fuzz=0 -p1 \
              -d "$out/hosted/pub.dev/health-${hosted.health.version}" \
              < ${healthPatch.patch}
          '';
        maven = inputs.gradle2nix.builders.${system}.buildMavenRepo {
          lockFile = ../android/gradle.lock;
        };
      };
    };
}
