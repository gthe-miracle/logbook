import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logbook/logbook.dart';
import 'package:logbook/src/feature/data/logbook_repository.dart';

void main() {
  setUp(() {
    LogBuffer.instance.debugReset();
    Logbook.config = const LogbookConfig(enabled: true);
  });

  Widget app({LogbookConfig config = const LogbookConfig(enabled: true)}) =>
      Logbook(
        config: config,
        child: const MaterialApp(home: Scaffold(body: SizedBox.expand())),
      );

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    // Finish the slide-in animation, then the auto-scroll animation and the
    // throttle windows so no timers are left pending.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 600));
  }

  Finder logRow(String text) => find.textContaining(text, findRichText: true);

  group('filtering', () {
    testWidgets('deselecting a prefix hides its logs', (tester) async {
      l
        ..i('info message')
        ..w('warning message');

      await tester.pumpWidget(app());
      await openPanel(tester);

      expect(logRow('info message'), findsOneWidget);
      expect(logRow('warning message'), findsOneWidget);

      // Open the filter overlay and deselect 'W'.
      await tester.tap(find.byIcon(Icons.filter_list_rounded));
      await tester.pump();
      await tester.tap(find.text('W'));
      await tester.pump();

      expect(logRow('info message'), findsOneWidget);
      expect(logRow('warning message'), findsNothing);
    });

    testWidgets('deselecting the last prefix snaps back to all', (
      tester,
    ) async {
      l
        ..i('info message')
        ..w('warning message');

      await tester.pumpWidget(app());
      await openPanel(tester);

      await tester.tap(find.byIcon(Icons.filter_list_rounded));
      await tester.pump();
      await tester.tap(find.text('W'));
      await tester.pump();
      await tester.tap(find.text('I'));
      await tester.pump();

      // Empty selection is unreachable — everything is selected again.
      expect(logRow('info message'), findsOneWidget);
      expect(logRow('warning message'), findsOneWidget);
    });

    testWidgets('the All row selects every prefix', (tester) async {
      l
        ..i('info message')
        ..w('warning message');

      await tester.pumpWidget(app());
      await openPanel(tester);

      await tester.tap(find.byIcon(Icons.filter_list_rounded));
      await tester.pump();
      await tester.tap(find.text('W'));
      await tester.pump();
      expect(logRow('warning message'), findsNothing);

      await tester.tap(find.text('All'));
      await tester.pump();
      expect(logRow('warning message'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('filters rows by the debounced query', (tester) async {
      l
        ..i('alpha event')
        ..i('beta event');

      await tester.pumpWidget(app());
      await openPanel(tester);

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'alpha');
      await tester.pump(const Duration(milliseconds: 250));

      expect(logRow('alpha event'), findsOneWidget);
      expect(logRow('beta event'), findsNothing);
    });
  });

  group('clear', () {
    testWidgets('clears the view but keeps the buffer', (tester) async {
      l.i('to be cleared');

      await tester.pumpWidget(app());
      await openPanel(tester);
      expect(logRow('to be cleared'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline_outlined));
      await tester.pump();

      expect(logRow('to be cleared'), findsNothing);
      expect(LogBuffer.instance.logs, isNotEmpty);
    });
  });

  group('send to server', () {
    testWidgets('shows a hint when no uri is configured', (tester) async {
      await tester.pumpWidget(app());
      await openPanel(tester);

      await tester.tap(find.byIcon(Icons.upload_file));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('Sending log to server is not enabled'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows a failure snack bar when the upload fails', (
      tester,
    ) async {
      LogBuffer.instance.repository = _ThrowingRepository();

      await tester.pumpWidget(
        app(
          config: LogbookConfig(
            enabled: true,
            uri: Uri.parse('https://example.com/upload'),
          ),
        ),
      );
      await openPanel(tester);

      await tester.tap(find.byIcon(Icons.upload_file));
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('Failed to send logs to the server'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sends successfully without user-facing errors', (
      tester,
    ) async {
      final repository = _RecordingRepository();
      LogBuffer.instance.repository = repository;
      l.i('to upload');

      await tester.pumpWidget(
        app(
          config: LogbookConfig(
            enabled: true,
            uri: Uri.parse('https://example.com/upload'),
            debugFileName: 'session.csv',
          ),
        ),
      );
      await openPanel(tester);

      await tester.tap(find.byIcon(Icons.upload_file));
      await tester.pump();
      await tester.pump();

      expect(repository.sentFileNames, ['session.csv']);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}

final class _ThrowingRepository implements ILogbookRepository {
  @override
  Future<void> sendLog(
    Uri uri,
    List<int> bytes, {
    required String fileName,
    Map<String, String>? fields,
  }) async {
    throw Exception('upload failed');
  }
}

final class _RecordingRepository implements ILogbookRepository {
  final List<String> sentFileNames = [];

  @override
  Future<void> sendLog(
    Uri uri,
    List<int> bytes, {
    required String fileName,
    Map<String, String>? fields,
  }) async {
    sentFileNames.add(fileName);
  }
}
