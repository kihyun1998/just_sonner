import 'package:flutter_test/flutter_test.dart';
import 'package:just_sonner/just_sonner.dart';

void main() {
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
