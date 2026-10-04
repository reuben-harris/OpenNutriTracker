{ ... }:
{
  perSystem =
    {
      pkgs,
      toolchain,
      workflow,
      projectSource,
      ...
    }:
    {
      checks = {
        gradle-toolchain =
          pkgs.runCommand "ont-gradle-toolchain" { nativeBuildInputs = [ pkgs.gnused ]; }
            ''
              wrapperVersion=$(sed -n 's@^distributionUrl=.*/gradle-\(.*\)-\(all\|bin\)\.zip$@\1@p' \
                ${../android/gradle/wrapper/gradle-wrapper.properties})
              if [[ "$wrapperVersion" != "${toolchain.gradle.version}" ]]; then
                echo "Gradle wrapper ($wrapperVersion) differs from Nix (${toolchain.gradle.version})." >&2
                echo 'Align the wrapper and nix/toolchain.nix, then refresh android/gradle.lock.' >&2
                exit 1
              fi
              touch "$out"
            '';
        nix-format = pkgs.runCommand "ont-nix-format" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
          nixfmt --check ${../flake.nix} ${./.}/*.nix ${./health-compat/flake.nix} ${./food-data}/*.nix
          touch "$out"
        '';
        app = pkgs.stdenvNoCC.mkDerivation {
          name = "ont-app-checks";
          src = projectSource;
          nativeBuildInputs = toolchain.tools ++ [ pkgs.writableTmpDirAsHomeHook ];
          dontConfigure = true;
          dontFixup = true;
          buildPhase = ''
            ${workflow.prepare}
            ont_prepare
            dart tool/check_locales.dart
            flutter --suppress-analytics analyze --no-pub
            flutter --suppress-analytics test --no-pub
          '';
          installPhase = ''touch "$out"'';
        };
      };
    };
}
