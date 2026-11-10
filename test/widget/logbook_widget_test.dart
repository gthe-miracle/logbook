import 'package:flutter_test/flutter_test.dart';
import 'package:logbook/logbook.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUp(() {
    LogBuffer.instance.debugReset();
    Logbook.config = const LogbookConfig();
  });

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    // Finish the slide-in animation, then the auto-scroll animation and the
    // throttle windows so no timers are left pending.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('Logbook', () {
    testWidgets('toggling enabled at runtime preserves the app state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Logbook(child: MaterialApp(home: _CounterPage())),
      );

      await tester.tap(find.text('increment'));
      await tester.pump();
      expect(find.text('count: 1'), findsOneWidget);

      Logbook.config = Logbook.config.copyWith(enabled: false);
      await tester.pump();
      expect(find.text('count: 1'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      Logbook.config = Logbook.config.copyWith(enabled: true);
      await tester.pump();
      expect(find.text('count: 1'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('the handle opens and closes the panel', (tester) async {
      await tester.pumpWidget(
        const Logbook(child: MaterialApp(home: _CounterPage())),
      );

      expect(find.text('Debug console'), findsNothing);

      await openPanel(tester);
      expect(find.text('Debug console'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Debug console'), findsNothing);
    });

    testWidgets('logs recorded before mount are shown', (tester) async {
      l.i('early bird message');

      await tester.pumpWidget(
        const Logbook(child: MaterialApp(home: _CounterPage())),
      );
      await openPanel(tester);

      expect(
        find.textContaining('early bird message', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('logs arriving while closed appear on open', (tester) async {
      await tester.pumpWidget(
        const Logbook(child: MaterialApp(home: _CounterPage())),
      );
      await tester.pump();

      l.i('logged while closed');
      await tester.pump();

      await openPanel(tester);
      expect(
        find.textContaining('logged while closed', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('stateOf opens the panel programmatically', (tester) async {
      await tester.pumpWidget(
        const Logbook(child: MaterialApp(home: _CounterPage())),
      );

      final context = tester.element(find.byType(_CounterPage));
      Logbook.stateOf(context).open();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Debug console'), findsOneWidget);
      expect(Logbook.stateOf(context).isOpen, isTrue);
    });

    testWidgets('stateOf throws a descriptive error out of scope', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: _CounterPage()));

      final context = tester.element(find.byType(_CounterPage));
      expect(() => Logbook.stateOf(context), throwsFlutterError);
    });
  });
}

class _CounterPage extends StatefulWidget {
  const new();

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('count: $_count'),
          TextButton(
            onPressed: () => setState(() => _count++),
            child: const Text('increment'),
          ),
        ],
      ),
    ),
  );
}
