import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_sonner/just_sonner.dart';
import 'package:just_sonner/src/content_fade.dart';
import 'package:just_sonner/src/controller.dart' show toastsOf;

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

  group('enter', () {
    testWidgets(
      'slides up from the bottom edge and fades in over 400 ms, ease',
      (tester) async {
        await tester.pumpWidget(app(controller: controller));

        controller.show('Saved');
        await tester.pump();
        final start = toastRect(tester, 'Saved');
        expect(presenceOf(tester, 'Saved'), 0);
        expect(
          start.top,
          576,
          reason:
              'starts a full height lower, its top on the resting bottom edge',
        );

        await tester.pump(const Duration(milliseconds: 200));
        // CSS `ease`, cubic-bezier(0.25, 0.1, 0.25, 1), at t = 0.5.
        expect(presenceOf(tester, 'Saved'), closeTo(0.8024, 0.001));

        await tester.pump(const Duration(milliseconds: 200));
        expect(presenceOf(tester, 'Saved'), 1);
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
        expect(presenceOf(tester, 'Saved'), inExclusiveRange(0, 1));

        await tester.pump(const Duration(milliseconds: 99));
        expect(find.text('Saved'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 1));
        expect(presenceOf(tester, 'Saved'), 0);

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

  group('update and replace', () {
    /// The opacity of the content fading in or out inside [title]'s toast.
    double contentFadeOf(WidgetTester tester, String title) => tester
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

    double drawnHeightOf(WidgetTester tester, String title) => tester
        .getRect(
          find.ancestor(
            of: find.text(title),
            matching: find.byType(SlideTransition),
          ),
        )
        .height;

    testWidgets(
      'an update changes the toast in place, without entering again',
      (tester) async {
        await tester.pumpWidget(app(controller: controller));
        controller.show('Behind');
        final id = controller.show('Checking');
        await tester.pumpAndSettle();
        final before = toastRect(tester, 'Checking');

        controller.update(id, title: 'Opening');
        await tester.pump();
        final toasts = find.ancestor(
          of: find.byType(Text),
          matching: find.byType(SlideTransition),
        );
        expect(
          tester.widgetList(toasts).toSet(),
          hasLength(2),
          reason: 'still two toasts, not a third entering',
        );
        expect(find.text('Opening'), findsOneWidget);
        expect(presenceOf(tester, 'Opening'), 1, reason: 'no re-enter');
        expect(toastRect(tester, 'Opening'), before);

        await tester.pumpAndSettle();
        expect(find.text('Checking'), findsNothing);
        expect(find.text('Opening'), findsOneWidget);
        expect(toastRect(tester, 'Opening'), before);
        expect(
          toastRect(tester, 'Behind').bottom,
          lessThan(before.bottom),
          reason: 'still behind it',
        );
      },
    );

    testWidgets(
      'new content fades in over the old in 200 ms, the old staying opaque',
      (tester) async {
        await tester.pumpWidget(app(controller: controller));
        final id = controller.show('Checking');
        await tester.pumpAndSettle();

        controller.update(id, title: 'Opening');
        await tester.pump();
        expect(paintedOpacityOf(tester, 'Checking'), 1);
        expect(contentFadeOf(tester, 'Opening'), 0);

        await tester.pump(const Duration(milliseconds: 100));
        expect(
          paintedOpacityOf(tester, 'Checking'),
          1,
          reason: 'the card underneath is not see-through',
        );
        expect(contentFadeOf(tester, 'Opening'), moreOrLessEquals(0.5));

        await tester.pump(const Duration(milliseconds: 100));
        expect(contentFadeOf(tester, 'Opening'), 1);
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.text('Checking'), findsNothing);
        expect(paintedOpacityOf(tester, 'Opening'), 1);
      },
    );

    testWidgets('an update mid-fade makes the half-faded content the base', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      final id = controller.show('10%');
      await tester.pumpAndSettle();

      controller.update(id, title: '20%');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      controller.update(id, title: '30%');
      await tester.pump();

      expect(find.text('10%'), findsNothing, reason: 'at most two layers');
      expect(paintedOpacityOf(tester, '20%'), 1, reason: 'now the base');
      expect(contentFadeOf(tester, '30%'), 0);

      await tester.pump(const Duration(milliseconds: 100));
      expect(paintedOpacityOf(tester, '20%'), 1);
      expect(contentFadeOf(tester, '30%'), moreOrLessEquals(0.5));
      await tester.pumpAndSettle();
      expect(find.text('20%'), findsNothing);
    });

    testWidgets('a replace clears the description it does not give', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      final id = controller.show('Checking', description: 'credentials');
      await tester.pumpAndSettle();

      controller.show('Connected', id: id);
      await tester.pumpAndSettle();

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('credentials'), findsNothing);
    });

    testWidgets('the outgoing content is not announced', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(app(controller: controller));
      final id = controller.show('Checking');
      await tester.pumpAndSettle();

      controller.update(id, title: 'Opening');
      await tester.pump();
      expect(
        tester.getSemantics(find.text('Opening')),
        isSemantics(label: 'Opening', isLiveRegion: true),
        reason: 'announced from the first frame, while still transparent',
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Checking'), findsOneWidget, reason: 'still fading');
      expect(find.bySemanticsLabel('Checking'), findsNothing);
      expect(
        tester.getSemantics(find.text('Opening')),
        isSemantics(label: 'Opening', isLiveRegion: true),
      );
      await tester.pumpAndSettle();
      semantics.dispose();
    });

    testWidgets('a toast shown at the id of one exiting enters beside it', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      const id = ToastId('connection');
      controller.show('Old', id: id);
      await tester.pumpAndSettle();

      controller.dismiss(id);
      controller.show('New', id: id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(presenceOf(tester, 'Old'), inExclusiveRange(0, 1));
      expect(presenceOf(tester, 'New'), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.text('Old'), findsNothing);
      expect(presenceOf(tester, 'New'), 1);
    });

    testWidgets(
      'the front jumps to a new height and the toasts behind ease to it over '
      '400 ms',
      (tester) async {
        await tester.pumpWidget(app(controller: controller));
        controller.show('Behind');
        final id = controller.show('Front');
        await tester.pumpAndSettle();
        final short = drawnHeightOf(tester, 'Front');

        controller.update(id, description: 'A second line');
        await tester.pump();
        final tall = drawnHeightOf(tester, 'A second line');
        expect(tall, greaterThan(short), reason: 'the front jumps');
        expect(drawnHeightOf(tester, 'Behind'), moreOrLessEquals(short));

        await tester.pump(const Duration(milliseconds: 200));
        // CSS `ease` at t = 0.5, as sonner's `transition: height 400ms`.
        expect(
          drawnHeightOf(tester, 'Behind'),
          moreOrLessEquals(short + (tall - short) * 0.8024, epsilon: 0.05),
        );

        await tester.pump(const Duration(milliseconds: 200));
        expect(drawnHeightOf(tester, 'Behind'), moreOrLessEquals(tall));
        await tester.pumpAndSettle();
        expect(drawnHeightOf(tester, 'Behind'), moreOrLessEquals(tall));

        controller.show('Short again', id: id);
        await tester.pump();
        expect(drawnHeightOf(tester, 'Short again'), moreOrLessEquals(short));
        expect(drawnHeightOf(tester, 'Behind'), moreOrLessEquals(tall));
        await tester.pumpAndSettle();
        expect(drawnHeightOf(tester, 'Behind'), moreOrLessEquals(short));
      },
    );

    testWidgets('a change of height mid-ease goes on from where it got to', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Behind');
      final id = controller.show('Front');
      await tester.pumpAndSettle();

      controller.update(id, description: 'A second line');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final midway = drawnHeightOf(tester, 'Behind');

      controller.show('Front', id: id);
      await tester.pump();
      expect(drawnHeightOf(tester, 'Behind'), moreOrLessEquals(midway));
      await tester.pump(const Duration(milliseconds: 16));
      expect(drawnHeightOf(tester, 'Behind'), lessThan(midway));
      await tester.pumpAndSettle();
    });

    testWidgets('an update mid-enter keeps the enter going', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      final id = controller.show('Checking');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final midway = presenceOf(tester, 'Checking');
      expect(midway, inExclusiveRange(0, 1));

      controller.update(id, title: 'Opening');
      await tester.pump();
      expect(presenceOf(tester, 'Opening'), moreOrLessEquals(midway));

      await tester.pump(const Duration(milliseconds: 100));
      expect(presenceOf(tester, 'Opening'), greaterThan(midway));
      await tester.pumpAndSettle();
    });

    testWidgets('content keeps its State as it moves underneath', (
      tester,
    ) async {
      final inits = <String>[];
      Widget fade(String name) => Directionality(
        textDirection: TextDirection.ltr,
        child: ContentFade(
          duration: const Duration(milliseconds: 200),
          child: _Tracked(key: ValueKey(name), name: name, inits: inits),
        ),
      );
      await tester.pumpWidget(fade('a'));
      await tester.pumpWidget(fade('b'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(fade('c'));
      await tester.pumpAndSettle();

      expect(inits, ['a', 'b', 'c'], reason: 'each built once');
    });

    group('an ease meeting a toast that enters or leaves', () {
      /// Shows Behind and a short Front, then makes Front tall and runs the
      /// ease 200 ms in. Returns Front's id and its short and tall heights.
      Future<(ToastId, double, double)> midEase(WidgetTester tester) async {
        await tester.pumpWidget(app(controller: controller));
        controller.show('Behind');
        final id = controller.show('Front');
        await tester.pumpAndSettle();
        final short = drawnHeightOf(tester, 'Front');
        controller.update(id, description: 'A second line');
        await tester.pump();
        final tall = drawnHeightOf(tester, 'A second line');
        await tester.pump(const Duration(milliseconds: 200));
        return (id, short, tall);
      }

      testWidgets('a new toast entering does not shrink the eased front', (
        tester,
      ) async {
        final (_, _, tall) = await midEase(tester);

        controller.show('New');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        // Barely covered yet, so drawn all but at its own height.
        expect(
          drawnHeightOf(tester, 'A second line'),
          moreOrLessEquals(tall, epsilon: 0.5),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('dismissing the eased front does not jump the ones behind', (
        tester,
      ) async {
        final (id, _, _) = await midEase(tester);
        final before = drawnHeightOf(tester, 'Behind');

        controller.dismiss(id);
        await tester.pump();

        expect(drawnHeightOf(tester, 'Behind'), moreOrLessEquals(before));
        await tester.pumpAndSettle();
      });

      testWidgets(
        'a toast updated as the front leaves reaches its height as it leaves',
        (tester) async {
          await tester.pumpWidget(app(controller: controller));
          final behind = controller.show('Behind');
          final front = controller.show('Front');
          await tester.pumpAndSettle();

          controller.dismiss(front);
          controller.update(behind, description: 'A second line');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 190));
          final leaving = drawnHeightOf(tester, 'A second line');

          await tester.pumpAndSettle();
          final own = drawnHeightOf(tester, 'A second line');
          expect(
            leaving,
            moreOrLessEquals(own, epsilon: 1),
            reason: 'drawn toward its own height, not the eased one',
          );
        },
      );
    });
  });

  group('expanded', () {
    /// A toast's box before it is scaled.
    Rect boxOf(WidgetTester tester, String title) => tester.getRect(
      find.ancestor(
        of: find.text(title),
        matching: find.byType(SlideTransition),
      ),
    );

    /// A mouse resting at [at], taken away when the test ends.
    Future<TestGesture> mouseAt(WidgetTester tester, Offset at) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: at);
      addTearDown(mouse.removePointer);
      await tester.pump();
      return mouse;
    }

    const away = Offset(40, 40);

    double scaleOf(WidgetTester tester, String title) => tester
        .widget<Transform>(
          find.ancestor(of: find.text(title), matching: find.byType(Transform)),
        )
        .transform
        .storage[0];

    /// Shows each of [toasts] alone and returns the height it is drawn at on
    /// its own, then shows them all, oldest first.
    Future<Map<String, double>> showMeasured(
      WidgetTester tester,
      SonnerController controller,
      List<(String, String?)> toasts, {
      List<String> behind = const [],
    }) async {
      final heights = <String, double>{};
      for (final (title, description) in toasts) {
        controller.show(title, description: description);
        await tester.pumpAndSettle();
        heights[title] = boxOf(tester, title).height;
        controller.dismissAll();
        await tester.pumpAndSettle();
      }
      behind.forEach(controller.show);
      for (final (title, description) in toasts) {
        controller.show(title, description: description);
      }
      await tester.pumpAndSettle();
      return heights;
    }

    const threeHeights = [
      ('Oldest', 'One\nTwo\nThree'),
      ('Middle', null),
      ('Newest', 'A second line'),
    ];

    testWidgets(
      'hovering the deck fans each visible toast out at its own height',
      (tester) async {
        await tester.pumpWidget(app(controller: controller));
        final h = await showMeasured(
          tester,
          controller,
          threeHeights,
          behind: ['Hidden'],
        );
        expect(toastsOf(controller), hasLength(4));
        expect(h['Oldest'], greaterThan(h['Newest']!));
        expect(h['Newest'], greaterThan(h['Middle']!));

        await mouseAt(tester, boxOf(tester, 'Newest').center);
        await tester.pumpAndSettle();

        final newest = boxOf(tester, 'Newest');
        final middle = boxOf(tester, 'Middle');
        final oldest = boxOf(tester, 'Oldest');
        expect(newest.bottom, 576);
        expect(middle.bottom, moreOrLessEquals(576 - h['Newest']! - 14));
        expect(
          oldest.bottom,
          moreOrLessEquals(576 - h['Newest']! - h['Middle']! - 28),
        );
        for (final title in ['Newest', 'Middle', 'Oldest']) {
          expect(
            boxOf(tester, title).height,
            moreOrLessEquals(h[title]!),
            reason: '$title is drawn at its own height',
          );
          expect(
            toastRect(tester, title).size,
            _sizeCloseTo(boxOf(tester, title).size),
            reason: '$title is not scaled',
          );
        }
        expect(
          boxOf(tester, 'Hidden').bottom,
          moreOrLessEquals(
            576 - h['Newest']! - h['Middle']! - h['Oldest']! - 42,
          ),
          reason: 'beyond the window, and fanned out with the rest',
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets('at the top, the expanded deck fans out downward', (
      tester,
    ) async {
      final controller = SonnerController(
        config: const SonnerConfig(
          position: SonnerPosition.topLeft,
          duration: Duration.zero,
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller: controller));
      final h = await showMeasured(tester, controller, threeHeights);

      await mouseAt(tester, boxOf(tester, 'Newest').center);
      await tester.pumpAndSettle();

      expect(boxOf(tester, 'Newest').top, 24);
      expect(
        boxOf(tester, 'Middle').top,
        moreOrLessEquals(24 + h['Newest']! + 14),
      );
      expect(
        boxOf(tester, 'Oldest').top,
        moreOrLessEquals(24 + h['Newest']! + h['Middle']! + 28),
      );
    });

    testWidgets('moving away collapses the deck again', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      final h = await showMeasured(tester, controller, threeHeights);
      final mouse = await mouseAt(tester, boxOf(tester, 'Newest').center);
      await tester.pumpAndSettle();
      expect(
        boxOf(tester, 'Middle').bottom,
        moreOrLessEquals(576 - h['Newest']! - 14),
      );

      await mouse.moveTo(away);
      await tester.pumpAndSettle();

      expect(boxOf(tester, 'Middle').bottom, moreOrLessEquals(576 - 14));
      expect(boxOf(tester, 'Middle').height, moreOrLessEquals(h['Newest']!));
    });

    testWidgets('collapse and expand animate over 400 ms, ease', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      final h = await showMeasured(tester, controller, threeHeights);
      const collapsed = 576 - 14.0;
      final expanded = 576 - h['Newest']! - 14;

      final mouse = await mouseAt(tester, boxOf(tester, 'Newest').center);
      await tester.pump(const Duration(milliseconds: 200));
      // CSS `ease` at t = 0.5.
      expect(
        boxOf(tester, 'Middle').bottom,
        moreOrLessEquals(
          collapsed + (expanded - collapsed) * 0.8024,
          epsilon: 0.05,
        ),
      );
      expect(
        boxOf(tester, 'Middle').height,
        moreOrLessEquals(
          h['Newest']! + (h['Middle']! - h['Newest']!) * 0.8024,
          epsilon: 0.05,
        ),
        reason: 'from the front height toward its own',
      );
      expect(
        tester
            .widget<Transform>(
              find.ancestor(
                of: find.text('Middle'),
                matching: find.byType(Transform),
              ),
            )
            .transform
            .storage[0],
        moreOrLessEquals(1 - 0.05 * (1 - 0.8024), epsilon: 1e-4),
        reason: 'scale eases toward 1 on the same clock',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(boxOf(tester, 'Middle').bottom, moreOrLessEquals(expanded));

      await mouse.moveTo(away);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        boxOf(tester, 'Middle').bottom,
        moreOrLessEquals(
          expanded + (collapsed - expanded) * 0.8024,
          epsilon: 0.05,
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(boxOf(tester, 'Middle').bottom, moreOrLessEquals(collapsed));
    });

    testWidgets(
      'the pointer in a gap between two toasts keeps the deck expanded and '
      'paused',
      (tester) async {
        final controller = SonnerController(
          config: const SonnerConfig(duration: Duration(seconds: 1)),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(app(controller: controller));
        controller.show('Behind');
        controller.show('Front');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final mouse = await mouseAt(tester, boxOf(tester, 'Front').center);
        await tester.pump(const Duration(milliseconds: 400));
        final front = boxOf(tester, 'Front');
        final behind = boxOf(tester, 'Behind');
        expect(front.top - behind.bottom, moreOrLessEquals(14));

        await mouse.moveTo(Offset(front.center.dx, front.top - 7));
        await tester.pump(const Duration(seconds: 5));
        expect(boxOf(tester, 'Behind'), behind, reason: 'still expanded');
        expect(find.text('Front'), findsOneWidget, reason: 'still paused');

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
        await tester.pump(const Duration(seconds: 1));
        await tester.tapAt(Offset(front.center.dx, front.top - 7));
        expect(taps, 0, reason: 'a gap in the deck takes the tap');

        await mouse.moveTo(away);
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pumpAndSettle();
        expect(find.text('Front'), findsNothing, reason: 'resumed and expired');
      },
    );

    testWidgets(
      'expandByDefault fans the deck out without hover, and does not pause',
      (tester) async {
        final controller = SonnerController(
          config: const SonnerConfig(
            duration: Duration(seconds: 1),
            expandByDefault: true,
          ),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(app(controller: controller));
        controller.show('Behind');
        controller.show('Front', description: 'A second line');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final front = boxOf(tester, 'Front');
        expect(
          boxOf(tester, 'Behind').bottom,
          moreOrLessEquals(576 - front.height - 14),
        );
        expect(boxOf(tester, 'Behind').height, lessThan(front.height));

        await tester.pump(const Duration(milliseconds: 800));
        await tester.pumpAndSettle();
        expect(find.text('Front'), findsNothing, reason: 'it counted down');

        controller.show('Hovered');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await mouseAt(tester, boxOf(tester, 'Hovered').center);
        await tester.pump(const Duration(seconds: 3));
        expect(
          toastsOf(controller),
          hasLength(1),
          reason: 'the pointer still pauses',
        );
        controller.dismissAll();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'a toast whose height changes re-lays the expanded stack, easing the '
      'ones after it over 400 ms',
      (tester) async {
        await tester.pumpWidget(app(controller: controller));
        controller.show('Behind');
        final id = controller.show('Front');
        await tester.pumpAndSettle();
        await mouseAt(tester, boxOf(tester, 'Front').center);
        await tester.pumpAndSettle();
        final short = boxOf(tester, 'Front').height;

        controller.update(id, description: 'A second line');
        await tester.pump();
        final tall = boxOf(tester, 'A second line').height;
        expect(tall, greaterThan(short), reason: 'drawn at its new height');
        expect(
          boxOf(tester, 'Behind').bottom,
          moreOrLessEquals(576 - short - 14),
        );

        await tester.pump(const Duration(milliseconds: 200));
        expect(
          boxOf(tester, 'Behind').bottom,
          moreOrLessEquals(
            576 - (short + (tall - short) * 0.8024) - 14,
            epsilon: 0.05,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          boxOf(tester, 'Behind').bottom,
          moreOrLessEquals(576 - tall - 14),
        );
      },
    );

    testWidgets('a toast leaving the expanded deck keeps its place as the '
        'deck collapses', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Oldest');
      final middle = controller.show('Middle', description: 'A second line');
      controller.show('Newest');
      await tester.pumpAndSettle();
      final mouse = await mouseAt(tester, boxOf(tester, 'Newest').center);
      await tester.pumpAndSettle();
      final place = boxOf(tester, 'Middle');
      final oldest = boxOf(tester, 'Oldest').bottom;

      controller.dismiss(middle);
      await mouse.moveTo(away);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        boxOf(tester, 'Newest').bottom,
        576,
        reason: 'the front does not move',
      );
      expect(
        boxOf(tester, 'Oldest').bottom,
        greaterThan(oldest),
        reason: 'the deck is collapsing',
      );
      expect(boxOf(tester, 'Middle'), place);
      await tester.pumpAndSettle();
    });

    SonnerController expandedController() {
      final controller = SonnerController(
        config: const SonnerConfig(
          duration: Duration.zero,
          expandByDefault: true,
        ),
      );
      addTearDown(controller.dispose);
      return controller;
    }

    testWidgets(
      'a toast entering or leaving the expanded deck moves the ones behind '
      'on its own clock',
      (tester) async {
        final controller = expandedController();
        await tester.pumpWidget(app(controller: controller));
        controller.show('Behind');
        await tester.pumpAndSettle();

        final front = controller.show('Front', description: 'A second line');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final height = boxOf(tester, 'Front').height;
        // The enter's `ease` at t = 0.5.
        expect(
          boxOf(tester, 'Behind').bottom,
          moreOrLessEquals(576 - (height + 14) * 0.8024, epsilon: 0.05),
        );
        await tester.pumpAndSettle();
        expect(
          boxOf(tester, 'Behind').bottom,
          moreOrLessEquals(576 - height - 14),
        );

        controller.dismiss(front);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        // The exit runs the same `ease` backwards over 200 ms.
        expect(
          boxOf(tester, 'Behind').bottom,
          moreOrLessEquals(576 - (height + 14) * 0.8024, epsilon: 0.05),
        );
        await tester.pump(const Duration(milliseconds: 101));
        expect(boxOf(tester, 'Behind').bottom, moreOrLessEquals(576));
      },
    );

    testWidgets(
      'in the expanded deck a toast on its way back never comes forward, '
      'however the clocks mix',
      (tester) async {
        final controller = expandedController();
        await tester.pumpWidget(app(controller: controller));
        controller.show('A');
        final b = controller.show('B');
        await tester.pumpAndSettle();
        final bottoms = <double>[];

        controller.show('C');
        await tester.pump();
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          bottoms.add(boxOf(tester, 'A').bottom);
        }
        controller.dismiss(b);
        controller.show('D');
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          bottoms.add(boxOf(tester, 'A').bottom);
        }

        for (var i = 1; i < bottoms.length; i++) {
          expect(
            bottoms[i],
            lessThanOrEqualTo(bottoms[i - 1] + 1e-9),
            reason: 'frame $i',
          );
        }
      },
    );

    testWidgets(
      'dismissing the toast under a resting pointer keeps the deck expanded '
      'and paused',
      (tester) async {
        final controller = SonnerController(
          config: const SonnerConfig(duration: Duration(seconds: 1)),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(app(controller: controller));
        controller.show('Oldest');
        controller.show('Middle');
        final front = controller.show('Front');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await mouseAt(tester, boxOf(tester, 'Front').center);
        await tester.pump(const Duration(milliseconds: 400));

        controller.dismiss(front);
        for (var elapsed = 0; elapsed <= 600; elapsed += 16) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            scaleOf(tester, 'Oldest'),
            1,
            reason: 'still expanded at $elapsed ms',
          );
        }
        await tester.pump(const Duration(seconds: 2));
        expect(toastsOf(controller), hasLength(2), reason: 'still paused');
        controller.dismissAll();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'the last toast leaving under a resting pointer lets the timers go',
      (tester) async {
        final controller = SonnerController(
          config: const SonnerConfig(duration: Duration(seconds: 1)),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(app(controller: controller));
        controller.show('Behind');
        controller.show('Front');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final mouse = await mouseAt(tester, boxOf(tester, 'Front').center);
        await tester.pump(const Duration(milliseconds: 400));
        await mouse.moveTo(boxOf(tester, 'Behind').center);
        await tester.pump();

        controller.dismissAll();
        await tester.pumpAndSettle();
        controller.show('Next');
        await tester.pump(const Duration(milliseconds: 1200));
        expect(
          toastsOf(controller),
          isEmpty,
          reason: 'the pointer rests where no toast is any more',
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets('one mouse leaving does not release another still over it', (
      tester,
    ) async {
      final controller = SonnerController(
        config: const SonnerConfig(duration: Duration(seconds: 1)),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller: controller));
      controller.show('Saved');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final centre = boxOf(tester, 'Saved').center;
      final first = await mouseAt(tester, centre);
      final second = TestGesture(
        dispatcher: tester.sendEventToBinding,
        pointer: 2,
        kind: PointerDeviceKind.mouse,
        device: 2,
      );
      await second.addPointer(location: centre + const Offset(10, 0));
      addTearDown(second.removePointer);
      await tester.pump();

      await first.moveTo(away);
      await tester.pump(const Duration(seconds: 3));
      expect(toastsOf(controller), hasLength(1), reason: 'the other holds');
      controller.dismissAll();
      await tester.pumpAndSettle();
    });

    testWidgets('a single toast pauses under the pointer', (tester) async {
      final controller = SonnerController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller: controller));
      controller.show('Saved');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final mouse = await mouseAt(tester, boxOf(tester, 'Saved').center);
      await tester.pump(const Duration(seconds: 10));
      expect(toastsOf(controller), hasLength(1), reason: 'paused');

      await mouse.moveTo(away);
      await tester.pump(const Duration(milliseconds: 3000));
      expect(toastsOf(controller), hasLength(1), reason: 'time was left');
      await tester.pump(const Duration(milliseconds: 800));
      expect(toastsOf(controller), isEmpty, reason: 'resumed');
      await tester.pumpAndSettle();
    });

    testWidgets('a pointer resting away from the deck does not pause', (
      tester,
    ) async {
      final controller = SonnerController(
        config: const SonnerConfig(duration: Duration(seconds: 1)),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller: controller));
      await mouseAt(tester, away);
      controller.show('Saved');

      await tester.pump(const Duration(milliseconds: 1200));
      expect(toastsOf(controller), isEmpty);
      await tester.pumpAndSettle();
    });

    testWidgets('a host removed under the pointer lets the timers go', (
      tester,
    ) async {
      final controller = SonnerController(
        config: const SonnerConfig(duration: Duration(seconds: 1)),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller: controller));
      controller.show('Saved');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await mouseAt(tester, boxOf(tester, 'Saved').center);
      await tester.pump(const Duration(seconds: 2));
      expect(toastsOf(controller), hasLength(1));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1200));
      expect(toastsOf(controller), isEmpty);
    });

    testWidgets('a host handed another controller lets the first one go', (
      tester,
    ) async {
      final first = SonnerController(
        config: const SonnerConfig(duration: Duration(seconds: 1)),
      );
      addTearDown(first.dispose);
      await tester.pumpWidget(app(controller: first));
      first.show('Saved');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await mouseAt(tester, boxOf(tester, 'Saved').center);
      await tester.pump(const Duration(seconds: 2));
      expect(toastsOf(first), hasLength(1));

      await tester.pumpWidget(app(controller: controller));
      await tester.pump(const Duration(milliseconds: 1200));
      expect(toastsOf(first), isEmpty);
    });

    group('every toast while hovered', () {
      /// Shows [count] toasts, `Toast 0` the oldest, and returns the height
      /// each is drawn at.
      Future<double> showMany(
        WidgetTester tester,
        SonnerController controller,
        int count,
      ) async {
        for (var n = 0; n < count; n++) {
          controller.show('Toast $n');
        }
        await tester.pumpAndSettle();
        return boxOf(tester, 'Toast ${count - 1}').height;
      }

      /// Turns a mouse wheel at [at] by [delta].
      Future<void> wheel(WidgetTester tester, Offset at, Offset delta) async {
        final wheel = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(wheel.hover(at));
        await tester.sendEventToBinding(wheel.scroll(delta));
      }

      bool drawn(String title) => find.text(title).evaluate().isNotEmpty;

      testWidgets('hovering fans out the toasts beyond visibleToasts too, and '
          'leaving hides them again', (tester) async {
        await tester.pumpWidget(app(controller: controller));
        final height = await showMany(tester, controller, 5);
        expect(drawn('Toast 1'), isFalse);

        final mouse = await mouseAt(tester, boxOf(tester, 'Toast 4').center);
        await tester.pumpAndSettle();
        for (var n = 0; n < 5; n++) {
          expect(
            boxOf(tester, 'Toast $n').bottom,
            moreOrLessEquals(576 - (4 - n) * (height + 14)),
            reason: 'Toast $n',
          );
          expect(paintedOpacityOf(tester, 'Toast $n'), 1, reason: 'Toast $n');
        }

        await mouse.moveTo(away);
        await tester.pumpAndSettle();
        expect(drawn('Toast 0'), isFalse);
        expect(drawn('Toast 1'), isFalse);
        expect(drawn('Toast 2'), isTrue);
      });

      testWidgets('a toast revealed by hover takes taps and keeps the deck '
          'paused under the pointer', (tester) async {
        final controller = SonnerController(
          config: const SonnerConfig(duration: Duration(seconds: 1)),
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
        for (var n = 0; n < 5; n++) {
          controller.show('Toast $n');
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final mouse = await mouseAt(tester, boxOf(tester, 'Toast 4').center);
        await tester.pump(const Duration(milliseconds: 400));

        await mouse.moveTo(boxOf(tester, 'Toast 0').center);
        await tester.pump(const Duration(seconds: 3));
        expect(toastsOf(controller), hasLength(5), reason: 'still paused');

        await tester.tapAt(boxOf(tester, 'Toast 0').center);
        expect(taps, 0, reason: 'the revealed toast takes the tap');
        final hit = HitTestResult();
        tester.binding.hitTestInView(
          hit,
          boxOf(tester, 'Toast 0').center,
          tester.view.viewId,
        );
        expect(
          hit.path.map((entry) => entry.target),
          contains(tester.renderObject(find.text('Toast 0'))),
          reason: 'the toast itself, not only the deck region',
        );

        await mouse.moveTo(away);
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pumpAndSettle();
        expect(toastsOf(controller), isEmpty);
      });

      testWidgets(
        'expandByDefault draws only visibleToasts until hovered, then fades '
        'the rest in over 400 ms',
        (tester) async {
          final controller = expandedController();
          await tester.pumpWidget(app(controller: controller));
          await showMany(tester, controller, 5);
          expect(drawn('Toast 0'), isFalse);
          expect(drawn('Toast 2'), isTrue);

          final mouse = await mouseAt(tester, boxOf(tester, 'Toast 4').center);
          await tester.pump(const Duration(milliseconds: 200));
          expect(paintedOpacityOf(tester, 'Toast 0'), inExclusiveRange(0, 1));
          await tester.pump(const Duration(milliseconds: 201));
          expect(paintedOpacityOf(tester, 'Toast 0'), 1);

          await mouse.moveTo(away);
          await tester.pumpAndSettle();
          expect(drawn('Toast 0'), isFalse);
          expect(drawn('Toast 2'), isTrue);
        },
      );

      testWidgets('a toast is in the semantics tree while it is drawn', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(app(controller: controller));
        await showMany(tester, controller, 4);
        expect(find.bySemanticsLabel('Toast 0'), findsNothing);

        final mouse = await mouseAt(tester, boxOf(tester, 'Toast 3').center);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Toast 0'), findsOneWidget);

        await mouse.moveTo(away);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Toast 0'), findsNothing);
        semantics.dispose();
      });

      testWidgets('toasts that do not fit scroll with the wheel, and stop at '
          'the oldest', (tester) async {
        await tester.pumpWidget(app(controller: controller));
        final height = await showMany(tester, controller, 12);
        final at = boxOf(tester, 'Toast 11').center;
        await mouseAt(tester, at);
        await tester.pumpAndSettle();
        expect(boxOf(tester, 'Toast 11').bottom, 576);
        expect(boxOf(tester, 'Toast 0').top, lessThan(0));

        await wheel(tester, at, const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(boxOf(tester, 'Toast 11').bottom, moreOrLessEquals(676));
        expect(
          boxOf(tester, 'Toast 0').top,
          moreOrLessEquals(676 - 12 * height - 11 * 14),
        );

        await wheel(tester, at, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(
          boxOf(tester, 'Toast 0').top,
          moreOrLessEquals(24),
          reason: 'the oldest stops at the far offset',
        );

        final gap = Offset(at.dx, boxOf(tester, 'Toast 5').top - 7);
        final before = boxOf(tester, 'Toast 5').top;
        await wheel(tester, gap, const Offset(0, 50));
        await tester.pumpAndSettle();
        expect(
          boxOf(tester, 'Toast 5').top,
          moreOrLessEquals(before - 50),
          reason: 'a gap between two toasts takes the wheel',
        );
      });

      testWidgets(
        'toasts more than 20 deep never scale past nothing as the deck '
        'collapses',
        (tester) async {
          await tester.pumpWidget(app(controller: controller));
          await showMany(tester, controller, 25);
          final mouse = await mouseAt(tester, boxOf(tester, 'Toast 24').center);
          await tester.pumpAndSettle();

          await mouse.moveTo(away);
          await tester.pump();
          // Late in the collapse, where 1 − 0.05 × 24 × 0.98 would be −0.18.
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.text('Toast 0'), findsOneWidget, reason: 'still drawn');
          for (final transform in tester.widgetList<Transform>(
            find.byType(Transform, skipOffstage: false),
          )) {
            expect(transform.transform.storage[0], greaterThanOrEqualTo(0));
          }
          await tester.pumpAndSettle();
        },
      );

      testWidgets('at the top, the wheel scrolls the other way', (
        tester,
      ) async {
        final controller = SonnerController(
          config: const SonnerConfig(
            duration: Duration.zero,
            position: SonnerPosition.topRight,
          ),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(app(controller: controller));
        await showMany(tester, controller, 12);
        final at = boxOf(tester, 'Toast 11').center;
        await mouseAt(tester, at);
        await tester.pumpAndSettle();
        expect(boxOf(tester, 'Toast 11').top, 24);

        await wheel(tester, at, const Offset(0, 100));
        await tester.pumpAndSettle();
        expect(boxOf(tester, 'Toast 11').top, moreOrLessEquals(-76));
      });

      testWidgets('a trackpad pan scrolls the deck', (tester) async {
        await tester.pumpWidget(app(controller: controller));
        await showMany(tester, controller, 12);
        final at = boxOf(tester, 'Toast 11').center;
        await mouseAt(tester, at);
        await tester.pumpAndSettle();

        final trackpad = TestPointer(2, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(trackpad.panZoomStart(at));
        for (var i = 1; i <= 6; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.sendEventToBinding(
            trackpad.panZoomUpdate(at, pan: Offset(0, 10.0 * i)),
          );
        }
        await tester.sendEventToBinding(trackpad.panZoomEnd());
        await tester.pumpAndSettle();
        expect(boxOf(tester, 'Toast 11').bottom, greaterThan(576));
      });

      testWidgets(
        'leaving eases the scroll back to the edge with the collapse, and the '
        'next hover starts there',
        (tester) async {
          await tester.pumpWidget(app(controller: controller));
          await showMany(tester, controller, 12);
          final at = boxOf(tester, 'Toast 11').center;
          final mouse = await mouseAt(tester, at);
          await tester.pumpAndSettle();
          await wheel(tester, at, const Offset(0, -100));
          await tester.pumpAndSettle();
          expect(boxOf(tester, 'Toast 11').bottom, moreOrLessEquals(676));

          await mouse.moveTo(away);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(
            boxOf(tester, 'Toast 11').bottom,
            // The collapse's `ease` at t = 0.5.
            moreOrLessEquals(576 + 100 * (1 - 0.8024), epsilon: 0.05),
          );
          await tester.pumpAndSettle();
          expect(boxOf(tester, 'Toast 11').bottom, 576);

          await mouse.moveTo(at);
          await tester.pumpAndSettle();
          expect(boxOf(tester, 'Toast 11').bottom, 576);
        },
      );

      /// Hovers 12 toasts scrolled by [scrolled], makes [change], and expects
      /// `Toast 6`, which is in view, not to move in any frame.
      Future<void> expectReadInPlace(
        WidgetTester tester, {
        required double scrolled,
        required void Function() change,
      }) async {
        await tester.pumpWidget(app(controller: controller));
        await showMany(tester, controller, 12);
        final at = boxOf(tester, 'Toast 11').center;
        await mouseAt(tester, at);
        await tester.pumpAndSettle();
        await wheel(tester, at, Offset(0, -scrolled));
        await tester.pumpAndSettle();
        final read = boxOf(tester, 'Toast 6');

        change();
        await tester.pump();
        for (var elapsed = 0; elapsed <= 500; elapsed += 16) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            boxOf(tester, 'Toast 6').top,
            moreOrLessEquals(read.top, epsilon: 0.5),
            reason: 'at $elapsed ms',
          );
        }
        await tester.pumpAndSettle();
        expect(boxOf(tester, 'Toast 6'), rectMoreOrLessEquals(read));
      }

      testWidgets('a toast shown while scrolled keeps the toasts being read in '
          'place', (tester) async {
        await expectReadInPlace(
          tester,
          scrolled: 100,
          change: () => controller.show('New'),
        );
        expect(boxOf(tester, 'New').top, greaterThan(576));
      });

      testWidgets('a toast shown at the edge of an overflowing deck keeps the '
          'toasts being read in place', (tester) async {
        await expectReadInPlace(
          tester,
          scrolled: 0,
          change: () => controller.show('New'),
        );
        expect(boxOf(tester, 'New').top, greaterThan(576));
      });

      testWidgets('the toasts being read stay in place as the toast they were '
          'kept by leaves', (tester) async {
        await expectReadInPlace(
          tester,
          scrolled: 100,
          // Toast 10, the first toast reaching into view.
          change: () => controller.dismiss(toastsOf(controller)[1].id),
        );
      });

      testWidgets('the toasts being read stay in place as a toast out of view '
          'grows', (tester) async {
        await expectReadInPlace(
          tester,
          scrolled: 100,
          change: () => controller.update(
            toastsOf(controller).first.id,
            description: 'One\nTwo\nThree',
          ),
        );
      });

      testWidgets('dismissing the farthest toast at the end of the scroll '
          'eases the deck toward it', (tester) async {
        await tester.pumpWidget(app(controller: controller));
        await showMany(tester, controller, 12);
        final at = boxOf(tester, 'Toast 11').center;
        await mouseAt(tester, at);
        await tester.pumpAndSettle();
        await wheel(tester, at, const Offset(0, -2000));
        await tester.pumpAndSettle();
        final start = boxOf(tester, 'Toast 5').top;

        controller.dismiss(toastsOf(controller).last.id);
        var previous = start;
        for (var elapsed = 0; elapsed <= 300; elapsed += 16) {
          await tester.pump(const Duration(milliseconds: 16));
          final top = boxOf(tester, 'Toast 5').top;
          expect(
            (top - previous).abs(),
            // A 66 px reach given back on the exit's 200 ms `ease`, not in
            // one frame.
            lessThan(15),
            reason: 'at $elapsed ms',
          );
          previous = top;
        }
        await tester.pumpAndSettle();
        final height = boxOf(tester, 'Toast 5').height;
        expect(
          boxOf(tester, 'Toast 5').top,
          moreOrLessEquals(start - height - 14),
          reason: 'the scroll ends a toast and a gap sooner',
        );
      });

      testWidgets('a pointer resting in the far margin stays over the deck as '
          'it scrolls to the end', (tester) async {
        await tester.pumpWidget(app(controller: controller));
        await showMany(tester, controller, 12);
        final front = boxOf(tester, 'Toast 11').center;
        final mouse = await mouseAt(tester, front);
        await tester.pumpAndSettle();
        final margin = Offset(front.dx, 10);
        await mouse.moveTo(margin);
        await tester.pumpAndSettle();

        for (var n = 0; n < 4; n++) {
          await wheel(tester, margin, const Offset(0, -100));
          await tester.pumpAndSettle();
        }
        expect(boxOf(tester, 'Toast 0').top, moreOrLessEquals(24));
        expect(boxOf(tester, 'Toast 11').bottom, greaterThan(576));
      });

      testWidgets('a host handed another controller draws its deck at the '
          'edge', (tester) async {
        await tester.pumpWidget(app(controller: controller));
        await showMany(tester, controller, 12);
        final at = boxOf(tester, 'Toast 11').center;
        await mouseAt(tester, at);
        await tester.pumpAndSettle();
        await wheel(tester, at, const Offset(0, -300));
        await tester.pumpAndSettle();

        final other = SonnerController(
          config: const SonnerConfig(duration: Duration.zero),
        );
        addTearDown(other.dispose);
        for (var n = 0; n < 14; n++) {
          other.show('Other $n');
        }
        await tester.pumpWidget(app(controller: other));
        await tester.pumpAndSettle();
        expect(boxOf(tester, 'Other 13').bottom, 576);
      });

      testWidgets('without a pointer, an expandByDefault deck taller than the '
          'layer leaves the margins to the app', (tester) async {
        tester.view.physicalSize = const Size(800, 220);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final controller = SonnerController(
          config: const SonnerConfig(
            duration: Duration(seconds: 1),
            expandByDefault: true,
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
        for (var n = 0; n < 3; n++) {
          controller.show('Toast $n');
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final column = boxOf(tester, 'Toast 2').center.dx;
        expect(boxOf(tester, 'Toast 0').top, lessThan(24), reason: 'overflows');

        await tester.tapAt(Offset(column, 5));
        expect(taps, 1, reason: 'the margin above the deck is the app');

        await mouseAt(tester, Offset(column, 5));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(toastsOf(controller), isEmpty, reason: 'nothing paused them');
      });

      testWidgets('hovering and scrolling the deck tell the app nothing about '
          'scrolling', (tester) async {
        var notifications = 0;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => NotificationListener<Notification>(
              onNotification: (notification) {
                if (notification is ScrollNotification ||
                    notification is ScrollMetricsNotification) {
                  notifications++;
                }
                return false;
              },
              child: SonnerHost(controller: controller, child: child!),
            ),
            home: const SizedBox.expand(),
          ),
        );
        await showMany(tester, controller, 12);
        final at = boxOf(tester, 'Toast 11').center;
        await mouseAt(tester, at);
        await tester.pumpAndSettle();
        await wheel(tester, at, const Offset(0, -100));
        await tester.pumpAndSettle();

        expect(boxOf(tester, 'Toast 11').bottom, moreOrLessEquals(676));
        expect(notifications, 0);
      });

      testWidgets(
        'a toast dismissed while scrolled stays where it is on screen as the '
        'deck scrolls under it',
        (tester) async {
          await tester.pumpWidget(app(controller: controller));
          await showMany(tester, controller, 12);
          final at = boxOf(tester, 'Toast 11').center;
          await mouseAt(tester, at);
          await tester.pumpAndSettle();
          await wheel(tester, at, const Offset(0, -100));
          await tester.pumpAndSettle();

          controller.dismiss(toastsOf(controller)[5].id);
          await tester.pump();
          final place = boxOf(tester, 'Toast 6');
          final neighbour = boxOf(tester, 'Toast 7').top;
          await wheel(tester, at, const Offset(0, -50));
          await tester.pump(const Duration(milliseconds: 16));
          expect(boxOf(tester, 'Toast 6').top, moreOrLessEquals(place.top));
          expect(
            boxOf(tester, 'Toast 7').top,
            isNot(moreOrLessEquals(neighbour)),
          );
          await tester.pumpAndSettle();
        },
      );
    });
  });

  group('a lifecycle state a test leaves behind', () {
    // Outlives the tests, as the exported `toast` does.
    final shared = SonnerController(
      config: const SonnerConfig(duration: Duration(seconds: 1)),
    );
    tearDownAll(shared.dispose);

    testWidgets('is left hidden by one test', (tester) async {
      await tester.pumpWidget(app(controller: shared));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    });

    testWidgets('does not hold the timers of the next', (tester) async {
      expect(
        tester.binding.lifecycleState,
        isNot(AppLifecycleState.hidden),
        reason: 'the binding reset it between the tests, telling nobody',
      );
      await tester.pumpWidget(app(controller: shared));
      shared.show('Saved');

      await tester.pump(const Duration(milliseconds: 1200));
      expect(toastsOf(shared), isEmpty);
      await tester.pumpAndSettle();
    });
  });

  group('lifecycle', () {
    tearDown(
      () => TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );

    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      testWidgets('timers pause while the app is ${state.name}', (
        tester,
      ) async {
        final controller = SonnerController(
          config: const SonnerConfig(duration: Duration(seconds: 1)),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(app(controller: controller));
        controller.show('Saved');
        await tester.pump(const Duration(milliseconds: 500));

        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump(const Duration(seconds: 10));
        expect(toastsOf(controller), hasLength(1));

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(toastsOf(controller), hasLength(1), reason: 'time was left');
        await tester.pump(const Duration(milliseconds: 300));
        expect(toastsOf(controller), isEmpty);
        await tester.pumpAndSettle();
      });
    }

    testWidgets('timers do not pause while the app is inactive', (
      tester,
    ) async {
      final controller = SonnerController(
        config: const SonnerConfig(duration: Duration(seconds: 1)),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller: controller));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      controller.show('Saved');

      await tester.pump(const Duration(milliseconds: 1200));
      expect(toastsOf(controller), isEmpty);
      await tester.pumpAndSettle();
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
    'a toast beyond the window joins the semantics tree as a live region '
    'when it reaches the window',
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
    expect(presenceOf(tester, 'Saved'), 1, reason: 'on screen, not exiting');

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      presenceOf(tester, 'Saved'),
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

/// How far [title]'s toast has entered or exited, 0 to 1: the fade of its slot,
/// not of the content inside it.
double presenceOf(WidgetTester tester, String title) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.ancestor(
              of: find.text(title),
              matching: find.byType(SlideTransition),
            ),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

/// Records each time its State is created.
class _Tracked extends StatefulWidget {
  const _Tracked({super.key, required this.name, required this.inits});

  final String name;
  final List<String> inits;

  @override
  State<_Tracked> createState() => _TrackedState();
}

class _TrackedState extends State<_Tracked> {
  @override
  void initState() {
    super.initState();
    widget.inits.add(widget.name);
  }

  @override
  Widget build(BuildContext context) => Text(widget.name);
}
