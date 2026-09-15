import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_sonner_example/main.dart';

/// Guards the harness itself: that its buttons are wired to a controller that
/// is drawing, so a section added here is known to be pressable before anyone
/// presses it. What the toasts then do is the package's own tests' business.
void main() {
  /// The harness is a desktop app, and at the 800x600 default the panel is one
  /// column with its later sections off screen.
  Future<void> pumpHarness(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1600, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ExampleApp());
  }

  testWidgets('a button puts a toast on screen, and it counts itself down', (
    tester,
  ) async {
    await pumpHarness(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Show a toast'));
    await tester.pump();
    expect(find.text('Event has been created'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Event has been created'), findsNothing);
  });

  testWidgets('a toast sits above a dialog', (tester) async {
    await pumpHarness(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Open a dialog'));
    await tester.pumpAndSettle();
    expect(find.text('A dialog'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Show a toast'));
    await tester.pump();
    expect(find.text('From inside the dialog'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Close'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a config control rebuilds the controller and clears the deck', (
    tester,
  ) async {
    await pumpHarness(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Show a toast'));
    await tester.pump();
    expect(find.text('Event has been created'), findsOneWidget);

    await tester.tap(find.text('expandByDefault'));
    await tester.pumpAndSettle();
    expect(find.text('Event has been created'), findsNothing);
  });
}
