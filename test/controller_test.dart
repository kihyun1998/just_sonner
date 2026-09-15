import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_sonner/just_sonner.dart';
import 'package:just_sonner/src/controller.dart' show toastsOf;

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
}
