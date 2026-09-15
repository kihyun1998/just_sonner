import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_sonner/just_sonner.dart';

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
