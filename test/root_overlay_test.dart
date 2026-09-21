import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_sonner/just_sonner.dart';
import 'package:just_sonner/src/host.dart' show ToastLayer;

void main() {
  late SonnerController controller;
  late GlobalKey<NavigatorState> navigatorKey;

  // Toasts here have no timer: a widget test must not end with one pending.
  setUp(() {
    controller = SonnerController(config: const SonnerConfig(duration: null));
    navigatorKey = GlobalKey<NavigatorState>();
  });

  Widget app({Widget home = const SizedBox.expand()}) =>
      MaterialApp(navigatorKey: navigatorKey, home: home);

  Future<void> openDialog(WidgetTester tester) async {
    showDialog<void>(
      context: navigatorKey.currentContext!,
      builder: (_) => const AlertDialog(content: Text('Dialog')),
    );
    await tester.pumpAndSettle();
  }

  Offset centreOf(WidgetTester tester, String title) => tester.getCenter(
    find.ancestor(of: find.text(title), matching: find.byType(Material)).first,
  );

  Future<void> cleanUp(WidgetTester tester) async {
    controller.dismissAll();
    await tester.pumpAndSettle();
    controller.dispose();
  }

  /// A full-screen entry that counts the taps reaching it.
  OverlayEntry tapCatcher(void Function() onTap) => OverlayEntry(
    builder: (_) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const SizedBox.expand(),
    ),
  );

  testWidgets('attached, opening the zone with no toast draws the empty card '
      'in the root overlay', (tester) async {
    controller.attach(navigatorKey);
    await tester.pumpWidget(app());

    controller.zone.open();
    await tester.pumpAndSettle();

    expect(find.text('No notifications'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('No notifications'),
        matching: find.byType(Overlay),
      ),
      findsOneWidget,
    );
    controller.zone.close();
    await cleanUp(tester);
  });

  testWidgets('attached with no navigator to draw in, opening the zone is an '
      'error and leaves it as it was', (tester) async {
    controller.attach(navigatorKey);

    expect(controller.zone.open, throwsStateError);
    expect(controller.zone.state, ZoneState.shown);
    controller.dispose();
  });

  testWidgets(
    'attached before the app is built, a toast is drawn in the root overlay',
    (tester) async {
      controller.attach(navigatorKey);
      await tester.pumpWidget(app());

      controller.show('Saved');
      await tester.pumpAndSettle();

      expect(find.text('Saved'), findsOneWidget);
      final overlay = tester.state<OverlayState>(
        find.ancestor(of: find.text('Saved'), matching: find.byType(Overlay)),
      );
      expect(overlay, same(navigatorKey.currentState!.overlay));
      await cleanUp(tester);
    },
  );

  testWidgets('an attached controller follows a config assigned '
      'with them on screen', (tester) async {
    controller.attach(navigatorKey);
    await tester.pumpWidget(app());
    controller.show('Saved');
    await tester.pumpAndSettle();
    final before = centreOf(tester, 'Saved');

    controller.config = controller.config.copyWith(
      position: SonnerPosition.topLeft,
    );
    await tester.pump();
    expect(centreOf(tester, 'Saved'), before, reason: 'from where it was');
    await tester.pumpAndSettle();
    final after = centreOf(tester, 'Saved');
    expect(after.dx, lessThan(before.dx));
    expect(after.dy, lessThan(before.dy));
    await cleanUp(tester);
  });

  testWidgets('a toast shown while a dialog is open is above the dialog', (
    tester,
  ) async {
    controller.attach(navigatorKey);
    await tester.pumpWidget(app());
    await openDialog(tester);

    controller.show('Saved');
    await tester.pumpAndSettle();
    await tester.tapAt(centreOf(tester, 'Saved'));
    await tester.pumpAndSettle();

    expect(
      find.text('Dialog'),
      findsOneWidget,
      reason: 'the barrier took no tap',
    );
    await cleanUp(tester);
  });

  testWidgets('a toast shown before a dialog opens is still above it', (
    tester,
  ) async {
    controller.attach(navigatorKey);
    await tester.pumpWidget(app());
    controller.show('Saved');
    await tester.pumpAndSettle();

    await openDialog(tester);
    await tester.tapAt(centreOf(tester, 'Saved'));
    await tester.pumpAndSettle();

    expect(
      find.text('Dialog'),
      findsOneWidget,
      reason: 'the barrier took no tap',
    );
    await cleanUp(tester);
  });

  testWidgets(
    'an entry inserted over the toasts covers them until the next show',
    (tester) async {
      controller.attach(navigatorKey);
      await tester.pumpWidget(app());
      controller.show('First');
      await tester.pumpAndSettle();

      var covered = 0;
      final catcher = tapCatcher(() => covered++);
      navigatorKey.currentState!.overlay!.insert(catcher);
      await tester.pump();
      await tester.tapAt(centreOf(tester, 'First'));
      expect(covered, 1, reason: 'inserted later, it is on top');

      controller.show('Second');
      await tester.pumpAndSettle();
      await tester.tapAt(centreOf(tester, 'Second'));
      expect(covered, 1, reason: 'the show raised the toasts over it');

      catcher
        ..remove()
        ..dispose();
      await cleanUp(tester);
    },
  );

  testWidgets('each promise state raises the toasts, as any show does', (
    tester,
  ) async {
    controller.attach(navigatorKey);
    await tester.pumpWidget(app());
    final work = Completer<void>();

    var covered = 0;
    final catcher = tapCatcher(() => covered++);

    final result = controller.promise(
      work.future,
      loading: const ToastContent('Connecting'),
      success: (_) => const ToastContent('Connected'),
      error: (e) => ToastContent('Failed: $e'),
    );
    // Not pumpAndSettle: the loading indicator never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    navigatorKey.currentState!.overlay!.insert(catcher);
    await tester.pump();
    await tester.tapAt(centreOf(tester, 'Connecting'));
    expect(covered, 1, reason: 'inserted later, it is on top');

    work.complete();
    await result;
    await tester.pumpAndSettle();
    await tester.tapAt(centreOf(tester, 'Connected'));
    expect(covered, 1, reason: 'the result state raised the toasts over it');

    catcher
      ..remove()
      ..dispose();
    await cleanUp(tester);
  });

  testWidgets('an update does not raise the toasts, and a replace does', (
    tester,
  ) async {
    controller.attach(navigatorKey);
    await tester.pumpWidget(app());
    final id = controller.show('First');
    await tester.pumpAndSettle();

    var covered = 0;
    final catcher = tapCatcher(() => covered++);
    navigatorKey.currentState!.overlay!.insert(catcher);
    await tester.pump();

    controller.update(id, title: 'Updated');
    await tester.pumpAndSettle();
    await tester.tapAt(centreOf(tester, 'Updated'));
    expect(covered, 1, reason: 'the update left the entry on top');

    controller.show('Replaced', id: id);
    await tester.pumpAndSettle();
    await tester.tapAt(centreOf(tester, 'Replaced'));
    expect(covered, 1, reason: 'the replace raised the toasts over it');

    catcher
      ..remove()
      ..dispose();
    await cleanUp(tester);
  });

  testWidgets('raising the toasts keeps an enter that is under way', (
    tester,
  ) async {
    controller.attach(navigatorKey);
    await tester.pumpWidget(app());
    controller.show('First');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    double presence() => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.ancestor(
                  of: find.text('First'),
                  matching: find.byType(SlideTransition),
                ),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;
    final midway = presence();
    expect(midway, inExclusiveRange(0, 1));

    final other = OverlayEntry(builder: (_) => const SizedBox.shrink());
    navigatorKey.currentState!.overlay!.insert(other);
    controller.show('Second');
    await tester.pump();

    expect(presence(), greaterThanOrEqualTo(midway));
    other
      ..remove()
      ..dispose();
    await cleanUp(tester);
  });

  group('attach refuses a navigator that is not the root one', () {
    Widget nested() => MaterialApp(
      home: Navigator(
        key: navigatorKey,
        onGenerateRoute: (_) =>
            MaterialPageRoute<void>(builder: (_) => const SizedBox()),
      ),
    );

    testWidgets('a nested navigator', (tester) async {
      await tester.pumpWidget(nested());

      expect(() => controller.attach(navigatorKey), throwsAssertionError);
      controller.dispose();
    });

    testWidgets('a navigator under an Overlay added in the builder', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => Overlay.wrap(child: child!),
          home: const SizedBox(),
        ),
      );

      expect(() => controller.attach(navigatorKey), throwsAssertionError);
      controller.dispose();
    });

    testWidgets('attached before it is built, the first show asserts', (
      tester,
    ) async {
      controller.attach(navigatorKey);
      await tester.pumpWidget(nested());

      expect(() => controller.show('Saved'), throwsAssertionError);
      controller.dispose();
    });
  });

  testWidgets('a refused attach leaves the toasts where they were', (
    tester,
  ) async {
    final nested = GlobalKey<NavigatorState>();
    controller.attach(navigatorKey);
    await tester.pumpWidget(
      app(
        home: Navigator(
          key: nested,
          onGenerateRoute: (_) =>
              MaterialPageRoute<void>(builder: (_) => const SizedBox()),
        ),
      ),
    );
    controller.show('Saved');
    await tester.pumpAndSettle();

    expect(() => controller.attach(nested), throwsAssertionError);
    controller.show('Again');
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Again'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets(
    'once attached, a show with no navigator throws and keeps no toast',
    (tester) async {
      controller.attach(navigatorKey);

      expect(() => controller.show('Lost'), throwsStateError);

      await tester.pumpWidget(app());
      controller.show('Kept');
      await tester.pumpAndSettle();
      expect(find.text('Kept'), findsOneWidget);
      expect(find.text('Lost'), findsNothing);
      await cleanUp(tester);
    },
  );

  testWidgets(
    'a promise whose states cannot be drawn still hands the future back',
    (tester) async {
      // Attached, with no navigator built: every show throws in debug. The
      // future's outcome is the caller's work, not the toast's to lose, so
      // promise reports the failure and delivers it anyway.
      controller.attach(navigatorKey);
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      final value = await controller.promise(
        Future<int>.value(7),
        loading: const ToastContent('Connecting'),
        success: (v) => ToastContent('Got $v'),
        error: (e) => ToastContent('Failed: $e'),
      );

      expect(value, 7);
      expect(reported, hasLength(2), reason: 'the loading and the result');
      expect(reported.first.library, 'just_sonner');
      expect(reported.first.exception, isStateError);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Got 7'), findsNothing, reason: 'both were dropped');
      await cleanUp(tester);
    },
  );

  testWidgets(
    'once attached, a replace with no navigator throws but still applies',
    (tester) async {
      final id = controller.show('Checking');
      controller.attach(navigatorKey);

      expect(() => controller.show('Connected', id: id), throwsStateError);

      await tester.pumpWidget(app());
      controller.show('Next');
      await tester.pumpAndSettle();
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Checking'), findsNothing);
      await cleanUp(tester);
    },
  );

  testWidgets('a toast shown while the app builds is drawn', (tester) async {
    controller.attach(navigatorKey);
    var shown = false;
    await tester.pumpWidget(
      app(
        home: Builder(
          builder: (context) {
            if (!shown) {
              shown = true;
              controller.show('From a build');
            }
            return const SizedBox.expand();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('From a build'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('a toast shown during a build, with the toasts already drawn, '
      'is drawn', (tester) async {
    controller.attach(navigatorKey);
    late StateSetter rebuild;
    var builds = 0;
    await tester.pumpWidget(
      app(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            if (++builds == 2) controller.show('From a build');
            return const SizedBox.expand();
          },
        ),
      ),
    );
    controller.show('Before');
    await tester.pumpAndSettle();

    rebuild(() {});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('From a build'), findsOneWidget);
    expect(find.text('Before'), findsOneWidget);
    await cleanUp(tester);
  });

  group('a show during a build, then before the frame ends', () {
    Widget showingApp(GlobalKey<NavigatorState> key, void Function() then) {
      var shown = false;
      return MaterialApp(
        navigatorKey: key,
        home: Builder(
          builder: (context) {
            if (!shown) {
              shown = true;
              controller.show('From a build');
              then();
            }
            return const SizedBox.expand();
          },
        ),
      );
    }

    testWidgets('dispose leaves nothing in the overlay', (tester) async {
      controller.attach(navigatorKey);
      await tester.pumpWidget(showingApp(navigatorKey, controller.dispose));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('From a build'), findsNothing);
    });

    testWidgets('attaching another navigator leaves nothing in the old one', (
      tester,
    ) async {
      final other = GlobalKey<NavigatorState>();
      controller.attach(navigatorKey);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              Expanded(
                child: showingApp(navigatorKey, () => controller.attach(other)),
              ),
              Expanded(
                child: MaterialApp(
                  navigatorKey: other,
                  home: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.show('Later');
      await tester.pumpAndSettle();

      for (final title in ['From a build', 'Later']) {
        expect(find.text(title), findsOneWidget, reason: title);
        final overlay = tester.state<OverlayState>(
          find.ancestor(of: find.text(title), matching: find.byType(Overlay)),
        );
        expect(overlay, same(other.currentState!.overlay), reason: title);
      }
      await cleanUp(tester);
    });
  });

  testWidgets(
    'after the overlay is replaced, toasts are drawn in the new one',
    (tester) async {
      controller.attach(navigatorKey);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          restorationScopeId: 'app',
          home: const SizedBox.expand(),
        ),
      );
      controller.show('Before');
      await tester.pumpAndSettle();
      final before = navigatorKey.currentState!.overlay;

      await tester.restartAndRestore();
      expect(navigatorKey.currentState!.overlay, isNot(same(before)));
      controller.show('After');
      await tester.pumpAndSettle();

      expect(find.text('Before'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
      await cleanUp(tester);
    },
  );

  testWidgets('attaching the same key twice draws the toasts once', (
    tester,
  ) async {
    controller.attach(navigatorKey);
    await tester.pumpWidget(app());
    controller.show('Saved');
    await tester.pumpAndSettle();

    controller.show('Entering');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    double presence() => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.ancestor(
                  of: find.text('Entering'),
                  matching: find.byType(SlideTransition),
                ),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;
    final midway = presence();

    controller.attach(navigatorKey);
    await tester.pump();
    expect(presence(), greaterThanOrEqualTo(midway), reason: 'not re-entered');

    controller.show('Again');
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('attaching another navigator moves the toasts to it', (
    tester,
  ) async {
    final first = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Expanded(
              child: MaterialApp(
                navigatorKey: first,
                home: const SizedBox.expand(),
              ),
            ),
            Expanded(child: app()),
          ],
        ),
      ),
    );
    controller.attach(first);
    controller.show('Saved');
    await tester.pumpAndSettle();

    controller.attach(navigatorKey);
    controller.show('Moved');
    await tester.pumpAndSettle();

    for (final title in ['Saved', 'Moved']) {
      final overlay = tester.state<OverlayState>(
        find.ancestor(of: find.text(title), matching: find.byType(Overlay)),
      );
      expect(overlay, same(navigatorKey.currentState!.overlay), reason: title);
    }
    await cleanUp(tester);
  });

  testWidgets('detach takes the toasts off and makes the controller plain', (
    tester,
  ) async {
    controller.attach(navigatorKey);
    await tester.pumpWidget(app());
    controller.show('Saved');
    await tester.pumpAndSettle();

    controller.detach();
    await tester.pump();
    expect(find.text('Saved'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    expect(
      () => controller.show('Unattached'),
      returnsNormally,
      reason: 'a detached controller is not checked for a navigator',
    );
    await cleanUp(tester);
  });

  testWidgets('toasts covered by an opaque entry keep their state', (
    tester,
  ) async {
    controller.attach(navigatorKey);
    await tester.pumpWidget(app());
    controller.show('Saved');
    await tester.pumpAndSettle();

    final cover = OverlayEntry(
      opaque: true,
      builder: (_) => const ColoredBox(color: Color(0xFF000000)),
    );
    navigatorKey.currentState!.overlay!.insert(cover);
    await tester.pump();
    cover
      ..remove()
      ..dispose();
    await tester.pump();

    final presence = tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.ancestor(
                  of: find.text('Saved'),
                  matching: find.byType(SlideTransition),
                ),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;
    expect(presence, 1, reason: 'uncovered, it does not enter again');
    await cleanUp(tester);
  });

  testWidgets('disposing the controller takes its toasts off the screen', (
    tester,
  ) async {
    controller.attach(navigatorKey);
    await tester.pumpWidget(app());
    controller.show('Saved');
    await tester.pumpAndSettle();

    controller.dispose();
    await tester.pump();

    expect(find.text('Saved'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the first toast shown while the app is hidden waits, before its host is '
    'built',
    (tester) async {
      final controller = SonnerController(
        config: const SonnerConfig(duration: Duration(seconds: 1)),
      );
      addTearDown(controller.dispose);
      controller.attach(navigatorKey);
      await tester.pumpWidget(app());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );

      controller.show('Saved');
      // Time passes with no frame, as it does while the app is hidden.
      await tester.binding.delayed(const Duration(seconds: 5));
      expect(
        find.byType(ToastLayer, skipOffstage: false),
        findsNothing,
        reason: 'no frame is drawn while hidden, so no host has been built',
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Saved'), findsOneWidget, reason: 'it waited');
      controller.dismissAll();
      await tester.pumpAndSettle();
    },
  );
}
