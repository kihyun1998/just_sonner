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

  testWidgets('dismissing the newest peels the deck one toast at a time', (
    tester,
  ) async {
    await pumpHarness(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Five in a row'));
    await tester.pump();
    expect(find.text('Toast 5 of 5'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Dismiss the newest'));
    await tester.pumpAndSettle();
    expect(find.text('Toast 5 of 5'), findsNothing);
    expect(find.text('Toast 4 of 5'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Dismiss the newest'));
    await tester.pumpAndSettle();
    expect(find.text('Toast 4 of 5'), findsNothing);
    expect(find.text('Toast 3 of 5'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Dismiss all'));
    await tester.pumpAndSettle();
  });

  testWidgets('dismissing the newest walks past ids whose toasts expired', (
    tester,
  ) async {
    await pumpHarness(tester);

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Stays until dismissed'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Short (1 s)'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Gone in a second'), findsNothing);
    expect(find.text('This one waits for you'), findsOneWidget);

    // The newest id the panel holds is the expired one, and nothing told it so.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Dismiss the newest'));
    await tester.pumpAndSettle();
    expect(find.text('This one waits for you'), findsNothing);
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

    // The panel grows a section per issue, so scroll the control into view
    // rather than trusting where it happens to sit today.
    await tester.ensureVisible(find.text('expandByDefault'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('expandByDefault'));
    await tester.pumpAndSettle();
    expect(find.text('Event has been created'), findsNothing);
  });
}
