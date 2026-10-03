{ inputs, ... }:
{
  perSystem = { pkgs, system, ... }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        android_sdk.accept_license = true;
      };
    };
    _module.args.toolchain = rec {
      flutter = pkgs.flutter.override {
        supportedTargetFlutterPlatforms = [
          "universal"
          "android"
        ];
      };
      java = pkgs.jdk17_headless;
      gradle = pkgs.gradle_8.override { java = java; };
      sdk =
        (pkgs.androidenv.composeAndroidPackages {
          platformVersions = [ "36" ];
          buildToolsVersions = [ "36.0.0" ];
          includeNDK = true;
          ndkVersions = [ "28.2.13676358" ];
          includeCmake = true;
          cmakeVersions = [ "3.22.1" ];
          includeEmulator = true;
          includeSystemImages = true;
          systemImageTypes = [ "google_apis" ];
          abiVersions = [ "x86_64" ];
        }).androidsdk;
      sdkRoot = "${sdk}/libexec/android-sdk";
      gradle2nix = inputs.gradle2nix.packages.${system}.gradle2nix;
      tools = [
        flutter
        flutter.dart
        java
        gradle
        sdk
        pkgs.git
        pkgs.python3
        pkgs.nixfmt
        pkgs.gnused
        pkgs.coreutils
      ];
      environment = ''
        export JAVA_HOME=${java.home}
        export ANDROID_HOME=${sdkRoot}
        export ANDROID_SDK_ROOT=${sdkRoot}
        export FLUTTER_SUPPRESS_ANALYTICS=true
        export DART_SUPPRESS_ANALYTICS=true
        export CI=true
        export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=${sdkRoot}/build-tools/36.0.0/aapt2"
      '';
    };
  };
}
