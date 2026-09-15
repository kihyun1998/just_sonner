import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'config.dart';

/// Lays out toasts newest first as a collapsed deck: each one `gap × depth`
/// from the screen edge [config] names, the front at its own height and the
/// ones behind it at the front's.
///
/// Children are identified by the layout ids in [order]. [depth] is how many
/// toasts sit in front of one, counting each by its [presence] (0 to 1), so a
/// toast moves back as another enters and forward as one leaves.
///
/// A toast covers the ones behind it in proportion to its presence, and the
/// height they are drawn at blends toward the height it covers with,
/// [covering], by that much; with no [covering], a toast covers with its own
/// height. Where a toast is only partly covered it is drawn between its own
/// height, as [natural] last measured it, and theirs.
///
/// The height each toast is drawn at and the height it covers with are
/// reported through [onPlaced]. A toast for which [pinned] returns heights is
/// drawn at and covers with those instead, and is not reported.
///
/// It lays out again whenever it is rebuilt, since what moves the toasts is
/// read from [depth] and [presence] rather than held by the delegate.
class ToastDeckDelegate<T extends Object> extends MultiChildLayoutDelegate {
  ToastDeckDelegate({
    required this.config,
    required this.order,
    required this.presence,
    required this.depth,
    required this.natural,
    required this.covering,
    required this.pinned,
    required this.onPlaced,
  });

  final SonnerConfig config;
  final List<T> order;
  final double Function(T id) presence;
  final double Function(T id) depth;
  final double? Function(T id) natural;
  final double? Function(T id) covering;
  final ({double height, double covering})? Function(T id) pinned;
  final void Function(T id, double height, double covering) onPlaced;

  @override
  void performLayout(Size size) {
    final left = switch (config.position) {
      SonnerPosition.topLeft || SonnerPosition.bottomLeft => config.offset,
      SonnerPosition.topCenter ||
      SonnerPosition.bottomCenter => (size.width - config.width) / 2,
      SonnerPosition.topRight ||
      SonnerPosition.bottomRight => size.width - config.offset - config.width,
    };

    // How much of the next toast is covered, and the covering toasts' heights
    // weighted by how much each covers.
    var covered = 0.0;
    var coveringHeight = 0.0;
    for (final id in order) {
      final pinnedHeights = pinned(id);
      final double own;
      final Size child;
      if (pinnedHeights != null) {
        own = pinnedHeights.height;
        child = layoutChild(
          id,
          BoxConstraints.tightFor(width: config.width, height: own),
        );
      } else if (covered == 0) {
        child = layoutChild(id, BoxConstraints.tightFor(width: config.width));
        own = child.height;
      } else {
        own = natural(id) ?? coveringHeight / covered;
        child = layoutChild(
          id,
          BoxConstraints.tightFor(
            width: config.width,
            height: (1 - covered) * own + coveringHeight,
          ),
        );
      }
      final covers = pinnedHeights?.covering ?? covering(id) ?? own;
      if (pinnedHeights == null) onPlaced(id, child.height, covers);

      final fromEdge = config.offset + config.gap * depth(id);
      final top = config.position.isTop
          ? fromEdge
          : size.height - fromEdge - child.height;
      positionChild(id, Offset(left, top));

      final weight = (1 - covered) * presence(id);
      coveringHeight += weight * covers;
      covered += weight;
    }
  }

  @override
  bool shouldRelayout(ToastDeckDelegate<T> oldDelegate) => true;
}

/// Draws [child] at the height its parent allows, stretching it when it would
/// be shorter and clipping it when it would be taller, and reports through
/// [onMeasured] the height it takes on its own.
class ToastHeight extends SingleChildRenderObjectWidget {
  const ToastHeight({super.key, required this.onMeasured, super.child});

  final ValueChanged<double> onMeasured;

  @override
  RenderToastHeight createRenderObject(BuildContext context) =>
      RenderToastHeight(onMeasured);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderToastHeight renderObject,
  ) => renderObject.onMeasured = onMeasured;
}

class RenderToastHeight extends RenderProxyBox {
  RenderToastHeight(this.onMeasured);

  ValueChanged<double> onMeasured;

  final _clip = LayerHandle<ClipRectLayer>();

  static BoxConstraints _unbounded(BoxConstraints constraints) =>
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final natural = child?.getDryLayout(_unbounded(constraints)) ?? Size.zero;
    return constraints.constrain(natural);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_unbounded(constraints), parentUsesSize: true);
    final natural = child.size.height;
    onMeasured(natural);
    final height = constraints.constrainHeight(natural);
    if (height > natural) {
      child.layout(
        constraints.copyWith(minHeight: height, maxHeight: height),
        parentUsesSize: true,
      );
    }
    size = constraints.constrain(Size(child.size.width, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || child.size.height <= size.height) {
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
