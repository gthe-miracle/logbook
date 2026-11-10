# 📚 Logbook

A powerful, elegant, and developer-friendly logging package for Flutter applications. Logbook provides an intuitive overlay UI for viewing logs in real-time, with support for different log levels, color coding, and optional server integration for remote debugging.

<div style="display: flex; flex-direction: row; flex-wrap: wrap; gap: 10px;">
  <img src="https://github.com/Miracle-Blue/logbook/raw/main/screenshots/screenshot_1.png" width="180" alt="Logbook Overview">
  <img src="https://github.com/Miracle-Blue/logbook/raw/main/screenshots/screenshot_2.png" width="180" alt="Logbook filter">
  <img src="https://github.com/Miracle-Blue/logbook/raw/main/screenshots/screenshot_3.png" width="180" alt="Logbook filter">
  <img src="https://github.com/Miracle-Blue/logbook/raw/main/screenshots/screenshot_4.png" width="180" alt="Logbook search">
</div>

## ✨ Features

- 🎨 **Comprehensive UI Overlay** - Slide-in panel with color-coded logs
- 📊 **Multiple Log Levels** - Fine, Config, Info, Warning, Severe, and Custom
- 🔍 **Real-Time Viewing** - See logs as they happen in your app
- 📱 **Server Integration** - Send logs to your server for remote debugging in CSV format
- 🚀 **Lightweight** - Near-zero cost while the panel is closed
- 🔧 **Configurable** - Enable/disable and reconfigure at runtime
- 📦 **Minimal Dependencies** - Only depends on the Flutter SDK, `material_ui` and `http`

---

## 📦 Installation

Add `logbook` to your `pubspec.yaml`:

```yaml
dependencies:
  logbook: ^1.0.0
```

Then run:

```bash
flutter pub get
```

