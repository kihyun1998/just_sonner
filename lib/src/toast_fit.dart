import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'toast_view.dart';

/// Lays [child] out at its own height and draws it from the top at the height
/// it is given, clipped there.
///
/// A toast behind a shorter front is laid out at the front's height, below its
/// own. A look wraps the content **inside** its card in this, so the card is
/// drawn at that height and the content does not overflow it. With room to
/// spare it takes the content's own height, which is what the deck measures.
/// [toastCardBuilder] does this for a builder given as a card and its content.
class ToastFit extends SingleChildRenderObjectWidget {
  const ToastFit({super.key, super.child});

  @override
  RenderToastFit createRenderObject(BuildContext context) => RenderToastFit();
}

class RenderToastFit extends RenderProxyBox with ClipsOverflow {
  @override
  bool get overflows => child!.size.height > size.height;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => constraints
      .constrain(child?.getDryLayout(ownHeight(constraints)) ?? Size.zero);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(ownHeight(constraints), parentUsesSize: true);
    size = constraints.constrain(child.size);
  }
}

/// A box that lays its child out at the child's own height and paints it
/// clipped to its own size while the child [overflows] it.
mixin ClipsOverflow on RenderProxyBox {
  final _clip = LayerHandle<ClipRectLayer>();

  /// Whether the child, laid out, reaches past this box. Read only while
  /// there is a child.
  bool get overflows;

  /// [constraints] with the height left to the child.
  BoxConstraints ownHeight(BoxConstraints constraints) =>
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || !overflows) {
      _clip.layer = null;
      super.paint(context, offset);
      return;
    }
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      super.paint,
      oldLayer: _clip.layer,
    );
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}

/// A [ToastBuilder] given as a card and the content drawn on it.
///
/// [content] is put inside [card] as its `child`, wrapped in [ToastFit] and
/// faded out by [ToastView.covered], so the card is drawn at whatever height
/// the deck gives the toast and the content leaves it while the deck covers
/// the toast — what the default look does for itself.
ToastBuilder toastCardBuilder({
  required Widget Function(BuildContext context, ToastView toast, Widget child)
  card,
  required ToastBuilder content,
}) =>
    (context, toast) => card(
      context,
      toast,
      ToastFit(
        child: FadeTransition(
          opacity: ReverseAnimation(toast.covered),
          // A covered toast is still a live region: what the deck hides is the
          // reading, not the announcement.
          alwaysIncludeSemantics: true,
          child: content(context, toast),
        ),
      ),
    );
