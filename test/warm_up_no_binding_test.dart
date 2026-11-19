import 'package:flutter_test/flutter_test.dart';
import 'package:just_sonner/just_sonner.dart';
import 'package:just_sonner/src/controller.dart' show warmUpOf;

/// No `testWidgets` here: declaring one sets up the binding this file needs
/// to be without.
void main() {
  test('warmUp before the binding exists throws and leaves no run behind', () {
    final controller = SonnerController();

    expect(controller.warmUp, throwsA(anything));
    expect(warmUpOf(controller).value, isNull);
  });
}
