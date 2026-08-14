# AGENTS.md

Flutter anime streaming app (GPL-3.0). Forked from Venera; video/UI patterns from Kazumi, Bangumi, animeko.

## Toolchain

- Flutter `3.47.0`, Dart `>=3.8.0 <4.0.0` (pinned in `pubspec.yaml`; CI uses `flutter-version-file`). Don't assume newer Flutter.
- State management is mixed: MobX + flutter_modular (older code) and Riverpod (newer). Check neighboring files before choosing.
- DB: drift (codegen) + raw sqlite3. i18n: slang. Models: freezed + json_serializable.

## Codegen (mandatory)

After editing drift tables/DAOs (`lib/database/`), MobX stores, `@freezed`/`@JsonSerializable` models, or i18n `.i18n.yaml` files, regenerate:

```
dart run build_runner build --delete-conflicting-outputs
```

Generated `*.g.dart` files are committed to the repo.

## Commands

- `flutter pub get`
- `flutter analyze` — the CI gate (`.github/workflows/analyze.yml`). There are no real tests (`test/widget_test.dart` is empty); verify changes with analyze + build.
- Build: `flutter build apk --release` / `flutter build windows` / `dart run msix:create` (Windows MSIX).
- Building may need a Rust toolchain for native deps (CI runs `rustup show` before the Android build).

## Conventions

- Imports use `package:kostori/...`, never relative (`always_use_package_imports: true`).
- All user-facing strings go through slang (`lib/i18n/*.i18n.yaml`); don't hardcode UI text.
- Code comments are mostly Chinese.

## Gotchas

- Many deps are git refs pinned by commit (`desktop_webview_window`, `flutter_inappwebview`, `flutter_qjs`, `flutter_saf`, …). Don't run `flutter pub upgrade` or change refs without reason.
- `dependency_overrides` are intentional: `intl` forced to `0.20.3` (see comment in `pubspec.yaml`); `super_native_extensions` from git `main`. Don't remove.
- `analysis_options.yaml` relaxes several lints (`use_build_context_synchronously`, `avoid_print`, `library_private_types_in_public_api`).

## Structure

- `lib/main.dart` entry; `lib/init.dart` startup wiring; `lib/headless.dart` headless/CLI mode (`--headless`, emits `[CLI PRINT]` JSON lines).
- `lib/foundation/` core services (`ai_service`, `anime_source`, `audio_service`, `bangumi`, `hub_services`, `me_plugin`, `translation`).
- `lib/pages/` one folder per feature. `lib/network/` dio/rhttp + cookie jar + Cloudflare bypass. `lib/database/` drift DBs + DAOs. `lib/skills/` built-in AI skills (registered in `init.dart`).
- `lib/repositories/` data layer (currently `ai_repository.dart`).

## Notes

- Danmaku is intentionally out of scope.
- Version is `X.Y.Z+<build>` in `pubspec.yaml` (`+130` = Android versionCode).
