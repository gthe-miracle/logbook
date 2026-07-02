## 0.6.0

### Fixed

- The viewer no longer misses the tail of a log burst: the internal throttle now runs a trailing pass, so logs arriving during the throttle window always appear
- Logs recorded before the `Logbook` widget mounts (e.g. in `main()` before `runApp`) are now visible immediately instead of waiting for the next log
- Toggling `Logbook.config.enabled` at runtime no longer re-inflates the app subtree (which reset navigation/form state when `Logbook` wrapped `MaterialApp` directly); the widget also works above `MaterialApp` now by providing its own `Directionality`/`Localizations` fallbacks
- Server upload hardening: 30-second timeout, non-2xx responses are treated as failures, and the response body is no longer blindly `json.decode`d (a plain-text "OK" used to be reported as an error)
- `l.w`/`l.s` no longer silently discard the documented `reason` parameter — it is appended to the message
- Filter fixes: the selection state notifier now actually notifies (sets are replaced, not mutated); the "All" checkbox state is derived, so deselecting one prefix un-checks it; deselecting the last prefix snaps back to "everything selected"; the filter list live-updates when new prefixes arrive while it is open
- Auto-scroll no longer sticks off after programmatic scrolls; only user drags pause it, and reaching the bottom (within 1px) resumes it
- Milliseconds are padded to three digits with a `.` separator (`12:00:05.007`); CSV exports use full ISO-8601 UTC timestamps, so multi-day exports are unambiguous
- CSV escaping handles `\r`, and cells starting with `=`, `+`, `-`, `@` are prefixed with `'` to neutralize spreadsheet formula injection
- `LogbookConfig.==`/`hashCode` contract fixes (deep map comparison both ways; comparing against non-config values returns false instead of throwing)
- Custom-prefix colors are now identical on web and VM (overflow-safe FNV-1a hash)
- Various lifecycle fixes: `mounted` guard after the upload `await`, `ValueNotifier` disposals, filter overlay entry removal/disposal on panel close and dispose
- `LogBuffer.addAll` keeps the newest entries of an oversized batch instead of the oldest

### Changed

- **Breaking:** `Logbook.sendLogsToServer()` and `LogBuffer.sendLogsToServer(...)` now return `Future<bool>` (true on success); upload failures show a SnackBar in the viewer
- **Breaking:** `LogbookState` no longer exposes `dismissed` and the drag handlers; use the new `open()`, `close()`, `toggle()` and `isOpen` instead
- **Breaking:** `LogMessage.timestamp` is now the raw `DateTime` (formatted string moved to `formattedTime`); the unused `color` field was removed
- Default in-memory buffer limit lowered from 65,536 to 10,000 messages and made configurable via `LogbookConfig.bufferLimit` (applies in release builds too)
- The closed panel no longer does any filtering/layout work — log consumption pauses while hidden and catches up on open
- Log rows use a shared `SelectionArea` (cross-row copy now works) instead of one `SelectableText` per row
- Opening search no longer overwrites the active prefix filter; the search field has a hint; the clear button documents that it clears the view only

### Added

- `Logbook.stateOf(context).open()/close()/toggle()/isOpen` for programmatic panel control
- `LogBuffer` and `LogMessage` are exported (the README already documented them)
- Test suite covering the buffer, throttling, logger, CSV export, config, repository (with mock HTTP), and the widget/viewer flows

### Security

- Removed a hardcoded Telegram bot token from the example app — **if you forked this repo, revoke that token via @BotFather**; treat it as compromised

## 0.5.5

- **Breaking:** `Logbook.sendLogsToServer()` no longer takes a `BuildContext` argument — call it with no parameters; it sends using the current `Logbook.config`

## 0.5.4

- `Logbook.sendLogsToServer` no longer requires a `Logbook` widget to be in scope; it sends using the current (possibly runtime-updated) config

## 0.5.3

- Config can now be changed at runtime via `Logbook.config` (get/set) and observed with `Logbook.configListenable`; the overlay updates live (theme, font, `enabled`, server settings)
- The `Logbook(config: ...)` constructor is unchanged, but the widget's instance `config` field is now private — read the static `Logbook.config` instead

## 0.5.2

- Custom `l.log` prefixes now each render in their own stable, dark-friendly color instead of all magenta
- The per-prefix color is shown consistently in both the console (24-bit color) and the in-app log viewer

## 0.5.1

- Replaced PopupMenuButton filter with a custom overlay-based filter panel
- Replaced raw `Isolate.spawn` with `compute` for CSV generation
- Updated `http` dependency to ^1.6.0

## 0.5.0

- Multi-select log filter with checkboxes and "All" toggle (replaces single-select)
- Scroll-to-bottom floating action button

## 0.4.0

- Added clear logs feature

## 0.3.3

- Log view changed

## 0.3.2

- Pub score fixed

## 0.3.1

- Pub score fixed

## 0.3.0

- Added sendLogsToServer method to Logbook class
- Added throttling for scroll to bottom
- Pub score fixed

## 0.2.1

- Package logo added

## 0.2.0

- Added theme mode support - allows customizing the logbook theme (light, dark, or system)
- Added automatic scroll to bottom when new logs arrive (unless user has scrolled up)
- Added copyWith method for LogbookConfig class

## 0.1.5

- Pub score fixed (The local variable '\_timePad' starts with an underscore)

## 0.1.4

- Error log fixed

## 0.1.3

- Pub score fixed

## 0.1.2

- logs fontSize changed to 11
- add functionality to change font family

## 0.1.1

- Pub score fixed

## 0.1.0

- Initial stable release

## 0.0.1

- Initial release.