Logbook 1.x requires Flutter >= 3.47.0 and Dart >= 3.13.0, and builds on
[`material_ui`](https://pub.dev/packages/material_ui) instead of
`package:flutter/material.dart`. Apps still on `package:flutter/material.dart`
should use `logbook: ^0.6.1`.

---

## 🚀 Quick Start

### 1. Wrap Your App

Wrap your app with the `Logbook` widget, preferably via `MaterialApp.builder`:

```dart
import 'package:logbook/logbook.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      home: const HomePage(),
      builder: (context, child) => Logbook(
        config: const LogbookConfig(enabled: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
```

Only mount one `Logbook` at a time — its configuration is process-global.

### 2. Start Logging

Use the global `l` instance to log messages:

```dart
import 'package:logbook/logbook.dart';

void someFunction() {
  l.i('This is an info message');
  l.w('This is a warning');
  l.f('This is a fine (debug) message');
}
```

### 3. View Logs

Tap the small overlay handle on the side of your screen to open the log viewer — or open it programmatically:

```dart
Logbook.stateOf(context).open(); // also: .close(), .toggle(), .isOpen
```

> The trash button in the viewer clears the **view only** — the underlying
> buffer keeps its logs, so a later "send to server" still uploads the full
> history. Use `LogBuffer.instance.clear()` to drop the buffer itself.

---

## 📖 Basic Usage

### Log Types

Logbook provides several log types, each with its own color and purpose:

```dart
// Fine - Detailed debugging information
l.f('User data loaded: ${user.name}');

// Config - Configuration information (Green)
l.c('API endpoint: https://api.example.com');

// Info - General information messages (Blue in console)
l.i('User logged in successfully');

// Warning - Potential issues (Yellow); the reason is appended to the message
l.w('Network latency is high', StackTrace.current, 'Performance Issue');

// Severe - Errors and exceptions (Red)
l.s('Failed to load data', StackTrace.current, 'API Error');

// Custom - Your own log type, with a stable per-prefix color
l.log('Custom event occurred', 'CUSTOM');
```

### Error Handling

Perfect for catching and logging exceptions:

```dart
try {
  await someRiskyOperation();
} catch (e, stackTrace) {
  l.s('Operation failed: $e', stackTrace);
}
```

### Global Error Handler

Catch all uncaught errors in your app:

```dart
import 'dart:async';
import 'package:logbook/logbook.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  runZonedGuarded(
    () => runApp(const MyApp()),
    (error, stackTrace) {
      l.s('Uncaught error: $error', stackTrace);
    },
  );
}
```

### Send Logs to Server

Send the buffered logs to your server as a CSV multipart upload (uses the
current `Logbook.config`). Returns `true` on success:

```dart
final success = await Logbook.sendLogsToServer();
```

The file is posted as `multipart/form-data` under the `document` field,
with `multipartFileFields` added as regular form fields. Requests time out
after 30 seconds, and non-2xx responses are treated as failures.

### Runtime Configuration

The constructor config seeds the initial value; you can read or replace it at
any time and the overlay updates live:

```dart
Logbook.config = Logbook.config.copyWith(themeMode: ThemeMode.dark);

// React to changes:
Logbook.configListenable.addListener(() => print(Logbook.config));
```

---

## ⚙️ Configuration

### LogbookConfig

Configure Logbook behavior with `LogbookConfig`:

```dart
Logbook(
  config: LogbookConfig(
    enabled: kDebugMode,                        // Show overlay only in debug mode
    debugFileName: 'app_logs.csv',              // CSV export filename
    uri: Uri.parse('https://your.server/logs'), // Optional: server URI
    multipartFileFields: {'caption': '#logs'},  // Optional: extra form fields
    fontFamily: 'FreeMono',                    // Optional: font family
    themeMode: ThemeMode.system,                // Optional: overlay theme
    bufferLimit: 32768,                         // Optional: max buffered logs
  ),
  child: child ?? const SizedBox.shrink(),
)
```

#### Parameters

| Parameter             | Type                   | Default            | Description                                                                                     |
| --------------------- | ---------------------- | ------------------ | ----------------------------------------------------------------------------------------------- |
| `enabled`             | `bool`                 | `kDebugMode`       | Show/hide the logbook overlay (log collection continues either way)                             |
| `debugFileName`       | `String`               | `'debug_info.csv'` | Filename for CSV exports to the server                                                          |
| `uri`                 | `Uri?`                 | `null`             | Server URI for remote logging                                                                   |
| `multipartFileFields` | `Map<String, String>?` | `null`             | Extra multipart form fields for remote logging                                                  |
| `fontFamily`          | `String`               | `'FreeMono'`      | Viewer font; takes effect only if your app bundles a font family with this name                 |
| `themeMode`           | `ThemeMode`            | `ThemeMode.system` | Overlay theme (light, dark, or follow the system); `ThemeMode` comes from `material_ui`         |
| `bufferLimit`         | `int`                  | `32768`            | Max log messages kept in memory (oldest evicted) — applies in release builds too                |

---

## 📱 Example App

Check out the [example](./example) directory for a complete working app showcasing all features:

```bash
cd example
flutter run
```

The example app demonstrates:

- All log types
- Async operations logging
- Error handling
- Background timer logs
- Runtime config changes (live theme toggle)

---

## 🛠️ API Reference

### Global Logger (`l`)

```dart
// Info log
l.i(Object? message);

// Fine/Debug log
l.f(Object? message);

// Config log
l.c(Object? message);

// Warning log (reason is appended to the stored message)
l.w(Object exception, [StackTrace? stackTrace, String? reason]);

// Severe/Error log
l.s(Object exception, [StackTrace? stackTrace, String? reason]);

// Custom log
l.log(Object message, String prefix, {
  StackTrace? stackTrace,
  bool withMilliseconds = false,
});
```

### Logbook

```dart
Logbook.config;                    // Current LogbookConfig (get/set, live)
Logbook.configListenable;          // ValueListenable<LogbookConfig>
Logbook.stateOf(context).open();   // Programmatic panel control
await Logbook.sendLogsToServer();  // Future<bool>
```

### LogBuffer

```dart
LogBuffer.instance.logs;            // Iterable<LogMessage> (oldest first)
LogBuffer.instance.logsPrefix;      // Distinct prefixes currently buffered
LogBuffer.instance.clear();         // Drop all buffered logs
LogBuffer.instance.add(logMessage); // Add your own LogMessage
```

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  If you find this package useful, give it a ⭐ on <a href="https://github.com/Miracle-Blue/logbook">GitHub</a>!
</p>
