import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_sonner/just_sonner.dart';
import 'package:just_sonner/src/content_fade.dart';
import 'package:just_sonner/src/controller.dart' show timersPaused, toastsOf;
import 'package:just_sonner/src/deck_backdrop.dart' show DeckBackdropBox;
import 'package:just_sonner/src/host.dart' show DeckHitBox;
import 'package:just_sonner/src/deck_layout.dart' show ToastHeight;
import 'package:just_sonner/src/deck_stow.dart';
import 'package:just_sonner/src/deck_dismiss_all.dart';
import 'package:just_sonner/src/deck_scrollbar.dart';
import 'package:just_sonner/src/default_look.dart' show DefaultToastLook;
import 'package:just_sonner/src/time_left.dart';

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

  /// Builds the page of [rebuildingApp] again.
  late void Function() rebuild;

  /// An app like [app] whose page runs [duringBuild] while it builds the
  /// second time, once [rebuild] asks for it.
  Widget rebuildingApp(void Function() duringBuild) {
    var builds = 0;
    return MaterialApp(
      builder: (context, child) =>
          SonnerHost(controller: controller, child: child!),
      home: StatefulBuilder(
        builder: (context, setState) {
          rebuild = () => setState(() {});
          if (++builds == 2) duringBuild();
          return const SizedBox.expand();
        },
      ),
    );
  }

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

  double scaleOf(WidgetTester tester, String title) => tester
      .widget<Transform>(
        find.ancestor(of: find.text(title), matching: find.byType(Transform)),
      )
      .transform
      .storage[0];

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
          offset: EdgeInsets.all(40),
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

    for (final position in SonnerPosition.values) {
      testWidgets('each edge’s offset holds the toast off that edge alone, and '
          'a centered one reads neither side, $position', (tester) async {
        final controller = SonnerController(
          config: SonnerConfig(
            position: position,
            offset: const EdgeInsets.fromLTRB(19, 11, 13, 17),
            duration: Duration.zero,
          ),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(app(controller: controller));

        controller.show('Saved');
        await tester.pumpAndSettle();

        final rect = toastRect(tester, 'Saved');
        switch (position) {
          case SonnerPosition.topLeft || SonnerPosition.bottomLeft:
            expect(rect.left, 19);
          case SonnerPosition.topRight || SonnerPosition.bottomRight:
            expect(rect.right, 800 - 13);
          case SonnerPosition.topCenter || SonnerPosition.bottomCenter:
            expect(rect.center.dx, 400);
        }
        if (position.isTop) {
          expect(rect.top, 11);
        } else {
          expect(rect.bottom, 600 - 17);
        }
      });
    }
  });

  group('leading slot', () {
    /// The box the slot is drawn in, or null when the toast has no slot.
    Rect? slotOf(WidgetTester tester, String title) {
      final card = find
          .ancestor(of: find.text(title), matching: find.byType(Material))
          .first;
      final slot = find.descendant(of: card, matching: find.byType(SizedBox));
      final boxes = tester
          .widgetList<SizedBox>(slot)
          .where((box) => box.width != null && box.width == box.height);
      if (boxes.isEmpty) return null;
      return tester.getRect(
        find
            .descendant(
              of: card,
              matching: find.byWidgetPredicate(
                (w) => w is SizedBox && w.width != null && w.width == w.height,
              ),
            )
            .first,
      );
    }

    double titleLeftOf(WidgetTester tester, String title) =>
        tester.getRect(find.text(title)).left;

    testWidgets('a toast with neither leading nor isLoading has no slot, and '
        'its title starts at the padding edge', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Bare');
      await tester.pumpAndSettle();

      expect(slotOf(tester, 'Bare'), isNull);
      final card = tester.getRect(
        find
            .ancestor(of: find.text('Bare'), matching: find.byType(Material))
            .first,
      );
      expect(titleLeftOf(tester, 'Bare'), moreOrLessEquals(card.left + 16));
    });

    testWidgets('leading places the caller’s widget before the title', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Saved', leading: const Icon(Icons.check));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
      final slot = slotOf(tester, 'Saved')!;
      expect(slot.right, lessThanOrEqualTo(titleLeftOf(tester, 'Saved')));
      final card = tester.getRect(
        find
            .ancestor(of: find.text('Saved'), matching: find.byType(Material))
            .first,
      );
      expect(slot.left, moreOrLessEquals(card.left + 16));
    });

    testWidgets('the slot is a fixed square of config.leadingSize, whatever it '
        'holds', (tester) async {
      final wide = SonnerController(
        config: const SonnerConfig(duration: Duration.zero, leadingSize: 20),
      );
      addTearDown(wide.dispose);
      await tester.pumpWidget(app(controller: wide));
      // A widget that would take the whole width if the slot let it.
      wide.show('Stretchy', leading: const SizedBox(width: 400, height: 400));
      await tester.pumpAndSettle();

      expect(slotOf(tester, 'Stretchy')!.size, const Size(20, 20));
    });

    testWidgets('while isLoading the slot holds the config indicator instead '
        'of leading', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      final id = controller.show(
        'Uploading',
        isLoading: true,
        leading: const Icon(Icons.check),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.byIcon(Icons.check),
        findsNothing,
        reason: 'the indicator wins',
      );
      expect(slotOf(tester, 'Uploading')!.size, const Size(20, 20));

      controller.update(id, isLoading: false);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.byIcon(Icons.check),
        findsOneWidget,
        reason: 'the leading widget it kept all along comes back',
      );
    });

    testWidgets('a covered toast draws no slot either', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Behind', isLoading: true);
      controller.show('Front');
      // Not pumpAndSettle: the indicator never settles (see the note on
      // SonnerConfig.loadingIndicator).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason: 'still in the tree, and still a live region',
      );
      expect(
        contentOpacityOf(tester, 'Behind'),
        0,
        reason: 'the slot rides the same fade as the rest of the content',
      );
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

    testWidgets('a taller toast behind is clipped at the front height, and '
        'takes no taps below it', (tester) async {
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

    testWidgets('a taller toast behind is laid out at the front height, so '
        'its whole card is drawn there', (tester) async {
      final controller = SonnerController(
        config: const SonnerConfig(
          position: SonnerPosition.topLeft,
          duration: Duration.zero,
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller: controller));
      controller.show('Tall', description: 'One\nTwo\nThree\nFour\nFive');
      controller.show('Short');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'the look fits');
      expect(
        toastRect(tester, 'Tall').height,
        moreOrLessEquals(toastRect(tester, 'Short').height * 0.95),
        reason: 'the card itself, not only the box it is cut to',
      );
    });

    testWidgets('the default look reports no overflow while a taller toast '
        'behind eases to the height of a shorter one entering', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Tall', description: 'One\nTwo\nThree\nFour\nFive');
      await tester.pumpAndSettle();
      final natural = toastRect(tester, 'Tall').height;

      controller.show('Short');
      await tester.pump();
      var eased = false;
      for (var elapsed = 0; elapsed <= 400; elapsed += 40) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull, reason: 'at $elapsed ms');
        final height = toastRect(tester, 'Tall').height;
        if (height < natural * 0.95 - 1 && height > 0) eased = true;
      }
      expect(eased, isTrue, reason: 'the card went below its own height');
      await tester.pumpAndSettle();
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

    testWidgets('the cards behind the front are not faded', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      for (var n = 0; n < 3; n++) {
        controller.show('Toast $n');
      }
      await tester.pumpAndSettle();

      for (var n = 0; n < 3; n++) {
        expect(paintedOpacityOf(tester, 'Toast $n'), 1, reason: 'Toast $n');
      }
    });

    testWidgets('a covered toast draws no content, so a taller one behind a '
        'shorter front shows no sliced description', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Tall', description: 'A second line, making it taller');
      controller.show('Short');
      await tester.pumpAndSettle();

      expect(contentOpacityOf(tester, 'Short'), 1, reason: 'the front reads');
      expect(contentOpacityOf(tester, 'Tall'), 0);
      expect(
        contentOpacityOf(tester, 'A second line, making it taller'),
        0,
        reason: 'the description the front cuts through is not drawn at all',
      );
      expect(
        paintedOpacityOf(tester, 'Tall'),
        1,
        reason: 'its card still shows, so the deck is a pile of cards',
      );
    });

    testWidgets('the content of the toast behind fades out over the 400 ms the '
        'new front takes to enter', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Tall', description: 'A second line, making it taller');
      await tester.pumpAndSettle();
      expect(contentOpacityOf(tester, 'Tall'), 1);

      controller.show('Short');
      await tester.pump();

      // The frames where the entering toast is still see-through are the ones
      // that showed two sets of text on top of each other.
      var last = 1.0;
      for (final step in [100, 100, 100]) {
        await tester.pump(Duration(milliseconds: step));
        final behind = contentOpacityOf(tester, 'Tall');
        expect(behind, lessThan(last), reason: 'it keeps fading');
        expect(
          behind,
          moreOrLessEquals(
            1 - paintedOpacityOf(tester, 'Short'),
            epsilon: 1e-9,
          ),
          reason:
              'a crossfade on one clock: what the front has still to gain '
              'is what the one behind has still to lose, so the text you can '
              'see through the front is never more than the text it hides',
        );
        last = behind;
      }

      await tester.pumpAndSettle();
      expect(contentOpacityOf(tester, 'Tall'), 0);
    });

    testWidgets('a toast brought back to the front draws its content again', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Behind');
      final front = controller.show('Front');
      await tester.pumpAndSettle();
      expect(contentOpacityOf(tester, 'Behind'), 0);

      controller.dismiss(front);
      await tester.pump();
      expect(
        contentOpacityOf(tester, 'Behind'),
        0,
        reason: 'the exit has not moved yet, so it is still covered',
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(contentOpacityOf(tester, 'Behind'), inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(contentOpacityOf(tester, 'Behind'), 1);
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

    testWidgets('a lowered visibleToasts stops drawing the toasts beyond it, '
        'and a raised one draws them again', (tester) async {
      var taps = 0;
      await tester.pumpWidget(tappableApp(() => taps++));
      for (var n = 0; n < 3; n++) {
        controller.show('Toast $n');
      }
      await tester.pumpAndSettle();
      final height = toastRect(tester, 'Toast 2').height;

      controller.config = controller.config.copyWith(visibleToasts: 1);
      await tester.pumpAndSettle();
      expect(find.text('Toast 1'), findsNothing, reason: 'not drawn');
      expect(toastsOf(controller), hasLength(3), reason: 'still in the list');
      await tester.tapAt(Offset(600, peekOf(1, height)));
      expect(taps, 1, reason: 'the second toast is out of the window');

      controller.config = controller.config.copyWith(visibleToasts: 3);
      await tester.pumpAndSettle();
      expect(find.text('Toast 1'), findsOneWidget);
      expect(find.text('Toast 0'), findsOneWidget);
      await tester.tapAt(Offset(600, peekOf(2, height)));
      expect(taps, 1, reason: 'the third toast is back in the window');
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
                of: _cardOf(title),
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

    /// A mouse moved to [at] and resting there, taken away when the test
    /// ends. It arrives by a move, since a pointer the deck merely appears
    /// under is not over it.
    Future<TestGesture> mouseAt(WidgetTester tester, Offset at) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: at - const Offset(1, 0));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(at);
      await tester.pump();
      return mouse;
    }

    const away = Offset(40, 40);

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

    testWidgets('the expanded deck draws the content of every toast, and hides '
        'it again as it collapses', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Behind', description: 'A second line');
      controller.show('Front');
      await tester.pumpAndSettle();
      expect(contentOpacityOf(tester, 'Behind'), 0);

      final mouse = await mouseAt(tester, boxOf(tester, 'Front').center);
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        contentOpacityOf(tester, 'Behind'),
        inExclusiveRange(0, 1),
        reason: 'it comes back with the fan-out, not at the end of it',
      );

      await tester.pumpAndSettle();
      expect(contentOpacityOf(tester, 'Behind'), 1);
      expect(
        contentOpacityOf(tester, 'A second line'),
        1,
        reason: 'expanded, every toast is drawn at its own height to be read',
      );

      await mouse.moveTo(away);
      await tester.pumpAndSettle();
      expect(contentOpacityOf(tester, 'Behind'), 0);
    });

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

    testWidgets('expandByDefault assigned with toasts on screen fans the deck '
        'out over 400 ms, with no pointer', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Behind');
      controller.show('Front');
      await tester.pumpAndSettle();
      final height = boxOf(tester, 'Front').height;
      const collapsed = 576 - 14.0;
      final expanded = 576 - height - 14;
      expect(boxOf(tester, 'Behind').bottom, moreOrLessEquals(collapsed));

      controller.config = controller.config.copyWith(expandByDefault: true);
      await tester.pump();
      expect(
        boxOf(tester, 'Behind').bottom,
        moreOrLessEquals(collapsed),
        reason: 'no jump in the frame it is assigned',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        boxOf(tester, 'Behind').bottom,
        allOf(lessThan(collapsed - 1), greaterThan(expanded + 1)),
        reason: 'on its way',
      );
      await tester.pump(const Duration(milliseconds: 201));
      expect(boxOf(tester, 'Behind').bottom, moreOrLessEquals(expanded));
      expect(presenceOf(tester, 'Front'), 1, reason: 'nothing entered again');

      controller.config = controller.config.copyWith(expandByDefault: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 401));
      expect(boxOf(tester, 'Behind').bottom, moreOrLessEquals(collapsed));
    });

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
      await second.addPointer(location: centre + const Offset(9, 0));
      addTearDown(second.removePointer);
      await second.moveTo(centre + const Offset(10, 0));
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

    group('a pointer the deck appears under', () {
      /// Where the front toast is drawn, found with a toast that is gone
      /// again by the time this returns.
      Future<Offset> frontCentre(
        WidgetTester tester,
        SonnerController controller,
      ) async {
        controller.show('Measure', duration: Duration.zero);
        await tester.pumpAndSettle();
        final centre = boxOf(tester, 'Measure').center;
        controller.dismissAll();
        await tester.pumpAndSettle();
        return centre;
      }

      /// A mouse added at [at] that has not moved, taken away when the test
      /// ends.
      Future<TestPointer> stillMouseAt(WidgetTester tester, Offset at) async {
        final mouse = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(mouse.addPointer(location: at));
        addTearDown(() => tester.sendEventToBinding(mouse.removePointer()));
        await tester.pump();
        return mouse;
      }

      Future<SonnerController> twoUnder(WidgetTester tester) async {
        final controller = SonnerController(
          config: const SonnerConfig(duration: Duration(seconds: 1)),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(app(controller: controller));
        final at = await frontCentre(tester, controller);
        await stillMouseAt(tester, at);
        controller.show('Behind');
        controller.show('Front');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        return controller;
      }

      testWidgets('counts down, and the deck stays collapsed, until it moves', (
        tester,
      ) async {
        final controller = await twoUnder(tester);
        expect(scaleOf(tester, 'Behind'), lessThan(1), reason: 'collapsed');

        await tester.pump(const Duration(milliseconds: 800));
        expect(toastsOf(controller), isEmpty, reason: 'not paused');
        await tester.pumpAndSettle();
      });

      for (final (act, how) in [
        (
          'moves',
          (TestPointer mouse, Offset at) => [
            mouse.hover(at + const Offset(1, 0)),
          ],
        ),
        (
          'presses',
          (TestPointer mouse, Offset at) => [mouse.down(at), mouse.up()],
        ),
        (
          'scrolls',
          (TestPointer mouse, Offset at) => [mouse.scroll(const Offset(0, 20))],
        ),
      ]) {
        testWidgets('fans out and pauses once it $act', (tester) async {
          final controller = SonnerController(
            config: const SonnerConfig(duration: Duration(seconds: 1)),
          );
          addTearDown(controller.dispose);
          await tester.pumpWidget(app(controller: controller));
          final at = await frontCentre(tester, controller);
          final mouse = await stillMouseAt(tester, at);
          controller.show('Behind');
          controller.show('Front');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          for (final event in how(mouse, at)) {
            await tester.sendEventToBinding(event);
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(scaleOf(tester, 'Behind'), 1, reason: 'expanded');
          await tester.pump(const Duration(seconds: 3));
          expect(toastsOf(controller), hasLength(2), reason: 'paused');

          controller.dismissAll();
          await tester.pumpAndSettle();
        });
      }

      testWidgets(
        'includes a pointer that was over the deck before it went away',
        (tester) async {
          final controller = SonnerController(
            config: const SonnerConfig(duration: Duration(seconds: 1)),
          );
          addTearDown(controller.dispose);
          await tester.pumpWidget(app(controller: controller));
          controller.show('First');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await mouseAt(tester, boxOf(tester, 'First').center);
          await tester.pump(const Duration(seconds: 2));
          expect(toastsOf(controller), hasLength(1), reason: 'paused');

          controller.dismissAll();
          await tester.pumpAndSettle();
          controller.show('Next');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1200));
          expect(toastsOf(controller), isEmpty, reason: 'not paused');
          await tester.pumpAndSettle();
        },
      );
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

      testWidgets('with no cap, toasts that do not fit the layer scroll with '
          'the wheel, and stop at the oldest', (tester) async {
        controller.config = controller.config.copyWith(deckCap: () => null);
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

      testWidgets('a wheel turned while the deck fans out scrolls it by the '
          'turn, and the fan-out carries on under it', (tester) async {
        await tester.pumpWidget(app(controller: controller));
        await showMany(tester, controller, 12);
        final at = boxOf(tester, 'Toast 11').center;
        await mouseAt(tester, at);
        await tester.pump(const Duration(milliseconds: 200));
        final read = boxOf(tester, 'Toast 6').top;
        await wheel(tester, at, const Offset(0, -150));
        await tester.pumpAndSettle();
        expect(
          boxOf(tester, 'Toast 11').bottom,
          moreOrLessEquals(576 + 150),
          reason: 'no toast is kept in place against the fan-out',
        );
        expect(
          boxOf(tester, 'Toast 6').top,
          lessThan(read + 150 - 1),
          reason: 'turned while the deck was still fanning out',
        );
      });

      testWidgets('a pointer leaving again on the way back to the edge eases '
          'on from where the deck is drawn', (tester) async {
        await tester.pumpWidget(app(controller: controller));
        await showMany(tester, controller, 12);
        final at = boxOf(tester, 'Toast 11').center;
        final mouse = await mouseAt(tester, at);
        await tester.pumpAndSettle();
        await wheel(tester, at, const Offset(0, -100));
        await tester.pumpAndSettle();

        await mouse.moveTo(away);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        // Toast 9 is still in the deck, where one beyond the window is not.
        await mouse.moveTo(boxOf(tester, 'Toast 9').center);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final easing = boxOf(tester, 'Toast 11').bottom;
        expect(easing, greaterThan(576), reason: 'still easing to the edge');
        await wheel(
          tester,
          boxOf(tester, 'Toast 9').center,
          const Offset(0, -40),
        );
        await tester.pump();
        final drawn = boxOf(tester, 'Toast 11').bottom;
        expect(drawn, greaterThan(easing), reason: 'the wheel scrolled it');

        await mouse.moveTo(away);
        await tester.pump();
        expect(boxOf(tester, 'Toast 11').bottom, moreOrLessEquals(drawn));
        await tester.pumpAndSettle();
        expect(boxOf(tester, 'Toast 11').bottom, 576);
      });

      testWidgets('a wheel turned while a toast enters at the edge keeps the '
          'toasts being read in place, not the one entering', (tester) async {
        await tester.pumpWidget(app(controller: controller));
        await showMany(tester, controller, 12);
        final at = boxOf(tester, 'Toast 11').center;
        await mouseAt(tester, at);
        await tester.pumpAndSettle();

        controller.show('New');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final read = boxOf(tester, 'Toast 11').top;
        await wheel(tester, at, const Offset(0, -5));
        await tester.pumpAndSettle();
        expect(boxOf(tester, 'Toast 11').top, moreOrLessEquals(read + 5));
        expect(boxOf(tester, 'New').top, greaterThan(576));
      });

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

      testWidgets('the toast reaching past the edge’s own offset into view '
          'keeps its place as it grows, however far the far edge’s is', (
        tester,
      ) async {
        controller.config = controller.config.copyWith(
          offset: const EdgeInsets.only(bottom: 10, top: 60, right: 24),
          deckCap: () => null,
        );
        await tester.pumpWidget(app(controller: controller));
        await showMany(tester, controller, 12);
        final at = boxOf(tester, 'Toast 11').center;
        await mouseAt(tester, at);
        await tester.pumpAndSettle();
        await wheel(tester, at, const Offset(0, -12));
        await tester.pumpAndSettle();
        // Past the near edge's offset, not the far edge's.
        final front = boxOf(tester, 'Toast 11');
        expect(600 - front.top, inExclusiveRange(10, 60));

        controller.update(
          toastsOf(
            controller,
          ).firstWhere((toast) => toast.state.title == 'Toast 11').id,
          description: 'One\nTwo\nThree',
        );
        await tester.pump();
        for (var elapsed = 0; elapsed <= 500; elapsed += 16) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            // The old content lies over the new while it fades.
            tester
                .getRect(
                  find
                      .ancestor(
                        of: find.text('Toast 11'),
                        matching: find.byType(SlideTransition),
                      )
                      .first,
                )
                .bottom,
            moreOrLessEquals(front.bottom, epsilon: 0.5),
            reason: 'at $elapsed ms',
          );
        }
        await tester.pumpAndSettle();
      });

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

      testWidgets('with no cap, a pointer resting in the layer’s far margin '
          'stays over the deck as it scrolls to the end', (tester) async {
        controller.config = controller.config.copyWith(
          deckCap: () => null,
          // The margin itself, with no control of the deck's width resting in
          // it: a wheel turned over a control does not reach the deck's
          // scroll.
          stowControl: () => null,
          dismissAll: () => null,
        );
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

      testWidgets('a position assigned to the other edge draws a scrolled deck '
          'from that edge', (tester) async {
        await tester.pumpWidget(app(controller: controller));
        await showMany(tester, controller, 12);
        final at = boxOf(tester, 'Toast 11').center;
        await mouseAt(tester, at);
        await tester.pumpAndSettle();
        await wheel(tester, at, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(boxOf(tester, 'Toast 11').bottom, greaterThan(576));

        controller.config = controller.config.copyWith(
          position: SonnerPosition.topRight,
        );
        await tester.pumpAndSettle();
        expect(boxOf(tester, 'Toast 11').top, 24);
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

    group('the deck cap', () {
      const edge = 24.0;

      SonnerController capped({
        DeckCap? cap = const DeckCap.pixels(200, fade: 0),
        DeckScrollbar? scrollbar,
        SonnerPosition position = SonnerPosition.bottomRight,
        bool expandByDefault = false,
        EdgeInsets offset = const EdgeInsets.all(edge),
      }) {
        final controller = SonnerController(
          config: SonnerConfig(
            duration: Duration.zero,
            position: position,
            offset: offset,
            deckCap: cap,
            scrollbar: scrollbar,
            expandByDefault: expandByDefault,
            // The cap's own reach, without the controls past it.
            dismissAll: null,
            stowControl: null,
          ),
        );
        addTearDown(controller.dispose);
        return controller;
      }

      /// How far from [position]'s edge [rect] reaches.
      double reach(SonnerPosition position, Rect rect) =>
          position.isTop ? rect.bottom : 600 - rect.top;

      Future<void> showToasts(
        WidgetTester tester,
        SonnerController controller,
        int count,
      ) async {
        for (var n = 0; n < count; n++) {
          controller.show('Toast $n');
        }
        await tester.pumpAndSettle();
      }

      /// Turns a mouse wheel at [at] toward the oldest toast until the deck
      /// stops.
      Future<void> scrollToOldest(
        WidgetTester tester,
        SonnerPosition position,
        Offset at,
      ) async {
        final wheel = TestPointer(7, PointerDeviceKind.mouse, 7);
        await tester.sendEventToBinding(wheel.addPointer(location: at));
        for (var i = 0; i < 30; i++) {
          await tester.sendEventToBinding(
            wheel.scroll(Offset(0, position.isTop ? 200 : -200)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        await tester.sendEventToBinding(wheel.removePointer());
      }

      for (final position in [
        SonnerPosition.bottomRight,
        SonnerPosition.topLeft,
      ]) {
        testWidgets('a deck capped in pixels scrolls its oldest toast into '
            'view inside the cap, $position', (tester) async {
          final controller = capped(position: position);
          await tester.pumpWidget(app(controller: controller));
          await showToasts(tester, controller, 12);
          await mouseAt(tester, boxOf(tester, 'Toast 11').center);
          await tester.pumpAndSettle();

          await scrollToOldest(
            tester,
            position,
            boxOf(tester, 'Toast 11').center,
          );
          expect(
            reach(position, boxOf(tester, 'Toast 0')),
            moreOrLessEquals(edge + 200),
            reason: 'the oldest ends at the cap',
          );
        });
      }
      testWidgets('a deck capped as a share of the layer reaches that share, '
          '`offset` included', (tester) async {
        final controller = capped(cap: const DeckCap.share(0.5, fade: 0));
        await tester.pumpWidget(app(controller: controller));
        await showToasts(tester, controller, 12);
        final at = boxOf(tester, 'Toast 11').center;
        await mouseAt(tester, at);
        await tester.pumpAndSettle();

        await scrollToOldest(tester, SonnerPosition.bottomRight, at);
        expect(
          reach(SonnerPosition.bottomRight, boxOf(tester, 'Toast 0')),
          moreOrLessEquals(300 - edge),
        );
      });

      testWidgets('a deck capped at three toasts reaches the far end of the '
          'third newest', (tester) async {
        final controller = capped(cap: const DeckCap.toasts(3, fade: 0));
        await tester.pumpWidget(app(controller: controller));
        await showToasts(tester, controller, 12);
        final height = boxOf(tester, 'Toast 11').height;
        final at = boxOf(tester, 'Toast 11').center;
        await mouseAt(tester, at);
        await tester.pumpAndSettle();

        await scrollToOldest(tester, SonnerPosition.bottomRight, at);
        expect(
          reach(SonnerPosition.bottomRight, boxOf(tester, 'Toast 0')),
          moreOrLessEquals(edge + 3 * height + 2 * 14),
        );
      });

      testWidgets('a cap shorter than the newest toast reaches its far end', (
        tester,
      ) async {
        final controller = capped(cap: const DeckCap.pixels(10, fade: 0));
        await tester.pumpWidget(app(controller: controller));
        await showToasts(tester, controller, 6);
        controller.show('Tall', description: 'One\nTwo\nThree\nFour');
        await tester.pumpAndSettle();
        final tall = boxOf(tester, 'Tall');
        await mouseAt(tester, tall.center);
        await tester.pumpAndSettle();

        await scrollToOldest(tester, SonnerPosition.bottomRight, tall.center);
        expect(
          reach(SonnerPosition.bottomRight, boxOf(tester, 'Toast 0')),
          moreOrLessEquals(edge + tall.height),
        );
      });

      testWidgets('a cap beyond the layer reaches as far as no cap does', (
        tester,
      ) async {
        final controller = capped(cap: const DeckCap.pixels(2000, fade: 0));
        await tester.pumpWidget(app(controller: controller));
        await showToasts(tester, controller, 12);
        final at = boxOf(tester, 'Toast 11').center;
        await mouseAt(tester, at);
        await tester.pumpAndSettle();

        await scrollToOldest(tester, SonnerPosition.bottomRight, at);
        expect(
          reach(SonnerPosition.bottomRight, boxOf(tester, 'Toast 0')),
          moreOrLessEquals(600 - edge),
        );
      });

      /// An app whose layer is captured by [key], over a page that counts its
      /// taps in [taps], with the debug banner only where [banner] asks.
      Widget shotApp(
        SonnerController controller,
        GlobalKey key, {
        List<int>? taps,
        bool banner = true,
      }) => RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: banner,
          builder: (context, child) =>
              SonnerHost(controller: controller, child: child!),
          home: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps?.add(1),
            child: const SizedBox.expand(),
          ),
        ),
      );

      /// The alpha of each row of [key]'s layer down the column at [x], top
      /// first.
      Future<List<int>> alphas(
        WidgetTester tester,
        GlobalKey key,
        double x,
      ) async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        final bytes = (await tester.runAsync(image.toByteData))!;
        final column = x.round();
        final out = [
          for (var y = 0; y < image.height; y++)
            bytes.getUint8((y * image.width + column) * 4 + 3),
        ];
        image.dispose();
        return out;
      }

      /// The rows from [from] to [to] from the bottom edge.
      List<int> band(List<int> column, double from, double to) =>
          column.sublist(600 - to.round(), 600 - from.round());

      for (final cap in const [
        DeckCap.pixels(200, fade: 0),
        // More toasts than the window: they leave the deck with the pointer.
        DeckCap.toasts(4, fade: 0),
      ]) {
        testWidgets('nothing is drawn past the cap while the pointer holds the '
            'deck, nor while it collapses after the pointer leaves, $cap', (
          tester,
        ) async {
          final key = GlobalKey();
          final controller = capped(cap: cap);
          await tester.pumpWidget(shotApp(controller, key));
          await showToasts(tester, controller, 12);
          final x = boxOf(tester, 'Toast 11').center.dx;
          final height = boxOf(tester, 'Toast 11').height;
          final far = cap.pixels != null
              ? edge + cap.pixels!
              : edge + 4 * height + 3 * 14;
          final mouse = await mouseAt(tester, boxOf(tester, 'Toast 11').center);
          await tester.pumpAndSettle();

          var column = await alphas(tester, key, x);
          expect(band(column, edge, far), contains(255), reason: 'kept');
          expect(band(column, far + 1, 600), everyElement(0), reason: 'cut');

          await mouse.moveTo(away);
          for (final ms in [50, 150, 300]) {
            await tester.pump(const Duration(milliseconds: 50));
            if (ms > 50) {
              await tester.pump(Duration(milliseconds: ms == 150 ? 50 : 100));
            }
            column = await alphas(tester, key, x);
            expect(
              band(column, far + 1, 600),
              everyElement(0),
              reason: 'cut while collapsing',
            );
          }
          await tester.pumpAndSettle();
        });
      }

      testWidgets('the toasts fade out over the cap’s fade before the cut', (
        tester,
      ) async {
        final key = GlobalKey();
        final controller = capped(cap: const DeckCap.pixels(200, fade: 40));
        await tester.pumpWidget(shotApp(controller, key));
        await showToasts(tester, controller, 12);
        final x = boxOf(tester, 'Toast 11').center.dx;
        await mouseAt(tester, boxOf(tester, 'Toast 11').center);
        await tester.pumpAndSettle();

        final column = await alphas(tester, key, x);
        final fading = band(column, edge + 161, edge + 200);
        expect(fading.where((a) => a > 0 && a < 255), isNotEmpty);
        expect(fading, everyElement(lessThan(255)));
        expect(band(column, edge + 201, 600), everyElement(0));
      });

      /// How many pixels of [key]'s layer, across its whole width, are drawn
      /// further than [far] from the edge of [position].
      Future<int> drawnPast(
        WidgetTester tester,
        GlobalKey key,
        SonnerPosition position,
        double far,
      ) async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        final bytes = (await tester.runAsync(image.toByteData))!;
        final rows = position.isTop
            ? [for (var y = far.round() + 1; y < image.height; y++) y]
            : [for (var y = 0; y < image.height - far.round() - 1; y++) y];
        var drawn = 0;
        for (final y in rows) {
          for (var x = 0; x < image.width; x++) {
            if (bytes.getUint8((y * image.width + x) * 4 + 3) > 0) drawn++;
          }
        }
        image.dispose();
        return drawn;
      }

      for (final position in [
        SonnerPosition.bottomRight,
        SonnerPosition.topRight,
      ]) {
        for (final look in [
          DeckStowMotionLook.slide,
          DeckStowMotionLook.shrink,
        ]) {
          testWidgets('a fading cut keeps the toasts laid out off the layer '
              'out of sight while the deck stows, $position, $look', (
            tester,
          ) async {
            final key = GlobalKey();
            final controller = capped(
              cap: const DeckCap.pixels(200, fade: 24),
              position: position,
            );
            controller.config = controller.config.copyWith(
              stowMotion: DeckStowMotion(look: look),
            );
            // The banner is drawn in a top corner, past a bottom deck's cap.
            await tester.pumpWidget(shotApp(controller, key, banner: false));
            // Enough that the oldest are laid out past the layer's far side.
            await showToasts(tester, controller, 20);
            await mouseAt(tester, boxOf(tester, 'Toast 19').center);
            await tester.pumpAndSettle();
            const far = edge + 200;
            expect(await drawnPast(tester, key, position, far), 0);

            controller.stow();
            await tester.pump();
            // The stow moves the deck most in its first half.
            for (var ms = 25; ms <= 150; ms += 25) {
              await tester.pump(const Duration(milliseconds: 25));
              expect(
                await drawnPast(tester, key, position, far),
                0,
                reason: '$ms ms into the stow',
              );
            }
            await tester.pumpAndSettle();
          });
        }
      }

      testWidgets(
        'a click past the cap and its margin reaches the app, and one '
        'inside it reaches the toast',
        (tester) async {
          final key = GlobalKey();
          final taps = <int>[];
          final controller = capped();
          await tester.pumpWidget(shotApp(controller, key, taps: taps));
          await showToasts(tester, controller, 12);
          await mouseAt(tester, boxOf(tester, 'Toast 11').center);
          await tester.pumpAndSettle();

          // A toast laid out past the cut and its margin, not a gap.
          final past = boxOf(tester, 'Toast 7').center;
          expect(600 - past.dy, greaterThan(edge + 200 + edge));
          await tester.tapAt(past, kind: PointerDeviceKind.mouse);
          await tester.pump();
          expect(taps, hasLength(1), reason: 'past the cut');

          await tester.tapAt(
            boxOf(tester, 'Toast 11').center,
            kind: PointerDeviceKind.mouse,
          );
          await tester.pump();
          expect(taps, hasLength(1), reason: 'the toast takes it');
          await tester.pumpAndSettle();
        },
      );

      // The edge the deck sits at, and the one it reaches toward, apart.
      const unequal = EdgeInsets.only(left: 24, right: 24, bottom: 30, top: 50);

      for (final (cap, far) in const [
        // From the edge's own offset.
        (DeckCap.pixels(200, fade: 0), 30.0 + 200),
        // Half the layer, short of the far edge's offset.
        (DeckCap.share(0.5, fade: 0), 300.0 - 50),
      ]) {
        testWidgets('a cap reaches as far from the edge as its own edge’s '
            'offsets say, $cap', (tester) async {
          final key = GlobalKey();
          final controller = capped(cap: cap, offset: unequal);
          await tester.pumpWidget(shotApp(controller, key));
          await showToasts(tester, controller, 12);
          final x = boxOf(tester, 'Toast 11').center.dx;
          await mouseAt(tester, boxOf(tester, 'Toast 11').center);
          await tester.pumpAndSettle();

          final column = await alphas(tester, key, x);
          expect(band(column, 30, far), contains(255), reason: 'kept');
          expect(band(column, far + 1, 600), everyElement(0), reason: 'cut');
        });
      }

      testWidgets('with no cap the oldest toast scrolls to the far edge’s '
          'offset', (tester) async {
        final controller = capped(cap: null, offset: unequal);
        await tester.pumpWidget(app(controller: controller));
        await showToasts(tester, controller, 12);
        final at = boxOf(tester, 'Toast 11').center;
        await mouseAt(tester, at);
        await tester.pumpAndSettle();

        await scrollToOldest(tester, SonnerPosition.bottomRight, at);
        expect(boxOf(tester, 'Toast 0').top, moreOrLessEquals(50));
      });

      testWidgets('the pointer holds the deck up to the far edge’s offset past '
          'the cap', (tester) async {
        final controller = capped(offset: unequal);
        await tester.pumpWidget(app(controller: controller));
        await showToasts(tester, controller, 12);
        final x = boxOf(tester, 'Toast 11').center.dx;
        final mouse = await mouseAt(tester, boxOf(tester, 'Toast 11').center);
        await tester.pumpAndSettle();

        // Past the near edge's offset, inside the far edge's.
        await mouse.moveTo(Offset(x, 600 - (30 + 200 + 40)));
        await tester.pumpAndSettle();
        expect(find.text('Toast 0'), findsOneWidget, reason: 'still held');

        await mouse.moveTo(Offset(x, 600 - (30 + 200 + 56)));
        await tester.pumpAndSettle();
        expect(find.text('Toast 0'), findsNothing, reason: 'left');
      });

      testWidgets('a toast laid out up to the far edge’s offset past the cap '
          'takes the pointer', (tester) async {
        final controller = capped(offset: unequal);
        await tester.pumpWidget(app(controller: controller));
        await showToasts(tester, controller, 12);
        final x = boxOf(tester, 'Toast 11').center.dx;
        await mouseAt(tester, boxOf(tester, 'Toast 11').center);
        await tester.pumpAndSettle();

        // Past the near edge's offset, inside the far edge's.
        final at = Offset(x, 600 - (30 + 200 + 40));
        final title = [
          for (var n = 0; n < 12; n++) 'Toast $n',
        ].firstWhere((title) => boxOf(tester, title).contains(at));
        final toast = tester.renderObject(
          find
              .ancestor(of: find.text(title), matching: find.byType(Material))
              .first,
        );
        final path = tester.hitTestOnBinding(at).path;
        expect(path.map((entry) => entry.target), contains(toast));
      });

      testWidgets('a click is the deck’s up to the far edge’s offset past the '
          'cap, and the app’s past that', (tester) async {
        final key = GlobalKey();
        final taps = <int>[];
        final controller = capped(offset: unequal);
        await tester.pumpWidget(shotApp(controller, key, taps: taps));
        await showToasts(tester, controller, 12);
        final x = boxOf(tester, 'Toast 11').center.dx;
        await mouseAt(tester, boxOf(tester, 'Toast 11').center);
        await tester.pumpAndSettle();

        // Past the near edge's offset, inside the far edge's.
        await tester.tapAt(
          Offset(x, 600 - (30 + 200 + 40)),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        expect(taps, isEmpty, reason: 'inside the margin');

        await tester.tapAt(
          Offset(x, 600 - (30 + 200 + 56)),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        expect(taps, hasLength(1), reason: 'past it');
        await tester.pumpAndSettle();
      });

      testWidgets('the pointer holds the deck up to the cap’s margin, and '
          'leaves it past that', (tester) async {
        final controller = capped();
        await tester.pumpWidget(app(controller: controller));
        await showToasts(tester, controller, 12);
        final x = boxOf(tester, 'Toast 11').center.dx;
        final mouse = await mouseAt(tester, boxOf(tester, 'Toast 11').center);
        await tester.pumpAndSettle();

        await mouse.moveTo(Offset(x, 600 - (edge + 200 + edge - 4)));
        await tester.pumpAndSettle();
        expect(find.text('Toast 0'), findsOneWidget, reason: 'still held');

        await mouse.moveTo(Offset(x, 600 - (edge + 200 + edge + 4)));
        await tester.pumpAndSettle();
        expect(find.text('Toast 0'), findsNothing, reason: 'left');
      });

      testWidgets('an expandByDefault deck with no pointer on it is cut at the '
          'cap', (tester) async {
        final key = GlobalKey();
        final controller = capped(
          cap: const DeckCap.pixels(80, fade: 0),
          expandByDefault: true,
        );
        await tester.pumpWidget(shotApp(controller, key));
        await showToasts(tester, controller, 3);
        final newest = boxOf(tester, 'Toast 2');
        final column = await alphas(tester, key, newest.center.dx);
        final far = edge + math.max(80, newest.height);
        expect(band(column, edge, far), contains(255));
        expect(band(column, far + 1, 600), everyElement(0));
      });
    });

    group('the deck scrollbar', () {
      const edge = 24.0;

      SonnerController barred({
        DeckScrollbar scrollbar = const DeckScrollbar(),
        SonnerPosition position = SonnerPosition.bottomRight,
        EdgeInsets offset = const EdgeInsets.all(edge),
      }) {
        final controller = SonnerController(
          config: SonnerConfig(
            duration: Duration.zero,
            position: position,
            offset: offset,
            deckCap: const DeckCap.pixels(200, fade: 0),
            scrollbar: scrollbar,
          ),
        );
        addTearDown(controller.dispose);
        return controller;
      }

      Future<void> showToasts(
        WidgetTester tester,
        SonnerController controller,
        int count,
      ) async {
        for (var n = 0; n < count; n++) {
          controller.show('Toast $n');
        }
        await tester.pumpAndSettle();
      }

      Rect thumbRect(WidgetTester tester) =>
          tester.getRect(find.byType(DeckScrollbarThumb));

      bool thumbShown(WidgetTester tester) {
        final rect = thumbRect(tester);
        return !rect.isEmpty &&
            rect.overlaps(Offset.zero & const Size(800, 600));
      }

      Future<void> wheel(WidgetTester tester, Offset at, double dy) async {
        final wheel = TestPointer(7, PointerDeviceKind.mouse, 7);
        await tester.sendEventToBinding(wheel.addPointer(location: at));
        await tester.sendEventToBinding(wheel.scroll(Offset(0, dy)));
        await tester.sendEventToBinding(wheel.removePointer());
      }

      testWidgets('shows only while the pointer holds a deck that scrolls', (
        tester,
      ) async {
        final controller = barred();
        await tester.pumpWidget(app(controller: controller));
        await showToasts(tester, controller, 2);
        final mouse = await mouseAt(tester, boxOf(tester, 'Toast 1').center);
        await tester.pumpAndSettle();
        expect(thumbShown(tester), isFalse, reason: 'nothing to scroll');

        await showToasts(tester, controller, 10);
        expect(thumbShown(tester), isTrue);

        await mouse.moveTo(away);
        await tester.pumpAndSettle();
        expect(thumbShown(tester), isFalse, reason: 'the pointer left');
      });

      for (final position in [
        SonnerPosition.bottomRight,
        SonnerPosition.topLeft,
      ]) {
        testWidgets('shows nowhere on an expandByDefault deck that overflows '
            'with no pointer on it, since nothing scrolls it', (tester) async {
          final controller = SonnerController(
            config: const SonnerConfig(
              duration: Duration.zero,
              expandByDefault: true,
              visibleToasts: 12,
              deckCap: DeckCap.pixels(200, fade: 0),
            ),
          );
          addTearDown(controller.dispose);
          await tester.pumpWidget(app(controller: controller));
          await showToasts(tester, controller, 12);
          expect(thumbShown(tester), isFalse);
        });

        testWidgets('its thumb runs from the edge’s margin to the cap as the '
            'deck scrolls, $position', (tester) async {
          final controller = barred(position: position);
          await tester.pumpWidget(app(controller: controller));
          await showToasts(tester, controller, 12);
          final front = boxOf(tester, 'Toast 11').center;
          await mouseAt(tester, front);
          await tester.pumpAndSettle();

          double fromEdge(double y) => position.isTop ? y : 600 - y;
          var thumb = thumbRect(tester);
          final near = position.isTop ? thumb.top : thumb.bottom;
          final far = position.isTop ? thumb.bottom : thumb.top;
          expect(fromEdge(near), moreOrLessEquals(edge), reason: 'at the edge');
          expect(fromEdge(far), lessThan(edge + 200));

          await wheel(tester, front, position.isTop ? 5000 : -5000);
          await tester.pumpAndSettle();
          thumb = thumbRect(tester);
          expect(
            fromEdge(position.isTop ? thumb.bottom : thumb.top),
            moreOrLessEquals(edge + 200),
            reason: 'at the cap',
          );
        });
      }

      for (final position in [
        SonnerPosition.bottomRight,
        SonnerPosition.topRight,
      ]) {
        testWidgets('its track starts at the offset of the edge the deck sits '
            'at, $position', (tester) async {
          final controller = barred(
            position: position,
            offset: const EdgeInsets.only(top: 37, bottom: 29, right: 24),
          );
          await tester.pumpWidget(app(controller: controller));
          await showToasts(tester, controller, 12);
          await mouseAt(tester, boxOf(tester, 'Toast 11').center);
          await tester.pumpAndSettle();

          final near = position.isTop ? 37.0 : 29.0;
          double fromEdge(double y) => position.isTop ? y : 600 - y;
          var thumb = thumbRect(tester);
          expect(
            fromEdge(position.isTop ? thumb.top : thumb.bottom),
            moreOrLessEquals(near),
            reason: 'at the edge',
          );

          await wheel(
            tester,
            boxOf(tester, 'Toast 11').center,
            position.isTop ? 5000 : -5000,
          );
          await tester.pumpAndSettle();
          thumb = thumbRect(tester);
          expect(
            fromEdge(position.isTop ? thumb.bottom : thumb.top),
            moreOrLessEquals(near + 200),
            reason: 'at the cap',
          );
        });
      }

      testWidgets('sits outside the deck’s right edge, or inside it', (
        tester,
      ) async {
        final controller = barred();
        await tester.pumpWidget(app(controller: controller));
        await showToasts(tester, controller, 12);
        final deckRight = boxOf(tester, 'Toast 11').right;
        await mouseAt(tester, boxOf(tester, 'Toast 11').center);
        await tester.pumpAndSettle();
        expect(thumbRect(tester).center.dx, moreOrLessEquals(deckRight + 10));

        controller.config = controller.config.copyWith(
          scrollbar: () =>
              const DeckScrollbar(placement: DeckScrollbarPlacement.inside),
        );
        await tester.pumpAndSettle();
        expect(thumbRect(tester).center.dx, moreOrLessEquals(deckRight - 8));
      });

      testWidgets('one not always shown shows while the deck scrolls, and '
          'fades 600 ms after', (tester) async {
        final controller = barred(
          scrollbar: const DeckScrollbar(alwaysShown: false),
        );
        await tester.pumpWidget(app(controller: controller));
        await showToasts(tester, controller, 12);
        final front = boxOf(tester, 'Toast 11').center;
        await mouseAt(tester, front);
        await tester.pumpAndSettle();
        double opacity() => tester
            .widget<FadeTransition>(
              find.descendant(
                of: find.byType(DeckScrollbarThumb),
                matching: find.byType(FadeTransition),
              ),
            )
            .opacity
            .value;
        expect(opacity(), 0);

        await wheel(tester, front, -60);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(opacity(), 1);
        await tester.pump(const Duration(milliseconds: 250));
        expect(opacity(), 1, reason: 'still shown at 550 ms');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 150));
        expect(opacity(), inExclusiveRange(0, 1), reason: 'fading');
        await tester.pump(const Duration(milliseconds: 200));
        expect(opacity(), 0);
      });

      testWidgets('the pointer moved from the deck onto the thumb outside it '
          'keeps the deck expanded', (tester) async {
        final controller = barred();
        await tester.pumpWidget(app(controller: controller));
        await showToasts(tester, controller, 12);
        final mouse = await mouseAt(tester, boxOf(tester, 'Toast 11').center);
        await tester.pumpAndSettle();

        await mouse.moveTo(thumbRect(tester).center);
        await tester.pumpAndSettle();
        expect(find.text('Toast 0'), findsOneWidget);
        expect(thumbShown(tester), isTrue);
      });

      testWidgets('dragging the thumb scrolls the deck by its share of the '
          'track, and holds the deck until it lets go', (tester) async {
        final controller = barred();
        await tester.pumpWidget(app(controller: controller));
        await showToasts(tester, controller, 12);
        final height = boxOf(tester, 'Toast 11').height;
        final mouse = await mouseAt(tester, boxOf(tester, 'Toast 11').center);
        await tester.pumpAndSettle();

        final thumb = thumbRect(tester);
        final track = 200.0;
        final extent = (12 * height + 11 * 14) - track;
        final travel = track - thumb.height;
        final newest = boxOf(tester, 'Toast 11').bottom;
        await mouse.moveTo(thumb.center);
        await tester.pump();
        await mouse.down(thumb.center);
        await tester.pump();
        await mouse.moveBy(const Offset(0, -20));
        await tester.pump();
        await mouse.moveBy(const Offset(0, -10));
        await tester.pump();
        expect(
          boxOf(tester, 'Toast 11').bottom,
          moreOrLessEquals(newest + 30 * extent / travel, epsilon: 0.5),
        );

        await mouse.moveTo(away);
        await tester.pumpAndSettle();
        expect(find.text('Toast 0'), findsOneWidget, reason: 'held');

        await mouse.up();
        await tester.pumpAndSettle();
        expect(find.text('Toast 0'), findsNothing, reason: 'let go');
      });

      testWidgets('one not draggable takes no pointer', (tester) async {
        final controller = barred(
          scrollbar: const DeckScrollbar(
            draggable: false,
            placement: DeckScrollbarPlacement.inside,
          ),
        );
        await tester.pumpWidget(app(controller: controller));
        await showToasts(tester, controller, 12);
        final mouse = await mouseAt(tester, boxOf(tester, 'Toast 11').center);
        await tester.pumpAndSettle();

        final thumb = thumbRect(tester);
        final hit = HitTestResult();
        tester.binding.hitTestInView(hit, thumb.center, tester.view.viewId);
        expect(
          hit.path.map((entry) => entry.target),
          isNot(contains(tester.renderObject(find.byType(DeckScrollbarThumb)))),
        );
        final newest = boxOf(tester, 'Toast 11').bottom;
        await mouse.moveTo(thumb.center);
        await mouse.down(thumb.center);
        await mouse.moveBy(const Offset(0, -30));
        await tester.pump();
        await mouse.up();
        await tester.pumpAndSettle();
        expect(boxOf(tester, 'Toast 11').bottom, moreOrLessEquals(newest));
      });

      testWidgets('a new cap assigned while the deck scrolls keeps the toasts '
          'in view where they are', (tester) async {
        final controller = barred();
        await tester.pumpWidget(app(controller: controller));
        await showToasts(tester, controller, 12);
        final front = boxOf(tester, 'Toast 11').center;
        await mouseAt(tester, front);
        await tester.pumpAndSettle();
        await wheel(tester, front, -70);
        await tester.pumpAndSettle();
        final before = boxOf(tester, 'Toast 9').top;

        controller.config = controller.config.copyWith(
          deckCap: () => const DeckCap.pixels(300, fade: 0),
        );
        await tester.pump();
        expect(boxOf(tester, 'Toast 9').top, moreOrLessEquals(before));
        await tester.pumpAndSettle();
        expect(boxOf(tester, 'Toast 9').top, moreOrLessEquals(before));
      });
    });

    group('the dismiss-all control', () {
      const edge = 24.0;
      const gap = 14.0;
      final control = find.byType(DeckDismissAllButton);

      SonnerController deckWith({
        DeckDismissAll? dismissAll = const DeckDismissAll(),
        SonnerPosition position = SonnerPosition.bottomRight,
        DeckCap? cap = const DeckCap.pixels(400, fade: 0),
      }) {
        final controller = SonnerController(
          config: SonnerConfig(
            duration: Duration.zero,
            position: position,
            deckCap: cap,
            scrollbar: null,
            dismissAll: dismissAll,
            // This control on its own; the two together are pinned by the
            // stow group.
            stowControl: null,
          ),
        );
        addTearDown(controller.dispose);
        return controller;
      }

      void showToasts(SonnerController controller, int count) {
        for (var n = 0; n < count; n++) {
          controller.show('Toast $n');
        }
      }

      Future<void> settle(WidgetTester tester) async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      testWidgets('shows only while the pointer holds an expanded deck with at '
          'least two toasts the user may dismiss', (tester) async {
        final controller = deckWith();
        await tester.pumpWidget(app(controller: controller));
        showToasts(controller, 1);
        controller.show('Saving', isLoading: true);
        await settle(tester);
        final mouse = await mouseAt(tester, boxOf(tester, 'Saving').center);
        await settle(tester);
        expect(control, findsNothing, reason: 'one the user may dismiss');

        controller.show('Toast 1');
        await settle(tester);
        expect(control, findsOneWidget);
        final semantics = tester.ensureSemantics();
        await tester.pump();
        expect(
          tester.getSemantics(find.text('Clear all')),
          isSemantics(isButton: true, label: 'Clear all'),
        );
        semantics.dispose();

        await mouse.moveTo(away);
        await settle(tester);
        expect(control, findsNothing, reason: 'collapsed');

        controller.config = controller.config.copyWith(dismissAll: () => null);
        await mouse.moveTo(boxOf(tester, 'Saving').center);
        await settle(tester);
        expect(control, findsNothing, reason: 'none configured');
      });

      for (final position in [
        SonnerPosition.bottomRight,
        SonnerPosition.topLeft,
        SonnerPosition.bottomCenter,
      ]) {
        testWidgets('sits a gap past the deck’s far end, on the position’s '
            'side, $position', (tester) async {
          final controller = deckWith(position: position);
          await tester.pumpWidget(app(controller: controller));
          showToasts(controller, 3);
          await tester.pumpAndSettle();
          await mouseAt(tester, boxOf(tester, 'Toast 2').center);
          await tester.pumpAndSettle();

          final far = boxOf(tester, 'Toast 0');
          final rect = tester.getRect(control);
          if (position.isTop) {
            expect(rect.top, moreOrLessEquals(far.bottom + gap));
          } else {
            expect(rect.bottom, moreOrLessEquals(far.top - gap));
          }
          switch (position) {
            case SonnerPosition.topLeft:
              expect(rect.left, moreOrLessEquals(far.left));
            case SonnerPosition.bottomCenter:
              expect(rect.center.dx, moreOrLessEquals(far.center.dx));
            default:
              expect(rect.right, moreOrLessEquals(far.right));
          }
        });
      }

      testWidgets('is placed from the first frame the pointer holds the deck', (
        tester,
      ) async {
        final controller = deckWith();
        await tester.pumpWidget(app(controller: controller));
        showToasts(controller, 3);
        await tester.pumpAndSettle();
        // The frame the pointer's arrival is built in, and no later.
        await mouseAt(tester, boxOf(tester, 'Toast 2').center);

        expect(control, findsOneWidget);
        expect(
          tester.getRect(control).bottom,
          moreOrLessEquals(boxOf(tester, 'Toast 0').top - gap),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('on a capped deck stays at the cap as the toasts scroll, and '
          'is drawn past the cut', (tester) async {
        final key = GlobalKey();
        final controller = deckWith();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: app(controller: controller),
          ),
        );
        showToasts(controller, 20);
        await tester.pumpAndSettle();
        final front = boxOf(tester, 'Toast 19').center;
        await mouseAt(tester, front);
        await tester.pumpAndSettle();

        final atCap = 600 - (edge + 400) - gap;
        expect(tester.getRect(control).bottom, moreOrLessEquals(atCap));
        final wheel = TestPointer(7, PointerDeviceKind.mouse, 7);
        await tester.sendEventToBinding(wheel.addPointer(location: front));
        await tester.sendEventToBinding(wheel.scroll(const Offset(0, -300)));
        await tester.sendEventToBinding(wheel.removePointer());
        await tester.pumpAndSettle();
        expect(tester.getRect(control).bottom, moreOrLessEquals(atCap));

        final centre = tester.getRect(control).center;
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        final bytes = (await tester.runAsync(image.toByteData))!;
        final alpha = bytes.getUint8(
          (centre.dy.round() * image.width + centre.dx.round()) * 4 + 3,
        );
        image.dispose();
        expect(alpha, greaterThan(0));
      });

      testWidgets('keeps the deck while the pointer moves onto it, and pressed '
          'dismisses every toast the user may dismiss, beyond the window too', (
        tester,
      ) async {
        final controller = deckWith();
        await tester.pumpWidget(app(controller: controller));
        controller.show('Saving', isLoading: true);
        controller.show('Pinned', dismissible: false);
        showToasts(controller, 6);
        await settle(tester);
        final mouse = await mouseAt(tester, boxOf(tester, 'Toast 5').center);
        await settle(tester);

        final from = boxOf(tester, 'Toast 5').center;
        final to = tester.getRect(control).center;
        for (var step = 1; step <= 10; step++) {
          await mouse.moveTo(Offset.lerp(from, to, step / 10)!);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await settle(tester);
        expect(control, findsOneWidget, reason: 'the deck is still held');

        await mouse.down(tester.getRect(control).center);
        await mouse.up();
        await settle(tester);
        expect(
          toastsOf(controller).map((toast) => toast.state.title),
          unorderedEquals(['Saving', 'Pinned']),
        );
      });

      testWidgets('a header reads the count and the label, as given', (
        tester,
      ) async {
        final controller = deckWith(
          dismissAll: const DeckDismissAll(look: DeckDismissAllLook.header),
        );
        await tester.pumpWidget(app(controller: controller));
        showToasts(controller, 3);
        await tester.pumpAndSettle();
        await mouseAt(tester, boxOf(tester, 'Toast 2').center);
        await tester.pumpAndSettle();
        expect(find.text('3 notifications'), findsOneWidget);
        expect(find.text('Clear all'), findsOneWidget);
        expect(
          tester.getRect(control).width,
          moreOrLessEquals(boxOf(tester, 'Toast 2').width),
        );

        controller.config = controller.config.copyWith(
          dismissAll: () => DeckDismissAll(
            look: DeckDismissAllLook.header,
            label: '모두 지우기',
            countLabel: (count) => '$count개',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('3개'), findsOneWidget);
        expect(find.text('모두 지우기'), findsOneWidget);
      });

      testWidgets('a builder draws the control, is placed by its own size, and '
          'dismisses through the view', (tester) async {
        DeckDismissAllView? seen;
        final controller = deckWith(
          dismissAll: DeckDismissAll(
            builder: (context, view) {
              seen = view;
              return GestureDetector(
                onTap: view.dismiss,
                child: SizedBox(
                  width: 50,
                  height: 20,
                  child: Text('${view.count}'),
                ),
              );
            },
          ),
        );
        await tester.pumpWidget(app(controller: controller));
        showToasts(controller, 3);
        await tester.pumpAndSettle();
        await mouseAt(tester, boxOf(tester, 'Toast 2').center);
        await tester.pumpAndSettle();

        expect(find.text('Clear all'), findsNothing);
        expect(find.text('3'), findsOneWidget);
        expect(seen!.count, 3);
        expect(seen!.expansion.value, 1);
        final rect = tester.getRect(control);
        expect(rect.size, const Size(50, 20));
        expect(
          rect.bottom,
          moreOrLessEquals(boxOf(tester, 'Toast 0').top - gap),
        );
        expect(rect.right, moreOrLessEquals(boxOf(tester, 'Toast 0').right));

        await tester.tap(find.text('3'), kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
        expect(toastsOf(controller), isEmpty);
      });
    });

    group('the backdrop', () {
      /// A controller whose deck draws [backdrop] behind it.
      SonnerController withBackdrop(DeckBackdrop? backdrop) {
        final controller = SonnerController(
          config: SonnerConfig(duration: Duration.zero, deckBackdrop: backdrop),
        );
        addTearDown(controller.dispose);
        return controller;
      }

      /// Whether the hard black/white edge behind the deck is smeared at each
      /// of [ys], read from [key]'s layer. A blur softens it; anywhere the
      /// backdrop does not reach it stays a step.
      Future<List<bool>> rowsBlurred(
        WidgetTester tester,
        GlobalKey key,
        List<double> ys,
      ) async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final out = <bool>[];
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          for (final y in ys) {
            final row = y.round().clamp(0, image.height - 1);
            var between = 0;

            for (var x = 0; x < image.width; x++) {
              final v = data!.getUint8((row * image.width + x) * 4);
              if (v > 24 && v < 231) between++;
            }
            // Hard stripes give at most a pixel or two of anti-aliasing per
            // edge; a blur of sigma 4 smears them into a wide grey band.
            out.add(between > 40);
          }
          image.dispose();
        });
        return out;
      }

      final blur = find.byType(BackdropFilter);
      final scrim = find.descendant(
        of: find.byType(DeckBackdropBox),
        matching: find.byType(ColoredBox),
      );

      testWidgets('no config draws none of it, hovered or not', (tester) async {
        final controller = withBackdrop(null);
        await tester.pumpWidget(app(controller: controller));
        controller.show('Only');
        await tester.pumpAndSettle();
        expect(blur, findsNothing);

        await mouseAt(tester, boxOf(tester, 'Only').center);
        await tester.pumpAndSettle();
        expect(blur, findsNothing);
        expect(scrim, findsNothing);
      });

      testWidgets('a collapsed deck draws none of it; hovering brings it, and '
          'leaving takes it away again', (tester) async {
        final controller = withBackdrop(const DeckBackdrop(dim: 0.2));
        await tester.pumpWidget(app(controller: controller));
        controller.show('Only');
        await tester.pumpAndSettle();
        expect(blur, findsNothing, reason: 'collapsed');
        expect(scrim, findsNothing, reason: 'collapsed');

        final mouse = await mouseAt(tester, boxOf(tester, 'Only').center);
        await tester.pumpAndSettle();
        expect(blur, findsOneWidget, reason: 'hovered');
        expect(scrim, findsOneWidget, reason: 'hovered');

        await mouse.moveTo(away);
        await tester.pumpAndSettle();
        expect(blur, findsNothing, reason: 'the pointer left');
        expect(scrim, findsNothing, reason: 'the pointer left');
      });

      testWidgets('a blur of 0 draws no filter and a dim of 0 no scrim, so the '
          'default draws the blur alone', (tester) async {
        final controller = withBackdrop(const DeckBackdrop());
        await tester.pumpWidget(app(controller: controller));
        controller.show('Only');
        await tester.pumpAndSettle();
        await mouseAt(tester, boxOf(tester, 'Only').center);
        await tester.pumpAndSettle();
        // The default is blur 4, dim 0.
        expect(blur, findsOneWidget);
        expect(scrim, findsNothing);

        controller.config = controller.config.copyWith(
          deckBackdrop: () => const DeckBackdrop(blur: 0, dim: 0.2),
        );
        await tester.pumpAndSettle();
        expect(blur, findsNothing);
        expect(scrim, findsOneWidget);
      });

      testWidgets('what it draws reaches past the deck by its padding', (
        tester,
      ) async {
        const pad = EdgeInsets.fromLTRB(10, 20, 30, 40);
        final key = GlobalKey();
        final controller = withBackdrop(const DeckBackdrop(padding: pad));
        // A hard black/white edge behind the deck: the blur smears it where it
        // reaches and leaves it alone where it does not. What is drawn is a
        // clip inside a render object rather than a box in the tree, so this
        // reads the pixels rather than a rect.
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              builder: (context, child) =>
                  SonnerHost(controller: controller, child: child!),
              home: const CustomPaint(
                painter: _HardEdge(),
                child: SizedBox.expand(),
              ),
            ),
          ),
        );
        controller.show('Only');
        await tester.pumpAndSettle();
        await mouseAt(tester, boxOf(tester, 'Only').center);
        await tester.pumpAndSettle();

        final hit = tester.getRect(find.byType(DeckHitBox));
        // The top edge only: the deck sits at the bottom, so "past the bottom
        // padding" is off the layer and says nothing.
        final rows = await rowsBlurred(tester, key, [
          hit.top + 4,
          hit.top - pad.top / 2,
          hit.top - pad.top * 3,
        ]);
        expect(rows[0], isTrue, reason: 'inside the deck');
        expect(rows[1], isTrue, reason: 'in the padding past the top edge');
        expect(rows[2], isFalse, reason: 'well past the padding');
      });

      testWidgets('a click in the padding it reaches into still reaches the '
          'app', (tester) async {
        const pad = EdgeInsets.all(20);
        final taps = <int>[];
        final controller = withBackdrop(const DeckBackdrop(padding: pad));
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) =>
                SonnerHost(controller: controller, child: child!),
            home: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps.add(1),
              child: const SizedBox.expand(),
            ),
          ),
        );
        controller.show('Only');
        await tester.pumpAndSettle();
        await mouseAt(tester, boxOf(tester, 'Only').center);
        await tester.pumpAndSettle();

        // Half a padding to the **side** of the toast: inside what the
        // backdrop draws over and outside the deck. Sideways rather than
        // above, because the deck's box reaches up past the toasts to take
        // in the stow control (§6) and a point above the toast lands on that.
        //
        // Measured from the toast, never from the backdrop's own box: that
        // box's size is the thing that could be wrong, so a ring derived from
        // it would move with the defect and never leave it.
        final toast = boxOf(tester, 'Only');
        final ring = Offset(toast.left - pad.left / 2, toast.center.dy);
        final hit = tester.getRect(find.byType(DeckHitBox));
        // The window this test needs: a point the backdrop draws over that
        // the deck does not claim. A deck grown to the drawn box would make
        // this fire, rather than let the tap below pass for the wrong reason.
        expect(hit.contains(ring), isFalse, reason: 'outside the deck');

        await tester.tapAt(ring, kind: PointerDeviceKind.mouse);
        await tester.pump();
        expect(taps, hasLength(1), reason: 'the app takes it');

        await tester.tapAt(toast.center, kind: PointerDeviceKind.mouse);
        await tester.pump();
        expect(taps, hasLength(1), reason: 'the deck takes its own');
        await tester.pumpAndSettle();
      });
    });
  });

  group('action slot and close button', () {
    const away = Offset(40, 40);

    /// A toast's box before it is scaled.
    Rect boxOf(WidgetTester tester, String title) => tester.getRect(
      find.ancestor(
        of: find.text(title),
        matching: find.byType(SlideTransition),
      ),
    );

    /// A mouse moved to [at] and resting there, taken away when the test
    /// ends. It arrives by a move, since a pointer the deck merely appears
    /// under is not over it.
    Future<TestGesture> mouseAt(WidgetTester tester, Offset at) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: at - const Offset(1, 0));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(at);
      await tester.pump();
      return mouse;
    }

    Widget tappableApp(void Function() onTap) => MaterialApp(
      builder: (context, child) =>
          SonnerHost(controller: controller, child: child!),
      home: GestureDetector(
        onTap: onTap,
        child: const ColoredBox(color: Color(0xFFFFFFFF)),
      ),
    );

    Finder closeButton() => find.byIcon(Icons.close);

    testWidgets('the action slot is placed at the trailing edge and is handed '
        'the toast', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      ToastView? given;
      controller.show(
        'Item deleted',
        action: (context, t) {
          given = t;
          return TextButton(onPressed: () {}, child: const Text('Undo'));
        },
      );
      await tester.pumpAndSettle();

      expect(given, isNotNull);
      expect(given!.id, toastsOf(controller).single.id);
      expect(given!.state.title, 'Item deleted');

      final card = tester.getRect(
        find
            .ancestor(
              of: find.text('Item deleted'),
              matching: find.byType(Material),
            )
            .first,
      );
      final undo = tester.getRect(find.text('Undo'));
      expect(
        undo.left,
        greaterThan(tester.getRect(find.text('Item deleted')).right),
      );
      expect(undo.right, lessThanOrEqualTo(card.right));
    });

    testWidgets('the widget in the slot decides whether pressing dismisses', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show(
        'Item deleted',
        action: (context, t) =>
            TextButton(onPressed: t.dismiss, child: const Text('Undo')),
      );
      controller.show(
        'Connection failed',
        action: (context, t) => TextButton(
          onPressed: () => controller.update(t.id, title: 'Retrying'),
          child: const Text('Retry'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Retrying'), findsOneWidget, reason: 'it stands');
      expect(toastsOf(controller), hasLength(2));

      // The other toast is behind, so expand the deck to reach its button.
      final mouse = await mouseAt(tester, boxOf(tester, 'Retrying').center);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Item deleted'), findsNothing, reason: 'it closed');
      await mouse.moveTo(away);
      await tester.pumpAndSettle();
    });

    testWidgets(
      'ToastView.dismiss completes once the toast has left the tree',
      (tester) async {
        await tester.pumpWidget(app(controller: controller));
        late ToastView view;
        controller.show(
          'Saved',
          action: (context, t) {
            view = t;
            return const SizedBox();
          },
        );
        await tester.pumpAndSettle();

        var done = false;
        unawaited(view.dismiss().then((_) => done = true));
        await tester.pump();
        expect(done, isFalse, reason: 'the exit is still running');
        expect(find.text('Saved'), findsOneWidget);

        await tester.pumpAndSettle();
        expect(done, isTrue);
        expect(find.text('Saved'), findsNothing);
      },
    );

    testWidgets('ToastView.dismiss on a dismissed toast leaves a new one at '
        'its id standing, and completes once the old one has left', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      const id = ToastId('connection');
      late ToastView old;
      controller.show(
        'Old',
        id: id,
        action: (context, t) {
          old = t;
          return const SizedBox();
        },
      );
      await tester.pumpAndSettle();

      controller.dismiss(id);
      controller.show('New', id: id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      var done = false;
      unawaited(old.dismiss().then((_) => done = true));
      await tester.pump();
      expect(toastsOf(controller).map((r) => r.state.title), [
        'New',
      ], reason: 'the id is the new toast\'s now');
      expect(done, isFalse, reason: 'the old one is still leaving');

      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(find.text('Old'), findsNothing);
      expect(find.text('New'), findsOneWidget);
    });

    testWidgets('the slot is handed an animation that runs 0 to 1 on enter', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      late ToastView view;
      controller.show(
        'Saved',
        action: (context, t) {
          view = t;
          return const SizedBox();
        },
      );
      await tester.pump();
      expect(view.animation.value, 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(view.animation.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(view.animation.value, 1);
    });

    testWidgets('holdTimer pauses until the toast is updated', (tester) async {
      final controller = SonnerController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller: controller));
      late ToastView view;
      final id = controller.show(
        'Dragging',
        action: (context, t) {
          view = t;
          return const SizedBox();
        },
      );
      // Pumped by hand: a toast counting down draws its time left on every
      // frame, so nothing settles until it is gone.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      view.holdTimer();
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Dragging'), findsOneWidget, reason: 'held');

      controller.update(id, title: 'Dropped');
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        find.text('Dropped'),
        findsNothing,
        reason: 'the update let the hold go, and it counted down',
      );
    });

    testWidgets('the close button follows the config, and show overrules it', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Plain');
      await tester.pumpAndSettle();
      expect(
        closeButton(),
        findsNothing,
        reason: 'config.closeButton is false',
      );

      controller.dismissAll();
      await tester.pumpAndSettle();
      controller.show('Asked', closeButton: true);
      await tester.pumpAndSettle();
      expect(closeButton(), findsOneWidget);

      await tester.tap(closeButton());
      await tester.pumpAndSettle();
      expect(find.text('Asked'), findsNothing);
    });

    testWidgets('a toast on screen follows a closeButton assigned to the '
        'config', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Plain');
      await tester.pumpAndSettle();
      expect(closeButton(), findsNothing);

      controller.config = controller.config.copyWith(closeButton: true);
      await tester.pump();
      expect(closeButton(), findsOneWidget);
      expect(presenceOf(tester, 'Plain'), 1, reason: 'nothing entered again');

      await tester.tap(closeButton());
      await tester.pumpAndSettle();
      expect(find.text('Plain'), findsNothing);
    });

    testWidgets('dismissible false takes the close button away, and dismiss '
        'still works', (tester) async {
      final controller = SonnerController(
        config: const SonnerConfig(duration: Duration.zero, closeButton: true),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller: controller));
      final id = controller.show('Pinned', dismissible: false);
      await tester.pumpAndSettle();

      expect(find.text('Pinned'), findsOneWidget);
      expect(
        closeButton(),
        findsNothing,
        reason: 'the close button is a way a user dismisses',
      );

      controller.dismiss(id);
      await tester.pumpAndSettle();
      expect(
        find.text('Pinned'),
        findsNothing,
        reason: 'dismissible governs the user, not the app',
      );
    });

    testWidgets('a loading toast has no close button until it stops loading', (
      tester,
    ) async {
      final controller = SonnerController(
        config: const SonnerConfig(duration: Duration.zero, closeButton: true),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller: controller));
      final id = controller.show('Uploading', isLoading: true);
      // Not pumpAndSettle: the indicator never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(closeButton(), findsNothing);

      controller.update(id, isLoading: false);
      await tester.pumpAndSettle();
      expect(
        closeButton(),
        findsOneWidget,
        reason: 'it hands itself back with no second call',
      );
    });

    testWidgets('a covered toast takes no taps on its content, and still stops '
        'one reaching the app', (tester) async {
      var taps = 0;
      var pressed = 0;
      await tester.pumpWidget(tappableApp(() => taps++));
      controller.show(
        'Behind',
        action: (context, t) =>
            TextButton(onPressed: () => pressed++, child: const Text('Undo')),
      );
      controller.show('Front');
      await tester.pumpAndSettle();

      // The strip of the covered toast that pokes out above the front.
      final behind = boxOf(tester, 'Behind');
      final at = Offset(behind.center.dx, behind.top + 4);
      await tester.tapAt(at);
      await tester.pumpAndSettle();

      expect(pressed, 0, reason: 'nothing is drawn there to press');
      expect(taps, 0, reason: 'the card still stops it reaching the app');

      // Expanded, every toast reads and its button works again.
      final mouse = await mouseAt(tester, boxOf(tester, 'Front').center);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(pressed, 1);
      await mouse.moveTo(away);
      await tester.pumpAndSettle();
    });

    testWidgets('a covered toast keeps its content in the semantics tree', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(app(controller: controller));
      controller.show(
        'Behind',
        closeButton: true,
        action: (context, t) =>
            TextButton(onPressed: () {}, child: const Text('Undo')),
      );
      controller.show('Front');
      await tester.pumpAndSettle();

      expect(contentOpacityOf(tester, 'Behind'), 0, reason: 'not drawn');
      expect(
        tester.getSemantics(find.text('Behind')),
        isSemantics(label: 'Behind', isLiveRegion: true),
        reason: 'what the deck hides is the reading, not the announcement',
      );
      expect(
        find.byIcon(Icons.close),
        findsOneWidget,
        reason: 'still in the tree, ready for the deck to open',
      );
      final announced = tester.getSemantics(find.text('Behind')).label;
      expect(
        announced,
        isNot(contains('Close')),
        reason: 'a covered toast announces its content, not its controls',
      );
      expect(
        tester.getSemantics(find.text('Undo')).owner,
        isNull,
        reason:
            'the action slot goes with it — its node is detached, so a '
            'screen reader is not offered it either',
      );
      expect(
        tester.getSemantics(find.text('Behind')),
        isSemantics(hasTapAction: false),
        reason: 'nothing on a covered toast offers itself to be pressed',
      );
      semantics.dispose();
    });
  });

  group('builder', () {
    /// A look that draws the toast's title under [label], and remembers the
    /// toast it was handed in [views], by title.
    ToastBuilder look(String label, [Map<String, ToastView>? views]) =>
        (context, toast) {
          views?[toast.state.title] = toast;
          return Container(
            height: 60,
            color: const Color(0xFF202020),
            child: Text('$label ${toast.state.title}'),
          );
        };

    testWidgets('a toast with a builder draws what it returns in place of the '
        'default look, and one without keeps the default look', (tester) async {
      final views = <String, ToastView>{};
      await tester.pumpWidget(app(controller: controller));
      final id = controller.show('Custom', builder: look('Own', views));
      controller.show('Plain');
      await tester.pumpAndSettle();

      expect(find.text('Own Custom'), findsOneWidget);
      expect(find.text('Custom'), findsNothing, reason: 'no default look');
      expect(find.byType(DefaultToastLook), findsOneWidget);
      expect(find.text('Plain'), findsOneWidget);
      expect(views['Custom']!.id, id);
    });

    group('behind a shorter front', () {
      late SonnerController controller;
      setUp(
        () => controller = SonnerController(
          config: const SonnerConfig(
            position: SonnerPosition.topLeft,
            duration: Duration.zero,
          ),
        ),
      );
      tearDown(() => controller.dispose());

      const five = 'One\nTwo\nThree\nFour\nFive';

      Widget text(BuildContext context, ToastView toast) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(toast.state.title),
          if (toast.state.description case final description?)
            Text(description),
        ],
      );

      Widget card(ToastView toast, Widget child) => Container(
        key: ValueKey('card ${toast.state.title}'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all()),
        child: child,
      );

      Rect cardOf(WidgetTester tester, String title) =>
          tester.getRect(find.byKey(ValueKey('card $title')));

      Future<void> showTallThenShort(
        WidgetTester tester,
        ToastBuilder builder,
      ) async {
        await tester.pumpWidget(app(controller: controller));
        controller.show('Tall', description: five, builder: builder);
        controller.show('Short', builder: builder);
        await tester.pumpAndSettle();
      }

      testWidgets('a builder from toastCardBuilder draws its card at the '
          'drawn height, and fades only its content', (tester) async {
        await showTallThenShort(
          tester,
          toastCardBuilder(
            card: (context, toast, child) => card(toast, child),
            content: text,
          ),
        );

        expect(tester.takeException(), isNull);
        expect(
          cardOf(tester, 'Tall').height,
          moreOrLessEquals(cardOf(tester, 'Short').height * 0.95),
        );
        expect(contentOpacityOf(tester, 'Short'), 1, reason: 'the front');
        expect(contentOpacityOf(tester, 'Tall'), 0, reason: 'covered');
        expect(
          _fadesAbove(tester, find.byKey(const ValueKey('card Tall'))),
          1,
          reason: 'the card stays',
        );
      });

      testWidgets('a builder that wraps its content in ToastFit draws its '
          'card at the drawn height', (tester) async {
        await showTallThenShort(
          tester,
          (context, toast) =>
              card(toast, ToastFit(child: text(context, toast))),
        );

        expect(tester.takeException(), isNull);
        expect(
          cardOf(tester, 'Tall').height,
          moreOrLessEquals(cardOf(tester, 'Short').height * 0.95),
        );
      });

      testWidgets('a builder that does neither reports its overflow, and '
          'nothing it lets overflow is drawn past the drawn height', (
        tester,
      ) async {
        await showTallThenShort(
          tester,
          (context, toast) => card(toast, text(context, toast)),
        );

        expect(
          tester.takeException(),
          isA<FlutterError>().having(
            (error) => error.message,
            'message',
            contains('overflowed'),
          ),
        );
        final drawn = tester.renderObject<RenderBox>(
          find.ancestor(
            of: find.text('Tall'),
            matching: find.byType(ToastHeight),
          ),
        );
        expect(
          cardOf(tester, 'Tall').height,
          moreOrLessEquals(drawn.size.height * 0.95),
          reason: 'its card is drawn whole',
        );
        expect(drawn, paints..clipRect(rect: Offset.zero & drawn.size));
      });
    });

    testWidgets('config.builder draws every toast without a builder of its '
        'own, and another assigned fades in over it', (tester) async {
      controller.config = controller.config.copyWith(builder: () => look('A'));
      await tester.pumpWidget(app(controller: controller));
      controller.show('Follows');
      controller.show('Keeps', builder: look('Own'));
      await tester.pumpAndSettle();
      expect(find.text('A Follows'), findsOneWidget);
      expect(find.text('Own Keeps'), findsOneWidget);

      controller.config = controller.config.copyWith(builder: () => look('B'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('A Follows'), findsOneWidget, reason: 'fading out');
      expect(find.text('B Follows'), findsOneWidget, reason: 'fading in');
      expect(find.text('Own Keeps'), findsOneWidget, reason: 'not faded');

      await tester.pumpAndSettle();
      expect(find.text('A Follows'), findsNothing);
      expect(find.text('B Follows'), findsOneWidget);

      controller.config = controller.config.copyWith(builder: () => null);
      await tester.pumpAndSettle();
      expect(find.text('Follows'), findsOneWidget, reason: 'the default look');
      expect(find.text('Own Keeps'), findsOneWidget);
    });

    testWidgets('a config change that keeps the builder does not fade the '
        'look', (tester) async {
      controller.config = controller.config.copyWith(builder: () => look('A'));
      await tester.pumpWidget(app(controller: controller));
      controller.show('Follows');
      await tester.pumpAndSettle();

      controller.config = controller.config.copyWith(
        offset: const EdgeInsets.all(80),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('A Follows'), findsOneWidget, reason: 'one layer');
      await tester.pumpAndSettle();
    });

    testWidgets('an update of the builder alone fades the new look in, and '
        'the old one takes no taps', (tester) async {
      var oldTaps = 0;
      await tester.pumpWidget(app(controller: controller));
      final id = controller.show(
        'Saved',
        builder: (context, toast) => GestureDetector(
          onTap: () => oldTaps++,
          child: Container(
            height: 60,
            color: const Color(0xFF202020),
            child: const Text('Old'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.update(id, builder: look('New'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Old'), findsOneWidget, reason: 'still underneath');
      expect(find.text('New Saved'), findsOneWidget);
      await tester.tap(find.text('Old'), warnIfMissed: false);
      expect(oldTaps, 0);
      await tester.pumpAndSettle();
      expect(find.text('Old'), findsNothing);
    });

    testWidgets('an update that keeps the builder fades the new content in '
        'over the old, as the default look does', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      final id = controller.show('Before', builder: look('Own'));
      await tester.pumpAndSettle();

      controller.update(id, title: 'After');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Own Before'), findsOneWidget, reason: 'underneath');
      expect(find.text('Own After'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Own Before'), findsNothing);
    });

    testWidgets('a builder receives an animation that runs 0 to 1 as the toast '
        'enters and 1 to 0 as it leaves', (tester) async {
      final views = <String, ToastView>{};
      await tester.pumpWidget(app(controller: controller));
      final id = controller.show('Saved', builder: look('Own', views));
      await tester.pump();
      final animation = views['Saved']!.animation;
      expect(animation.value, 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(animation.value, closeTo(0.5, 0.01));
      await tester.pumpAndSettle();
      expect(animation.value, 1);

      controller.dismiss(id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(animation.value, closeTo(0.5, 0.01));
      expect(animation.status, AnimationStatus.reverse);
      await tester.pumpAndSettle();
      expect(find.text('Own Saved'), findsNothing);
    });

    testWidgets('covered is 0 at the front, rises toward 1 behind a toast '
        'entering in front, and is 0 again with the deck expanded', (
      tester,
    ) async {
      final views = <String, ToastView>{};
      await tester.pumpWidget(app(controller: controller));
      controller.show('Behind', builder: look('Own', views));
      await tester.pumpAndSettle();
      final covered = views['Behind']!.covered;
      expect(covered.value, 0, reason: 'the front');

      controller.show('Front', builder: look('Own', views));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(covered.value, allOf(greaterThan(0.1), lessThan(0.9)));
      await tester.pumpAndSettle();
      expect(covered.value, 1, reason: 'behind one fully present');
      expect(views['Front']!.covered.value, 0);
      expect(
        identical(views['Behind']!.covered, covered),
        isTrue,
        reason: 'one object a look can listen to, not a value per frame',
      );

      controller.config = controller.config.copyWith(expandByDefault: true);
      await tester.pumpAndSettle();
      expect(covered.value, 0, reason: 'the expansion undoes it');
    });

    testWidgets('a builder that drives its animation to 0 removes the toast, '
        'and a dismiss after that completes', (tester) async {
      final views = <String, ToastView>{};
      await tester.pumpWidget(app(controller: controller));
      controller.show('Flung', builder: look('Own', views));
      controller.show('Front');
      await tester.pumpAndSettle();
      final view = views['Flung']!;

      view.animation.fling(velocity: -2);
      await tester.pumpAndSettle();
      expect(toastsOf(controller).map((r) => r.state.title), ['Front']);
      expect(find.text('Own Flung'), findsNothing);
      expect(tester.takeException(), isNull);

      var completed = false;
      unawaited(view.dismiss().then((_) => completed = true));
      await tester.pump();
      expect(completed, isTrue);
      expect(find.text('Front'), findsOneWidget, reason: 'nothing else went');
    });

    testWidgets('a scrollable in a builder takes the wheel, and the app hears '
        'it scroll', (tester) async {
      var notifications = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              notifications++;
              return false;
            },
            child: SonnerHost(controller: controller, child: child!),
          ),
          home: const SizedBox.expand(),
        ),
      );
      controller.show(
        'List',
        builder: (context, toast) => SizedBox(
          height: 80,
          child: ListView(
            children: [
              for (var i = 0; i < 20; i++)
                SizedBox(height: 30, child: Text('Row $i')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final at = tester.getCenter(find.text('Row 1'));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(at));
      await tester.pumpAndSettle();
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 60)));
      await tester.pumpAndSettle();

      expect(find.text('Row 0'), findsNothing, reason: 'the list scrolled');
      expect(notifications, greaterThan(0));
      await tester.sendEventToBinding(pointer.removePointer());
    });

    testWidgets('a builder that flings to 0 and then dismisses, as flash '
        'does, is removed once', (tester) async {
      final views = <String, ToastView>{};
      await tester.pumpWidget(app(controller: controller));
      controller.show('Flung', builder: look('Own', views));
      await tester.pumpAndSettle();
      final view = views['Flung']!;

      view.animation.fling(velocity: -2);
      var completed = false;
      unawaited(view.dismiss().then((_) => completed = true));
      await tester.pumpAndSettle();
      expect(toastsOf(controller), isEmpty);
      expect(find.text('Own Flung'), findsNothing);
      expect(completed, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('swipe', () {
    /// Presses [title]'s card and drags it [by] over [taking], holding on.
    Future<TestGesture> dragBy(
      WidgetTester tester,
      String title,
      Offset by, {
      Duration taking = const Duration(seconds: 1),
    }) async {
      final gesture = await tester.startGesture(
        toastRect(tester, title).center,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(by, timeStamp: taking);
      await tester.pump();
      return gesture;
    }

    /// Drags [title]'s card [by] over [taking], and lets go.
    Future<void> swipe(
      WidgetTester tester,
      String title,
      Offset by, {
      Duration taking = const Duration(seconds: 1),
    }) async {
      final gesture = await dragBy(tester, title, by, taking: taking);
      await gesture.up();
      await tester.pump();
    }

    testWidgets('a drag past 45 px in an allowed direction dismisses', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Saved');
      await tester.pumpAndSettle();

      // 60 px over a second: past the threshold and well under the speed.
      await swipe(tester, 'Saved', const Offset(0, 60));

      expect(toastsOf(controller), isEmpty);
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('a drag short of it, and slow, springs the toast back', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Saved');
      await tester.pumpAndSettle();
      final at = toastRect(tester, 'Saved');

      await swipe(tester, 'Saved', const Offset(0, 30));

      expect(toastsOf(controller), hasLength(1));
      await tester.pumpAndSettle();
      expect(toastRect(tester, 'Saved'), at);
    });

    testWidgets('a drag short of it, but fast, dismisses on speed alone', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Saved');
      await tester.pumpAndSettle();

      // 20 px in 100 ms: 0.2 px/ms, past the speed and well short of 45 px.
      await swipe(
        tester,
        'Saved',
        const Offset(0, 20),
        taking: const Duration(milliseconds: 100),
      );

      expect(toastsOf(controller), isEmpty);
      await tester.pumpAndSettle();
    });

    testWidgets('a swiped toast leaves the way it was swiped, over 200 ms', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Saved');
      await tester.pumpAndSettle();
      final at = toastRect(tester, 'Saved');

      // Right, which `bottomRight` allows and which the exit slide — down,
      // the edge the toast entered from — would not take it.
      await swipe(tester, 'Saved', const Offset(60, 0));

      await tester.pump(const Duration(milliseconds: 100));
      final going = toastRect(tester, 'Saved');
      expect(
        going.left,
        greaterThan(at.left + 60),
        reason: 'it carries on past where the drag left it',
      );
      expect(going.top, at.top, reason: 'and not toward the edge below it');
      expect(presenceOf(tester, 'Saved'), inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 100));
      expect(presenceOf(tester, 'Saved'), 0);
      // An AnimationController reports `dismissed` on the first tick past its
      // duration.
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('a drag the position does not allow is damped, not blocked', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Saved');
      await tester.pumpAndSettle();
      final at = toastRect(tester, 'Saved');

      // Up, which `bottomRight` does not allow.
      final gesture = await dragBy(tester, 'Saved', const Offset(0, -60));

      expect(
        at.top - toastRect(tester, 'Saved').top,
        closeTo(13.33, 0.05),
        reason: '60 px damped by 1 / (1.5 + 60 / 20)',
      );

      await gesture.up();
      await tester.pump();
      expect(toastsOf(controller), hasLength(1));
      await tester.pumpAndSettle();
      expect(toastRect(tester, 'Saved'), at);
    });

    testWidgets('a fast flick the wrong way is fast enough and still stays', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Saved');
      await tester.pumpAndSettle();

      // The damped 13.33 px in 100 ms is 0.133 px/ms, past the speed: the
      // direction is what refuses it.
      await swipe(
        tester,
        'Saved',
        const Offset(0, -60),
        taking: const Duration(milliseconds: 100),
      );

      expect(toastsOf(controller), hasLength(1));
      await tester.pumpAndSettle();
    });

    /// A controller whose toasts have no timer, configured by [config].
    SonnerController controllerWith(SonnerConfig config) {
      final made = SonnerController(config: config);
      addTearDown(made.dispose);
      return made;
    }

    testWidgets("the position's own words name the directions", (tester) async {
      final left = controllerWith(
        const SonnerConfig(
          duration: Duration.zero,
          position: SonnerPosition.bottomLeft,
        ),
      );
      await tester.pumpWidget(app(controller: left));
      left.show('Saved');
      await tester.pumpAndSettle();

      await swipe(tester, 'Saved', const Offset(60, 0));
      expect(
        toastsOf(left),
        hasLength(1),
        reason: 'right is the way `bottomLeft` does not allow',
      );
      await tester.pumpAndSettle();

      await swipe(tester, 'Saved', const Offset(-60, 0));
      expect(toastsOf(left), isEmpty);
      await tester.pumpAndSettle();
    });

    testWidgets('another position names another set', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Saved');
      await tester.pumpAndSettle();

      await swipe(tester, 'Saved', const Offset(0, -60));
      expect(
        toastsOf(controller),
        hasLength(1),
        reason: 'up is the way `bottomRight` does not allow',
      );
      await tester.pumpAndSettle();

      // Read at each pointer-down, so they follow a position assigned with
      // the toast on screen.
      controller.config = controller.config.copyWith(
        position: SonnerPosition.topRight,
      );
      await tester.pumpAndSettle();

      await swipe(tester, 'Saved', const Offset(0, 60));
      expect(
        toastsOf(controller),
        hasLength(1),
        reason: 'down is the way `topRight` does not allow',
      );
      await tester.pumpAndSettle();

      await swipe(tester, 'Saved', const Offset(0, -60));
      expect(toastsOf(controller), isEmpty);
      await tester.pumpAndSettle();
    });

    testWidgets('config.swipeDirections wins over the position', (
      tester,
    ) async {
      final upward = controllerWith(
        const SonnerConfig(
          duration: Duration.zero,
          swipeDirections: {SwipeDirection.up},
        ),
      );
      await tester.pumpWidget(app(controller: upward));
      upward.show('Saved');
      await tester.pumpAndSettle();

      await swipe(tester, 'Saved', const Offset(0, 60));
      expect(
        toastsOf(upward),
        hasLength(1),
        reason: 'down is what `bottomRight` names, and the config took it away',
      );
      await tester.pumpAndSettle();

      await swipe(tester, 'Saved', const Offset(0, -60));
      expect(toastsOf(upward), isEmpty);
      await tester.pumpAndSettle();
    });

    testWidgets('config.swipeDirections can name several ways out, and every '
        'one of them dismisses', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.config = controller.config.copyWith(
        swipeDirections: () => {SwipeDirection.left, SwipeDirection.right},
      );

      for (final (way, by) in [
        ('left', const Offset(-60, 0)),
        ('right', const Offset(60, 0)),
      ]) {
        controller.show('Saved');
        await tester.pumpAndSettle();
        await swipe(tester, 'Saved', by);
        expect(toastsOf(controller), isEmpty, reason: way);
        await tester.pumpAndSettle();
      }

      controller.show('Saved');
      await tester.pumpAndSettle();
      await swipe(tester, 'Saved', const Offset(0, 60));
      expect(
        toastsOf(controller),
        hasLength(1),
        reason: 'down is what `bottomRight` names, and the set left it out',
      );
      await tester.pumpAndSettle();

      controller.config = controller.config.copyWith(
        swipeDirections: () => SwipeDirection.values.toSet(),
      );
      for (final (way, by) in [
        ('up', const Offset(0, -60)),
        ('down', const Offset(0, 60)),
      ]) {
        if (toastsOf(controller).isEmpty) {
          controller.show('Saved');
          await tester.pumpAndSettle();
        }
        await swipe(tester, 'Saved', by);
        expect(toastsOf(controller), isEmpty, reason: 'all four: $way');
        await tester.pumpAndSettle();
      }
    });

    testWidgets('a toast the deck covers takes a swipe like any other', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Behind');
      controller.show('Front');
      await tester.pumpAndSettle();
      final behind = toastRect(tester, 'Behind');
      final front = toastRect(tester, 'Front');
      expect(behind.top, lessThan(front.top), reason: 'its strip peeks out');

      // The strip above the front, which only the covered toast is under.
      final strip = Offset(front.center.dx, (behind.top + front.top) / 2);
      final gesture = await tester.startGesture(
        strip,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(
        const Offset(0, 60),
        timeStamp: const Duration(seconds: 1),
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(toastsOf(controller).map((toast) => toast.state.title), ['Front']);
      await gesture.removePointer();
      await tester.pumpAndSettle();
    });

    testWidgets('a toast the user may not dismiss takes no swipe', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      final id = controller.show('Pinned', dismissible: false);
      await tester.pumpAndSettle();
      final at = toastRect(tester, 'Pinned');

      final gesture = await dragBy(tester, 'Pinned', const Offset(0, 60));
      expect(
        toastRect(tester, 'Pinned'),
        at,
        reason: 'the drag does not move it either',
      );
      await gesture.up();
      await tester.pump();
      expect(toastsOf(controller), hasLength(1));

      controller.dismiss(id);
      await tester.pumpAndSettle();
      expect(
        toastsOf(controller),
        isEmpty,
        reason: 'what it takes away is the user, not the app',
      );
    });

    testWidgets('a loading toast takes one the moment it stops loading', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      final id = controller.show('Uploading', isLoading: true);
      // Not pumpAndSettle: the indicator never settles (see the note on
      // SonnerConfig.loadingIndicator).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await swipe(tester, 'Uploading', const Offset(0, 60));
      expect(
        toastsOf(controller),
        hasLength(1),
        reason: 'unset `dismissible` follows `isLoading`',
      );

      controller.update(id, isLoading: false, title: 'Uploaded');
      await tester.pumpAndSettle();

      await swipe(tester, 'Uploaded', const Offset(0, 60));
      expect(
        toastsOf(controller),
        isEmpty,
        reason: 'and the caller never mentions `dismissible`',
      );
      await tester.pumpAndSettle();
    });

    /// A mouse that presses [title] and drags it [by], holding on, from a
    /// pointer that was already resting on the deck.
    Future<TestGesture> pressAndDrag(
      WidgetTester tester,
      String title,
      Offset by,
    ) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final at = toastRect(tester, title).center;
      await mouse.addPointer(location: at - const Offset(1, 0));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(at);
      await tester.pump();
      await mouse.down(at);
      await tester.pump();
      await mouse.moveBy(by, timeStamp: const Duration(seconds: 1));
      await tester.pump();
      return mouse;
    }

    testWidgets('a drag holds the timers, and keeps holding off the deck', (
      tester,
    ) async {
      final counting = controllerWith(
        const SonnerConfig(duration: Duration(seconds: 1)),
      );
      await tester.pumpWidget(app(controller: counting));
      counting.show('Saved');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final mouse = await pressAndDrag(tester, 'Saved', const Offset(0, 20));
      // Off the deck with the button still down, which the hover lets go of.
      await mouse.moveTo(
        const Offset(40, 40),
        timeStamp: const Duration(seconds: 2),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(
        toastsOf(counting),
        hasLength(1),
        reason: 'the drag holds them where the pointer no longer does',
      );

      await mouse.up();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(toastsOf(counting), isEmpty, reason: 'and lets go when it ends');
      await tester.pumpAndSettle();
    });

    testWidgets('a toast that stops being dismissible mid-drag lets go', (
      tester,
    ) async {
      final counting = controllerWith(
        const SonnerConfig(duration: Duration(seconds: 1)),
      );
      await tester.pumpWidget(app(controller: counting));
      final id = counting.show('Saved', duration: Duration.zero);
      await tester.pumpAndSettle();
      final at = toastRect(tester, 'Saved');

      final gesture = await dragBy(tester, 'Saved', const Offset(0, 60));
      counting.update(id, isLoading: true);
      await tester.pump();
      await gesture.up();
      await gesture.removePointer();
      await tester.pump();
      expect(
        toastsOf(counting),
        hasLength(1),
        reason: 'past the threshold, and the user may not dismiss it now',
      );

      counting.show('Counts');
      await tester.pump(const Duration(milliseconds: 1500));
      expect(
        toastsOf(counting).map((toast) => toast.state.title),
        ['Saved'],
        reason:
            'the drag let the timers go, though its recognizer said nothing',
      );
      expect(toastRect(tester, 'Saved'), at, reason: 'and it came back');
      counting.dismissAll();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a host gone from under a press ignores it going up', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Saved');
      await tester.pumpAndSettle();

      final gesture = await dragBy(tester, 'Saved', const Offset(0, 60));
      await tester.pumpWidget(const SizedBox.expand());
      await gesture.up();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('a press keeps the deck fanned out until it lets go', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Behind');
      controller.show('Front');
      await tester.pumpAndSettle();
      expect(scaleOf(tester, 'Behind'), closeTo(0.95, 0.001));

      final mouse = await pressAndDrag(tester, 'Front', const Offset(0, 20));
      await tester.pumpAndSettle();
      expect(scaleOf(tester, 'Behind'), 1, reason: 'the pointer fans it out');

      await mouse.moveTo(
        const Offset(40, 40),
        timeStamp: const Duration(seconds: 2),
      );
      await tester.pumpAndSettle();
      expect(
        scaleOf(tester, 'Behind'),
        1,
        reason: 'and the press holds it open, off the deck and all',
      );

      await mouse.up();
      await tester.pumpAndSettle();
      expect(scaleOf(tester, 'Behind'), closeTo(0.95, 0.001));
    });
  });

  group('config assigned', () {
    /// A toast's box before it is scaled.
    Rect boxOf(WidgetTester tester, String title) => tester.getRect(
      find.ancestor(
        of: find.text(title),
        matching: find.byType(SlideTransition),
      ),
    );

    testWidgets('a new offset moves the toasts over 400 ms, from where they '
        'were', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Behind');
      controller.show('Front');
      await tester.pumpAndSettle();
      expect(boxOf(tester, 'Front').bottom, 576);
      expect(boxOf(tester, 'Behind').bottom, 562);

      controller.config = controller.config.copyWith(
        offset: const EdgeInsets.all(80),
      );
      await tester.pump();
      expect(boxOf(tester, 'Front').bottom, 576, reason: 'no jump');

      await tester.pump(const Duration(milliseconds: 200));
      expect(
        boxOf(tester, 'Front').bottom,
        allOf(lessThan(575), greaterThan(521)),
        reason: 'on its way',
      );
      expect(
        boxOf(tester, 'Front').bottom - boxOf(tester, 'Behind').bottom,
        moreOrLessEquals(14),
        reason: 'the deck moves as one',
      );

      await tester.pump(const Duration(milliseconds: 201));
      expect(boxOf(tester, 'Front').bottom, 520);
      expect(boxOf(tester, 'Behind').bottom, 506);
    });

    testWidgets('a config assigned first thing after the host mounts still '
        'moves the toasts from where they were', (tester) async {
      controller.show('Front');
      await tester.pumpWidget(app(controller: controller));
      await tester.pumpAndSettle();

      controller.config = controller.config.copyWith(
        offset: const EdgeInsets.all(80),
      );
      await tester.pump();
      expect(boxOf(tester, 'Front').bottom, 576, reason: 'no jump');
      await tester.pumpAndSettle();
      expect(boxOf(tester, 'Front').bottom, 520);
    });

    testWidgets('a toast brought back by swapping its controller back follows '
        'the next config, wherever an assignment left it', (tester) async {
      final other = SonnerController(
        config: const SonnerConfig(duration: Duration.zero),
      );
      addTearDown(other.dispose);
      await tester.pumpWidget(app(controller: controller));
      controller.show('Kept');
      await tester.pumpAndSettle();

      await tester.pumpWidget(app(controller: other));
      await tester.pump(const Duration(milliseconds: 50));
      other.config = other.config.copyWith(offset: const EdgeInsets.all(80));
      await tester.pump();
      await tester.pumpWidget(app(controller: controller));
      await tester.pumpAndSettle();
      expect(boxOf(tester, 'Kept').bottom, 576);

      controller.config = controller.config.copyWith(
        offset: const EdgeInsets.all(80),
      );
      await tester.pumpAndSettle();
      expect(boxOf(tester, 'Kept').bottom, 520);
    });

    testWidgets(
      'a new position takes the toasts across the screen over 400 ms',
      (tester) async {
        await tester.pumpWidget(app(controller: controller));
        controller.show('Front');
        await tester.pumpAndSettle();
        final start = boxOf(tester, 'Front');
        expect((start.left, start.bottom), (420.0, 576.0));

        controller.config = controller.config.copyWith(
          position: SonnerPosition.topLeft,
        );
        await tester.pump();
        expect(boxOf(tester, 'Front'), start, reason: 'no jump');

        await tester.pump(const Duration(milliseconds: 200));
        final halfway = boxOf(tester, 'Front');
        expect(halfway.left, allOf(greaterThan(25), lessThan(419)));
        expect(halfway.top, allOf(greaterThan(25), lessThan(start.top - 1)));

        await tester.pump(const Duration(milliseconds: 201));
        final end = boxOf(tester, 'Front');
        expect((end.left, end.top), (24.0, 24.0));
        expect(presenceOf(tester, 'Front'), 1, reason: 'nothing entered again');
      },
    );

    testWidgets('a narrower toast keeps the edge its position names', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Front');
      await tester.pumpAndSettle();

      controller.config = controller.config.copyWith(width: 200);
      await tester.pump();
      expect(
        (boxOf(tester, 'Front').right, boxOf(tester, 'Front').width),
        (776.0, 200.0),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(boxOf(tester, 'Front').right, 776);
    });

    testWidgets('a toast leaving a lowered window fades over 400 ms, and one '
        'coming back into a raised window fades in', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      for (final title in ['Oldest', 'Middle', 'Newest']) {
        controller.show(title);
      }
      await tester.pumpAndSettle();
      expect(paintedOpacityOf(tester, 'Middle'), 1);

      controller.config = controller.config.copyWith(visibleToasts: 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        paintedOpacityOf(tester, 'Middle'),
        allOf(greaterThan(0), lessThan(1)),
        reason: 'on its way out',
      );
      await tester.pump(const Duration(milliseconds: 301));
      expect(find.text('Middle'), findsNothing);

      controller.config = controller.config.copyWith(visibleToasts: 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        paintedOpacityOf(tester, 'Middle'),
        allOf(greaterThan(0), lessThan(1)),
        reason: 'on its way back',
      );
      await tester.pump(const Duration(milliseconds: 101));
      expect(paintedOpacityOf(tester, 'Middle'), 1);
    });

    testWidgets('a toast exiting as a config is assigned stays where it is on '
        'screen', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Behind');
      controller.show('Front');
      await tester.pumpAndSettle();
      controller.dismiss(toastsOf(controller).first.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final at = boxOf(tester, 'Front');

      controller.config = controller.config.copyWith(
        position: SonnerPosition.topLeft,
      );
      for (var elapsed = 0; elapsed < 140; elapsed += 20) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(boxOf(tester, 'Front'), at, reason: 'at $elapsed ms');
        expect(
          tester
              .widget<SlideTransition>(
                find.ancestor(
                  of: find.text('Front'),
                  matching: find.byType(SlideTransition),
                ),
              )
              .position
              .value
              .dy,
          greaterThan(0),
          reason: 'still leaving toward the bottom edge, at $elapsed ms',
        );
      }
      expect(boxOf(tester, 'Behind').top, lessThan(at.top - 1));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump();
      expect(find.text('Front'), findsNothing, reason: 'removed on time');
      await tester.pumpAndSettle();
    });

    testWidgets('a toast dismissed on its way to a new config stays where it '
        'was drawn', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Front');
      await tester.pumpAndSettle();
      controller.config = controller.config.copyWith(
        offset: const EdgeInsets.all(200),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final at = boxOf(tester, 'Front');

      controller.dismiss(toastsOf(controller).first.id);
      await tester.pump();
      expect(boxOf(tester, 'Front'), at);
      await tester.pump(const Duration(milliseconds: 100));
      expect(boxOf(tester, 'Front'), at);
      await tester.pumpAndSettle();
    });

    testWidgets('a config assigned on the way to another goes on from where '
        'the toasts are drawn', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Front');
      await tester.pumpAndSettle();
      controller.config = controller.config.copyWith(
        offset: const EdgeInsets.all(200),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final at = boxOf(tester, 'Front').bottom;
      expect(at, allOf(lessThan(575), greaterThan(401)));

      controller.config = controller.config.copyWith(
        offset: const EdgeInsets.all(24),
      );
      await tester.pump();
      expect(boxOf(tester, 'Front').bottom, moreOrLessEquals(at));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        boxOf(tester, 'Front').bottom,
        // Toward 576, by less than a frame of 400 ms run at its fastest.
        allOf(greaterThan(at), lessThan(at + (576 - at) * 16 / 400 * 1.6)),
        reason: 'on its way back, from where it was',
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(boxOf(tester, 'Front').bottom, 576);
    });

    testWidgets('a config assigned during a build moves the toasts from where '
        'they were', (tester) async {
      await tester.pumpWidget(
        rebuildingApp(
          () => controller.config = controller.config.copyWith(
            offset: const EdgeInsets.all(80),
          ),
        ),
      );
      controller.show('Front');
      await tester.pumpAndSettle();

      rebuild();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(boxOf(tester, 'Front').bottom, 576, reason: 'no jump');
      // The glide starts at the end of the frame that assigned it, so its
      // first frame is the next one.
      await tester.pump();
      expect(boxOf(tester, 'Front').bottom, 576, reason: 'no jump');
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        boxOf(tester, 'Front').bottom,
        allOf(lessThan(575), greaterThan(521)),
        reason: 'on its way',
      );
      await tester.pumpAndSettle();
      expect(boxOf(tester, 'Front').bottom, 520);
    });

    testWidgets('a config assigned while a widget above the host builds moves '
        'the toasts from where they were', (tester) async {
      late StateSetter rebuildAbove;
      var builds = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuildAbove = setState;
            if (++builds == 2) {
              controller.config = controller.config.copyWith(
                offset: const EdgeInsets.all(80),
              );
            }
            return app(controller: controller);
          },
        ),
      );
      controller.show('Front');
      await tester.pumpAndSettle();

      rebuildAbove(() {});
      await tester.pump();
      expect(boxOf(tester, 'Front').bottom, 576, reason: 'no jump');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        boxOf(tester, 'Front').bottom,
        allOf(lessThan(575), greaterThan(521)),
        reason: 'on its way',
      );
      await tester.pumpAndSettle();
      expect(boxOf(tester, 'Front').bottom, 520);
    });
  });

  group('a show during a build', () {
    testWidgets('is drawn, with the toasts already drawn', (tester) async {
      await tester.pumpWidget(
        rebuildingApp(() => controller.show('From a build')),
      );
      controller.show('Before');
      await tester.pumpAndSettle();

      rebuild();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('From a build'), findsOneWidget);
      expect(find.text('Before'), findsOneWidget);
    });

    testWidgets('by a page that takes the host out of the tree reaches no '
        'host', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Before');
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            controller.show('From a build');
            return const SizedBox.expand();
          },
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
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

  testWidgets(
    'swapping back to a controller while its toasts exit keeps them',
    (tester) async {
      final other = SonnerController(
        config: const SonnerConfig(duration: Duration.zero),
      );
      addTearDown(other.dispose);
      await tester.pumpWidget(app(controller: controller));
      final kept = controller.show('Kept');
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(controller: other));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(app(controller: controller));
      expect(find.text('Kept'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Kept'), findsOneWidget);

      controller.dismiss(kept);
      await tester.pumpAndSettle();
      expect(find.text('Kept'), findsNothing);
    },
  );

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

  group('time left', () {
    /// The toasts' views by title, as their action slots were handed them.
    final views = <String, ToastView>{};
    setUp(views.clear);

    ToastId showCounting(
      String title, {
      Duration duration = const Duration(seconds: 4),
      bool isLoading = false,
    }) => controller.show(
      title,
      duration: isLoading ? null : duration,
      isLoading: isLoading,
      action: (context, toast) {
        views[toast.state.title] = toast;
        return const SizedBox();
      },
    );

    testWidgets('a toast counting down has a time left, starting full; one '
        'with no timer has none until it starts counting', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      showCounting('Counting');
      showCounting('Waits', duration: Duration.zero);
      final saving = showCounting('Saving', isLoading: true);
      await tester.pump();

      expect(views['Counting']!.timeLeft?.value, 1);
      expect(views['Waits']!.timeLeft, isNull, reason: 'Duration.zero');
      expect(views['Saving']!.timeLeft, isNull, reason: 'loading');

      controller.update(
        saving,
        isLoading: false,
        duration: const Duration(seconds: 4),
      );
      await tester.pump();
      expect(views['Saving']!.timeLeft?.value, 1);

      controller.dismissAll();
      await tester.pumpAndSettle();
    });

    testWidgets('time left runs down on every frame rather than a tick at a '
        'time, and is empty when the timer dismisses the toast', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      showCounting('Counting', duration: const Duration(seconds: 1));
      await tester.pump();

      final values = <double>[];
      while (toastsOf(controller).isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 16));
        values.add(views['Counting']!.timeLeft!.value);
      }
      var moved = 0;
      for (var i = 1; i < values.length; i++) {
        final step = values[i - 1] - values[i];
        expect(step, greaterThanOrEqualTo(0), reason: 'frame $i rose');
        // A tick is a tenth of this toast's second.
        expect(step, lessThan(0.05), reason: 'frame $i stepped a tick');
        if (step > 0) moved++;
      }
      expect(moved, greaterThan(values.length * 0.8), reason: 'most frames');
      expect(values.last, 0, reason: 'empty as the timer dismisses it');
      await tester.pumpAndSettle();
    });

    testWidgets('time left stands still while the timers are paused, and '
        'goes on from where it stood', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      showCounting('Counting');
      await tester.pump();
      Future<List<double>> frames(int count) async => [
        for (var i = 0; i < count; i++)
          await tester
              .pump(const Duration(milliseconds: 16))
              .then((_) => views['Counting']!.timeLeft!.value),
      ];
      await frames(30);

      // The pointer on the deck.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final counting = tester.getCenter(find.text('Counting'));
      await mouse.addPointer(location: counting - const Offset(1, 0));
      await mouse.moveTo(counting);
      await tester.pump();
      final stood = views['Counting']!.timeLeft!.value;
      expect(await frames(60), everyElement(stood));

      await mouse.moveTo(const Offset(10, 10));
      await tester.pump();
      var going = await frames(30);
      expect(going.first, lessThanOrEqualTo(stood));
      expect(stood - going.first, lessThan(0.01), reason: 'no jump');
      expect(going.last, lessThan(stood));

      // The app hidden.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      final hidden = views['Counting']!.timeLeft!.value;
      expect(await frames(60), everyElement(hidden));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      going = await frames(30);
      expect(hidden - going.first, lessThan(0.01), reason: 'no jump');
      expect(going.last, lessThan(hidden));

      controller.dismissAll();
      await tester.pumpAndSettle();
    });

    testWidgets('a countdown started again eases the time left back up over '
        '400 ms, or jumps to full without easeRestart', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      for (final ease in [true, false]) {
        controller.config = controller.config.copyWith(
          timeLeft: () => ToastTimeLeft(easeRestart: ease),
        );
        final id = showCounting('Counting $ease');
        await tester.pump();
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final left = views['Counting $ease']!.timeLeft!;
        final before = left.value;
        expect(before, lessThan(0.8));

        controller.update(id, description: 'Again');
        await tester.pump(const Duration(milliseconds: 16));
        final first = left.value;
        await tester.pump(const Duration(milliseconds: 184));
        final halfway = left.value;
        await tester.pump(const Duration(milliseconds: 250));
        final after = left.value;
        if (ease) {
          expect(first - before, lessThan(0.05), reason: 'barely moved yet');
          // On its way up toward a countdown that is already running again.
          expect(halfway, inExclusiveRange(first + 0.05, 0.99));
          expect(after, greaterThan(0.85), reason: 'up, and counting on');
        } else {
          expect(first, greaterThan(0.99), reason: 'full at once');
          expect(after, lessThan(first), reason: 'counting on');
          // A shorter duration starts it again too.
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          controller.update(id, duration: const Duration(seconds: 2));
          await tester.pump(const Duration(milliseconds: 16));
          expect(left.value, greaterThan(0.99), reason: 'a shorter restart');
          for (var i = 0; i < 30; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(
            left.value,
            lessThan(0.85),
            reason: 'counting from the shorter duration, not the time before',
          );
        }
        controller.dismissAll();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('frames run for the time left only while a toast counts '
        'down', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show('Waits');
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'no timer');

      final id = showCounting('Counting');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'counting');

      controller.dismiss(id);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'gone');
      controller.dismissAll();
      await tester.pumpAndSettle();
    });

    /// Runs frames until the ticker has stopped, or says it has not: it stops
    /// from inside its own callback, so one frame after the last drawn toast
    /// counting down goes out of sight.
    Future<bool> settledWithoutFrames(WidgetTester tester) async {
      for (var n = 0; n < 4; n++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (!tester.binding.hasScheduledFrame) return true;
      }
      return false;
    }

    testWidgets('and only while one of them is drawn: a stowed deck is worth '
        'no frames, and takes them up again as it comes back', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      showCounting('Counting', duration: const Duration(seconds: 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'drawn');

      controller.stow();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        await settledWithoutFrames(tester),
        isTrue,
        reason: 'out of sight: nothing to draw the time left on',
      );

      controller.unstow();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'drawn again');

      controller.dismissAll();
      await tester.pumpAndSettle();
    });

    testWidgets('a toast counting beyond the window is worth no frames on its '
        'own, and is followed again once the pointer reveals it', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      // Newest first, so the counting one is the one the others push out.
      showCounting('Counting', duration: const Duration(seconds: 10));
      for (var n = 0; n < 3; n++) {
        showCounting('Waits $n', duration: Duration.zero);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        await settledWithoutFrames(tester),
        isTrue,
        reason: 'the only toast counting is beyond visibleToasts',
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Waits 2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.binding.hasScheduledFrame,
        isTrue,
        reason: 'revealed, so drawn, so followed again',
      );

      await mouse.moveTo(const Offset(-100, -100));
      controller.dismissAll();
      await tester.pumpAndSettle();
    });

    testWidgets('a time left taken up again is the controller’s number, not '
        'where it stood when it went out of sight', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      showCounting('Counting', duration: const Duration(seconds: 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final timeLeft = views['Counting']!.timeLeft!;

      controller.stow();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(await settledWithoutFrames(tester), isTrue);
      final stood = timeLeft.value;
      expect(stood, closeTo(0.91, 0.02), reason: 'about 0.9 s has gone');

      // Twenty seconds pass with the deck away and the app gone, so the
      // countdown does not run either: the toast has spent none of them. The
      // follower sees none of them go by.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump(const Duration(seconds: 20));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // The tick the resume lets pass is spent out of sight, so the frame the
      // deck comes back on has nothing shielding it from the gap.
      await tester.pump(const Duration(milliseconds: 300));

      controller.unstow();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        timeLeft.value,
        closeTo(0.89, 0.02),
        reason:
            'about 0.2 s more has been counted since, and not one of the 20 '
            'seconds the countdown stood still for',
      );

      controller.dismissAll();
      await tester.pumpAndSettle();
    });

    /// The painters the default look of [title] draws its time left with.
    List<CustomPainter> painted(WidgetTester tester, String title) => [
      for (final paint in tester.widgetList<CustomPaint>(
        find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(DefaultToastLook),
          ),
          matching: find.byType(CustomPaint),
        ),
      ))
        if (paint.painter case final TimeLeftPainter painter) painter,
    ];

    testWidgets('the default look draws the time left as a border sweeping '
        'clockwise from the top start, 2 px in the theme’s primary colour; a '
        'toast with no timer draws none', (tester) async {
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6A1B9A)),
      );
      await tester.pumpWidget(app(controller: controller, theme: theme));
      showCounting('Counting');
      showCounting('Waits', duration: Duration.zero);
      await tester.pump();

      final [painter as TimeLeftBorderPainter] = painted(tester, 'Counting');
      expect(painter.timeLeft, same(views['Counting']!.timeLeft));
      expect(painter.color, theme.colorScheme.primary);
      expect(painter.strokeWidth, 2);
      expect(painter.start, TimeLeftStart.topStart);
      expect(painter.clockwise, isTrue);
      expect(painted(tester, 'Waits'), isEmpty);

      controller.dismissAll();
      await tester.pumpAndSettle();
    });

    testWidgets('each look is drawn where the config names it, and at once; '
        'with none the default look draws nothing, and a builder still gets '
        'the time left', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      controller.show(
        'Built',
        duration: const Duration(seconds: 4),
        builder: (context, toast) {
          views['Built'] = toast;
          return const SizedBox(height: 40, child: Text('Built'));
        },
      );
      // In front, so drawn at full scale.
      showCounting('Counting');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final card = toastRect(tester, 'Counting');

      Rect paintedAt(CustomPainter painter) => tester.getRect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && identical(widget.painter, painter),
        ),
      );

      for (final look in TimeLeftLook.values) {
        controller.config = controller.config.copyWith(
          timeLeft: () => ToastTimeLeft(look: look),
        );
        await tester.pump();
        final [painter] = painted(tester, 'Counting');
        switch (look) {
          case TimeLeftLook.border:
            expect(painter, isA<TimeLeftBorderPainter>());
            expect(paintedAt(painter), card);
          case TimeLeftLook.bottomBar || TimeLeftLook.topBar:
            expect(
              painter,
              isA<TimeLeftBarPainter>().having(
                (it) => it.atTop,
                'atTop',
                look == TimeLeftLook.topBar,
              ),
            );
            expect(paintedAt(painter), card);
          case TimeLeftLook.cornerRing:
            expect(painter, isA<TimeLeftRingPainter>());
            expect(
              paintedAt(painter),
              Rect.fromLTRB(
                card.right - 20,
                card.bottom - 20,
                card.right - 8,
                card.bottom - 8,
              ),
              reason: '12 px, 8 px in from the bottom end corner',
            );
          case TimeLeftLook.leadingRing:
            expect(painter, isA<TimeLeftRingPainter>());
            expect(
              paintedAt(painter),
              Rect.fromLTWH(card.left + 16, card.center.dy - 10, 20, 20),
              reason: 'the leading slot, which the ring makes',
            );
        }
      }

      controller.config = controller.config.copyWith(timeLeft: () => null);
      await tester.pump();
      expect(painted(tester, 'Counting'), isEmpty);
      expect(views['Built']!.timeLeft, isNotNull);

      controller.dismissAll();
      await tester.pumpAndSettle();
    });

    testWidgets('the config’s own colour and stroke are drawn; the card’s '
        'border goes from under a border sweep without keepBorder; a covered '
        'toast’s time left fades with its content unless told otherwise', (
      tester,
    ) async {
      const red = Color(0xFFFF0000);
      final theme = ThemeData();
      controller.config = controller.config.copyWith(
        timeLeft: () =>
            const ToastTimeLeft(color: red, strokeWidth: 3, keepBorder: false),
      );
      await tester.pumpWidget(app(controller: controller, theme: theme));
      showCounting('Behind');
      showCounting('Front');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final [front as TimeLeftBorderPainter] = painted(tester, 'Front');
      expect(front.color, red);
      expect(front.strokeWidth, 3);
      BorderSide sideOf(String title) =>
          (tester
                      .widget<Material>(
                        find
                            .ancestor(
                              of: find.text(title),
                              matching: find.byType(Material),
                            )
                            .first,
                      )
                      .shape!
                  as RoundedRectangleBorder)
              .side;
      expect(sideOf('Front'), BorderSide.none);

      /// How opaque the look draws [painter], within the toast’s own look.
      double opacityOf(CustomPainter painter) {
        final paint = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && identical(widget.painter, painter),
        );
        var opacity = 1.0;
        for (final fade in tester.widgetList<FadeTransition>(
          find.ancestor(
            of: paint,
            matching: find.descendant(
              of: find.byType(DefaultToastLook),
              matching: find.byType(FadeTransition),
            ),
          ),
        )) {
          opacity *= fade.opacity.value;
        }
        return opacity;
      }

      final [behind] = painted(tester, 'Behind');
      expect(opacityOf(front), 1);
      expect(
        opacityOf(behind),
        0,
        reason: 'covered, it fades with the content',
      );

      controller.config = controller.config.copyWith(
        timeLeft: () => controller.config.timeLeft!.copyWith(
          look: TimeLeftLook.bottomBar,
          fadeWhenCovered: false,
        ),
      );
      await tester.pump();
      expect(
        sideOf('Front'),
        BorderSide(color: theme.colorScheme.outlineVariant),
        reason: 'only a border sweep takes the card’s border',
      );
      final [stays] = painted(tester, 'Behind');
      expect(opacityOf(stays), 1, reason: 'stays on the card');

      controller.dismissAll();
      await tester.pumpAndSettle();
    });

    testWidgets('a leading ring goes round the leading widget, drawn smaller '
        'inside it', (tester) async {
      controller.config = controller.config.copyWith(
        timeLeft: () => const ToastTimeLeft(look: TimeLeftLook.leadingRing),
      );
      await tester.pumpWidget(app(controller: controller));
      controller.show(
        'Signed in',
        duration: const Duration(seconds: 4),
        leading: const SizedBox.square(key: Key('icon'), dimension: 20),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final [ring] = painted(tester, 'Signed in');
      final slot = tester.getRect(
        find.byWidgetPredicate(
          (widget) => widget is CustomPaint && identical(widget.painter, ring),
        ),
      );
      final icon = tester.getRect(find.byKey(const Key('icon')));
      expect(icon.center, slot.center);
      expect(icon.width, closeTo(12, 0.01), reason: 'inside the ring');

      controller.dismissAll();
      await tester.pumpAndSettle();
    });

    testWidgets('what the time left is drawn over still takes the press', (
      tester,
    ) async {
      await tester.pumpWidget(app(controller: controller));
      for (final look in TimeLeftLook.values) {
        controller.config = controller.config.copyWith(
          timeLeft: () => ToastTimeLeft(look: look),
        );
        var pressed = 0;
        controller.show(
          '$look',
          duration: const Duration(seconds: 4),
          action: (context, toast) =>
              TextButton(onPressed: () => pressed++, child: const Text('Undo')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Undo'));
        expect(pressed, 1, reason: '$look');
        controller.dismissAll();
        await tester.pumpAndSettle();
      }
    });

    test('a bar draws what is left from its start edge, and a ring from its '
        'top going clockwise', () {
      final left = AnimationController(vsync: const TestVSync(), value: 0.25);
      addTearDown(left.dispose);
      const size = Size(356, 72);
      const red = Color(0xFFFF0000);

      _Recording paint(CustomPainter painter, Size size) {
        final canvas = _Recording();
        painter.paint(canvas, size);
        return canvas;
      }

      TimeLeftBarPainter bar({bool atTop = false, TextDirection? direction}) =>
          TimeLeftBarPainter(
            timeLeft: left,
            color: red,
            strokeWidth: 2,
            atTop: atTop,
            textDirection: direction ?? TextDirection.ltr,
            radius: 8,
          );
      expect(paint(bar(), size).rects, [const Rect.fromLTWH(0, 70, 89, 2)]);
      expect(paint(bar(atTop: true), size).rects, [
        const Rect.fromLTWH(0, 0, 89, 2),
      ]);
      expect(paint(bar(direction: TextDirection.rtl), size).rects, [
        const Rect.fromLTWH(267, 70, 89, 2),
      ]);

      final ring = paint(
        TimeLeftRingPainter(timeLeft: left, color: red, strokeWidth: 2),
        const Size.square(12),
      );
      expect(ring.arcs, [
        (const Rect.fromLTWH(1, 1, 10, 10), -math.pi / 2, math.pi / 2),
      ]);
    });

    group('the border sweep', () {
      // A 356 × 72 card with an 8 px radius, drawn with a 2 px line: the
      // line runs 1 px in from the edge, round corners of 7.
      const size = Size(356, 72);
      const topCenter = Offset(178, 1);
      const centerEnd = Offset(355, 36);
      const bottomCenter = Offset(178, 71);
      const centerStart = Offset(1, 36);
      // The middle of a 7 px arc whose centre is 8 px in from the corner.
      final corner = 8 - 7 * math.sqrt1_2;

      TimeLeftSweep sweep(
        double value, {
        TimeLeftStart start = TimeLeftStart.topStart,
        bool clockwise = true,
        TextDirection textDirection = TextDirection.ltr,
      }) => TimeLeftSweep(
        size,
        radius: 8,
        strokeWidth: 2,
        value: value,
        start: start,
        clockwise: clockwise,
        textDirection: textDirection,
      );

      Matcher at(Offset point) => isA<Offset>()
          .having((it) => it.dx, 'dx', closeTo(point.dx, 0.5))
          .having((it) => it.dy, 'dy', closeTo(point.dy, 0.5));

      test('starts at the corners and the middle of each side', () {
        final starts = {
          TimeLeftStart.topStart: Offset(corner, corner),
          TimeLeftStart.topCenter: topCenter,
          TimeLeftStart.topEnd: Offset(356 - corner, corner),
          TimeLeftStart.centerEnd: centerEnd,
          TimeLeftStart.bottomEnd: Offset(356 - corner, 72 - corner),
          TimeLeftStart.bottomCenter: bottomCenter,
          TimeLeftStart.bottomStart: Offset(corner, 72 - corner),
          TimeLeftStart.centerStart: centerStart,
        };
        for (final MapEntry(key: start, value: point) in starts.entries) {
          final full = sweep(1, start: start);
          expect(full.from, at(point), reason: '$start');
          expect(full.to, at(point), reason: '$start, all the way round');
          expect(full.length, closeTo(full.perimeter, 0.01));
        }
      });

      test('clockwise, the gap opens from the start going clockwise; '
          'otherwise the line runs back toward the start', () {
        final open = sweep(0.75, start: TimeLeftStart.topCenter);
        expect(open.to, at(topCenter), reason: 'ends at the start');
        expect(open.from, at(centerEnd), reason: 'a quarter round clockwise');
        expect(open.length, closeTo(open.perimeter * 0.75, 0.01));

        final back = sweep(
          0.75,
          start: TimeLeftStart.topCenter,
          clockwise: false,
        );
        expect(back.from, at(topCenter), reason: 'begins at the start');
        expect(back.to, at(centerStart), reason: 'three quarters clockwise');

        expect(sweep(0).length, 0);
      });

      test('start and end follow the text direction; clockwise does not', () {
        final rtl = sweep(1, textDirection: TextDirection.rtl);
        expect(rtl.from, at(Offset(356 - corner, corner)));
        final open = sweep(
          0.75,
          start: TimeLeftStart.centerStart,
          textDirection: TextDirection.rtl,
        );
        expect(open.to, at(centerEnd), reason: 'start is the right in rtl');
        expect(open.from, at(bottomCenter), reason: 'still clockwise');
      });
    });

    testWidgets('a toast dismissed while it counts keeps the time left it '
        'had as it leaves', (tester) async {
      await tester.pumpWidget(app(controller: controller));
      final id = showCounting('Counting');
      await tester.pump();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final left = views['Counting']!.timeLeft!;

      controller.dismiss(id);
      final had = left.value;
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(left.value, had, reason: 'frame $i of the exit');
      }
      await tester.pumpAndSettle();
    });
  });

  group('the stowed deck', () {
    const away = Offset(40, 40);

    Rect boxOf(WidgetTester tester, String title) => tester.getRect(
      find
          .ancestor(of: find.text(title), matching: find.byType(Material))
          .first,
    );

    Future<TestGesture> mouseAt(WidgetTester tester, Offset at) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: at - const Offset(1, 0));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(at);
      await tester.pump();
      return mouse;
    }

    SonnerController deckWith({
      DeckStowControl? control,
      DeckStowMotion motion = const DeckStowMotion(),
      DeckStowHandle? handle,
      DeckDismissAll? dismissAll,
      SonnerPosition position = SonnerPosition.bottomRight,
      Duration duration = Duration.zero,
    }) {
      final controller = SonnerController(
        config: SonnerConfig(
          duration: duration,
          position: position,
          scrollbar: null,
          dismissAll: dismissAll,
          stowControl: control,
          stowMotion: motion,
          stowHandle: handle,
        ),
      );
      addTearDown(controller.dispose);
      return controller;
    }

    void showToasts(SonnerController controller, int count) {
      for (var n = 0; n < count; n++) {
        controller.show('Toast $n');
      }
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('stowing takes the deck out of sight and lets go of the '
        'pointer, and a pointer moving where it was holds nothing', (
      tester,
    ) async {
      final controller = deckWith();
      await tester.pumpWidget(app(controller: controller));
      showToasts(controller, 3);
      await settle(tester);
      final at = boxOf(tester, 'Toast 2').center;
      final mouse = await mouseAt(tester, at);
      await settle(tester);
      expect(timersPaused(controller), isTrue, reason: 'the pointer holds it');

      controller.stow();
      expect(
        timersPaused(controller),
        isFalse,
        reason: 'let go as it stows, not a frame later',
      );
      await tester.pump();
      await settle(tester);
      expect(find.text('Toast 2').hitTestable(), findsNothing);

      await mouse.moveTo(at + const Offset(2, 2));
      await settle(tester);
      expect(timersPaused(controller), isFalse);
      expect(find.text('Toast 2').hitTestable(), findsNothing);
    });

    /// Every label in the semantics tree as it is rendered, which is what a
    /// screen reader reads — not the annotations the widgets carry.
    Set<String> labels(WidgetTester tester) {
      final found = <String>{};
      void walk(SemanticsNode node) {
        if (node.label.isNotEmpty) found.add(node.label);
        node.visitChildren((child) {
          walk(child);
          return true;
        });
      }

      walk(tester.binding.rootElement!.renderObject!.debugSemantics!);
      return found;
    }

    testWidgets('a wheel turned over the control past the far end scrolls '
        'the deck, as one over the deck does', (tester) async {
      final controller = SonnerController(
        config: const SonnerConfig(
          duration: Duration.zero,
          deckCap: DeckCap.pixels(200, fade: 0),
          scrollbar: null,
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller: controller));
      for (var n = 0; n < 12; n++) {
        controller.show('Toast $n');
      }
      await settle(tester);
      await mouseAt(tester, boxOf(tester, 'Toast 11').center);
      await settle(tester);

      final control = tester.getRect(find.text('Hide')).center;
      final before = boxOf(tester, 'Toast 11').top;
      final wheel = TestPointer(9, PointerDeviceKind.mouse, 9);
      await tester.sendEventToBinding(wheel.hover(control));
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, -80)));
      await settle(tester);

      expect(
        boxOf(tester, 'Toast 11').top,
        greaterThan(before + 20),
        reason: 'the deck scrolled under a wheel turned on its control',
      );
    });

    testWidgets('a stowed deck is out of the semantics tree', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = deckWith();
      await tester.pumpWidget(app(controller: controller));
      showToasts(controller, 2);
      await settle(tester);
      expect(labels(tester), contains('Toast 1'));

      controller.stow();
      await settle(tester);
      expect(labels(tester), isNot(contains('Toast 1')));

      controller.unstow();
      await settle(tester);
      expect(labels(tester), contains('Toast 1'));
      semantics.dispose();
    });

    testWidgets('a new toast brings the deck back with the toasts it kept', (
      tester,
    ) async {
      final controller = deckWith();
      await tester.pumpWidget(app(controller: controller));
      showToasts(controller, 2);
      await settle(tester);
      controller.stow();
      await settle(tester);

      controller.show('New');
      await settle(tester);
      expect(controller.stowed, isFalse);
      expect(find.text('New').hitTestable(), findsOneWidget);
      expect(toastsOf(controller), hasLength(3));
      final mouse = await mouseAt(tester, boxOf(tester, 'New').center);
      await settle(tester);
      expect(find.text('Toast 0').hitTestable(), findsOneWidget);
      await mouse.moveTo(away);
      await settle(tester);
    });

    testWidgets('the last toast timing out while stowed leaves the deck out '
        'of sight, and the next toast draws', (tester) async {
      final controller = deckWith(duration: const Duration(seconds: 3));
      await tester.pumpWidget(app(controller: controller));
      controller.show('Only');
      await settle(tester);
      controller.stow();
      await settle(tester);

      // Stopping inside the 200 ms exit, while the toast is still drawn.
      await tester.pump(const Duration(milliseconds: 1900));
      await tester.pump(const Duration(milliseconds: 100));
      expect(toastsOf(controller), isEmpty, reason: 'it timed out');
      expect(controller.stowed, isFalse, reason: 'nothing left to stow');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Only'), findsOneWidget, reason: 'still leaving');
      expect(
        boxOf(tester, 'Only').top,
        greaterThan(600),
        reason: 'its exit runs past the edge, out of sight',
      );

      await tester.pump(const Duration(milliseconds: 300));
      controller.show('Next');
      await settle(tester);
      expect(find.text('Next').hitTestable(), findsOneWidget);
      controller.dismissAll();
      await tester.pumpAndSettle();
    });

    testWidgets('a swipe under way when the deck is stowed is called off, and '
        'the toast is where it was when the deck comes back', (tester) async {
      final controller = deckWith();
      await tester.pumpWidget(app(controller: controller));
      showToasts(controller, 2);
      await settle(tester);
      final box = boxOf(tester, 'Toast 1');

      final mouse = await tester.startGesture(box.center);
      await mouse.moveBy(const Offset(200, 0));
      await tester.pump();
      expect(boxOf(tester, 'Toast 1').left, greaterThan(box.left + 100));

      controller.stow();
      await settle(tester);
      await mouse.up();
      await settle(tester);
      expect(
        toastsOf(controller),
        hasLength(2),
        reason: 'a drag the deck left behind does not dismiss',
      );

      controller.unstow();
      await settle(tester);
      expect(boxOf(tester, 'Toast 1').left, moreOrLessEquals(box.left));
      expect(
        find.text('Toast 0').hitTestable(),
        findsNothing,
        reason: 'the press it was stowed under holds it open no longer',
      );
    });

    testWidgets('a press held through a stow does not hold the deck open '
        'when it comes back', (tester) async {
      final controller = deckWith();
      await tester.pumpWidget(app(controller: controller));
      showToasts(controller, 2);
      await settle(tester);
      final mouse = await tester.startGesture(boxOf(tester, 'Toast 1').center);
      await tester.pump();

      controller.stow();
      await settle(tester);
      controller.unstow();
      await settle(tester);
      expect(
        find.text('Toast 0').hitTestable(),
        findsNothing,
        reason: 'collapsed, though the button is still down',
      );

      await mouse.up();
      await settle(tester);
    });

    for (final (look, moves, scales) in [
      (DeckStowMotionLook.slide, true, false),
      (DeckStowMotionLook.fade, false, false),
      (DeckStowMotionLook.shrink, false, true),
    ]) {
      testWidgets('$look takes the deck out of sight and brings it back', (
        tester,
      ) async {
        final controller = deckWith(motion: DeckStowMotion(look: look));
        await tester.pumpWidget(app(controller: controller));
        showToasts(controller, 2);
        await settle(tester);
        final resting = boxOf(tester, 'Toast 1');

        controller.stow();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final moving = boxOf(tester, 'Toast 1');
        expect(
          moving.bottom > resting.bottom + 20,
          moves,
          reason: 'carried toward the edge',
        );
        expect(moving.width < resting.width - 4, scales, reason: 'shrank');
        final fade = tester
            .widgetList<Opacity>(
              find.descendant(
                of: find.byType(DeckStowMotionBox),
                matching: find.byType(Opacity),
              ),
            )
            .first;
        expect(fade.opacity, lessThan(1), reason: 'fading either way');

        await settle(tester);
        expect(find.text('Toast 1').hitTestable(), findsNothing);

        controller.unstow();
        await settle(tester);
        expect(find.text('Toast 1').hitTestable(), findsOneWidget);
        expect(boxOf(tester, 'Toast 1'), resting);
      });
    }

    testWidgets('a motion builder is handed the deck and an animation that '
        'runs to 1 and back, and the deck still takes no pointer', (
      tester,
    ) async {
      final values = <double>[];
      final controller = deckWith(
        motion: DeckStowMotion(
          builder: (context, view, deck) {
            values.add(view.stowed.value);
            expect(view.position, SonnerPosition.bottomRight);
            return Opacity(opacity: 1 - view.stowed.value * 0.5, child: deck);
          },
        ),
      );
      await tester.pumpWidget(app(controller: controller));
      showToasts(controller, 1);
      await settle(tester);
      expect(values.last, 0);

      controller.stow();
      await settle(tester);
      expect(values.last, 1);
      expect(
        find.text('Toast 0').hitTestable(),
        findsNothing,
        reason: 'the host, not the builder, keeps the pointer off',
      );

      controller.unstow();
      await settle(tester);
      expect(values.last, 0);
      expect(find.text('Toast 0').hitTestable(), findsOneWidget);
    });

    testWidgets('the control shows while the pointer holds an expanded deck '
        'with a toast on it, even one the user may not dismiss', (
      tester,
    ) async {
      final controller = deckWith(control: const DeckStowControl());
      await tester.pumpWidget(app(controller: controller));
      controller.show('Saving', isLoading: true);
      await settle(tester);
      expect(find.text('Hide'), findsNothing, reason: 'collapsed');

      final mouse = await mouseAt(tester, boxOf(tester, 'Saving').center);
      await settle(tester);
      expect(
        find.text('Hide'),
        findsOneWidget,
        reason: 'one loading toast is reason enough',
      );
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(
        tester.getSemantics(find.text('Hide')),
        isSemantics(isButton: true, label: 'Hide'),
      );
      semantics.dispose();

      await tester.tap(find.text('Hide'));
      await settle(tester);
      expect(controller.stowed, isTrue);
      expect(find.text('Hide'), findsNothing, reason: 'stowed');

      controller.unstow();
      await settle(tester);
      await mouse.moveTo(away);
      await settle(tester);
      expect(find.text('Hide'), findsNothing, reason: 'collapsed again');

      await mouse.moveTo(boxOf(tester, 'Saving').center);
      await settle(tester);
      expect(find.text('Hide'), findsOneWidget);
      controller.config = controller.config.copyWith(stowControl: () => null);
      await settle(tester);
      expect(find.text('Hide'), findsNothing, reason: 'none configured');
      controller.dismissAll();
      await tester.pumpAndSettle();
    });

    for (final position in [
      SonnerPosition.bottomRight,
      SonnerPosition.topLeft,
    ]) {
      testWidgets('the control sits a gap past the deck’s far end, on the '
          'position’s side, $position', (tester) async {
        final controller = deckWith(
          control: const DeckStowControl(),
          position: position,
        );
        await tester.pumpWidget(app(controller: controller));
        showToasts(controller, 3);
        await settle(tester);
        await mouseAt(tester, boxOf(tester, 'Toast 2').center);
        await settle(tester);

        final control = tester.getRect(find.text('Hide'));
        final deck = boxOf(tester, 'Toast 0');
        if (position.isTop) {
          expect(control.top, greaterThan(boxOf(tester, 'Toast 2').bottom));
          expect(control.left, closeTo(deck.left, 14));
        } else {
          expect(control.bottom, lessThan(boxOf(tester, 'Toast 2').top));
          expect(control.right, closeTo(deck.right, 14));
        }
      });
    }

    testWidgets('a header on its own is a bar the deck’s width, reading the '
        'count and the label', (tester) async {
      final controller = deckWith(
        control: const DeckStowControl(look: DeckStowLook.header),
      );
      await tester.pumpWidget(app(controller: controller));
      showToasts(controller, 3);
      await settle(tester);
      await mouseAt(tester, boxOf(tester, 'Toast 2').center);
      await settle(tester);

      expect(find.text('3 notifications'), findsOneWidget);
      expect(
        tester.getRect(find.byType(DeckFarEndBar)).width,
        moreOrLessEquals(boxOf(tester, 'Toast 2').width),
      );

      controller.config = controller.config.copyWith(
        stowControl: () => DeckStowControl(
          look: DeckStowLook.header,
          label: '숨기기',
          countLabel: (count) => '알림 $count개',
        ),
      );
      await settle(tester);
      expect(find.text('알림 3개'), findsOneWidget);
      await tester.tap(find.text('숨기기'));
      await settle(tester);
      expect(controller.stowed, isTrue);
    });

    testWidgets('an icon draws a chevron at the other end of the deck’s '
        'width, labelled for semantics', (tester) async {
      final controller = deckWith(
        control: const DeckStowControl(look: DeckStowLook.icon),
        dismissAll: const DeckDismissAll(),
      );
      await tester.pumpWidget(app(controller: controller));
      showToasts(controller, 3);
      await settle(tester);
      await mouseAt(tester, boxOf(tester, 'Toast 2').center);
      await settle(tester);

      final chevron = find.byIcon(Icons.keyboard_arrow_down);
      expect(chevron, findsOneWidget);
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(
        tester.getSemantics(chevron),
        isSemantics(isButton: true, label: 'Hide'),
      );
      semantics.dispose();
      final deck = boxOf(tester, 'Toast 0');
      expect(tester.getRect(chevron).left, closeTo(deck.left, 14));
      expect(
        tester.getRect(find.text('Clear all')).right,
        closeTo(deck.right, 14),
      );

      await tester.tap(chevron);
      await settle(tester);
      expect(controller.stowed, isTrue);
    });

    for (final position in [
      SonnerPosition.bottomRight,
      SonnerPosition.bottomLeft,
    ]) {
      testWidgets('two pills sit side by side, with the dismiss-all control '
          'on the deck’s own side, $position', (tester) async {
        final controller = deckWith(
          control: const DeckStowControl(),
          dismissAll: const DeckDismissAll(),
          position: position,
        );
        await tester.pumpWidget(app(controller: controller));
        showToasts(controller, 3);
        await settle(tester);
        await mouseAt(tester, boxOf(tester, 'Toast 2').center);
        await settle(tester);

        final hide = tester.getRect(find.text('Hide'));
        final clear = tester.getRect(find.text('Clear all'));
        final deck = boxOf(tester, 'Toast 0');
        if (position == SonnerPosition.bottomLeft) {
          expect(clear.left, closeTo(deck.left, 14));
          expect(hide.left, greaterThan(clear.right));
        } else {
          expect(clear.right, closeTo(deck.right, 14));
          expect(hide.right, lessThan(clear.left));
        }
        expect(find.byType(DeckFarEndBar), findsNothing, reason: 'no bar');
      });
    }

    for (final (name, control, dismissAll, count) in [
      (
        'the stow control asks for it',
        const DeckStowControl(look: DeckStowLook.header),
        const DeckDismissAll(),
        '3 notifications',
      ),
      (
        'the dismiss-all control asks for it',
        const DeckStowControl(),
        const DeckDismissAll(look: DeckDismissAllLook.header),
        '2 notifications',
      ),
    ]) {
      testWidgets('the two controls share one bar when $name', (tester) async {
        final controller = deckWith(control: control, dismissAll: dismissAll);
        await tester.pumpWidget(app(controller: controller));
        showToasts(controller, 2);
        controller.show('Saving', isLoading: true);
        await settle(tester);
        await mouseAt(tester, boxOf(tester, 'Saving').center);
        await settle(tester);

        expect(find.byType(DeckFarEndBar), findsOneWidget);
        expect(
          find.text(count),
          findsOneWidget,
          reason: 'the header-look control counts what it would act on',
        );
        expect(find.text('Hide'), findsOneWidget);
        expect(find.text('Clear all'), findsOneWidget);
        expect(
          tester.getRect(find.byType(DeckFarEndBar)).width,
          moreOrLessEquals(boxOf(tester, 'Saving').width),
        );

        await tester.tap(find.text('Clear all'));
        await settle(tester);
        expect(toastsOf(controller).map((toast) => toast.state.title), [
          'Saving',
        ], reason: 'the dismiss-all control still leaves what stays');
        expect(controller.stowed, isFalse);
      });
    }

    testWidgets('a builder draws the control, is handed the count and stows '
        'through the view, and sits in the bar where there is one', (
      tester,
    ) async {
      var seen = 0;
      final builder = DeckStowControl(
        builder: (context, view) {
          seen = view.count;
          return FadeTransition(
            opacity: view.expansion,
            child: TextButton(
              onPressed: view.stow,
              child: Text('away with ${view.count}'),
            ),
          );
        },
      );
      final controller = deckWith(control: builder);
      await tester.pumpWidget(app(controller: controller));
      showToasts(controller, 2);
      await settle(tester);
      await mouseAt(tester, boxOf(tester, 'Toast 1').center);
      await settle(tester);
      expect(find.text('away with 2'), findsOneWidget);
      expect(find.text('Hide'), findsNothing);
      expect(seen, 2);

      controller.config = controller.config.copyWith(
        dismissAll: () => const DeckDismissAll(look: DeckDismissAllLook.header),
      );
      await settle(tester);
      expect(find.byType(DeckFarEndBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DeckFarEndBar),
          matching: find.text('away with 2'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('away with 2'));
      await settle(tester);
      expect(controller.stowed, isTrue);
    });

    testWidgets('a host handed another controller draws that deck as that '
        'controller has it, stowed or not', (tester) async {
      final stowed = deckWith();
      final drawn = deckWith();
      await tester.pumpWidget(app(controller: stowed));
      stowed.show('Stowed away');
      drawn.show('Wide awake');
      await settle(tester);
      stowed.stow();
      await settle(tester);
      expect(find.text('Stowed away').hitTestable(), findsNothing);

      await tester.pumpWidget(app(controller: drawn));
      await settle(tester);
      expect(
        find.text('Wide awake').hitTestable(),
        findsOneWidget,
        reason: 'this controller has not stowed its deck',
      );

      await tester.pumpWidget(app(controller: stowed));
      await settle(tester);
      expect(
        find.text('Stowed away').hitTestable(),
        findsNothing,
        reason: 'and this one has',
      );
    });

    testWidgets('no handle is left at the edge unless one is configured', (
      tester,
    ) async {
      final controller = deckWith();
      await tester.pumpWidget(app(controller: controller));
      showToasts(controller, 2);
      await settle(tester);
      controller.stow();
      await settle(tester);
      expect(find.text('2 hidden'), findsNothing);
    });

    testWidgets('a handle reads what the deck is keeping, brings it back, and '
        'pauses nothing while the pointer is on it', (tester) async {
      final controller = deckWith(handle: const DeckStowHandle());
      await tester.pumpWidget(app(controller: controller));
      showToasts(controller, 2);
      await settle(tester);
      expect(find.text('2 hidden'), findsNothing, reason: 'the deck is drawn');

      controller.stow();
      await settle(tester);
      expect(find.text('2 hidden'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(
        tester.getSemantics(find.text('2 hidden')),
        isSemantics(isButton: true, label: '2 hidden'),
      );
      semantics.dispose();

      final mouse = await mouseAt(
        tester,
        tester.getRect(find.text('2 hidden')).center,
      );
      await settle(tester);
      expect(timersPaused(controller), isFalse, reason: 'not the deck');

      await tester.tap(find.text('2 hidden'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.stowed, isFalse);
      expect(find.text('2 hidden'), findsOneWidget, reason: 'still fading');
      expect(
        find.text('2 hidden').hitTestable(),
        findsNothing,
        reason: 'it takes the pointer only while the deck is stowed',
      );

      await settle(tester);
      expect(find.text('Toast 1').hitTestable(), findsOneWidget);
      expect(find.text('2 hidden'), findsNothing);
      await mouse.moveTo(away);
      await settle(tester);
    });

    for (final position in [
      SonnerPosition.bottomRight,
      SonnerPosition.topLeft,
      SonnerPosition.topCenter,
    ]) {
      testWidgets('a handle sits in the position’s corner, held off its two '
          'edges by their offsets, $position', (tester) async {
        final controller = deckWith(
          handle: const DeckStowHandle(),
          position: position,
        );
        controller.config = controller.config.copyWith(
          offset: const EdgeInsets.fromLTRB(90, 11, 13, 17),
        );
        await tester.pumpWidget(app(controller: controller));
        showToasts(controller, 2);
        await settle(tester);
        controller.stow();
        await settle(tester);

        final rect = tester.getRect(find.byType(DeckStowHandleButton));
        switch (position) {
          case SonnerPosition.bottomRight:
            expect((rect.right, rect.bottom), (800.0 - 13, 600.0 - 17));
          case SonnerPosition.topLeft:
            expect((rect.left, rect.top), (90.0, 11.0));
          default:
            expect((rect.center.dx, rect.top), (400.0, 11.0));
        }
      });
    }

    testWidgets('a handle reads its own count label, and a builder draws it '
        'instead', (tester) async {
      final controller = deckWith(
        handle: DeckStowHandle(countLabel: (count) => '$count개 숨김'),
      );
      await tester.pumpWidget(app(controller: controller));
      showToasts(controller, 3);
      await settle(tester);
      controller.stow();
      await settle(tester);
      expect(find.text('3개 숨김'), findsOneWidget);

      controller.config = controller.config.copyWith(
        stowHandle: () => DeckStowHandle(
          builder: (context, view) => TextButton(
            onPressed: view.unstow,
            child: Text('back to ${view.count}'),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('3개 숨김'), findsNothing);
      expect(find.text('back to 3'), findsOneWidget);

      await tester.tap(find.text('back to 3'));
      await settle(tester);
      expect(controller.stowed, isFalse);
    });
  });

  group('with no controller', () {
    tearDown(toast.dismissAll);

    testWidgets('the host draws the exported toast', (tester) async {
      await tester.pumpWidget(app());

      toast.show('From anywhere');
      // Pumped by hand: it counts down, so nothing settles until it is gone.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

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

/// Every fade above [of], multiplied.
double _fadesAbove(WidgetTester tester, Finder of) {
  var opacity = 1.0;
  final above = find.ancestor(
    of: of,
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

/// The toast's card in [title]'s toast.
Finder _cardOf(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(Material)).first;

/// The opacity [title]'s toast is painted with: every fade above its card, so
/// the enter, the window and a change of content, but not the fade the deck
/// puts on the content of a covered toast.
double paintedOpacityOf(WidgetTester tester, String title) =>
    _fadesAbove(tester, _cardOf(title));

/// The opacity [title] itself is painted with: [paintedOpacityOf] and the
/// covered-content fade inside the card together.
double contentOpacityOf(WidgetTester tester, String title) =>
    _fadesAbove(tester, find.text(title));

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

/// A canvas that keeps the rectangles and arcs drawn on it.
class _Recording implements Canvas {
  final rects = <Rect>[];
  final arcs = <(Rect, double, double)>[];

  @override
  void drawRect(Rect rect, Paint paint) => rects.add(rect);

  @override
  void drawArc(
    Rect rect,
    double startAngle,
    double sweepAngle,
    bool useCenter,
    Paint paint,
  ) => arcs.add((rect, startAngle, sweepAngle));

  @override
  void noSuchMethod(Invocation invocation) {}
}

/// Hard black/white stripes across the layer, for reading whether a blur
/// reached a given row: stripes rather than one edge, so a row crosses several
/// wherever the deck happens to sit. A `Row` of `ColoredBox`es does not paint
/// here; a painter does.
class _HardEdge extends CustomPainter {
  const _HardEdge();

  static const _width = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var x = 0.0; x < size.width; x += _width) {
      paint.color = (x ~/ _width).isEven
          ? const Color(0xFF000000)
          : const Color(0xFFFFFFFF);
      canvas.drawRect(Rect.fromLTWH(x, 0, _width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_HardEdge oldDelegate) => false;
}
