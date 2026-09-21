import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import '../config.dart';

/// The thumb of the deck's [scrollbar], drawn down the middle of the box it is
/// laid out in and faded by [opacity]. A draggable one reports each vertical
/// drag's movement through [onDrag]; one that is not takes no pointer.
class DeckScrollbarThumb extends StatelessWidget {
  const DeckScrollbarThumb({
    super.key,
    required this.scrollbar,
    required this.opacity,
    required this.onDrag,
  });

  final DeckScrollbar scrollbar;
  final Animation<double> opacity;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final color =
        scrollbar.color ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    final thumb = ExcludeSemantics(
      child: FadeTransition(
        opacity: opacity,
        child: Center(
          child: SizedBox(
            width: scrollbar.thickness,
            height: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(scrollbar.thickness / 2),
              ),
            ),
          ),
        ),
      ),
    );
    if (!scrollbar.draggable) return IgnorePointer(child: thumb);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onVerticalDragUpdate: (details) => onDrag(details.delta.dy),
      child: thumb,
    );
  }
}
