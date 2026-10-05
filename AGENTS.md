# AGENTS.md

OpenNutriTracker is an Android Flutter app developed on x86_64 Linux with Nix.

## Workflow

- `nix run .#emulator` creates and launches the project AVD.
- `nix run .#run` prepares dependencies, generates code, and starts development.
- `nix run .#format` formats changed/new authored Dart and Nix files against HEAD.
- `nix flake check` validates localization, analysis, existing tests, and Nix style.
- `nix build .#apk` builds the sandboxed develop debug APK.
- `nix develop` provides tools for editor integration and direct diagnostics.
- Refresh `android/gradle.lock` with `nix run .#update-gradle-deps` after changing
  Flutter, Android plugins, or native dependencies. Do not upgrade implicitly.
- `nix flake update` deliberately updates Nix inputs.

Use [Scoped Commits](https://scopedcommits.com/): `<scope>: <description>`, with a
subsystem scope such as `nix`, `android`, or `settings`. Never add assistant
attribution, assistant names, or AI co-author trailers.

## App conventions

- English UI strings live in `lib/l10n/intl_en.arb`. Reuse existing keys before
  introducing another wording. Preserve placeholder metadata.
- Never edit generated code by hand. Hive/JSON `*.g.dart` adapters and
  `lib/hive_registrar.g.dart` are tracked; `lib/generated/` is ignored.
- Preserve Hive type and field IDs. Retired IDs remain unused; never renumber
  unrelated fields. Regenerate adapters when changing annotated models.
- `locator<T>()` on a factory registration creates a fresh instance: it does not
  return an existing screen's state.
- Give new interactive widgets stable kebab-case `Semantics(identifier: ...)`.
  Label dynamic list surfaces; ordinary Material dialog actions need no wrapper.
  Avoid duplicating roles already supplied by widgets. Use `container: true`
  only where layout requires it and verify tight bounds on Android.
- Constrain Row titles with Expanded, bounded lines, and ellipsis; use AutoSizeText
  for prominent titles. Avoid Flexible titles competing with a Spacer.
- Prefix catalogue food `code` values with `<datasource>:<id>` when adding new food 
  databases to prevent ID collisions.
  Keep `isCatalogueFood` and catalogue lookup parsing in sync with new prefixes.
- Keep formatting scoped to changed files and exclude generated Dart.

## Documentation

- Do not add or create additional documentation unless explicitly requested.
  Update existing documentation references only when the changed surface
  requires it.

## Known tooling issues

- Flutter 3.47.4's Built-in Kotlin warning detector scans build-file text. It can
  name `flutter_image_compress_common`, `flutter_timezone`, and `sentry_flutter`
  even when their conditional KGP declarations are skipped. These warnings were
  verified as false positives on the migrated toolchain: no Android KGP plugins
  were actually applied. Check Gradle's evaluated plugin containers before
  treating these warnings as incompatibilities. Keep nixpkgs Flutter unpatched
  for these warnings. Track [Flutter #189770](https://github.com/flutter/flutter/issues/189770);
  [PR #190339](https://github.com/flutter/flutter/pull/190339) was closed without
  merging. Recheck this note when Flutter or the affected plugins change.
