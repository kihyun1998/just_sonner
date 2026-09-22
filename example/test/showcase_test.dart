import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_sonner_example/main.dart';

/// Guards the showcase: that its options reach the toasts and its buttons are
/// wired to a controller that is drawing.
void main() {
  Future<void> pumpShowcase(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1600, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ExampleApp());
  }

  /// A `Text`, so a field holding the same words is not counted.
  Finder toast(String text) =>
      find.byWidgetPredicate((it) => it is Text && it.data == text);

  Future<void> press(WidgetTester tester, String label) async {
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    // Past an enter or a crossfade, by hand: toasts count down.
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> open(WidgetTester tester, String group) async {
    final tile = find.widgetWithText(ExpansionTile, group);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text(group));
    await tester.pumpAndSettle();
  }

  testWidgets('Show puts up what the toast options compose', (tester) async {
    await pumpShowcase(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'title'),
      'Composed',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'description'),
      'A second line',
    );
    await press(tester, 'Show');
    expect(toast('Composed'), findsOneWidget);
    expect(toast('A second line'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a config option reaches a toast on screen', (tester) async {
    await pumpShowcase(tester);

    // Opened first: settling the fold would wait out the toast's countdown.
    await open(tester, 'Look');
    await press(tester, 'Show');
    expect(find.byIcon(Icons.close), findsNothing);

    final closeButton = find.widgetWithText(SwitchListTile, 'closeButton');
    await tester.ensureVisible(closeButton);
    await tester.pump();
    await tester.tap(closeButton);
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a scenario puts its toasts up', (tester) async {
    await pumpShowcase(tester);

    await press(tester, 'A burst of twelve');
    expect(toast('Burst 12 of 12'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('the zone buttons open and close the zone', (tester) async {
    await pumpShowcase(tester);

    await press(tester, 'open()');
    expect(find.text('state: open · held: false'), findsOneWidget);
    await press(tester, 'close()');
    expect(find.text('state: shown · held: false'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('the harness sits on a page behind the app bar', (tester) async {
    await pumpShowcase(tester);
    expect(find.text('Show and dismiss'), findsNothing);

    await tester.tap(find.byTooltip('Harness'));
    await tester.pumpAndSettle();
    expect(find.text('Show and dismiss'), findsOneWidget);
  });
}
