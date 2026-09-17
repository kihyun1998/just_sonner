import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_sonner/just_sonner.dart';
import 'package:just_sonner/src/controller.dart'
    show holdTimers, releaseTimers, toastsOf;

void main() {
  group('countdown', () {
    test('a toast with no duration dismisses itself after 4 s', () {
      fakeAsync((async) {
        final controller = SonnerController();
        var notifications = 0;
        final id = controller.show('Saved');
        controller.addListener(() => notifications++);

        async.elapse(const Duration(milliseconds: 3999));
        expect(notifications, 0, reason: 'still on screen just before 4 s');

        async.elapse(const Duration(milliseconds: 1));
        expect(notifications, 1, reason: 'dismissed at 4 s');

        controller.dismiss(id);
        expect(
          notifications,
          1,
          reason: 'it is gone, so dismissing is a no-op',
        );
        controller.dispose();
      });
    });

    test('an explicit duration is used instead of the config', () {
      fakeAsync((async) {
        final controller = SonnerController();
        var notifications = 0;
        controller.show('Quick', duration: const Duration(seconds: 2));
        controller.addListener(() => notifications++);

        async.elapse(const Duration(milliseconds: 1999));
        expect(notifications, 0);
        async.elapse(const Duration(milliseconds: 1));
        expect(notifications, 1);
        controller.dispose();
      });
    });

    test('Duration.zero means no timer at all', () {
      fakeAsync((async) {
        final controller = SonnerController();
        var notifications = 0;
        controller.show('Pinned', duration: Duration.zero);
        controller.addListener(() => notifications++);

        expect(async.periodicTimerCount, 0);
        async.elapse(const Duration(minutes: 1));
        expect(notifications, 0);
        controller.dispose();
      });
    });

    test('one tick serves every counting toast, and stops with the last', () {
      fakeAsync((async) {
        final controller = SonnerController();
        final first = controller.show('First');
        final second = controller.show('Second');
        controller.show('Pinned', duration: Duration.zero);
        expect(async.periodicTimerCount, 1);

        controller.dismiss(first);
        expect(async.periodicTimerCount, 1, reason: 'Second still counts');

        controller.dismiss(second);
        expect(
          async.periodicTimerCount,
          0,
          reason: 'a toast with no timer does not keep the tick alive',
        );

        controller.show('Next');
        expect(async.periodicTimerCount, 1, reason: 'starts again');

        controller.dismissAll();
        expect(async.periodicTimerCount, 0);

        controller.show('Expires');
        async.elapse(const Duration(seconds: 4));
        expect(async.periodicTimerCount, 0, reason: 'the last one expired');
        controller.dispose();
      });
    });

    test(
      'a toast shown between ticks runs up to one tick long, never short',
      () {
        fakeAsync((async) {
          final controller = SonnerController();
          controller.show('Starts the tick');
          async.elapse(const Duration(milliseconds: 50));

          var notifications = 0;
          controller.show('Late', duration: const Duration(seconds: 1));
          controller.addListener(() => notifications++);

          async.elapse(const Duration(milliseconds: 999));
          expect(notifications, 0, reason: 'a full second has not passed');

          async.elapse(const Duration(milliseconds: 100));
          expect(notifications, 1, reason: 'gone within one tick of a second');
          controller.dispose();
        });
      },
    );

    test(
      'a duration between ticks rounds up to the next tick, never short',
      () {
        fakeAsync((async) {
          final controller = SonnerController();
          controller.show('Starts the tick');
          async.elapse(const Duration(milliseconds: 1));

          var notifications = 0;
          controller.show('Odd', duration: const Duration(milliseconds: 150));
          controller.addListener(() => notifications++);

          async.elapse(const Duration(milliseconds: 149));
          expect(notifications, 0, reason: '150 ms have not passed');

          // 150 ms rounds up to 200 ms, plus up to one tick for joining late.
          async.elapse(const Duration(milliseconds: 150));
          expect(notifications, 1);
          controller.dispose();
        });
      },
    );

    test('a tick left in a finished zone does not stall a later one', () {
      final controller = SonnerController();
      fakeAsync((async) {
        controller.show('Left behind by an earlier test');
      });

      fakeAsync((async) {
        var notifications = 0;
        controller.show('Shown by a later test');
        controller.addListener(() => notifications++);

        async.elapse(const Duration(seconds: 4));
        expect(notifications, 1, reason: 'the later toast still counts down');
        controller.dismissAll();
      });
      controller.dispose();
    });

    test('toasts shown in quick succession do not hold back the tick', () {
      fakeAsync((async) {
        final controller = SonnerController();
        final first = controller.show(
          'First',
          duration: const Duration(seconds: 1),
        );
        for (var i = 0; i < 12; i++) {
          async.elapse(const Duration(milliseconds: 90));
          controller.show('Burst $i', duration: const Duration(seconds: 10));
        }
        async.elapse(const Duration(milliseconds: 20));

        var notifications = 0;
        controller.addListener(() => notifications++);
        controller.dismiss(first);
        expect(notifications, 0, reason: 'First already expired by 1.1 s');
        controller.dispose();
      });
    });

    test('a negative duration is refused', () {
      final controller = SonnerController();
      expect(
        () => controller.show('Past', duration: const Duration(seconds: -1)),
        throwsAssertionError,
      );
      expect(
        () => SonnerController(
          config: const SonnerConfig(duration: Duration(seconds: -1)),
        ),
        throwsAssertionError,
      );
      controller.dispose();
    });

    test('visibleToasts outside 1 to 20 is refused', () {
      for (final visibleToasts in [-1, 0, 21]) {
        expect(
          () => SonnerController(
            config: SonnerConfig(
              visibleToasts: visibleToasts,
              duration: Duration.zero,
            ),
          ),
          throwsAssertionError,
          reason: '$visibleToasts',
        );
      }
      for (final visibleToasts in [1, 20]) {
        SonnerController(
          config: SonnerConfig(
            visibleToasts: visibleToasts,
            duration: Duration.zero,
          ),
        ).dispose();
      }
    });

    test('show on a disposed controller fails without leaving a timer', () {
      fakeAsync((async) {
        final controller = SonnerController()..dispose();

        expect(() => controller.show('Too late'), throwsFlutterError);
        expect(async.periodicTimerCount, 0);
      });
    });

    test('disposing the controller cancels the tick', () {
      fakeAsync((async) {
        final controller = SonnerController();
        controller.show('Saved');

        controller.dispose();

        expect(async.periodicTimerCount, 0);
      });
    });

    test('a config duration of zero keeps toasts until dismissed', () {
      fakeAsync((async) {
        final controller = SonnerController(
          config: const SonnerConfig(duration: Duration.zero),
        );
        controller.show('Pinned');

        expect(async.periodicTimerCount, 0);
        controller.dispose();
      });
    });

    test('a toast pushed beyond visibleToasts keeps counting down', () {
      fakeAsync((async) {
        final controller = SonnerController(
          config: const SonnerConfig(visibleToasts: 1),
        );
        List<String> titles() => [
          for (final record in toastsOf(controller)) record.state.title,
        ];
        controller.show('Oldest');
        async.elapse(const Duration(seconds: 1));
        controller.show('Newest', duration: const Duration(seconds: 10));

        async.elapse(const Duration(milliseconds: 2999));
        expect(titles(), [
          'Newest',
          'Oldest',
        ], reason: 'kept, undrawn, just before its 4 s');

        async.elapse(const Duration(milliseconds: 1));
        expect(
          titles(),
          ['Newest'],
          reason: 'expired at 4 s, neither paused nor restarted while hidden',
        );
        controller.dispose();
      });
    });
  });

  group('pause', () {
    test('a held controller does not count down, and resumes with the time '
        'left', () {
      fakeAsync((async) {
        final controller = SonnerController();
        const holder = #pointer;
        var notifications = 0;
        controller.show('Saved');
        controller.addListener(() => notifications++);
        // Letting go of nothing is not coming out of a pause, so it costs the
        // countdown no tick.
        releaseTimers(controller, holder);

        async.elapse(const Duration(seconds: 1));
        holdTimers(controller, holder);
        async.elapse(const Duration(seconds: 10));
        expect(notifications, 0, reason: 'held, so nothing is subtracted');
        expect(
          async.periodicTimerCount,
          1,
          reason: 'the tick keeps running while held',
        );

        releaseTimers(controller, holder);
        async.elapse(const Duration(milliseconds: 2999));
        expect(notifications, 0, reason: '3 s were left, not 4 and not 0');
        async.elapse(const Duration(milliseconds: 101));
        expect(notifications, 1, reason: 'gone within a tick of the 3 s left');
        controller.dispose();
      });
    });

    test('a pause released between ticks never runs a toast short', () {
      fakeAsync((async) {
        final controller = SonnerController();
        const holder = #pointer;
        var notifications = 0;
        controller.show('Short', duration: const Duration(seconds: 1));
        controller.addListener(() => notifications++);

        // 50 ms counted, then held over no tick, then released 10 ms before
        // the next one: 1 s of unheld time is not over until 1040 ms.
        async.elapse(const Duration(milliseconds: 50));
        holdTimers(controller, holder);
        async.elapse(const Duration(milliseconds: 40));
        releaseTimers(controller, holder);

        async.elapse(const Duration(milliseconds: 949));
        expect(notifications, 0, reason: 'a full unheld second has not passed');
        async.elapse(const Duration(milliseconds: 111));
        expect(notifications, 1);
        controller.dispose();
      });
    });

    test('every holder has to let go before the countdown resumes', () {
      fakeAsync((async) {
        final controller = SonnerController();
        var notifications = 0;
        controller.show('Saved');
        controller.addListener(() => notifications++);

        holdTimers(controller, #first);
        holdTimers(controller, #second);
        releaseTimers(controller, #first);
        releaseTimers(controller, #never);
        async.elapse(const Duration(seconds: 10));
        expect(notifications, 0, reason: 'the second holder still holds');

        releaseTimers(controller, #second);
        async.elapse(const Duration(milliseconds: 4100));
        expect(notifications, 1);
        controller.dispose();
      });
    });

    test('a toast shown while held waits with the rest', () {
      fakeAsync((async) {
        final controller = SonnerController();
        holdTimers(controller, #pointer);
        var notifications = 0;
        controller.show('Saved');
        controller.addListener(() => notifications++);

        async.elapse(const Duration(seconds: 10));
        expect(notifications, 0);

        releaseTimers(controller, #pointer);
        async.elapse(const Duration(milliseconds: 3999));
        expect(notifications, 0, reason: 'it starts from its full 4 s');
        async.elapse(const Duration(milliseconds: 101));
        expect(notifications, 1);
        controller.dispose();
      });
    });
  });

  group('loading', () {
    test('a loading toast has no timer, and keeps its duration for later', () {
      fakeAsync((async) {
        final controller = SonnerController();
        var notifications = 0;
        final id = controller.show('Uploading', isLoading: true);
        controller.addListener(() => notifications++);

        expect(toastsOf(controller).single.remaining, isNull);
        expect(async.periodicTimerCount, 0, reason: 'nothing to tick for');

        async.elapse(const Duration(seconds: 60));
        expect(notifications, 0, reason: 'it waits for its work, not a clock');

        expect(controller.update(id, isLoading: false), isTrue);
        async.elapse(const Duration(milliseconds: 3999));
        expect(notifications, 1, reason: 'only the update so far');
        async.elapse(const Duration(milliseconds: 101));
        expect(
          notifications,
          2,
          reason: 'it counts down config.duration once it stops loading',
        );
        controller.dispose();
      });
    });

    test('entering isLoading stops a countdown already under way', () {
      fakeAsync((async) {
        final controller = SonnerController();
        var notifications = 0;
        final id = controller.show('Saved');
        controller.addListener(() => notifications++);

        async.elapse(const Duration(seconds: 3));
        expect(toastsOf(controller).single.remaining, isNotNull);

        controller.update(id, isLoading: true, title: 'Retrying');
        expect(toastsOf(controller).single.remaining, isNull);
        expect(async.periodicTimerCount, 0, reason: 'the tick stops with it');

        async.elapse(const Duration(seconds: 60));
        expect(notifications, 1, reason: 'the update, and nothing since');
        controller.dismissAll();
        controller.dispose();
      });
    });

    test('leaving isLoading counts down the toast’s own duration, not what '
        'was left of it', () {
      fakeAsync((async) {
        final controller = SonnerController();
        final id = controller.show('Saved', duration: const Duration(hours: 1));
        async.elapse(const Duration(minutes: 59));
        controller.update(id, isLoading: true);
        controller.update(id, isLoading: false);

        expect(
          toastsOf(controller).single.remaining,
          const Duration(hours: 1),
          reason: 'a restart, from the duration it was shown with',
        );
        controller.dismissAll();
        controller.dispose();
      });
    });

    test('a loading toast can stop and start again at the same id', () {
      fakeAsync((async) {
        final controller = SonnerController();
        final id = controller.show('Step 1', isLoading: true);
        controller.update(id, isLoading: false, title: 'Step 1 done');
        expect(toastsOf(controller).single.remaining, isNotNull);

        controller.update(id, isLoading: true, title: 'Step 2');
        expect(toastsOf(controller).single.remaining, isNull);
        async.elapse(const Duration(seconds: 60));
        expect(toastsOf(controller), hasLength(1), reason: 'still waiting');

        controller.dismissAll();
        controller.dispose();
      });
    });

    test(
      'a duration on a loading toast asserts, since it would be ignored',
      () {
        final controller = SonnerController();
        addTearDown(controller.dispose);
        expect(
          () => controller.show(
            'Uploading',
            isLoading: true,
            duration: const Duration(seconds: 4),
          ),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test('a loading toast with Duration.zero keeps no timer either way', () {
      fakeAsync((async) {
        final controller = SonnerController(
          config: const SonnerConfig(duration: Duration.zero),
        );
        final id = controller.show('Uploading', isLoading: true);
        expect(toastsOf(controller).single.remaining, isNull);

        controller.update(id, isLoading: false);
        expect(
          toastsOf(controller).single.remaining,
          isNull,
          reason: 'Duration.zero means it waits to be dismissed',
        );
        async.elapse(const Duration(seconds: 60));
        expect(toastsOf(controller), hasLength(1));
        controller.dispose();
      });
    });
  });

  group('promise', () {
    ToastState stateOf(SonnerController controller) =>
        toastsOf(controller).single.state;

    List<String> titles(SonnerController controller) => [
      for (final record in toastsOf(controller)) record.state.title,
    ];

    SonnerController pinned() {
      final controller = SonnerController(
        config: const SonnerConfig(duration: Duration.zero),
      );
      addTearDown(controller.dispose);
      return controller;
    }

    test('success replaces the loading toast and returns the future’s own '
        'value', () async {
      final controller = pinned();
      final work = Completer<int>();

      final result = controller.promise(
        work.future,
        loading: const ToastContent('Uploading…'),
        success: (value) => ToastContent('Uploaded $value files'),
        error: (e) => ToastContent('Failed: $e'),
      );

      expect(stateOf(controller).title, 'Uploading…');
      expect(stateOf(controller).isLoading, isTrue);
      expect(toastsOf(controller).single.remaining, isNull, reason: 'no timer');

      work.complete(3);
      expect(await result, 3);

      expect(toastsOf(controller), hasLength(1), reason: 'the same toast');
      expect(stateOf(controller).title, 'Uploaded 3 files');
      expect(stateOf(controller).isLoading, isFalse);
    });

    test('failure replaces it too, and rethrows the future’s own error with '
        'its stack', () async {
      final controller = pinned();
      final work = Completer<int>();
      final thrown = StateError('no connection');

      final result = controller.promise(
        work.future,
        loading: const ToastContent('Uploading…'),
        success: (value) => ToastContent('Uploaded $value'),
        error: (e) => ToastContent('Failed', description: '$e'),
      );

      work.completeError(thrown, StackTrace.fromString('the original trace'));
      final caught = await result.then<Object?>(
        (_) => null,
        onError: (Object e, StackTrace s) => [e, '$s'],
      );
      expect((caught! as List)[0], same(thrown), reason: 'the future’s own');
      expect((caught as List)[1], 'the original trace', reason: 'its stack');

      expect(toastsOf(controller), hasLength(1));
      expect(stateOf(controller).title, 'Failed');
      expect(stateOf(controller).description, 'Bad state: no connection');
    });

    test('promise(id:) takes over a toast already on screen, keeping its '
        'place', () async {
      final controller = pinned();
      final id = controller.show('Checking credentials…', isLoading: true);
      controller.update(id, title: 'Opening the session…');
      controller.show('Newer');
      final record = toastsOf(controller)[1];

      final work = Completer<void>();
      final result = controller.promise(
        work.future,
        id: id,
        loading: const ToastContent('Connecting…'),
        success: (_) => const ToastContent('Connected'),
        error: (e) => ToastContent('Failed: $e'),
      );

      expect(toastsOf(controller), hasLength(2), reason: 'no second toast');
      expect(toastsOf(controller)[1], same(record), reason: 'its place kept');
      expect(record.state.title, 'Connecting…');

      work.complete();
      await result;
      expect(toastsOf(controller)[1], same(record));
      expect(record.state.title, 'Connected');
    });

    test('a dismissed loading toast still gets its result, as a new '
        'toast', () async {
      final controller = pinned();
      const id = ToastId('upload');
      final work = Completer<void>();
      final result = controller.promise(
        work.future,
        id: id,
        loading: const ToastContent('Uploading…'),
        success: (_) => const ToastContent('Uploaded'),
        error: (e) => ToastContent('Failed: $e'),
      );
      final loadingRecord = toastsOf(controller).single;

      controller.dismiss(id);
      expect(toastsOf(controller), isEmpty, reason: 'the user swept it away');

      work.complete();
      await result;

      expect(toastsOf(controller), hasLength(1));
      expect(stateOf(controller).title, 'Uploaded');
      expect(
        toastsOf(controller).single,
        isNot(same(loadingRecord)),
        reason: 'a new toast, not the dismissed one brought back',
      );
    });

    test('two promises at once do not touch each other', () async {
      final controller = pinned();
      final first = Completer<String>();
      final second = Completer<String>();

      final a = controller.promise(
        first.future,
        loading: const ToastContent('First…'),
        success: (v) => ToastContent('First $v'),
        error: (e) => const ToastContent('First failed'),
      );
      final b = controller.promise(
        second.future,
        loading: const ToastContent('Second…'),
        success: (v) => ToastContent('Second $v'),
        error: (e) => const ToastContent('Second failed'),
      );
      expect(toastsOf(controller), hasLength(2));

      second.complete('b');
      expect(await b, 'b');
      expect(
        titles(controller),
        ['Second b', 'First…'],
        reason: 'newest first; the other is untouched and still loading',
      );

      first.complete('a');
      expect(await a, 'a');
      expect(titles(controller), ['Second b', 'First a']);
    });

    test('the result counts down from its own duration', () {
      fakeAsync((async) {
        final controller = SonnerController();
        final work = Completer<void>();
        controller.promise(
          work.future,
          loading: const ToastContent('Uploading…'),
          success: (_) =>
              const ToastContent('Uploaded', duration: Duration(seconds: 10)),
          error: (e) => ToastContent('Failed: $e'),
        );
        async.elapse(const Duration(seconds: 30));
        expect(toastsOf(controller), hasLength(1), reason: 'still loading');

        work.complete();
        async.flushMicrotasks();
        expect(
          toastsOf(controller).single.remaining,
          const Duration(seconds: 10),
        );

        async.elapse(const Duration(seconds: 11));
        expect(toastsOf(controller), isEmpty);
        controller.dispose();
      });
    });

    test('a duration on the loading content asserts, since it is ignored', () {
      final controller = SonnerController();
      addTearDown(controller.dispose);
      expect(
        () => controller.promise(
          Future<void>.value(),
          loading: const ToastContent('Up', duration: Duration(seconds: 4)),
          success: (_) => const ToastContent('Done'),
          error: (e) => ToastContent('Failed: $e'),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a success callback that throws is reported, and the value still '
        'reaches the caller', () async {
      final controller = pinned();
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      final value = await controller.promise(
        Future<int>.value(7),
        loading: const ToastContent('Uploading…'),
        success: (_) => throw StateError('a bug in the caller'),
        error: (e) => ToastContent('Failed: $e'),
      );

      expect(value, 7, reason: 'the caller’s work is not the toast’s to lose');
      expect(reported, hasLength(1));
      expect(reported.single.library, 'just_sonner');
      expect(reported.single.exception, isStateError);
    });
  });

  group('slots, close button and dismissible', () {
    SonnerController pinned([SonnerConfig? config]) {
      final controller = SonnerController(
        config: config ?? const SonnerConfig(duration: Duration.zero),
      );
      addTearDown(controller.dispose);
      return controller;
    }

    Widget noop(BuildContext context, ToastView toast) => const SizedBox();

    test('unset dismissible follows isLoading, read by read', () {
      final controller = pinned();
      final id = controller.show('Uploading', isLoading: true);
      final record = toastsOf(controller).single;
      expect(record.state.dismissible, isNull, reason: 'stored as unset');
      expect(record.state.dismissibleNow, isFalse);

      controller.update(id, isLoading: false);

      expect(record.state.dismissible, isNull, reason: 'still unset');
      expect(
        record.state.dismissibleNow,
        isTrue,
        reason: 'it hands itself back with no second call',
      );
    });

    test('dismissible given wins over isLoading, both ways', () {
      final controller = pinned();
      controller.show('Closeable', isLoading: true, dismissible: true);
      controller.show('Pinned', dismissible: false);

      // Newest first.
      expect(toastsOf(controller)[1].state.dismissibleNow, isTrue);
      expect(toastsOf(controller)[0].state.dismissibleNow, isFalse);
    });

    test('closeButton resolves show over config, and false by default', () {
      bool drawn(SonnerController c, int at) =>
          toastsOf(c)[at].state.closeButtonNow(c.config.closeButton);

      final off = pinned();
      off.show('Plain');
      off.show('Asked', closeButton: true);
      expect(drawn(off, 1), isFalse, reason: 'the config says no');
      expect(drawn(off, 0), isTrue, reason: 'the toast overrules it');

      final on = pinned(
        const SonnerConfig(duration: Duration.zero, closeButton: true),
      );
      on.show('Follows');
      on.show('Declines', closeButton: false);
      expect(drawn(on, 1), isTrue, reason: 'the config says yes');
      expect(drawn(on, 0), isFalse, reason: 'the toast overrules it');
    });

    test('a toast the user may not dismiss has no close button', () {
      final controller = pinned(
        const SonnerConfig(duration: Duration.zero, closeButton: true),
      );
      controller.show('Uploading', isLoading: true);
      expect(
        toastsOf(controller).single.state.closeButtonNow(true),
        isFalse,
        reason: 'the close button is a way a user dismisses, and it may not',
      );
    });

    test('update patches the slots, and a replace clears them', () {
      final controller = pinned(
        const SonnerConfig(duration: Duration.zero, closeButton: true),
      );
      const id = ToastId('connection');
      controller.show(
        'Checking',
        action: noop,
        closeButton: false,
        dismissible: false,
        id: id,
      );
      final record = toastsOf(controller).single;

      controller.update(id, title: 'Opening');
      expect(record.state.action, same(noop), reason: 'not passed, not lost');
      expect(record.state.closeButton, isFalse);
      expect(record.state.dismissible, isFalse);

      controller.show('Connected', id: id);
      expect(record.state.action, isNull);
      expect(
        record.state.closeButton,
        isNull,
        reason: 'back to following the config',
      );
      expect(record.state.closeButtonNow(true), isTrue);
      expect(record.state.dismissible, isNull);
    });

    test(
      'an update of dismissible alone restarts the countdown, never short',
      () {
        fakeAsync((async) {
          final controller = SonnerController();
          final id = controller.show('Checking');
          async.elapse(const Duration(milliseconds: 3050));
          var notifications = 0;
          controller.addListener(() => notifications++);

          controller.update(id, dismissible: false);
          expect(notifications, 1);
          notifications = 0;

          async.elapse(const Duration(milliseconds: 4000));
          expect(notifications, 0, reason: 'a full 4 s has not passed');
          async.elapse(const Duration(milliseconds: 100));
          expect(notifications, 1, reason: 'gone within one tick of 4 s');
          controller.dispose();
        });
      },
    );

    test('a promise state carries the slots its content gives', () async {
      final controller = pinned();
      await controller.promise(
        Future<void>.value(),
        loading: const ToastContent('Connecting'),
        success: (_) => ToastContent('Connected', action: noop),
        error: (e) => ToastContent('Failed: $e'),
      );
      expect(toastsOf(controller).single.state.action, same(noop));
    });

    test('update changes the builder and keeps it when not passed, a replace '
        'clears it, and a promise state carries its own', () async {
      Widget first(BuildContext context, ToastView toast) => const Text('1');
      Widget second(BuildContext context, ToastView toast) => const Text('2');
      final controller = pinned();
      const id = ToastId('connection');
      controller.show('Checking', builder: first, id: id);
      final record = toastsOf(controller).single;
      expect(record.state.builder, same(first));

      controller.update(id, title: 'Opening');
      expect(record.state.builder, same(first), reason: 'not passed, not lost');
      controller.update(id, builder: second);
      expect(record.state.builder, same(second));

      controller.show('Connected', id: id);
      expect(record.state.builder, isNull, reason: 'a replace clears it');

      await controller.promise(
        Future<void>.value(),
        loading: ToastContent('Connecting', builder: first),
        success: (_) => ToastContent('Connected', builder: second),
        error: (e) => ToastContent('Failed: $e'),
        id: id,
      );
      expect(record.state.builder, same(second));
    });
  });

  group('update and replace', () {
    List<String> titles(SonnerController controller) => [
      for (final record in toastsOf(controller)) record.state.title,
    ];

    test('update changes only the fields passed, in place', () {
      final controller = SonnerController(
        config: const SonnerConfig(duration: Duration.zero),
      );
      addTearDown(controller.dispose);
      final id = controller.show('Checking', description: 'credentials');
      controller.show('Newer');
      final record = toastsOf(controller)[1];
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.update(id, title: 'Opening'), isTrue);

      expect(notifications, 1);
      expect(titles(controller), ['Newer', 'Opening']);
      expect(
        toastsOf(controller)[1],
        same(record),
        reason: 'the same toast, so the host keeps its slot',
      );
      expect(record.state.description, 'credentials');

      controller.update(id, description: 'the session');
      expect(record.state.title, 'Opening');
      expect(record.state.description, 'the session');
    });

    test('update returns false for an id that is not on screen', () {
      final controller = SonnerController(
        config: const SonnerConfig(duration: Duration.zero),
      );
      addTearDown(controller.dispose);
      final id = controller.show('Saved');
      controller.dismiss(id);
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.update(id, title: 'Too late'), isFalse);
      expect(controller.update(const ToastId('never'), title: 'No'), isFalse);
      expect(notifications, 0);
      expect(toastsOf(controller), isEmpty);
    });

    test('show at an id on screen replaces it whole, in place', () {
      final controller = SonnerController(
        config: const SonnerConfig(duration: Duration.zero),
      );
      addTearDown(controller.dispose);
      final id = controller.show('Checking', description: 'credentials');
      controller.show('Newer');
      final record = toastsOf(controller)[1];
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.show('Connected', id: id), id);

      expect(notifications, 1);
      expect(titles(controller), ['Newer', 'Connected']);
      expect(toastsOf(controller)[1], same(record));
      expect(
        record.state.description,
        isNull,
        reason: 'a replace clears what it does not give',
      );
    });

    test('a replace clears leading and isLoading too', () {
      final controller = SonnerController(
        config: const SonnerConfig(duration: Duration.zero),
      );
      addTearDown(controller.dispose);
      const id = ToastId('connection');
      controller.show(
        'Checking',
        isLoading: true,
        leading: const SizedBox.shrink(),
      );
      controller.show('Loading', isLoading: true, id: id);
      final record = toastsOf(controller)[0];
      expect(record.state.isLoading, isTrue);

      controller.show('Connected', id: id);

      expect(record.state.isLoading, isFalse);
      expect(record.state.leading, isNull);
    });

    test(
      'show at a dismissed id makes a new toast with nothing of the old',
      () {
        final controller = SonnerController(
          config: const SonnerConfig(duration: Duration.zero),
        );
        addTearDown(controller.dispose);
        const id = ToastId('connection');
        controller.show('Checking', description: 'credentials', id: id);
        final old = toastsOf(controller).single;
        controller.show('Newer');
        controller.dismiss(id);

        expect(controller.show('Connected', id: id), id);

        final record = toastsOf(controller).first;
        expect(titles(controller), ['Connected', 'Newer']);
        expect(record, isNot(same(old)));
        expect(record.id, id);
        expect(record.state.description, isNull);
      },
    );

    test('show with a caller id not on screen makes a toast with that id', () {
      final controller = SonnerController(
        config: const SonnerConfig(duration: Duration.zero),
      );
      addTearDown(controller.dispose);

      expect(controller.show('Saved', id: const ToastId('a')), ToastId('a'));
      expect(controller.update(const ToastId('a'), title: 'Stored'), isTrue);
      expect(titles(controller), ['Stored']);
    });

    // Each case lands 50 ms into a tick, so a restart that does not skip the
    // partial tick runs a tick short and fails the first expectation.
    for (final (name, change)
        in <(String, void Function(SonnerController, ToastId))>[
          ('an update of the title', (c, id) => c.update(id, title: 'Opening')),
          ('an update that passes nothing', (c, id) => c.update(id)),
          (
            'an update of the duration alone, which is not on screen',
            (c, id) => c.update(id, duration: const Duration(seconds: 4)),
          ),
          ('a replace', (c, id) => c.show('Connected', id: id)),
        ]) {
      test('$name restarts the countdown, never short', () {
        fakeAsync((async) {
          final controller = SonnerController();
          final id = controller.show('Checking');
          async.elapse(const Duration(milliseconds: 3050));
          var notifications = 0;
          controller.addListener(() => notifications++);

          change(controller, id);
          expect(notifications, 1);
          notifications = 0;

          async.elapse(const Duration(milliseconds: 4000));
          expect(notifications, 0, reason: 'a full 4 s has not passed');
          async.elapse(const Duration(milliseconds: 100));
          expect(notifications, 1, reason: 'gone within one tick of 4 s');
          expect(toastsOf(controller), isEmpty);
          controller.dispose();
        });
      });
    }

    test('an update restarts from the toast own duration, not the config', () {
      fakeAsync((async) {
        final controller = SonnerController();
        final id = controller.show(
          'Quick',
          duration: const Duration(seconds: 2),
        );
        async.elapse(const Duration(milliseconds: 1500));

        controller.update(id, title: 'Still quick');
        async.elapse(const Duration(milliseconds: 1900));
        expect(titles(controller), ['Still quick'], reason: 'restarted');

        async.elapse(const Duration(milliseconds: 200));
        expect(toastsOf(controller), isEmpty, reason: 'kept its 2 s');
        controller.dispose();
      });
    });

    test('an update with a duration restarts from that duration', () {
      fakeAsync((async) {
        final controller = SonnerController();
        final id = controller.show(
          'Quick',
          duration: const Duration(seconds: 2),
        );

        controller.update(id, duration: const Duration(seconds: 10));
        async.elapse(const Duration(milliseconds: 9900));
        expect(titles(controller), ['Quick']);

        controller.update(id, title: 'Long');
        async.elapse(const Duration(milliseconds: 9900));
        expect(titles(controller), [
          'Long',
        ], reason: 'a later update keeps the 10 s it was given');
        async.elapse(const Duration(milliseconds: 200));
        expect(toastsOf(controller), isEmpty);
        controller.dispose();
      });
    });

    test('a replace resets the duration to config.duration', () {
      fakeAsync((async) {
        final controller = SonnerController();
        final id = controller.show(
          'Quick',
          duration: const Duration(seconds: 2),
        );

        controller.show('Replaced', id: id);
        async.elapse(const Duration(milliseconds: 3900));
        expect(titles(controller), ['Replaced'], reason: 'not the old 2 s');

        async.elapse(const Duration(milliseconds: 200));
        expect(toastsOf(controller), isEmpty);
        controller.dispose();
      });
    });

    test(
      'an update to Duration.zero stops the countdown, and back starts it',
      () {
        fakeAsync((async) {
          final controller = SonnerController();
          final id = controller.show('Saved');

          controller.update(id, duration: Duration.zero);
          expect(async.periodicTimerCount, 0, reason: 'nothing left to count');
          async.elapse(const Duration(minutes: 1));
          expect(titles(controller), ['Saved']);

          controller.update(id, duration: const Duration(seconds: 1));
          expect(async.periodicTimerCount, 1);
          async.elapse(const Duration(milliseconds: 1100));
          expect(toastsOf(controller), isEmpty);
          expect(async.periodicTimerCount, 0);
          controller.dispose();
        });
      },
    );

    test('a replace without a duration on a pinned toast starts counting', () {
      fakeAsync((async) {
        final controller = SonnerController();
        final id = controller.show('Pinned', duration: Duration.zero);
        expect(async.periodicTimerCount, 0);

        controller.show('Done', id: id);
        expect(async.periodicTimerCount, 1);
        async.elapse(const Duration(seconds: 4));
        expect(toastsOf(controller), isEmpty);
        controller.dispose();
      });
    });

    test('an update in a new zone does not stall on a finished tick', () {
      final controller = SonnerController();
      late ToastId id;
      fakeAsync((async) {
        id = controller.show('Left behind by an earlier test');
      });

      fakeAsync((async) {
        controller.update(id, title: 'Updated by a later test');
        async.elapse(const Duration(milliseconds: 4100));
        expect(toastsOf(controller), isEmpty);
      });
      controller.dispose();
    });

    test('a negative duration on update is refused', () {
      final controller = SonnerController();
      addTearDown(controller.dispose);
      final id = controller.show('Saved', duration: Duration.zero);

      expect(
        () => controller.update(id, duration: const Duration(seconds: -1)),
        throwsAssertionError,
      );
    });
  });

  late SonnerController controller;
  late int notifications;

  setUp(() {
    controller = SonnerController();
    notifications = 0;
    controller.addListener(() => notifications++);
  });

  tearDown(() => controller.dispose());

  test('show returns a distinct id each time and notifies', () {
    final first = controller.show('First');
    final second = controller.show('Second');

    expect(first, isNot(second));
    expect(notifications, 2);
  });

  test('dismiss removes the toast, so dismissing it again changes nothing', () {
    final id = controller.show('Saved');
    notifications = 0;

    controller.dismiss(id);
    expect(notifications, 1);

    controller.dismiss(id);
    expect(notifications, 1);
  });

  test('dismiss on an id that was never shown is a no-op', () {
    controller.show('Saved');
    notifications = 0;

    controller.dismiss(const ToastId('never shown'));

    expect(notifications, 0);
  });

  test('dismissAll removes every toast', () {
    final first = controller.show('First');
    final second = controller.show('Second');
    notifications = 0;

    controller.dismissAll();
    expect(notifications, 1);

    controller.dismiss(first);
    controller.dismiss(second);
    controller.dismissAll();
    expect(notifications, 1);
  });

  group('config', () {
    test('assigning a config notifies, and a lowered visibleToasts keeps the '
        'hidden toasts in the list', () {
      final controller = SonnerController(
        config: const SonnerConfig(duration: Duration.zero),
      );
      for (final title in ['First', 'Second', 'Third']) {
        controller.show(title);
      }
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.config = controller.config.copyWith(visibleToasts: 1);

      expect(notifications, 1);
      expect(controller.config.visibleToasts, 1);
      expect(
        [for (final record in toastsOf(controller)) record.state.title],
        ['Third', 'Second', 'First'],
        reason: 'lowering the window dismisses nothing',
      );
      controller.dispose();
    });

    test('copyWith keeps swipeDirections unless given one, and can put it '
        'back to following the position', () {
      const up = {SwipeDirection.up};
      const set = SonnerConfig(swipeDirections: up);

      expect(set.copyWith(gap: 20).swipeDirections, up, reason: 'kept');
      expect(
        const SonnerConfig()
            .copyWith(swipeDirections: () => up)
            .swipeDirections,
        up,
      );
      final unset = set.copyWith(swipeDirections: () => null);
      expect(unset.swipeDirections, isNull);
      expect(
        unset.copyWith(position: SonnerPosition.topLeft).swipeDirectionsNow,
        {SwipeDirection.up, SwipeDirection.left},
        reason: 'following the position again',
      );
    });

    test('copyWith keeps builder unless given one, can put it back to the '
        'default look, and a config with another builder is not equal', () {
      Widget look(BuildContext context, ToastView toast) => const Text('look');
      final set = SonnerConfig(builder: look);

      expect(set.copyWith(gap: 20).builder, same(look), reason: 'kept');
      expect(set.copyWith(), set, reason: 'the same builder is equal');
      expect(const SonnerConfig().copyWith(builder: () => look).builder, look);
      expect(set.copyWith(builder: () => null).builder, isNull);
      expect(set == const SonnerConfig(), isFalse);
    });

    test('a config draws the time left by default, as a border sweeping '
        'clockwise from the top start, 2 px in the primary colour, over the '
        'card’s own border', () {
      const left = ToastTimeLeft();
      expect(const SonnerConfig().timeLeft, left);
      expect(left.look, TimeLeftLook.border);
      expect(left.start, TimeLeftStart.topStart);
      expect(left.clockwise, isTrue);
      expect(left.strokeWidth, 2);
      expect(left.color, isNull, reason: 'the theme’s primary');
      expect(left.keepBorder, isTrue);
      expect(left.easeRestart, isTrue);
      expect(left.fadeWhenCovered, isTrue);
    });

    test('ToastTimeLeft copyWith keeps what it is not given, can put the '
        'colour back to the theme’s, and compares by value', () {
      const red = Color(0xFFFF0000);
      final changed = const ToastTimeLeft().copyWith(
        look: TimeLeftLook.bottomBar,
        start: TimeLeftStart.bottomEnd,
        clockwise: false,
        strokeWidth: 3,
        color: () => red,
        keepBorder: false,
        easeRestart: false,
        fadeWhenCovered: false,
      );
      expect(
        changed,
        const ToastTimeLeft(
          look: TimeLeftLook.bottomBar,
          start: TimeLeftStart.bottomEnd,
          clockwise: false,
          strokeWidth: 3,
          color: red,
          keepBorder: false,
          easeRestart: false,
          fadeWhenCovered: false,
        ),
      );
      expect(changed.hashCode, isNot(const ToastTimeLeft().hashCode));
      expect(changed.copyWith(strokeWidth: 1).color, red, reason: 'kept');
      expect(changed.copyWith(color: () => null).color, isNull);
      expect(changed == const ToastTimeLeft(), isFalse);
      for (final one in [
        const ToastTimeLeft(look: TimeLeftLook.cornerRing),
        const ToastTimeLeft(start: TimeLeftStart.centerEnd),
        const ToastTimeLeft(clockwise: false),
        const ToastTimeLeft(strokeWidth: 1),
        const ToastTimeLeft(color: red),
        const ToastTimeLeft(keepBorder: false),
        const ToastTimeLeft(easeRestart: false),
        const ToastTimeLeft(fadeWhenCovered: false),
      ]) {
        expect(one == const ToastTimeLeft(), isFalse, reason: '$one');
      }
    });

    test('copyWith keeps timeLeft unless given one, and can take it away; a '
        'config with another is not equal', () {
      const bar = ToastTimeLeft(look: TimeLeftLook.topBar);
      const set = SonnerConfig(timeLeft: bar);

      expect(set.copyWith(gap: 20).timeLeft, bar, reason: 'kept');
      expect(set.copyWith(timeLeft: () => null).timeLeft, isNull);
      expect(set == const SonnerConfig(), isFalse);
      expect(set.hashCode, isNot(const SonnerConfig().hashCode));
      expect(
        const SonnerConfig(timeLeft: ToastTimeLeft(strokeWidth: 3)),
        const SonnerConfig().copyWith(
          timeLeft: () => const ToastTimeLeft(strokeWidth: 3),
        ),
      );
    });

    test('an equal config does not notify', () {
      final controller = SonnerController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.config = const SonnerConfig();
      controller.config = controller.config.copyWith();

      expect(notifications, 0);
      controller.dispose();
    });

    test('an assigned config is refused where a constructed one would be', () {
      final controller = SonnerController();
      for (final config in [
        const SonnerConfig(duration: Duration(seconds: -1)),
        const SonnerConfig(visibleToasts: 0),
        const SonnerConfig(visibleToasts: 21),
      ]) {
        expect(
          () => controller.config = config,
          throwsAssertionError,
          reason: '$config',
        );
      }
      expect(controller.config, const SonnerConfig(), reason: 'kept');
      controller.dispose();
    });

    test('a new duration leaves the countdowns under way alone', () {
      fakeAsync((async) {
        final controller = SonnerController();
        var notifications = 0;
        controller.show('Four seconds');
        controller.addListener(() => notifications++);

        controller.config = controller.config.copyWith(
          duration: const Duration(seconds: 1),
        );
        notifications = 0;

        async.elapse(const Duration(seconds: 2));
        expect(notifications, 0, reason: 'it started with 4 s, not 1 s');
        async.elapse(const Duration(milliseconds: 2100));
        expect(notifications, 1);

        controller.show('One second');
        async.elapse(const Duration(milliseconds: 1100));
        expect(
          toastsOf(controller),
          isEmpty,
          reason: 'the next toast gets 1 s',
        );
        controller.dispose();
      });
    });
  });
}
