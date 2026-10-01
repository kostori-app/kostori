# AGENTS.md

Flutter anime streaming app (GPL-3.0). Forked from Venera; video/UI patterns from Kazumi, Bangumi, animeko.

## Toolchain

- Flutter `3.47.2`, Dart `>=3.13.2 <4.0.0` (pinned in `pubspec.yaml`; CI uses `flutter-version-file`). Don't assume newer Flutter.
- State management is mixed: MobX (`with Store` + `@observable`, codegen) in older controllers, Riverpod (manual providers) elsewhere. There is no `flutter_modular` dependency. Check neighboring files before choosing.
- DB: drift (codegen) + raw sqlite3. i18n: slang. Models: freezed + json_serializable.

## Codegen (mandatory)

After editing drift tables/DAOs (`lib/database/`), MobX stores (`with Store`), or `@freezed`/`@JsonSerializable` models, regenerate:

```
dart run build_runner build
```

After editing i18n `.i18n.yaml` files, regenerate with slang (build_runner does not handle these):

```
dart run slang
```

Generated `*.g.dart` / `*.freezed.dart` / `lib/i18n/strings.g.dart` are committed — regenerate and commit them, don't hand-edit.

## Commands

- `flutter pub get`
- `dart format lib test` — **CI fails on unformatted code** (`--set-exit-if-changed`); run before finishing.
- `flutter test` — tests in `test/` (widget + unit).
- `flutter analyze` — analyzer gate; `analysis_options.yaml` excludes platform dirs (`android/`, `ios/`, …).
- Build: `flutter build apk --release` / `flutter build windows` / `dart run msix:create`.
- Android build needs a Rust toolchain for native deps (CI runs `rustup show` first).

CI order (`.github/workflows/analyze.yml`): `flutter pub get` → format check → `flutter test` → dart analyze. `main.yml` builds APK/Windows on GitHub Release; `fastlane.yml` validates store metadata.

## Conventions

- Imports use `package:kostori/...`, never relative (`always_use_package_imports: true`).
- All user-facing strings go through slang (`lib/i18n/*.i18n.yaml`); don't hardcode UI text.
- Code comments are mostly Chinese.
- Commits use Conventional Commits types from `.versionrc.js` (`feat`/`fix`/`perf`/`refactor`/…).

## UI 组件复用（强制）

Full catalog + Material→project mapping lives in `docs/components.md` (auto-loaded via `opencode.json` `instructions`). Reuse existing widgets instead of Flutter/Material defaults:

- General import: `package:kostori/components/components.dart` (some files, e.g. `ui_components.dart`, `bangumi_widget.dart`, `empty_state.dart`, need their own import — see the doc).
- Toast/提示 → `context.showMessage` (not `SnackBar`); dialogs → `ContentDialog.show` / `show*Dialog` (not `AlertDialog`/`showDialog`); bottom sheet → `Sheet`; app bar → `Appbar`/`SliverAppbar`; buttons → `Button`/`CapsuleButton`; dropdown → `Select`; toggle → `CustomSwitch`; loading → `PolygonRefreshIndicator`; images → `AnimatedImage`/`KostoriHero`; empty → `EmptyState`.
- Navigation → `context.to` / `context.toSheet` / `context.toBlurFade` (not `Navigator.push` + `MaterialPageRoute`). Strings → `context.t.xxx`.
- Put new reusable UI in `lib/components/`, not inside page folders.

## Gotchas

- `@riverpod` codegen is **disabled** (`riverpod_generator` commented out in `pubspec.yaml`); write Riverpod providers manually, don't add `@riverpod`.
- Many deps are git refs pinned by commit (`desktop_webview_window`, `flutter_inappwebview`, `flutter_qjs`, `flutter_saf`, …). Don't run `flutter pub upgrade` or change refs without reason.
- `dependency_overrides` are intentional: `intl` forced to `0.20.3` (comment in `pubspec.yaml`), `super_native_extensions` from git `main`, forked `dtorrent_task_v2`. Don't remove.
- `analysis_options.yaml` relaxes several lints (`use_build_context_synchronously`, `avoid_print`, `library_private_types_in_public_api`).

## Structure

- `lib/main.dart` entry; `lib/init.dart` startup wiring (called once from `main`); `lib/headless.dart` CLI/server mode.
- Headless CLI: `--headless` plus `--service hub|headless`, `--port`, `--bind`, `--no-auth`, `--cert`/`--key`, fixed `--api-key`/`--admin-key`, `--lang zh_cn|zh_tw|en|system` (or `KOSTORI_LANG`, default `zh_cn`). Emits `[CLI PRINT] <json>` lines. LAN remote control is app-UI-only: it drives the on-device player, so it has no headless mode.
- `lib/foundation/` core services (`ai_service`, `anime_source`, `audio_service`, `bangumi`, `hub_services`, `me_plugin`, `translation`, `image_loader`, `webview`).
- `lib/pages/` one folder per feature. `lib/network/` dio/rhttp + cookie jar + Cloudflare bypass. `lib/database/` drift DBs + DAOs. `lib/services/` download + torrent. `lib/skills/` AI skills (builtins registered in `init.dart`). `lib/components/` shared UI. `lib/utils/` helpers.
- `lib/repositories/` data layer (currently only `ai_repository.dart`).

## Notes

- Danmaku is intentionally out of scope (see `README.md`).
- Version is `X.Y.Z+<build>` in `pubspec.yaml` (`+130` = Android versionCode).
