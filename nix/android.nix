{ ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      toolchain,
      workflow,
      ...
    }:
    let
      source = lib.cleanSourceWith {
        src = ../.;
        filter =
          path: type:
          let
            relative = lib.removePrefix (toString ../. + "/") (toString path);
            name = baseNameOf path;
            top = builtins.head (lib.splitString "/" relative);
          in
          (type == "directory" && relative == toString ../.)
          ||
            (
              builtins.elem top [
                "android"
                "assets"
                "fonts"
                "lib"
                "test"
                "tool"
                "nix"
              ]
              || builtins.elem relative [
                "pubspec.yaml"
                "pubspec.lock"
                "l10n.yaml"
                "analysis_options.yaml"
                "flake.nix"
                "flake.lock"
              ]
            )
            && !(builtins.elem name [
              "build"
              ".gradle"
              ".dart_tool"
              "generated"
              "local.properties"
              "key.properties"
              "gradlew"
              "gradlew.bat"
              "gradle-wrapper.jar"
            ])
            && !(lib.hasSuffix ".env" name || lib.hasSuffix ".jks" name || lib.hasSuffix ".keystore" name);
      };
    in
    {
      _module.args.projectSource = source;
      packages.apk = pkgs.stdenvNoCC.mkDerivation {
        pname = "opennutritracker-develop-apk";
        version = "2.4.0";
        src = source;
        nativeBuildInputs = toolchain.tools ++ [ pkgs.writableTmpDirAsHomeHook ];
        dontConfigure = true;
        dontFixup = true;
        buildPhase = ''
          runHook preBuild
          ${workflow.prepare}
          ont_prepare
          ${workflow.offline}
          flutter --suppress-analytics build apk --debug --flavor develop --no-pub
          runHook postBuild
        '';
        installPhase = ''
          mkdir -p "$out"
          cp build/app/outputs/flutter-apk/app-develop-debug.apk "$out/"
        '';
      };
    };
}
