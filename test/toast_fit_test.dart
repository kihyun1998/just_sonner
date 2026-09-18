import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_sonner/just_sonner.dart';

void main() {
  /// [child] under [constraints], top-left in a 800 × 600 surface.
  Widget under(BoxConstraints constraints, Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(constraints: constraints, child: child),
    ),
  );

  const content = SizedBox(key: ValueKey('content'), width: 100, height: 80);

  RenderBox fitOf(WidgetTester tester) =>
      tester.renderObject<RenderBox>(find.byType(ToastFit));

  testWidgets('with room, it takes its content’s own height', (tester) async {
    await tester.pumpWidget(
      under(
        const BoxConstraints(maxWidth: 100),
        const ToastFit(child: content),
      ),
    );

    expect(fitOf(tester).size, const Size(100, 80));
    expect(fitOf(tester), isNot(paints..clipRect()));
  });

  testWidgets('given less than its content’s height, it takes that height, '
      'draws its content at its own height from the top and clips it', (
    tester,
  ) async {
    await tester.pumpWidget(
      under(
        const BoxConstraints.tightFor(width: 100, height: 30),
        const ToastFit(child: content),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(fitOf(tester).size, const Size(100, 30));
    expect(
      tester.getRect(find.byKey(const ValueKey('content'))),
      const Rect.fromLTWH(0, 0, 100, 80),
    );
    expect(
      fitOf(tester),
      paints..clipRect(rect: const Rect.fromLTWH(0, 0, 100, 30)),
    );
  });

  testWidgets('given more than its content’s height, it takes that height and '
      'draws its content from the top', (tester) async {
    await tester.pumpWidget(
      under(
        const BoxConstraints.tightFor(width: 100, height: 120),
        const ToastFit(child: content),
      ),
    );

    expect(fitOf(tester).size, const Size(100, 120));
    expect(
      tester.getRect(find.byKey(const ValueKey('content'))),
      const Rect.fromLTWH(0, 0, 100, 80),
    );
    expect(fitOf(tester), isNot(paints..clipRect()));
  });

  testWidgets('a content that would overflow a tight height does not', (
    tester,
  ) async {
    await tester.pumpWidget(
      under(
        const BoxConstraints.tightFor(width: 100, height: 30),
        const ToastFit(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [SizedBox(height: 40), SizedBox(height: 40)],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
