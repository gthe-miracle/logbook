# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`logbook` is a Flutter package published on pub.dev: a global logger (`l`), an in-memory log buffer, a slide-in overlay that shows the logs inside the host app, and an optional CSV upload to a server. `example/` is a demo app that depends on the package by path.

## Commands

No `.fvmrc` is pinned, so `fvm` resolves to the global SDK. The package needs Flutter >= 3.47 / Dart >= 3.13.

```bash
fvm flutter pub get
fvm flutter analyze                 # also analyzes example/ with the root analysis_options.yaml
fvm flutter analyze lib test        # package only
fvm dart format .                   # 80 columns
fvm flutter test                    # whole suite
fvm flutter test test/log_buffer_test.dart
fvm flutter test test/log_buffer_test.dart --plain-name 'evicts the oldest message beyond bufferLimit'
(cd example && fvm flutter test)    # example app smoke test
pana                                # pub.dev score
```

`flutter analyze` exits non-zero on info-level lints too. `.githooks/pre-commit` (opt-in: `git config core.hooksPath .githooks`) formats the staged Dart files, then runs `fvm flutter analyze` and `pana --exit-code-threshold 0`, so any of them blocks the commit.

## Language and toolchain conventions

The code targets Dart 3.13 and uses syntax that older references do not show. It is valid here; do not rewrite it to the older form, and use it in new code:

- Constructors are declared with `new` instead of repeating the class name: `const new({required this.child, super.key});`, `new _internal();`, `factory of(BuildContext context) { ... }`. Call sites are unchanged (`LogBuffer._internal()`, `LoggerColors.of(context)`).
- A private field can be a named initializing formal: `const new({this._client});` is called as `LogbookRepositoryImpl(client: ...)`.
- Material comes from `package:material_ui/material_ui.dart`. Nothing imports `package:flutter/material.dart`; `flutter/foundation.dart` and `flutter/services.dart` still come from the SDK.

Lints that shape how code is written here (`analysis_options.yaml` has the full list):

- `public_member_api_docs`: every public member needs a `///` comment. Classes use a `{@template name}` / `{@macro name}` pair so the constructor reuses the class doc.
- `prefer_relative_imports` inside `lib/`. Tests import `package:logbook/...`, including `package:logbook/src/...` for internals.
- `prefer_expression_function_bodies`, `avoid_catches_without_on_clauses` (write `on Object catch (e, s)`), `lines_longer_than_80_chars`, `avoid_print`, plus strict casts, raw types and inference.

## Architecture

The public API is exactly what `lib/logbook.dart` exports: `l`, `Logbook` (with `LogbookState`), `LogbookConfig`, `LogBuffer`, `LogMessage`. Everything else under `lib/src` is internal.

### Log flow

`l.i/f/c/w/s/log` (`common/util/logger.dart`) adds a `LogMessage` to `LogBuffer.instance` in every build mode, then prints an ANSI-colored line through `developer.log` unless in release mode.

`LogBuffer` (`feature/logbook/log_buffer.dart`) is a process-wide singleton `ChangeNotifier` over a `Queue` capped at `bufferLimit`. The rest of the code depends on three of its properties:

- `totalLogsCount` only grows; eviction never decrements it. Consumers keep a cursor and call `logsSince(cursor)`.
- `_prefixCounts` reference-counts prefixes so `logsPrefix` stays correct under eviction. Every path that adds or removes a message must track or untrack its prefix.
- Notifications are coalesced to one per microtask.

### Viewer

`LogViewerScreen` pulls from the buffer instead of rendering it. It keeps its own list (`_activeLogMessages`) and a `_consumedLogsCount` cursor, consumes through a 300 ms `Throttling` (leading and trailing edge, so the tail of a burst is never dropped), and stops consuming while the panel is closed, catching up on open. Two consequences: the trash button clears the view's list and never the buffer, and a closed panel does no work.

Filter state is a `ValueNotifier<Set<String>>` of real prefixes. "All" is derived, never stored; an empty selection is unreachable; sets are replaced rather than mutated so the notifier fires. Until the user touches the filter (`_filterInteracted`), newly seen prefixes are selected automatically.

### Overlay widget

`Logbook.config` is a static `ValueNotifier`, so configuration is process-global: the constructor's `config` only seeds it in `initState`, and the setter also pushes `bufferLimit` into `LogBuffer`. This is why only one `Logbook` may be mounted.

`_LogbookState.build` must produce the same tree shape whether `enabled` is true or false, so `widget.child` keeps its element slot. Otherwise toggling `enabled` re-inflates the host app and resets its state (a widget test guards this). The panel brings its own `Theme`, `Navigator` and `ScaffoldMessenger`, and adds `Directionality` / `Localizations` fallbacks so it works both inside `MaterialApp.builder` and above `MaterialApp`.

Stateful widgets are split across two files: `foo.dart` holds the widget and a private `_FooState` containing only `build`; `foo_state.dart` is a `part` with the abstract `FooState` holding fields, handlers and lifecycle.

### Upload

`Logbook.sendLogsToServer()` → `LogBuffer.sendLogsToServer` → `toCSVString()` (`common/util/log_message_to_csv.dart`: `compute` from 1000 rows, BOM for Excel, formula-injection escaping, ISO-8601 UTC timestamps) → `ILogbookRepository.sendLog` (multipart POST with the file under the `document` field, 30 s timeout, non-2xx throws). Failures are caught, logged with `l.s`, and returned as `false`.

### Colors

Built-in prefixes `F C I W S` map through `ConsoleColor` to `LoggerColors`, a `ThemeExtension` with light and dark defaults. Any other prefix is hashed (FNV-1a, written to give the same result on web and VM) into `kPrefixPalette`. The palette is append-only: reordering or removing entries changes the color of existing prefixes. `colorForPrefix` (viewer) and `ansiForegroundForPrefix` (console) are parallel mappings and must change together.

## Tests

- State is global, so each test file resets it in `setUp`: `LogBuffer.instance.debugReset()`, plus `Logbook.config = const LogbookConfig()` in widget tests.
- Widget tests must pump past the 300 ms slide animation and the 300/500 ms throttle windows, or they fail on pending timers. Follow the `openPanel` helper in `test/widget/`.
- Log rows are `Text.rich`; find them with `find.textContaining(text, findRichText: true)`.
- Replace the upload backend with `LogBuffer.instance.repository = <fake ILogbookRepository>`, or test HTTP handling with `LogbookRepositoryImpl(client: MockClient(...))`. Timer-driven code such as `Throttling` is tested with `fake_async`.

## Docs that follow the code

`README.md` (install snippet, config table, API reference) and `CHANGELOG.md` document the public API and every `LogbookConfig` default. A change to the public API, a default, or the `pubspec.yaml` version needs the matching edit in both.
