import 'package:flutter/widgets.dart';

import 'config.dart';

/// Lays out toasts newest first: the newest nearest the screen edge [config]
/// names, each older one the height before it plus `gap` further in.
///
/// Children are identified by the layout ids in [order]. Each one's [presence]
/// (0 to 1) scales how much room it takes, so the toasts around an entering or
/// exiting one move to their places with it.
///
/// Distances from the edge are reported through [onPlaced]. A toast for which
/// [pinned] returns a distance is laid out there instead of in the flow, and is
/// not reported.
class ToastStackDelegate<T extends Object> extends MultiChildLayoutDelegate {
  ToastStackDelegate({
    required this.config,
    required this.order,
    required this.presence,
    required this.pinned,
    required this.onPlaced,
    super.relayout,
  });

  final SonnerConfig config;
  final List<T> order;
  final double Function(T id) presence;
  final double? Function(T id) pinned;
  final void Function(T id, double fromEdge) onPlaced;

  @override
  void performLayout(Size size) {
    final left = switch (config.position) {
      SonnerPosition.topLeft || SonnerPosition.bottomLeft => config.offset,
      SonnerPosition.topCenter ||
      SonnerPosition.bottomCenter => (size.width - config.width) / 2,
      SonnerPosition.topRight ||
      SonnerPosition.bottomRight => size.width - config.offset - config.width,
    };

    var flow = config.offset;
    for (final id in order) {
      final child = layoutChild(
        id,
        BoxConstraints.tightFor(width: config.width),
      );
      final fromEdge = pinned(id) ?? flow;
      if (pinned(id) == null) onPlaced(id, fromEdge);
      final top = config.position.isTop
          ? fromEdge
          : size.height - fromEdge - child.height;
      positionChild(id, Offset(left, top));
      flow += (child.height + config.gap) * presence(id);
    }
  }

  @override
  bool shouldRelayout(ToastStackDelegate<T> oldDelegate) =>
      oldDelegate.config != config || !_sameOrder(oldDelegate.order, order);

  static bool _sameOrder(List<Object> a, List<Object> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }
}
