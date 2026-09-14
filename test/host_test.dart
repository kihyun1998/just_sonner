import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_sonner/just_sonner.dart';

void main() {
  late SonnerController controller;

  setUp(() => controller = SonnerController());
  tearDown(() => controller.dispose());

  Widget app({SonnerController? controller, ThemeData? theme}) => MaterialApp(
    theme: theme,
    builder: (context, child) =>
        SonnerHost(controller: controller, child: child!),
    home: const SizedBox.expand(),
  );

  testWidgets(
    'a toast shown on the controller is drawn, with its description',
    (tester) async {
      await tester.pumpWidget(app(controller: controller));

      controller.show('Saved', description: 'All changes are stored');
      await tester.pumpAndSettle();

      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('All changes are stored'), findsOneWidget);
    },
  );

  testWidgets(
    'the default look takes its surface, border and text from the theme',
    (tester) async {
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6A1B9A)),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 17),
          bodySmall: TextStyle(fontSize: 11),
        ),
      );
      await tester.pumpWidget(app(controller: controller, theme: theme));

      controller.show('Saved', description: 'All changes are stored');
      await tester.pumpAndSettle();

      final surface = tester.widget<Material>(
        find
            .ancestor(of: find.text('Saved'), matching: find.byType(Material))
            .first,
      );
      final shape = surface.shape! as RoundedRectangleBorder;
      expect(surface.color, theme.colorScheme.surfaceContainerHigh);
      expect(shape.side.color, theme.colorScheme.outlineVariant);
      expect(shape.borderRadius, BorderRadius.circular(8));

      TextStyle styleOf(String text) =>
          tester.renderObject<RenderParagraph>(find.text(text)).text.style!;
      expect(styleOf('Saved').fontSize, 17);
      expect(styleOf('All changes are stored').fontSize, 11);
      expect(styleOf('Saved').color, theme.colorScheme.onSurface);
    },
  );

  Rect toastRect(WidgetTester tester, String title) => tester.getRect(
    find.ancestor(of: find.text(title), matching: find.byType(Material)).first,
  );

  group('position', () {
    // The test surface is 800 × 600.
    const expectations = {
      SonnerPosition.topLeft: (
        left: 24.0,
        right: null,
        centerX: null,
        top: 24.0,
        bottom: null,
      ),
      SonnerPosition.topCenter: (
        left: null,
        right: null,
        centerX: 400.0,
        top: 24.0,
        bottom: null,
      ),
      SonnerPosition.topRight: (
        left: null,
        right: 776.0,
        centerX: null,
        top: 24.0,
        bottom: null,
      ),
      SonnerPosition.bottomLeft: (
        left: 24.0,
        right: null,
        centerX: null,
        top: null,
        bottom: 576.0,
      ),
      SonnerPosition.bottomCenter: (
        left: null,
        right: null,
        centerX: 400.0,
        top: null,
        bottom: 576.0,
      ),
      SonnerPosition.bottomRight: (
        left: null,
        right: 776.0,
        centerX: null,
        top: null,
        bottom: 576.0,
      ),
    };

    for (final MapEntry(key: position, value: edge) in expectations.entries) {
      testWidgets('$position places the toast offset from its edges', (
        tester,
      ) async {
        final controller = SonnerController(
          config: SonnerConfig(position: position),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(app(controller: controller));

        controller.show('Saved');
        await tester.pumpAndSettle();

        final rect = toastRect(tester, 'Saved');
        expect(rect.width, 356);
        if (edge.left != null) expect(rect.left, edge.left);
        if (edge.right != null) expect(rect.right, edge.right);
        if (edge.centerX != null) expect(rect.center.dx, edge.centerX);
        if (edge.top != null) expect(rect.top, edge.top);
        if (edge.bottom != null) expect(rect.bottom, edge.bottom);
      });
    }

    testWidgets('defaults to bottomRight', (tester) async {
      await tester.pumpWidget(app(controller: controller));

      controller.show('Saved');
      await tester.pumpAndSettle();

      final rect = toastRect(tester, 'Saved');
      expect((rect.right, rect.bottom), (776.0, 576.0));
    });

    testWidgets('width and offset come from the config', (tester) async {
      final controller = SonnerController(
        config: const SonnerConfig(width: 300, offset: 40),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller: controller));

      controller.show('Saved');
      await tester.pumpAndSettle();

      final rect = toastRect(tester, 'Saved');
      expect((rect.width, rect.right, rect.bottom), (300.0, 760.0, 560.0));
    });
  });

  group('stacking', () {
    testWidgets(
      'at the bottom, the newest is nearest the edge, the older gap above',
      (tester) async {
        await tester.pumpWidget(app(controller: controller));

        controller.show('Older');
        controller.show('Newer');
        await tester.pumpAndSettle();

        final older = toastRect(tester, 'Older');
        final newer = toastRect(tester, 'Newer');
        expect(newer.bottom, 576);
        expect(newer.top - older.bottom, 14);
      },
    );

    testWidgets(
      'at the top, the newest is nearest the edge, the older gap below',
      (tester) async {
        final controller = SonnerController(
          config: const SonnerConfig(position: SonnerPosition.topLeft, gap: 20),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(app(controller: controller));

        controller.show('Older');
        controller.show('Newer', description: 'A taller toast');
        await tester.pumpAndSettle();

        final older = toastRect(tester, 'Older');
        final newer = toastRect(tester, 'Newer');
        expect(newer.top, 24);
        expect(older.top - newer.bottom, 20);
      },
    );
  });

  double opacityOf(WidgetTester tester, String title) => tester
      .widget<FadeTransition>(
        find
            .ancestor(
              of: find.text(title),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  group('enter', () {
    testWidgets(
      'slides up from the bottom edge and fades in over 400 ms, ease',
      (tester) async {
        await tester.pumpWidget(app(controller: controller));

        controller.show('Saved');
        await tester.pump();
        final start = toastRect(tester, 'Saved');
        expect(opacityOf(tester, 'Saved'), 0);
        expect(
          start.top,
          576,
          reason:
              'starts a full height lower, its top on the resting bottom edge',
        );

        await tester.pump(const Duration(milliseconds: 200));
        // CSS `ease`, cubic-bezier(0.25, 0.1, 0.25, 1), at t = 0.5.
        expect(opacityOf(tester, 'Saved'), closeTo(0.8024, 0.001));

        await tester.pump(const Duration(milliseconds: 200));
        expect(opacityOf(tester, 'Saved'), 1);
        expect(toastRect(tester, 'Saved').bottom, 576);
      },
    );

    testWidgets('slides down from the top edge', (tester) async {
      final controller = SonnerController(
        config: const SonnerConfig(position: SonnerPosition.topCenter),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller: controller));

      controller.show('Saved');
      await tester.pump();

      expect(toastRect(tester, 'Saved').bottom, 24);
    });
  });

  group('exit', () {
    testWidgets(
      'slides to the edge, fades out by 200 ms, leaves the tree next frame',
      (tester) async {
        await tester.pumpWidget(app(controller: controller));
        final id = controller.show('Saved');
        await tester.pumpAndSettle();
        final resting = toastRect(tester, 'Saved');

        controller.dismiss(id);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(toastRect(tester, 'Saved').top, greaterThan(resting.top));
        expect(opacityOf(tester, 'Saved'), inExclusiveRange(0, 1));

        await tester.pump(const Duration(milliseconds: 99));
        expect(find.text('Saved'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 1));
        expect(opacityOf(tester, 'Saved'), 0);

        // An AnimationController reports `dismissed` on the first tick past
        // its duration.
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(find.text('Saved'), findsNothing);
      },
    );

    testWidgets('a toast dismissed mid-enter still takes 200 ms to leave', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      final id = controller.show('Saved');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      controller.dismiss(id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 199));
      expect(find.text('Saved'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2));
      await tester.pump();
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('a toast dismissed before its first frame leaves', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));

      final id = controller.show('Saved');
      controller.dismiss(id);
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);

      controller.show('Next');
      controller.dismissAll();
      await tester.pumpAndSettle();
      expect(find.text('Next'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('an exiting toast keeps the place it was dismissed from', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Oldest');
      controller.show('Middle');
      controller.show('Newest');
      await tester.pumpAndSettle();
      final resting = toastRect(tester, 'Oldest');

      controller.dismissAll();
      await tester.pump();
      for (var elapsed = 0; elapsed < 200; elapsed += 25) {
        final now = toastRect(tester, 'Oldest');
        expect(
          now.top - resting.top,
          inInclusiveRange(0, resting.height),
          reason: 'at $elapsed ms it may only slide its own height to the edge',
        );
        await tester.pump(const Duration(milliseconds: 25));
      }
    });

    testWidgets('a toast shown while another exits does not push it away', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      final old = controller.show('Old');
      await tester.pumpAndSettle();
      final resting = toastRect(tester, 'Old');

      controller.dismiss(old);
      controller.show('New');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(toastRect(tester, 'Old').top, greaterThanOrEqualTo(resting.top));
    });

    testWidgets('the newest toast is painted over an older one', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Old');
      controller.show('New');
      await tester.pumpAndSettle();

      // Children of the toast layer paint in order, so the last one is on top.
      final painted = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .toList();
      expect(painted, ['Old', 'New']);
    });

    testWidgets('the toasts behind close the gap', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Older');
      final newer = controller.show('Newer');
      await tester.pumpAndSettle();
      final before = toastRect(tester, 'Older');

      controller.dismiss(newer);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final midway = toastRect(tester, 'Older');
      expect(midway.bottom, greaterThan(before.bottom));
      expect(midway.bottom, lessThan(576));

      await tester.pumpAndSettle();
      expect(toastRect(tester, 'Older').bottom, 576);
    });

    testWidgets('dismissAll sends every toast out', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('First');
      controller.show('Second');
      await tester.pumpAndSettle();

      controller.dismissAll();
      await tester.pump();
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsNothing);
    });

    testWidgets('a toast shown while another exits takes the edge', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      final old = controller.show('Old');
      await tester.pumpAndSettle();

      controller.dismiss(old);
      controller.show('New');
      await tester.pump();

      expect(find.text('Old'), findsOneWidget, reason: 'still exiting');
      expect(
        toastRect(tester, 'New').top,
        576,
        reason: 'enters at the edge, not behind the exiting toast',
      );
    });
  });

  testWidgets('a toast is announced as a live region', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(controller: controller));

    controller.show('Saved');
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('Saved')),
      isSemantics(isLiveRegion: true),
    );
    semantics.dispose();
  });

  testWidgets('taps away from the toasts reach the app underneath', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            SonnerHost(controller: controller, child: child!),
        home: GestureDetector(
          onTap: () => taps++,
          child: const ColoredBox(color: Color(0xFFFFFFFF)),
        ),
      ),
    );
    controller.show('Saved');
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(40, 40));

    expect(taps, 1);
  });

  testWidgets('a host handed a different controller follows it', (
    tester,
  ) async {
    final other = SonnerController();
    await tester.pumpWidget(app(controller: controller));
    controller.show('Before');
    await tester.pumpAndSettle();

    await tester.pumpWidget(app(controller: other));
    await tester.pumpAndSettle();
    expect(find.text('Before'), findsNothing);

    other.show('After');
    await tester.pumpAndSettle();
    expect(find.text('After'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    controller.show('Nobody is listening');
    other.show('Nor here');
    await tester.pump();
    expect(tester.takeException(), isNull);
    other.dispose();
  });

  group('with no controller', () {
    tearDown(toast.dismissAll);

    testWidgets('the host draws the exported toast', (tester) async {
      await tester.pumpWidget(app());

      toast.show('From anywhere');
      await tester.pumpAndSettle();

      expect(find.text('From anywhere'), findsOneWidget);
    });

    testWidgets('a host given a controller does not draw the exported toast', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));

      toast.show('Not mine');
      await tester.pumpAndSettle();

      expect(find.text('Not mine'), findsNothing);
    });
  });
}
