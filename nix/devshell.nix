{ ... }:
{
  perSystem = { pkgs, toolchain, ... }: {
    devShells.default = pkgs.mkShell {
      packages = toolchain.tools;
      shellHook = toolchain.environment + ''
        export XDG_CACHE_HOME="$PWD/.nix-cache/cache"
        export XDG_CONFIG_HOME="$PWD/.nix-cache/config"
        export PUB_CACHE="$PWD/.nix-cache/pub"
        export GRADLE_USER_HOME="$PWD/.nix-cache/gradle"
        export ANDROID_USER_HOME="$PWD/.nix-cache/android"
        export ANDROID_AVD_HOME="$PWD/.nix-cache/avd"
        mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$PUB_CACHE" "$GRADLE_USER_HOME" "$ANDROID_USER_HOME" "$ANDROID_AVD_HOME"
        echo "OpenNutriTracker: Flutter ${toolchain.flutter.version}, Java 17, Android 36"
      '';
    };
  };
}
