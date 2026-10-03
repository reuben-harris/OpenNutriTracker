{ ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      toolchain,
      dependencies,
      ...
    }:
    let
      prepare =
        toolchain.environment
        + ''
          export ONT_PUB_CACHE=${dependencies.pubCache}
          export ONT_FLUTTER=${toolchain.flutter}
        ''
        + builtins.readFile ./prepare.sh;
      offline = ''
        cat > android/gradlew <<'WRAPPER'
        #!${pkgs.bash}/bin/bash
        exec ${toolchain.gradle}/bin/gradle --offline --no-daemon --no-watch-fs \
          --init-script ${dependencies.maven.gradleInitScript} "$@"
        WRAPPER
        chmod +x android/gradlew
      '';
      task =
        name: runtimeTools: text:
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = runtimeTools;
          text = ''
            if (( $# != 0 )); then
              echo '${name} takes no arguments.' >&2
              exit 2
            fi
          ''
          + text;
        };
      run = task "ont-run" toolchain.tools (
        prepare
        + ''
          ont_prepare
          ${offline}
          exec flutter --suppress-analytics run --no-pub --flavor develop
        ''
      );
      emulator = task "ont-emulator" [ toolchain.sdk toolchain.java pkgs.gnugrep pkgs.coreutils ] (
        toolchain.environment
        + ''
          export ANDROID_USER_HOME="$PWD/.nix-cache/android"
          export ANDROID_AVD_HOME="$PWD/.nix-cache/avd"
          mkdir -p "$ANDROID_USER_HOME" "$ANDROID_AVD_HOME"
          emulator -accel-check
          if ! avdmanager list avd -c | grep -Fxq opennutritracker-dev; then
            printf 'no\n' | avdmanager create avd \
              --name opennutritracker-dev \
              --package 'system-images;android-36;google_apis;x86_64' --device pixel
          fi
          args=(-avd opennutritracker-dev -accel on -gpu swiftshader -noaudio -no-boot-anim)
          if [[ -z "''${DISPLAY:-}" && -z "''${WAYLAND_DISPLAY:-}" ]]; then
            args+=(-no-window)
          fi
          exec emulator "''${args[@]}"
        ''
      );
      format =
        task "ont-format" [ toolchain.flutter.dart pkgs.git pkgs.python3 pkgs.nixfmt pkgs.coreutils ]
          (''
            export DART_SUPPRESS_ANALYTICS=true
            export XDG_CONFIG_HOME="$PWD/.nix-cache/config"
            mkdir -p "$XDG_CONFIG_HOME"
            python3 ${./format.py}
          '');
      update = task "ont-update-gradle-deps" (toolchain.tools ++ [ toolchain.gradle2nix ]) (
        prepare
        + ''
          ont_prepare
          cd android
          gradle2nix --gradle-home ${toolchain.gradle}/libexec/gradle \
            --gradle-jdk ${toolchain.java.home} --task assembleDevelopDebug \
          --out-dir . --lock-file gradle.lock -- \
          -Pandroid.aapt2FromMavenOverride=${toolchain.sdkRoot}/build-tools/36.0.0/aapt2
          echo 'Updated android/gradle.lock for the selected dependencies.'
        ''
      );
    in
    {
      _module.args.workflow = { inherit prepare offline; };
      apps = {
        run = {
          type = "app";
          program = lib.getExe run;
          meta.description = "Run the develop Android app with hot reload";
        };
        emulator = {
          type = "app";
          program = lib.getExe emulator;
          meta.description = "Create and launch the project Android emulator";
        };
        format = {
          type = "app";
          program = lib.getExe format;
          meta.description = "Format changed authored Dart and Nix files";
        };
        update-gradle-deps = {
          type = "app";
          program = lib.getExe update;
          meta.description = "Refresh the locked Android dependency manifest";
        };
      };
    };
}
