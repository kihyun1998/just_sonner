import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'config.dart';

/// Lays out toasts newest first as a deck, between collapsed and expanded by
/// [expansion] (0 to 1).
///
/// Collapsed, each toast is `gap × depth` from the screen edge [config] names,
/// the front at its own height and the ones behind it at the front's.
/// Expanded, each is drawn at its own height and lifted further from the edge
/// by [lift], the heights of the toasts in front of it.
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
/// The height each toast is drawn at, the height it covers with and its
/// distance from the edge, on screen and before scrolling, are reported
/// through [onPlaced]. A toast for which [pinned] returns heights is drawn at
/// and covers with those instead, at the distance it gives if any, reaching as
/// far into the scroll as the place it gives, and is not reported.
///
/// The box around the toasts [inDeck] names, and the gaps between them, cut to
/// the layer, is reported through [onDeck]; while they do not fit and the deck
/// [follows] the pointer, it runs the layer's whole length. A child with the id [backdrop], if any, is laid out
/// over that box.
///
/// With a [scroll], the toasts [inDeck] names scroll between the edge and
/// `offset` from the far side, an exiting toast shrinking out of that reach by
/// its presence, and every toast not pinned to a distance is drawn that much,
/// plus [unscrolled], closer to the edge. With an [anchor], the scroll first
/// moves by as much as the anchored toast has moved from the distance it
/// gives, so the toasts in view stay where they are. The anchor is kept while
/// it is laid out anew and nothing else has moved the scroll since; otherwise
/// the first fully present toast reaching into view takes its place. Either is
/// reported through [onAnchor] with the scroll it was taken at.
///
/// While [glide] is short of 1, a toast [glideFrom] gives a box for is drawn
/// that much of the way from that box to the place the config gives it,
/// holding the edges the config's position names, so a toast narrowed at the
/// right keeps its right edge. A toast [screenPinned] gives a box for is drawn
/// in that box, and counts toward neither the deck's box nor the scroll's
/// reach. Where each toast is drawn is reported through [onDrawn].
///
/// It lays out again whenever it is rebuilt, since what moves the toasts is
/// read from [depth], [lift] and [presence] rather than held by the delegate,
/// and whenever [scroll] changes.
class ToastDeckDelegate<T extends Object> extends MultiChildLayoutDelegate {
  ToastDeckDelegate({
    required this.config,
    required this.order,
    required this.expansion,
    required this.presence,
    required this.depth,
    required this.lift,
    required this.natural,
    required this.covering,
    required this.pinned,
    required this.inDeck,
    required this.onPlaced,
    required this.onDeck,
    this.glide = 1,
    this.glideFrom,
    this.screenPinned,
    this.onDrawn,
    this.scroll,
    this.follows = false,
    this.unscrolled = 0,
    this.anchor,
    this.onAnchor,
    this.backdrop,
  }) : super(relayout: scroll);

  final SonnerConfig config;
  final List<T> order;
  final double expansion;
  final double Function(T id) presence;
  final double Function(T id) depth;
  final double Function(T id) lift;
  final double? Function(T id) natural;
  final double? Function(T id) covering;
  final ({double height, double covering, double? distance, double? place})?
  Function(T id)
  pinned;
  final bool Function(T id) inDeck;
  final void Function(
    T id,
    double height,
    double covering,
    double distance,
    double place,
  )
  onPlaced;
  final ValueChanged<Rect> onDeck;
  final double glide;
  final Rect? Function(T id)? glideFrom;
  final Rect? Function(T id)? screenPinned;
  final void Function(T id, Rect drawn)? onDrawn;
  final ViewportOffset? scroll;
  final bool follows;
  final double unscrolled;
  final ({T? id, double distance, double pixels})? Function()? anchor;
  final void Function(T? id, double distance, double pixels)? onAnchor;
  final Object? backdrop;

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
    final placed = <_Placed<T>>[];
    for (final id in order) {
      final pinnedHeights = pinned(id);
      final screen = screenPinned?.call(id);
      final double own;
      final Size child;
      if (screen != null) {
        own = screen.height;
        child = layoutChild(
          id,
          BoxConstraints.tightFor(width: screen.width, height: own),
        );
      } else if (pinnedHeights != null) {
        own = pinnedHeights.height;
        child = layoutChild(
          id,
          BoxConstraints.tightFor(width: config.width, height: own),
        );
      } else if (covered == 0 || expansion == 1) {
        child = layoutChild(id, BoxConstraints.tightFor(width: config.width));
        own = child.height;
      } else {
        own = natural(id) ?? coveringHeight / covered;
        final collapsed = (1 - covered) * own + coveringHeight;
        child = layoutChild(
          id,
          BoxConstraints.tightFor(
            width: config.width,
            height: collapsed + (own - collapsed) * expansion,
          ),
        );
      }
      final covers = pinnedHeights?.covering ?? covering(id) ?? own;
      final distance = pinnedHeights?.distance;
      placed.add((
        id: id,
        height: child.height,
        covers: covers,
        fromEdge:
            distance ??
            config.offset + config.gap * depth(id) + lift(id) * expansion,
        pinned: pinnedHeights != null || screen != null,
        pinnedDistance: distance != null,
        place: pinnedHeights?.place,
        screen: screen,
      ));

      final weight = (1 - covered) * presence(id);
      coveringHeight += weight * covers;
      covered += weight;
    }

    final (:pixels, :overflows) = _scroll(size, placed);
    final scrolled = pixels + unscrolled;

