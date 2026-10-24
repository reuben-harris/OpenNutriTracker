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

## Architecture and reuse

- Treat this as a new app. Design changes around the intended final
  architecture, as if designing the affected feature from scratch.
  Update callers directly and remove obsolete code. Backwards compatibility
  is not required unless explicitly requested, including compatibility with
  older database schemas. Do not add compatibility adapters, deprecated
  aliases, legacy branches, or database migrations solely to preserve an
  older implementation.

- Keep the current database schema internally consistent. Hive type and
  field IDs may change as part of an intentional schema redesign; preserving
  previously stored development data is not required. Regenerate annotated
  adapters when changing models, and never edit generated code by hand.

- Build one reusable implementation for UI structure and behavior shared
  across features. Centralize repeated layout, spacing, image loading,
  loading feedback, and interaction patterns.
  Feature components should supply their specific content and actions.

- Keep shared primitives focused and compose them into reusable components.
  Create abstractions around existing repeated patterns or an identified
  next consumer. Retain feature wrappers when they assemble meaningful
  feature content or behavior; remove wrappers that only preserve an old
  name or forward arguments

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

## Food databases

- Preserve the complete datasource: keep original source archives unchanged and
  retain full published food records, including nutrients the app does not yet
  display, original values and precision, units, measurement bases, food metadata,
  portions, and provenance. Retain supporting records as well.
  We keep this information so future features can expose more of a datasource
  without reconstructing discarded data or repeating source review. Filtering
  imports to today's UI adds maintenance work and can discard context needed to
  interpret values correctly.

- Keep published source records separate from the app's nutrition projection.
  Make nutrient selection and unit conversions explicit. Missing values are not
  zero; retain qualifiers such as trace or detection limits. Similarly named
  nutrients and different measurement bases are not automatically interchangeable.
  This preserves source fidelity while allowing the app's supported fields to
  evolve.

- Give each database independently managed pins, import logic, mappings, release
  discovery, repairs, and tests. Share fetching, catalogue writing, indexing, and
  validation where behavior is common. A database must be independently
  updateable or removable without changing another database's pins or rebuilding
  its source package.

- Use the existing per-source manifests and Nix fetchers for official, pinned
  releases. Validate candidates before updating pins. Nix makes downloads and
  builds reproducible; a CSV added as a non-flake input would still require
  source-specific parsing, nutrient mapping, validation, and reviewed repairs.

- Guard reviewed parsing exceptions and repairs with the exact
  affected source pin and reviewed record conditions; never carry them
  automatically to another release. Source defects differ between formats and
  releases, so broad repair rules can silently corrupt otherwise valid data.

- Prefix catalogue food codes with `<datasource>:<id>` and namespace other
  source-local identities. Keep catalogue classification and lookup consistent.
  Do not merge foods from different databases solely because names match: their
  preparation, sampling, nutrient definitions, and values may differ.

- Register source names, releases, attribution, website, and applicable terms
  through shared source descriptors. Use them for database settings, result
  labels, and Sources & References. Check each source's reuse terms; do not assume
  another database's permissions apply.

- Cover source completeness, precision, units, missing versus zero values,
  portions, provenance, reviewed exceptions, deterministic output, and independent
  updates with regression tests. Adding a database should extend the shared
  catalogue rather than introduce another app-specific search implementation.

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
