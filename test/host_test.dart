import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_sonner/just_sonner.dart';

void main() {
  late SonnerController controller;

  // These tests are about layout and motion, so their toasts have no timer: a
  // widget test must not end with one pending.
  setUp(
    () => controller = SonnerController(
      config: const SonnerConfig(duration: Duration.zero),
    ),
  );
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
          config: SonnerConfig(position: position, duration: Duration.zero),
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
        config: const SonnerConfig(
          width: 300,
          offset: 40,
          duration: Duration.zero,
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller: controller));

      controller.show('Saved');
      await tester.pumpAndSettle();

      final rect = toastRect(tester, 'Saved');
      expect((rect.width, rect.right, rect.bottom), (300.0, 760.0, 560.0));
    });
  });

  group('deck', () {
    /// Where toast [i] behind the front of a bottomRight deck is drawn: a box
    /// of [height], its bottom `gap × i` above the front's, scaled by
    /// `1 − 0.05 × i` about its centre.
    Rect collapsed(int i, double height) {
      final scale = 1 - 0.05 * i;
      final box = Rect.fromLTRB(
        420,
        576 - 14.0 * i - height,
        776,
        576 - 14.0 * i,
      );
      return Rect.fromCenter(
        center: box.center,
        width: box.width * scale,
        height: box.height * scale,
      );
    }

    for (final count in [1, 2, 3, 5]) {
      testWidgets('$count toasts collapse into a deck of at most three', (
        tester,
      ) async {
        await tester.pumpWidget(app(controller: controller));
        for (var n = 0; n < count; n++) {
          controller.show('Toast $n');
        }
        await tester.pumpAndSettle();

        final front = toastRect(tester, 'Toast ${count - 1}');
        for (var i = 0; i < count; i++) {
          final title = 'Toast ${count - 1 - i}';
          if (i < 3) {
            final rect = toastRect(tester, title);
            expect(
              rect.left,
              moreOrLessEquals(collapsed(i, front.height).left),
            );
            expect(rect.top, moreOrLessEquals(collapsed(i, front.height).top));
            expect(rect.size, _sizeCloseTo(collapsed(i, front.height).size));
          } else {
            expect(find.text(title), findsNothing, reason: '$title is hidden');
            expect(
              find.text(title, skipOffstage: false),
              findsOneWidget,
              reason: '$title is still kept',
            );
          }
        }
      });
    }

    testWidgets('at the top, the toasts behind shift down', (tester) async {
      final controller = SonnerController(
        config: const SonnerConfig(
          position: SonnerPosition.topLeft,
          gap: 20,
          visibleToasts: 2,
          duration: Duration.zero,
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller: controller));

      controller.show('Oldest');
      controller.show('Older');
      controller.show('Newer');
      await tester.pumpAndSettle();

      final newer = toastRect(tester, 'Newer');
      final older = toastRect(tester, 'Older');
      expect(newer.top, 24);
      expect(older.center.dy - newer.center.dy, moreOrLessEquals(20));
      expect(older.height / newer.height, moreOrLessEquals(0.95));
      expect(find.text('Oldest'), findsNothing);
    });

    testWidgets('a shorter toast behind is stretched to the front height', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Short');
      controller.show('Tall', description: 'A second line');
      await tester.pumpAndSettle();

      final tall = toastRect(tester, 'Tall');
      final short = toastRect(tester, 'Short');
      expect(short.height, moreOrLessEquals(tall.height * 0.95));
      expect(short.bottom, moreOrLessEquals(collapsed(1, tall.height).bottom));
    });

    testWidgets('a taller toast behind is cut to the front height', (
      tester,
    ) async {
      final controller = SonnerController(
        config: const SonnerConfig(
          position: SonnerPosition.topLeft,
          duration: Duration.zero,
        ),
      );
      addTearDown(controller.dispose);
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
      controller.show('Alone');
      await tester.pumpAndSettle();
      final alone = toastRect(tester, 'Alone').height;
      controller.dismissAll();
      await tester.pumpAndSettle();

      controller.show('Tall', description: 'One\nTwo\nThree\nFour\nFive');
      controller.show('Short');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(
        toastRect(tester, 'Short').height,
        alone,
        reason: 'the front is drawn at its own height',
      );
      final scaled = tester.renderObject<RenderTransform>(
        find.ancestor(of: find.text('Tall'), matching: find.byType(Transform)),
      );
      final drawn = scaled.child!;
      final tall = MatrixUtils.transformRect(
        drawn.getTransformTo(null),
        Offset.zero & drawn.paintBounds.size,
      );
      expect(tall.height, moreOrLessEquals(alone * 0.95));
      expect(
        tester.renderObject(
          find.ancestor(
            of: find.text('Tall'),
            matching: find.byType(Transform),
          ),
        ),
        paints..clipRect(rect: Offset.zero & Size(356, alone)),
      );

      await tester.tapAt(Offset(tall.center.dx, tall.bottom + 20));
      expect(taps, 1, reason: 'the part cut off takes no taps');
    });

    testWidgets(
      'the deck takes the front height plus a gap per toast behind it',
      (tester) async {
        await tester.pumpWidget(app(controller: controller));
        for (var n = 0; n < 5; n++) {
          controller.show('Toast $n', description: n == 4 ? 'Front' : null);
        }
        await tester.pumpAndSettle();

        final front = toastRect(tester, 'Toast 4').height;
        // A toast's box before it is scaled.
        final boxes = [
          for (var n = 2; n < 5; n++)
            tester.getRect(
              find.ancestor(
                of: find.text('Toast $n'),
                matching: find.byType(SlideTransition),
              ),
            ),
        ];
        final deck = boxes.reduce((a, b) => a.expandToInclude(b));
        expect(deck.bottom, 576);
        expect(deck.height, moreOrLessEquals(front + 14 * 2));
      },
    );

    testWidgets('the toasts behind the front are not faded', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      for (var n = 0; n < 3; n++) {
        controller.show('Toast $n');
      }
      await tester.pumpAndSettle();

      for (var n = 0; n < 3; n++) {
        expect(paintedOpacityOf(tester, 'Toast $n'), 1, reason: 'Toast $n');
      }
    });

    /// The y of a point only toast [i] of a resting bottomRight deck covers:
    /// between its top and the top of the toast in front of it.
    double peekOf(int i, double height) =>
        (collapsed(i, height).top + collapsed(i - 1, height).top) / 2;

    Widget tappableApp(void Function() onTap) => MaterialApp(
      builder: (context, child) =>
          SonnerHost(controller: controller, child: child!),
      home: GestureDetector(
        onTap: onTap,
        child: const ColoredBox(color: Color(0xFFFFFFFF)),
      ),
    );

    testWidgets('toasts beyond visibleToasts take no taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(tappableApp(() => taps++));
      for (var n = 0; n < 4; n++) {
        controller.show('Toast $n');
      }
      await tester.pumpAndSettle();
      final height = toastRect(tester, 'Toast 3').height;

      await tester.tapAt(Offset(600, peekOf(2, height)));
      expect(taps, 0, reason: 'the third toast takes the tap');

      await tester.tapAt(Offset(600, peekOf(3, height)));
      expect(taps, 1, reason: 'the fourth toast is hidden');
    });

    testWidgets('a toast pushed out of the window fades as the new one enters, '
        'taking no taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(tappableApp(() => taps++));
      for (var n = 0; n < 3; n++) {
        controller.show('Toast $n');
      }
      await tester.pumpAndSettle();
      final height = toastRect(tester, 'Toast 2').height;

      controller.show('Toast 3');
      await tester.pump();
      expect(paintedOpacityOf(tester, 'Toast 0'), 1);

      await tester.pump(const Duration(milliseconds: 200));
      expect(paintedOpacityOf(tester, 'Toast 0'), inExclusiveRange(0, 1));
      await tester.tapAt(Offset(600, toastRect(tester, 'Toast 0').top + 2));
      expect(taps, 1);

      await tester.pumpAndSettle();
      expect(find.text('Toast 0'), findsNothing);
      expect(
        toastRect(tester, 'Toast 1').top,
        moreOrLessEquals(collapsed(2, height).top),
      );
    });

    testWidgets('dismissing the front brings the next toast into the window', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(tappableApp(() => taps++));
      final ids = [for (var n = 0; n < 4; n++) controller.show('Toast $n')];
      await tester.pumpAndSettle();
      final height = toastRect(tester, 'Toast 3').height;

      controller.dismiss(ids[3]);
      await tester.pump();
      expect(find.text('Toast 0'), findsOneWidget, reason: 'in at once');

      await tester.pump(const Duration(milliseconds: 100));
      expect(paintedOpacityOf(tester, 'Toast 0'), inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(paintedOpacityOf(tester, 'Toast 0'), 1);
      expect(
        toastRect(tester, 'Toast 0').top,
        moreOrLessEquals(collapsed(2, height).top),
      );
      await tester.tapAt(Offset(600, peekOf(2, height)));
      expect(taps, 0, reason: 'it takes taps');
    });

    double scaleOf(WidgetTester tester, String title) => tester
        .widget<Transform>(
          find.ancestor(of: find.text(title), matching: find.byType(Transform)),
        )
        .transform
        .storage[0];

    testWidgets(
      'a toast shown as the front leaves holds the ones behind still',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(tappableApp(() => taps++));
        final ids = [for (var n = 0; n < 4; n++) controller.show('Toast $n')];
        await tester.pumpAndSettle();
        final height = toastRect(tester, 'Toast 3').height;

        controller.dismiss(ids[3]);
        controller.show('New');
        await tester.pump();
        for (var elapsed = 0; elapsed <= 400; elapsed += 20) {
          expect(
            find.text('Toast 0'),
            findsNothing,
            reason: 'hidden before and after, at $elapsed ms',
          );
          expect(
            paintedOpacityOf(tester, 'Toast 1'),
            1,
            reason: 'in the window before and after, at $elapsed ms',
          );
          expect(
            scaleOf(tester, 'Toast 1'),
            moreOrLessEquals(0.9),
            reason: 'third before and after, at $elapsed ms',
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        await tester.pumpAndSettle();
        expect(
          toastRect(tester, 'Toast 1').top,
          moreOrLessEquals(collapsed(2, height).top),
        );
      },
    );

    testWidgets(
      'a toast on its way back never comes forward, however the clocks mix',
      (tester) async {
        await tester.pumpWidget(app(controller: controller));
        controller.show('A');
        final b = controller.show('B');
        await tester.pumpAndSettle();
        final bottoms = <double>[];

        controller.show('C');
        await tester.pump();
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          bottoms.add(toastRect(tester, 'A').bottom);
        }
        controller.dismiss(b);
        controller.show('D');
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          bottoms.add(toastRect(tester, 'A').bottom);
        }

        // At the bottom, moving back means moving up: the bottom edge only
        // ever falls.
        for (var i = 1; i < bottoms.length; i++) {
          expect(
            bottoms[i],
            lessThanOrEqualTo(bottoms[i - 1] + 1e-9),
            reason: 'frame $i',
          );
        }
      },
    );

    testWidgets('a toast dismissed outside the window still takes no taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(tappableApp(() => taps++));
      final oldest = controller.show('Toast 0');
      for (var n = 1; n < 3; n++) {
        controller.show('Toast $n');
      }
      await tester.pumpAndSettle();

      controller.show('Toast 3');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final fading = toastRect(tester, 'Toast 0');

      controller.dismiss(oldest);
      await tester.pump();
      await tester.tapAt(Offset(600, fading.top + 2));
      expect(taps, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('an exiting toast keeps the scale it was dismissed at', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      final back = controller.show('Back');
      controller.show('Front');
      await tester.pumpAndSettle();

      controller.dismiss(back);
      controller.show('New');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(scaleOf(tester, 'Back'), moreOrLessEquals(0.95));
      expect(scaleOf(tester, 'Front'), inExclusiveRange(0.95, 1));

      await tester.pumpAndSettle();
      expect(scaleOf(tester, 'Front'), moreOrLessEquals(0.95));
    });

    // A toast's height before it is scaled.
    double drawnHeightOf(WidgetTester tester, String title) => tester
        .getRect(
          find.ancestor(
            of: find.text(title),
            matching: find.byType(SlideTransition),
          ),
        )
        .height;

    testWidgets(
      'a toast brought to the front grows from the height it was drawn at',
      (tester) async {
        await tester.pumpWidget(app(controller: controller));
        controller.show('Short');
        final tall = controller.show('Tall', description: 'A second line');
        await tester.pumpAndSettle();
        final tallHeight = drawnHeightOf(tester, 'Tall');

        controller.dismiss(tall);
        await tester.pump();
        expect(drawnHeightOf(tester, 'Short'), moreOrLessEquals(tallHeight));

        await tester.pump(const Duration(milliseconds: 100));
        final midway = drawnHeightOf(tester, 'Short');

        await tester.pumpAndSettle();
        final own = drawnHeightOf(tester, 'Short');
        expect(own, lessThan(tallHeight));
        expect(midway, inExclusiveRange(own, tallHeight));
      },
    );

    testWidgets('an exiting toast keeps the height it was dismissed at', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Short');
      controller.show('Tall', description: 'A second line');
      await tester.pumpAndSettle();
      final tallHeight = drawnHeightOf(tester, 'Tall');

      controller.dismissAll();
      await tester.pump();
      for (var elapsed = 0; elapsed < 200; elapsed += 40) {
        expect(
          drawnHeightOf(tester, 'Short'),
          moreOrLessEquals(tallHeight),
          reason: 'at $elapsed ms',
        );
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();
    });

    testWidgets('the front toast is not clipped', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Tall', description: 'One\nTwo\nThree');
      controller.show('Front');
      await tester.pumpAndSettle();

      expect(
        tester.renderObject(
          find.ancestor(
            of: find.text('Front'),
            matching: find.byType(Transform),
          ),
        ),
        isNot(paints..clipRect()),
      );
    });

    testWidgets(
      'the toast a new one covers takes its height as the new one enters',
      (tester) async {
        await tester.pumpWidget(app(controller: controller));
        controller.show('Short');
        await tester.pumpAndSettle();
        final own = drawnHeightOf(tester, 'Short');

        controller.show('Tall', description: 'A second line');
        await tester.pump();
        expect(drawnHeightOf(tester, 'Short'), moreOrLessEquals(own));

        await tester.pump(const Duration(milliseconds: 200));
        final midway = drawnHeightOf(tester, 'Short');

        await tester.pumpAndSettle();
        final tallHeight = drawnHeightOf(tester, 'Tall');
        expect(drawnHeightOf(tester, 'Short'), moreOrLessEquals(tallHeight));
        expect(midway, inExclusiveRange(own, tallHeight));
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
        config: const SonnerConfig(
          position: SonnerPosition.topCenter,
          duration: Duration.zero,
        ),
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

  testWidgets(
    'a toast beyond the window is announced when it reaches the window',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(app(controller: controller));
      final ids = [for (var n = 0; n < 4; n++) controller.show('Toast $n')];
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Toast 0'), findsNothing);

      controller.dismiss(ids[3]);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Toast 0')),
        isSemantics(label: 'Toast 0', isLiveRegion: true),
      );
      semantics.dispose();
    },
  );

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
    final other = SonnerController(
      config: const SonnerConfig(duration: Duration.zero),
    );
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

  testWidgets('a toast leaves the screen on its own after its duration', (
    tester,
  ) async {
    final controller = SonnerController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller: controller));

    controller.show('Saved');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3999));
    expect(opacityOf(tester, 'Saved'), 1, reason: 'on screen, not exiting');

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      opacityOf(tester, 'Saved'),
      lessThan(1),
      reason: 'dismissed at 4 s, so exiting',
    );

    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  });

  group('with no controller', () {
    tearDown(toast.dismissAll);

    testWidgets('the host draws the exported toast', (tester) async {
      await tester.pumpWidget(app());

      toast.show('From anywhere');
      await tester.pumpAndSettle();

      expect(find.text('From anywhere'), findsOneWidget);

      toast.dismissAll();
      await tester.pumpAndSettle();
    });

    testWidgets('a host given a controller does not draw the exported toast', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));

      toast.show('Not mine');
      await tester.pumpAndSettle();

      expect(find.text('Not mine'), findsNothing);

      toast.dismissAll();
      await tester.pumpAndSettle();
    });
  });
}

Matcher _sizeCloseTo(Size expected) => predicate<Size>(
  (size) =>
      (size.width - expected.width).abs() < 1e-6 &&
      (size.height - expected.height).abs() < 1e-6,
  'a size close to $expected',
);

/// The opacity [title]'s toast is painted with: every fade above it multiplied.
double paintedOpacityOf(WidgetTester tester, String title) {
  var opacity = 1.0;
  final above = find.ancestor(
    of: find.text(title),
    matching: find.byWidgetPredicate(
      (widget) => widget is Opacity || widget is FadeTransition,
    ),
  );
  for (final widget in tester.widgetList(above)) {
    opacity *= switch (widget) {
      Opacity(:final opacity) => opacity,
      FadeTransition(:final opacity) => opacity.value,
      _ => 1,
    };
  }
  return opacity;
}
