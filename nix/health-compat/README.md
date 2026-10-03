# Temporary health Kotlin compatibility

This standalone, input-free flake carries the Android Gradle patch for
`health` **13.3.2**. That release still applies `kotlin-android`, which conflicts
with Android Gradle Plugin 9's built-in Kotlin support.

Upstream migration: [carp-health-flutter PR #491](https://github.com/carp-dk/carp-health-flutter/pull/491).
The PR was still open when this patch was added on 2026-10-03. This patch also
preserves the plugin's JVM target of 11 using `kotlin.compilerOptions`.

The parent flake imports `lib.healthPatch`, checks the locked package version,
and applies the patch with zero fuzz while constructing its Pub cache. The
original package archive remains pinned by `pubspec.lock`; no shared Pub cache
or vendored plugin source is maintained. Changing the patch changes the Nix
cache derivation, so development preparation replaces its local cache copy.

## Remove after upstream migration

1. Inspect a published health release's Android build script: it must avoid
   applying `kotlin-android` when built-in Kotlin is enabled, and migrate legacy
   `kotlinOptions`. A merged PR alone is insufficient.
2. Upgrade health in `pubspec.yaml` and `pubspec.lock`.
3. Remove the `health-compat` input from the root `flake.nix`, its version guard
   and patch application from `nix/dependencies.nix`, and this directory.
4. Remove the child-flake formatting path from `nix/checks.nix` and update the
   root flake lock without upgrading unrelated inputs.
5. Run `nix run .#update-gradle-deps`, scoped formatting, `nix flake check`, and
   `nix build .#apk`. Verify Android startup and Health Connect permissions,
   workout imports, and calorie imports.

Do not bypass the version guard after an upgrade: remove the workaround when
unnecessary, or explicitly review and refresh it for the new package source.
