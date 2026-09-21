import 'package:flash/flash.dart';
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

    // Pumped past the 200 ms exit by hand: the toasts left are counting down
    // and draw their time left on every frame, so nothing settles.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Dismiss the newest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Toast 5 of 5'), findsNothing);
    expect(find.text('Toast 4 of 5'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Dismiss the newest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
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

    // The panel grows a section per issue, so scroll the button into view
    // rather than trusting where it happens to sit today.
    final open = find.widgetWithText(OutlinedButton, 'Open a dialog');
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.text('A dialog'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Show a toast'));
    await tester.pump();
    expect(find.text('From inside the dialog'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Close'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('the swipe section puts a toast up to drag', (tester) async {
    await pumpHarness(tester);

    final one = find.widgetWithText(OutlinedButton, 'One to swipe');
    await tester.ensureVisible(one);
    await tester.pumpAndSettle();
    await tester.tap(one);
    await tester.pump();

    expect(find.text('Drag me off the screen'), findsOneWidget);
  });

  testWidgets('the builder section puts a FlashBar up through the adapter', (
    tester,
  ) async {
    await pumpHarness(tester);

    final button = find.widgetWithText(
      OutlinedButton,
      'FlashBar, keeping the toast’s swipe',
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();

    expect(find.text('Saved through the adapter'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is FlashBar),
      findsOneWidget,
      reason: 'not the default look',
    );
  });

  testWidgets('the time left section shows a counting toast, and its switch '
      'takes the time left away', (tester) async {
    await pumpHarness(tester);

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'One, 8 s'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(OutlinedButton, 'One, 8 s'));
    await tester.pump();
    expect(find.text('Counting down'), findsOneWidget);

    expect(find.text('look'), findsOneWidget);
    await tester.tap(find.widgetWithText(SwitchListTile, 'timeLeft'));
    await tester.pump();
    expect(find.text('look'), findsNothing, reason: 'the config has none');
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
  });

  testWidgets('the expand section fans the deck out with no pointer, and '
      'collapse folds it up', (tester) async {
    await pumpHarness(tester);

    final five = find.widgetWithText(OutlinedButton, 'Five toasts, 10 s each');
    await tester.ensureVisible(five);
    await tester.pumpAndSettle();
    await tester.tap(five);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('Toast 1 of 5'),
      findsNothing,
      reason: 'beyond the window',
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'The app: expand()'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Toast 1 of 5'), findsOneWidget);
    expect(find.text('expanded: true · held: false'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'The app: collapse()'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Toast 1 of 5'), findsNothing);
    expect(find.text('expanded: false · held: false'), findsOneWidget);

    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
  });

  testWidgets('a config control is assigned, and the deck stays', (
    tester,
  ) async {
    await pumpHarness(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Show a toast'));
    await tester.pump();
    expect(find.text('Event has been created'), findsOneWidget);

    // The panel grows a section per issue, so scroll the control into view
    // rather than trusting where it happens to sit today.
    await tester.ensureVisible(find.text('expandByDefault'));
    // The toast counts down, so nothing settles: pump the scroll by hand.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('expandByDefault'));
    await tester.pump();
    expect(find.text('Event has been created'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