    Rect? around;
    for (final toast in placed) {
      final screen = toast.screen;
      if (screen != null) {
        positionChild(toast.id, screen.topLeft);
        onDrawn?.call(toast.id, screen);
        continue;
      }
      final fromEdge = toast.pinnedDistance
          ? toast.fromEdge
          : toast.fromEdge - scrolled;
      if (!toast.pinned) {
        onPlaced(
          toast.id,
          toast.height,
          toast.covers,
          fromEdge,
          toast.fromEdge,
        );
      }

      final top = config.position.isTop
          ? fromEdge
          : size.height - fromEdge - toast.height;
      final drawn = _glided(
        toast.id,
        Rect.fromLTWH(left, top, config.width, toast.height),
      );
      positionChild(toast.id, drawn.topLeft);
      onDrawn?.call(toast.id, drawn);

      if (inDeck(toast.id)) around = around?.expandToInclude(drawn) ?? drawn;
    }

    var deck = Rect.zero;
    if (around != null) {
      // A deck being scrolled moves its own ends across the margins, and must
      // not slide out from under the pointer resting there. With no pointer on
      // it nothing scrolls, and the margins are the app's.
      if (overflows && follows) {
        around = Rect.fromLTRB(around.left, 0, around.right, size.height);
      }
      deck = around.intersect(Offset.zero & size);
      if (deck.isEmpty) deck = Rect.zero;
    }
    onDeck(deck);

    final backdrop = this.backdrop;
    if (backdrop != null && hasChild(backdrop)) {
      layoutChild(backdrop, BoxConstraints.tight(deck.size));
      positionChild(backdrop, deck.topLeft);
    }
  }

  /// [to] as drawn [glide] of the way from the box [glideFrom] gives, holding
  /// the edges the position names.
  Rect _glided(T id, Rect to) {
    final from = glideFrom?.call(id);
    if (from == null || glide >= 1) return to;
    double lerp(double a, double b) => a + (b - a) * glide;
    final left = switch (config.position) {
      SonnerPosition.topLeft ||
      SonnerPosition.bottomLeft => lerp(from.left, to.left),
      SonnerPosition.topCenter || SonnerPosition.bottomCenter =>
        lerp(from.center.dx, to.center.dx) - to.width / 2,
      SonnerPosition.topRight ||
      SonnerPosition.bottomRight => lerp(from.right, to.right) - to.width,
    };
    final top = config.position.isTop
        ? lerp(from.top, to.top)
        : lerp(from.bottom, to.bottom) - to.height;
    return Rect.fromLTWH(left, top, to.width, to.height);
  }

  /// Tells [scroll] how far the toasts in the deck reach, keeps the anchored
  /// toast in place, and returns how far the deck is scrolled and whether it
  /// has anywhere to scroll.
  ({double pixels, bool overflows}) _scroll(
    Size size,
    List<_Placed<T>> placed,
  ) {
    final scroll = this.scroll;
    if (scroll == null) return (pixels: 0, overflows: false);

    final start = scroll.pixels;
    var reach = 0.0;
    for (final toast in placed) {
      if (!inDeck(toast.id) || toast.screen != null) continue;
      if (toast.pinnedDistance) {
        // An exiting toast gives its place and the gap before it back as it
        // goes, so the end of the scroll does not jump when it is removed.
        final near = toast.place ?? toast.fromEdge + start;
        final goes = (toast.height + config.gap) * presence(toast.id);
        reach = math.max(reach, near + goes - config.gap);
      } else if (!toast.pinned) {
        reach = math.max(reach, toast.fromEdge + toast.height);
      }
    }
    final extent = math.max(0.0, reach + config.offset - size.height);

    final anchor = this.anchor?.call();
    _Placed<T>? kept;
    var to = start;
    if (anchor != null) {
      for (final toast in placed) {
        if (toast.pinned || !identical(toast.id, anchor.id)) continue;
        to += toast.fromEdge - anchor.distance;
        if (start == anchor.pixels) kept = toast;
        break;
      }
    }
    // Kept within the reach here, so a reach shrinking under the scroll moves
    // the deck with it rather than springing it back.
    to = to.clamp(0.0, extent);
    if (to != start) scroll.correctBy(to - start);
    scroll.applyViewportDimension(size.height);
    scroll.applyContentDimensions(0, extent);
    final pixels = scroll.pixels;
    final overflows = extent > 0;

    if (anchor == null) {
      onAnchor?.call(null, 0, pixels);
      return (pixels: pixels, overflows: overflows);
    }
    if (kept == null) {
      for (final toast in placed) {
        if (toast.pinned || presence(toast.id) < 1) continue;
        if (toast.fromEdge + toast.height - pixels <= config.offset) continue;
        kept = toast;
        break;
      }
    }
    onAnchor?.call(kept?.id, kept?.fromEdge ?? 0, pixels);
    return (pixels: pixels, overflows: overflows);
  }

  @override
  bool shouldRelayout(ToastDeckDelegate<T> oldDelegate) => true;
}

/// A toast as [ToastDeckDelegate] has laid it out: its `fromEdge` is before
/// scrolling unless it is `pinnedDistance`, and it is `pinned` when its
/// heights were given rather than measured.
typedef _Placed<T> = ({
  T id,
  double height,
  double covers,
  double fromEdge,
  bool pinned,
  bool pinnedDistance,
  double? place,
  Rect? screen,
});

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
