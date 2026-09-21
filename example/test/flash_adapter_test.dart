import 'package:flash/flash.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_sonner/just_sonner.dart';
import 'package:just_sonner/src/controller.dart' show toastsOf;
import 'package:just_sonner_example/flash_adapter.dart';

/// A `FlashBar`-based widget through the adapter, with flash as the example's
/// dependency and never the package's.
void main() {
  late SonnerController controller;
  late FlashController<void> flash;
  late ToastView handed;

  setUp(
    () => controller = SonnerController(
      config: const SonnerConfig(duration: null),
    ),
  );
  tearDown(() => controller.dispose());

  ToastBuilder bar({List<FlashDismissDirection>? dismissDirections}) =>
      flashToast((context, controller, toast) {
        flash = controller;
        handed = toast;
        return FlashBar(
          controller: controller,
          dismissDirections: dismissDirections ?? FlashDismissDirection.values,
          content: Text(toast.state.title),
        );
      });

  Future<void> pumpHost(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          SonnerHost(controller: controller, child: child!),
      home: const SizedBox.expand(),
    ),
  );

  testWidgets('a FlashBar enters on the toast\'s own animation, and flash\'s '
      'stays at rest', (tester) async {
    await pumpHost(tester);
    final id = controller.show('Saved', builder: bar());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Saved'), findsOneWidget);
    expect(handed.id, id, reason: 'the builder is handed the toast');
    expect(handed.animation.value, closeTo(0.5, 0.01));
    expect(flash.controller.value, 1, reason: 'flash fades and slides nothing');
    await tester.pumpAndSettle();
  });

  testWidgets('a FlashBar draws in mount mode 1 too', (tester) async {
    final key = GlobalKey<NavigatorState>();
    controller.attach(key);
    await tester.pumpWidget(
      MaterialApp(navigatorKey: key, home: const SizedBox.expand()),
    );
    controller.show('Over the navigator', builder: bar());
    await tester.pumpAndSettle();

    expect(find.text('Over the navigator'), findsOneWidget);
    expect(tester.takeException(), isNull);
    controller.dismissAll();
    await tester.pumpAndSettle();
  });

  testWidgets('flash\'s fling dismisses the toast', (tester) async {
    await pumpHost(tester);
    controller.show('Saved', builder: bar());
    await tester.pumpAndSettle();

    await tester.fling(find.text('Saved'), const Offset(300, 0), 3000);
    await tester.pumpAndSettle();
    expect(toastsOf(controller), isEmpty);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('a toast the user may not dismiss springs back from flash\'s '
      'fling, and its timer holds', (tester) async {
    controller.config = const SonnerConfig(duration: Duration(seconds: 1));
    await pumpHost(tester);
    final id = controller.show('Pinned', dismissible: false, builder: bar());
    await tester.pump();
    // In, with half its second left to count.
    await tester.pump(const Duration(milliseconds: 450));

    await tester.fling(find.text('Pinned'), const Offset(300, 0), 3000);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(toastsOf(controller).map((it) => it.id), [id]);
    expect(flash.controller.value, 1, reason: 'back at rest');
    expect(find.text('Pinned'), findsOneWidget);

    controller.dismiss(id);
    await tester.pumpAndSettle();
  });

  testWidgets('dismissDirections: const [] leaves the swipe to the toast', (
    tester,
  ) async {
    await pumpHost(tester);
    controller.show('Saved', builder: bar(dismissDirections: const []));
    await tester.pumpAndSettle();

    final mouse = await tester.startGesture(
      tester.getCenter(find.text('Saved')),
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 0; i < 10; i++) {
      await mouse.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(flash.controller.value, 1, reason: 'flash took none of it');
    await mouse.up();
    await tester.pumpAndSettle();
    expect(toastsOf(controller), isEmpty, reason: 'the toast\'s swipe did');
  });
}
