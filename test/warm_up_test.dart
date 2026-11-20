import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show ContainerLayer, Layer, RenderStack, ShaderMaskLayer;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_sonner/just_sonner.dart';
import 'package:just_sonner/src/host.dart' show ToastLayer;
import 'package:just_sonner/src/look/deck_backdrop.dart' show DeckBackdropBox;
import 'package:just_sonner/src/look/default_look.dart' show DefaultToastLook;
import 'package:just_sonner/src/config.dart' show PastNewestCap;
import 'package:just_sonner/src/controller.dart' show warmUpOf;
import 'package:just_sonner/src/warm_up.dart' show warmUpTitle;

void main() {
  late SonnerController controller;

  setUp(
    () => controller = SonnerController(
      config: const SonnerConfig(duration: null),
    ),
  );
  tearDown(() => controller.dispose());

  /// The app's screen, opaque, over which the hidden deck is drawn.
  const screenKey = Key('screen');

  Widget app({Widget? home}) => MaterialApp(
    builder: (context, child) =>
        SonnerHost(controller: controller, child: child!),
    home: home ?? const ColoredBox(key: screenKey, color: Color(0xFFFFFFFF)),
  );

  /// A host inside the app's page rather than above its navigator, so nothing
  /// the navigator draws stands between [child] and the deck under it.
  Widget hostInPage(Widget child) => MaterialApp(
    home: SonnerHost(controller: controller, child: child),
  );

  /// Pumps until [future] has completed, a frame at a time, and returns how
  /// many frames that took; fails past [limit].
  Future<int> pumpUntilDone(
    WidgetTester tester,
    Future<void> future, {
    int limit = 100,
  }) async {
    var done = false;
    future.then((_) => done = true);
    var frames = 0;
    await tester.pump();
    while (!done) {
      expect(frames, lessThan(limit), reason: 'the warm-up never ended');
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
    }
    return frames;
  }

  /// Whether [future] has completed once the microtasks queued now have run.
  Future<bool> completesAtOnce(WidgetTester tester, Future<void> future) async {
    var done = false;
    future.then((_) => done = true);
    await tester.idle();
    return done;
  }

  Future<void> pumpUntilFannedOut(WidgetTester tester) async {
    var backdropDrawn = false;
    for (var i = 0; i < 30 && !backdropDrawn; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      backdropDrawn = find.byType(BackdropFilter).evaluate().isNotEmpty;
    }
    expect(backdropDrawn, isTrue, reason: 'the deck never fanned out');
  }

  void expectLaidUnder(
    WidgetTester tester,
    Finder stack, {
    required Finder below,
    required Finder above,
  }) {
    final layers = tester.renderObject<RenderStack>(stack).getChildrenAsList();
    int layerOf(Finder finder) {
      RenderObject? node = tester.renderObject(finder);
      while (node != null && !layers.contains(node)) {
        node = node.parent;
      }
      return layers.indexOf(node! as RenderBox);
    }

    expect(layerOf(below), lessThan(layerOf(above)));
  }

  final standIn = find.text(warmUpTitle, skipOffstage: false);

  /// The stand-ins a warm-up under a config with the default `dismissAll`
  /// holds.
  final findsStandIns = findsNWidgets(2);

  group('wrapped', () {
    testWidgets(
      'draws the stand-in and the backdrop, fanned out, then takes them away',
      (tester) async {
        controller.config = const SonnerConfig(
          duration: null,
          deckBackdrop: DeckBackdrop(blur: 4),
        );
        await tester.pumpWidget(app());
        // The host's own deck, with nothing in it, keeps a backdrop box too.
        final boxes = find.byType(DeckBackdropBox).evaluate().length;

        final warming = controller.warmUp();
        await tester.pump();

        expect(standIn, findsStandIns);
        expect(find.byType(DefaultToastLook), findsStandIns);
        expect(find.byType(DeckBackdropBox), findsNWidgets(boxes + 1));
        expect(find.byType(BackdropFilter), findsNothing);

        await pumpUntilFannedOut(tester);
        expect(
          tester.renderObject(find.byType(BackdropFilter)).debugNeedsPaint,
          isFalse,
        );
        expect(tester.renderObject(standIn.first).debugNeedsPaint, isFalse);

        await pumpUntilDone(tester, warming);
        await tester.pump();

        expect(standIn, findsNothing);
        expect(find.byType(DefaultToastLook), findsNothing);
        expect(find.byType(DeckBackdropBox), findsNWidgets(boxes));
        expect(find.byType(BackdropFilter), findsNothing);
      },
    );

    testWidgets('runs with no backdrop set', (tester) async {
      await tester.pumpWidget(app());

      final warming = controller.warmUp();
      await tester.pump();

      expect(standIn, findsStandIns);
      expect(find.byType(DeckBackdropBox), findsNothing);

      await pumpUntilDone(tester, warming);
      await tester.pump();
      expect(standIn, findsNothing);
    });

    testWidgets("the stand-in is laid under the app's screen", (tester) async {
      await tester.pumpWidget(app());

      final warming = controller.warmUp();
      await tester.pump();

      expectLaidUnder(
        tester,
        find
            .descendant(
              of: find.byType(SonnerHost),
              matching: find.byType(Stack),
            )
            .first,
        below: standIn.first,
        above: find.byKey(screenKey),
      );

      await pumpUntilDone(tester, warming);
    });

    testWidgets('a press over the stand-in reaches the app, not the stand-in', (
      tester,
    ) async {
      var appTaps = 0;
      var standInTaps = 0;
      controller.config = SonnerConfig(
        duration: null,
        builder: (context, toast) => Listener(
          onPointerDown: (_) => standInTaps++,
          child: SizedBox(
            width: 300,
            height: 60,
            child: Text(toast.state.title),
          ),
        ),
      );
      // Translucent, so a press it takes still reaches what is under it.
      await tester.pumpWidget(
        hostInPage(
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => appTaps++,
            child: const SizedBox.expand(),
          ),
        ),
      );

      final warming = controller.warmUp();
      await tester.pump();
      // The stand-in enters from past the window's bottom edge.
      await tester.pump(const Duration(milliseconds: 400));
      final center = tester.getCenter(standIn.first);
      expect(
        tester.view.physicalSize / tester.view.devicePixelRatio,
        isA<Size>().having((size) => size.contains(center), 'contains', isTrue),
      );

      await tester.tapAt(center);
      expect(standInTaps, 0);
      expect(appTaps, 1);

      await pumpUntilDone(tester, warming);
    });

    testWidgets('a screen reader is not told of the stand-in', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(hostInPage(const SizedBox.expand()));

      final warming = controller.warmUp();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(standIn, findsStandIns);
      expect(find.bySemanticsLabel(RegExp(warmUpTitle)), findsNothing);

      await pumpUntilDone(tester, warming);

      // A toast shown for real is told of, so the finder can see one.
      controller.show(warmUpTitle);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp(warmUpTitle)), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('nothing in the stand-in takes focus', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      controller.config = SonnerConfig(
        duration: null,
        builder: (context, toast) => Focus(
          focusNode: node,
          child: const SizedBox(width: 300, height: 60),
        ),
      );
      await tester.pumpWidget(app());

      final warming = controller.warmUp();
      await tester.pump();
      node.requestFocus();
      await tester.pump();

      expect(node.hasFocus, isFalse);

      await pumpUntilDone(tester, warming);
    });

    testWidgets("the app's builder receives the stand-in", (tester) async {
      final seen = <ToastView>[];
      controller.config = SonnerConfig(
        duration: null,
        builder: (context, toast) {
          seen.add(toast);
          return const SizedBox(width: 300, height: 60);
        },
      );
      await tester.pumpWidget(app());

      final warming = controller.warmUp();
      await tester.pump();

      expect(seen, isNotEmpty);
      expect(seen.last.state.title, warmUpTitle);
      expect(seen.last.state.description, isNotEmpty);
      expect(seen.last.state.leading, isNull);
      expect(seen.last.state.action, isNull);
      expect(seen.last.state.isLoading, isFalse);
      expect(seen.last.timeLeft, isNull);
      expect(find.byType(DefaultToastLook), findsNothing);

      await pumpUntilDone(tester, warming);
    });

    testWidgets(
      'leaves the controller as it was: no toast, no notification, zone shown',
      (tester) async {
        await tester.pumpWidget(app());
        var notified = 0;
        controller.addListener(() => notified++);

        final warming = controller.warmUp();
        await tester.pump();
        expect(standIn, findsStandIns);

        expect(controller.count, 0);
        expect(controller.zone.state, ZoneState.shown);

        await pumpUntilDone(tester, warming);
        await tester.pump();

        expect(notified, 0);
        expect(controller.count, 0);
        expect(controller.zone.state, ZoneState.shown);
      },
    );

    testWidgets('follows a config assigned while it runs', (tester) async {
      await tester.pumpWidget(app());

      final warming = controller.warmUp();
      await tester.pump();
      expect(find.byType(DefaultToastLook), findsStandIns);

      controller.config = SonnerConfig(
        duration: null,
        builder: (context, toast) =>
            const SizedBox(key: Key('built'), width: 300, height: 60),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const Key('built'), skipOffstage: false),
        findsStandIns,
      );

      await pumpUntilDone(tester, warming);
    });
  });

  group('does nothing', () {
    testWidgets('with a toast alive', (tester) async {
      await tester.pumpWidget(app());
      controller.show('Saved');
      await tester.pumpAndSettle();

      final warming = controller.warmUp();
      expect(await completesAtOnce(tester, warming), isTrue);
      await tester.pump();

      expect(standIn, findsNothing);
    });

    testWidgets('with the zone open', (tester) async {
      await tester.pumpWidget(app());
      controller.zone.open();
      await tester.pumpAndSettle();

      final warming = controller.warmUp();
      expect(await completesAtOnce(tester, warming), isTrue);
      await tester.pump();

      expect(standIn, findsNothing);
    });

    testWidgets('while one runs', (tester) async {
      await tester.pumpWidget(app());

      final first = controller.warmUp();
      await tester.pump();
      final second = controller.warmUp();

      expect(await completesAtOnce(tester, second), isTrue);
      await tester.pump();
      expect(standIn, findsStandIns);

      await pumpUntilDone(tester, first);
    });

    testWidgets('after one has finished', (tester) async {
      await tester.pumpWidget(app());
      await pumpUntilDone(tester, controller.warmUp());
      await tester.pump();

      final again = controller.warmUp();
      expect(await completesAtOnce(tester, again), isTrue);
      await tester.pump();

      expect(standIn, findsNothing);
    });

    testWidgets('with no host to draw it, after a frame', (tester) async {
      await tester.pumpWidget(const SizedBox());

      final warming = controller.warmUp();
      final frames = await pumpUntilDone(tester, warming, limit: 3);

      expect(frames, lessThanOrEqualTo(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('while the app is hidden', (tester) async {
      await tester.pumpWidget(app());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );

      final warming = controller.warmUp();
      expect(await completesAtOnce(tester, warming), isTrue);
    });
  });

  group('cut short', () {
    testWidgets('by show: the hidden deck goes by the next frame', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      final warming = controller.warmUp();
      await tester.pump();
      expect(standIn, findsStandIns);

      final id = controller.show('Saved');
      expect(await completesAtOnce(tester, warming), isTrue);
      await tester.pump();

      expect(standIn, findsNothing);
      expect(find.text('Saved'), findsOneWidget);
      expect(controller.count, 1);
      expect(controller.isAlive(id), isTrue);

      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(tester.getRect(find.text('Saved')).top, greaterThan(0));
    });

    testWidgets('by zone.open: the hidden deck goes by the next frame', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      final warming = controller.warmUp();
      await tester.pump();
      expect(standIn, findsStandIns);

      controller.zone.open();
      expect(await completesAtOnce(tester, warming), isTrue);
      await tester.pump();

      expect(standIn, findsNothing);
      expect(controller.zone.state, ZoneState.open);
    });

    testWidgets('by the host going away: not finished, so it runs again', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      final warming = controller.warmUp();
      await tester.pump();
      expect(standIn, findsStandIns);

      await tester.pumpWidget(const SizedBox());
      final frames = await pumpUntilDone(tester, warming, limit: 3);
      expect(frames, lessThanOrEqualTo(1));

      await tester.pumpWidget(app());
      final again = controller.warmUp();
      await tester.pump();

      expect(standIn, findsStandIns);
      await pumpUntilDone(tester, again);
    });

    testWidgets('a warm-up cut short can be run again', (tester) async {
      await tester.pumpWidget(app());
      controller.warmUp();
      await tester.pump();
      final id = controller.show('Saved');
      await tester.pump();
      controller.dismiss(id);
      await tester.pumpAndSettle();

      final again = controller.warmUp();
      await tester.pump();

      expect(standIn, findsStandIns);
      await pumpUntilDone(tester, again);
    });

    testWidgets('by the app going hidden', (tester) async {
      await tester.pumpWidget(app());
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      final warming = controller.warmUp();
      await tester.pump();
      expect(standIn, findsStandIns);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);

      expect(await completesAtOnce(tester, warming), isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(standIn, findsNothing);
    });

    testWidgets('by disposing the controller', (tester) async {
      final own = SonnerController(config: const SonnerConfig(duration: null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              SonnerHost(controller: own, child: child!),
          home: const SizedBox.expand(),
        ),
      );
      final warming = own.warmUp();
      await tester.pump();
      expect(standIn, findsStandIns);

      own.dispose();

      expect(await completesAtOnce(tester, warming), isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });

  group('attached', () {
    late GlobalKey<NavigatorState> navigatorKey;
    setUp(() => navigatorKey = GlobalKey<NavigatorState>());

    Widget attachedApp({bool slot = true, VoidCallback? onTap}) => MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) => Stack(
        children: [
          if (slot)
            Positioned.fill(child: SonnerWarmUpSlot(controller: controller)),
          child!,
        ],
      ),
      home: GestureDetector(
        onTap: onTap,
        child: const ColoredBox(
          key: screenKey,
          color: Color(0xFFFFFFFF),
          child: SizedBox.expand(),
        ),
      ),
    );

    testWidgets(
      'with a slot: draws the stand-in and the backdrop under the screen, '
      'then takes them away',
      (tester) async {
        controller.config = const SonnerConfig(
          duration: null,
          deckBackdrop: DeckBackdrop(blur: 4),
        );
        var appTaps = 0;
        await tester.pumpWidget(attachedApp(onTap: () => appTaps++));
        controller.attach(navigatorKey);

        final warming = controller.warmUp();
        expect(await completesAtOnce(tester, warming), isFalse);
        await tester.pump();

        expect(standIn, findsStandIns);
        expect(find.byType(DeckBackdropBox), findsOneWidget);
        expect(controller.count, 0);

        expectLaidUnder(
          tester,
          find
              .ancestor(
                of: find.byType(SonnerWarmUpSlot),
                matching: find.byType(Stack),
              )
              .first,
          below: standIn.first,
          above: find.byKey(screenKey),
        );

        await pumpUntilFannedOut(tester);
        expect(tester.renderObject(standIn.first).debugNeedsPaint, isFalse);

        await tester.tapAt(tester.getCenter(find.byKey(screenKey)));
        expect(appTaps, 1);

        await pumpUntilDone(tester, warming);
        await tester.pump();

        expect(standIn, findsNothing);
        expect(find.byType(DeckBackdropBox), findsNothing);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(controller.count, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('with a slot: a toast shown after it is drawn once, attached', (
      tester,
    ) async {
      await tester.pumpWidget(attachedApp());
      controller.attach(navigatorKey);
      await pumpUntilDone(tester, controller.warmUp());
      await tester.pump();

      controller.show('Saved');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Saved'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SonnerWarmUpSlot),
          matching: find.byType(ToastLayer),
        ),
        findsNothing,
      );
      controller.dismissAll();
      await tester.pumpAndSettle();
    });

    testWidgets('with no slot: draws nothing and ends after the first frame', (
      tester,
    ) async {
      await tester.pumpWidget(attachedApp(slot: false));
      controller.attach(navigatorKey);
      final layers = find.byType(ToastLayer, skipOffstage: false);

      final warming = controller.warmUp();
      expect(await completesAtOnce(tester, warming), isFalse);
      final frames = await pumpUntilDone(tester, warming, limit: 3);

      expect(frames, lessThanOrEqualTo(1));
      expect(standIn, findsNothing);
      expect(layers, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('to a key with no navigator built: a slot still draws it', (
      tester,
    ) async {
      await tester.pumpWidget(attachedApp());
      controller.attach(GlobalKey<NavigatorState>());

      final warming = controller.warmUp();
      await tester.pump();

      expect(standIn, findsStandIns);
      await pumpUntilDone(tester, warming);
      await tester.pump();
      expect(standIn, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a show dropped for want of a navigator still ends it', (
      tester,
    ) async {
      await tester.pumpWidget(attachedApp());
      controller.attach(GlobalKey<NavigatorState>());
      final warming = controller.warmUp();
      await tester.pump();
      expect(standIn, findsStandIns);

      expect(() => controller.show('Lost'), throwsStateError);

      expect(await completesAtOnce(tester, warming), isTrue);
      await tester.pump();
      expect(standIn, findsNothing);
      expect(controller.count, 0);
    });

    testWidgets('a zone.open() refused for want of a navigator still ends it', (
      tester,
    ) async {
      await tester.pumpWidget(attachedApp());
      controller.attach(GlobalKey<NavigatorState>());
      final warming = controller.warmUp();
      await tester.pump();
      expect(standIn, findsStandIns);

      expect(controller.zone.open, throwsStateError);

      expect(await completesAtOnce(tester, warming), isTrue);
      await tester.pump();
      expect(standIn, findsNothing);
      expect(controller.zone.state, ZoneState.shown);
    });

    testWidgets('attach while one runs does not cut it short', (tester) async {
      await tester.pumpWidget(attachedApp());

      final warming = controller.warmUp();
      await tester.pump();
      expect(standIn, findsStandIns);

      controller.attach(navigatorKey);
      expect(await completesAtOnce(tester, warming), isFalse);
      await tester.pump(const Duration(milliseconds: 16));
      expect(standIn, findsStandIns);

      await pumpUntilDone(tester, warming);
      await tester.pump();
      expect(standIn, findsNothing);
      final again = controller.warmUp();
      expect(await completesAtOnce(tester, again), isTrue);
      await tester.pump();
      expect(standIn, findsNothing);
    });
  });

  testWidgets("a slot given no controller draws the exported toast's", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => Stack(
          children: [
            const Positioned.fill(child: SonnerWarmUpSlot()),
            child!,
          ],
        ),
        home: const ColoredBox(color: Color(0xFFFFFFFF)),
      ),
    );

    final warming = toast.warmUp();
    await tester.pump();

    expect(standIn, findsStandIns);
    await pumpUntilDone(tester, warming);
    await tester.pump();
    expect(standIn, findsNothing);
  });

  testWidgets('called during a build, it starts once the frame ends', (
    tester,
  ) async {
    Future<void>? warming;
    var builds = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      app(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            if (++builds == 2) warming = controller.warmUp();
            return const SizedBox.expand();
          },
        ),
      ),
    );
    rebuild(() {});
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(standIn, findsStandIns);

    await pumpUntilDone(tester, warming!);
  });

  group('what it draws', () {
    /// How many cut masks the frame last drawn painted.
    int masksPainted(WidgetTester tester) {
      var masks = 0;
      void walk(Layer? layer) {
        while (layer != null) {
          if (layer is ShaderMaskLayer) masks++;
          if (layer is ContainerLayer) walk(layer.firstChild);
          layer = layer.nextSibling;
        }
      }

      walk(tester.binding.renderViews.first.debugLayer);
      return masks;
    }

    /// Pumps [warming] to its end [frame] apart, and returns the most cut
    /// masks one of its frames painted.
    Future<int> peakMasks(
      WidgetTester tester,
      Future<void> warming,
      Duration frame,
    ) async {
      var done = false;
      warming.then((_) => done = true);
      await tester.pump();
      expect(standIn, findsWidgets);
      var peak = 0;
      var frames = 0;
      while (!done) {
        expect(frames, lessThan(100), reason: 'the warm-up never ended');
        await tester.pump(frame);
        frames++;
        final masks = masksPainted(tester);
        if (masks > peak) peak = masks;
      }
      return peak;
    }

    for (final ms in [16, 8]) {
      testWidgets("paints the cut's fading mask with $ms ms frames", (
        tester,
      ) async {
        await tester.pumpWidget(app());

        final peak = await peakMasks(
          tester,
          controller.warmUp(),
          Duration(milliseconds: ms),
        );
        expect(peak, greaterThan(0));
      });
    }

    testWidgets("paints it with no dismissAll", (tester) async {
      controller.config = const SonnerConfig(duration: null, dismissAll: null);
      await tester.pumpWidget(app());

      final peak = await peakMasks(
        tester,
        controller.warmUp(),
        const Duration(milliseconds: 16),
      );
      expect(peak, greaterThan(0));
    });

    for (final height in [40.0, 500.0]) {
      testWidgets('paints it with a card $height px tall, at 8 ms frames', (
        tester,
      ) async {
        controller.config = SonnerConfig(
          duration: null,
          builder: (context, toast) => SizedBox(
            width: 300,
            height: height,
            child: Text(toast.state.title),
          ),
        );
        await tester.pumpWidget(app());

        final peak = await peakMasks(
          tester,
          controller.warmUp(),
          const Duration(milliseconds: 8),
        );
        expect(peak, greaterThan(0));
      });
    }

    for (final (dismissAll, cap, count, label) in [
      (const DeckDismissAll(), _defaultCap, 2, 'the default dismissAll'),
      (const DeckDismissAll(minCount: 3), _defaultCap, 3, 'a minCount of 3'),
      (null, _defaultCap, 2, 'no dismissAll and a cap that fades'),
      (null, null, 1, 'no dismissAll and no cap'),
      (
        null,
        const DeckCap.pixels(400, fade: 0),
        1,
        'no dismissAll and no fade',
      ),
    ]) {
      testWidgets('holds $count stand-ins with $label', (tester) async {
        controller.config = SonnerConfig(
          duration: null,
          dismissAll: dismissAll,
          deckCap: cap,
        );
        await tester.pumpWidget(app());

        final warming = controller.warmUp();
        await tester.pump();
        expect(standIn, findsNWidgets(count));

        var done = false;
        warming.then((_) => done = true);
        var controlDrawn = false;
        for (var i = 0; i < 100 && !done; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          controlDrawn |= find.text('Clear all').evaluate().isNotEmpty;
        }
        expect(done, isTrue);
        expect(controlDrawn, dismissAll != null);
        expect(controller.count, 0);
      });
    }

    SonnerConfig deckConfig() => warmUpOf(controller).value!.deck.config;

    testWidgets(
      "its cap ends the app's fade past the newest stand-in, a config "
      'assigned while it runs included',
      (tester) async {
        controller.config = const SonnerConfig(
          duration: null,
          deckCap: DeckCap.pixels(300, fade: 10),
        );
        await tester.pumpWidget(app());
        final warming = controller.warmUp();
        await tester.pump();

        expect(deckConfig().deckCap, const PastNewestCap(10));
        expect(
          deckConfig().copyWith(deckCap: () => controller.config.deckCap),
          controller.config,
        );

        controller.config = controller.config.copyWith(
          gap: 20,
          deckCap: () => const DeckCap.share(0.5, fade: 30),
        );
        expect(deckConfig().deckCap, const PastNewestCap(30));
        expect(deckConfig().gap, 20);

        controller.config = controller.config.copyWith(deckCap: () => null);
        expect(deckConfig(), controller.config);

        await pumpUntilDone(tester, warming);
      },
    );

    for (final cap in [null, const DeckCap.pixels(300, fade: 0)]) {
      testWidgets("with deckCap $cap, its cap is the app's", (tester) async {
        controller.config = SonnerConfig(duration: null, deckCap: cap);
        await tester.pumpWidget(app());
        final warming = controller.warmUp();
        await tester.pump();

        expect(deckConfig(), controller.config);
        await pumpUntilDone(tester, warming);
      });
    }
  });
}

const _defaultCap = DeckCap.pixels(400);
