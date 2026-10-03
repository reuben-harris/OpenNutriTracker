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
- Keep formatting scoped to changed files and exclude generated Dart.
