# Shared prerequisite preparation for run, build, check, and dependency refresh.
ont_prepare() {
  if [[ ! -f pubspec.yaml || ! -d android ]]; then
    echo 'Run this command from the OpenNutriTracker repository root.' >&2
    return 1
  fi
  export XDG_CACHE_HOME="$PWD/.nix-cache/cache"
  export XDG_CONFIG_HOME="$PWD/.nix-cache/config"
  export PUB_CACHE="$PWD/.nix-cache/pub"
  export GRADLE_USER_HOME="$PWD/.nix-cache/gradle"
  export ANDROID_USER_HOME="$PWD/.nix-cache/android"
  export ANDROID_AVD_HOME="$PWD/.nix-cache/avd"
  export FLUTTER_ROOT="$PWD/.nix-cache/flutter"
  mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$GRADLE_USER_HOME" "$ANDROID_USER_HOME" "$ANDROID_AVD_HOME"

  if [[ ! -f "$PUB_CACHE/.source" ]] || [[ "$(cat "$PUB_CACHE/.source")" != "$ONT_PUB_CACHE" ]]; then
    rm -rf "$PUB_CACHE"
    mkdir -p "$PUB_CACHE"
    cp -aL "$ONT_PUB_CACHE/." "$PUB_CACHE/"
    chmod -R u+w "$PUB_CACHE"
    printf '%s' "$ONT_PUB_CACHE" > "$PUB_CACHE/.source"
  fi
  if [[ ! -f "$FLUTTER_ROOT/.source" ]] || [[ "$(cat "$FLUTTER_ROOT/.source")" != "$ONT_FLUTTER" ]]; then
    if [[ -d "$FLUTTER_ROOT" ]]; then
      chmod -R u+w "$FLUTTER_ROOT"
    fi
    rm -rf "$FLUTTER_ROOT"
    mkdir -p "$FLUTTER_ROOT"
    cp -rs "$ONT_FLUTTER/." "$FLUTTER_ROOT/"
    chmod -R u+w "$FLUTTER_ROOT"
    # Nixpkgs redirects the Flutter Gradle plugin to HOME; use our local cache.
    rm "$FLUTTER_ROOT/packages/flutter_tools/gradle/settings.gradle"
    # Keep the dollar expressions literal for Gradle's Groovy interpolation.
    # shellcheck disable=SC2016
    sed 's@\$System.env.HOME/.cache@\$System.env.XDG_CACHE_HOME@g' \
      "$ONT_FLUTTER/packages/flutter_tools/gradle/settings.gradle" \
      > "$FLUTTER_ROOT/packages/flutter_tools/gradle/settings.gradle"
    printf '%s' "$ONT_FLUTTER" > "$FLUTTER_ROOT/.source"
  fi

  printf 'sdk.dir=%s\nflutter.sdk=%s\n' "$ANDROID_HOME" "$FLUTTER_ROOT" > android/local.properties
  flutter --suppress-analytics pub get --offline --enforce-lockfile
  rm -rf lib/generated
  flutter --suppress-analytics gen-l10n
  dart run build_runner build
}
