import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('renders the demo and opens the logbook panel', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Logbook Demo'), findsOneWidget);

    // Open the logbook overlay via its edge handle.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Debug console'), findsOneWidget);

    // Unmount so the demo's periodic timer and animations are disposed.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
