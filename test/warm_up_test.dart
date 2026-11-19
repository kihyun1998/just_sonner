import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderStack;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_sonner/just_sonner.dart';
import 'package:just_sonner/src/host.dart' show ToastLayer;
import 'package:just_sonner/src/look/deck_backdrop.dart' show DeckBackdropBox;
import 'package:just_sonner/src/look/default_look.dart' show DefaultToastLook;
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

  final standIn = find.text(warmUpTitle, skipOffstage: false);

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

        expect(standIn, findsOneWidget);
        expect(find.byType(DefaultToastLook), findsOneWidget);
        expect(find.byType(DeckBackdropBox), findsNWidgets(boxes + 1));
        expect(find.byType(BackdropFilter), findsNothing);

        var backdropDrawn = false;
        for (var i = 0; i < 30 && !backdropDrawn; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          backdropDrawn = find.byType(BackdropFilter).evaluate().isNotEmpty;
        }
        expect(backdropDrawn, isTrue, reason: 'the deck never fanned out');
        expect(
          tester.renderObject(find.byType(BackdropFilter)).debugNeedsPaint,
          isFalse,
        );
        expect(tester.renderObject(standIn).debugNeedsPaint, isFalse);

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

      expect(standIn, findsOneWidget);
      expect(find.byType(DeckBackdropBox), findsNothing);

      await pumpUntilDone(tester, warming);
      await tester.pump();
      expect(standIn, findsNothing);
    });

    testWidgets("the stand-in is laid under the app's screen", (tester) async {
      await tester.pumpWidget(app());

      final warming = controller.warmUp();
      await tester.pump();

      // A stack paints its children in order, so the first is the lowest.
      final stack = tester.renderObject<RenderStack>(
        find
            .descendant(
              of: find.byType(SonnerHost),
              matching: find.byType(Stack),
            )
            .first,
      );
      final layers = stack.getChildrenAsList();
      int layerOf(Finder finder) {
        RenderObject? node = tester.renderObject(finder);
        while (node != null && !layers.contains(node)) {
          node = node.parent;
        }
        return layers.indexOf(node! as RenderBox);
      }

      expect(layerOf(standIn), lessThan(layerOf(find.byKey(screenKey))));

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
      final center = tester.getCenter(standIn);
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

      expect(standIn, findsOneWidget);
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
        expect(standIn, findsOneWidget);

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
      expect(find.byType(DefaultToastLook), findsOneWidget);

      controller.config = SonnerConfig(
        duration: null,
        builder: (context, toast) =>
            const SizedBox(key: Key('built'), width: 300, height: 60),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const Key('built'), skipOffstage: false),
        findsOneWidget,
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
      expect(standIn, findsOneWidget);

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

    testWidgets('attached, with the navigator built', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.expand()),
      );
      controller.attach(navigatorKey);
      final entries = find.byType(ToastLayer, skipOffstage: false);

      final warming = controller.warmUp();
      expect(await completesAtOnce(tester, warming), isTrue);
      await tester.pump();

      expect(standIn, findsNothing);
      expect(entries, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('attached, with no navigator built', (tester) async {
      controller.attach(GlobalKey<NavigatorState>());
      await tester.pumpWidget(const SizedBox());

      final warming = controller.warmUp();
      expect(await completesAtOnce(tester, warming), isTrue);
      await tester.pump();

      expect(tester.takeException(), isNull);
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
      expect(standIn, findsOneWidget);

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
      expect(standIn, findsOneWidget);

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
      expect(standIn, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      final frames = await pumpUntilDone(tester, warming, limit: 3);
      expect(frames, lessThanOrEqualTo(1));

      await tester.pumpWidget(app());
      final again = controller.warmUp();
      await tester.pump();

      expect(standIn, findsOneWidget);
      await pumpUntilDone(tester, again);
    });

    testWidgets('by attach', (tester) async {
      await tester.pumpWidget(app());
      final warming = controller.warmUp();
      await tester.pump();
      expect(standIn, findsOneWidget);

      controller.attach(GlobalKey<NavigatorState>());
      expect(await completesAtOnce(tester, warming), isTrue);
      await tester.pump();

      expect(standIn, findsNothing);
      expect(tester.takeException(), isNull);
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

      expect(standIn, findsOneWidget);
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
      expect(standIn, findsOneWidget);

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
      expect(standIn, findsOneWidget);

      own.dispose();

      expect(await completesAtOnce(tester, warming), isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
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
    expect(standIn, findsOneWidget);

    await pumpUntilDone(tester, warming!);
  });
}
