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
        nix-format = pkgs.runCommand "ont-nix-format" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
          nixfmt --check ${../flake.nix} ${./.}/*.nix
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
