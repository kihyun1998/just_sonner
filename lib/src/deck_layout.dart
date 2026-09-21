import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'config.dart';
import 'toast_fit.dart' show ClipsOverflow;

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
/// [follows] the pointer, it runs from the edge to [DeckOffsets.farOffset] past
/// the cap, and takes in a draggable [scrollbar]. A child with the id
/// [backdrop], if any, is laid out over that box.
///
/// With a [scroll], the toasts [inDeck] names scroll between the edge and the
/// cap — [DeckOffsets.farOffset] from the far side, or nearer where
/// `config.deckCap` says, and never short of the newest toast's far end — an
/// exiting toast shrinking out of that reach by its presence, and every toast
/// not pinned to a distance is drawn that much, plus [unscrolled], closer to
/// the edge. Where any toast is drawn past a cap nearer than the layer's, or
/// nearer the edge than [DeckOffsets.nearOffset], that end of the cut is
/// reported through [onCut]; with neither end cut, null is.
///
/// While [dismissAllSize] gives a size, the dismiss-all control of that size
/// is placed `gap` past the deck's far end, no further than the cap, on the
/// side the position names; its box is reported through [onDismissAll] and
/// taken into the box around the deck.
///
/// While the deck [follows] the pointer and its toasts scroll, a child with the
/// id [scrollbar] is laid out as the thumb of `config.scrollbar` beside the
/// deck's right edge, over the track from [DeckOffsets.nearOffset] to the cap,
/// and its geometry is reported through [onScrollbar]; otherwise it is laid
/// out empty, off the layer, and null is reported. With an [anchor], the scroll
/// first moves by as much as the anchored toast has moved from the distance it
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
/// A child with the id [empty], if any, is laid out at `config.width` where
/// the front toast would be collapsed, and taken into the box around the
/// deck.
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
    this.empty,
    this.scrollbar,
    this.onCut,
    this.onScrollbar,
    this.dismissAllSize,
    this.onDismissAll,
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
  final Object? empty;
  final Object? scrollbar;
  final ValueChanged<DeckCut?>? onCut;
  final ValueChanged<DeckScrollbarGeometry?>? onScrollbar;
  final Size? Function()? dismissAllSize;
  final ValueChanged<Rect?>? onDismissAll;

  /// The shortest thumb, where the track allows it.
  static const _minThumb = 24.0;

  /// How much wider than the thumb the part that takes the pointer is, on
  /// each side.
  static const _thumbReach = 4.0;

  @override
  void performLayout(Size size) {
    final left = switch (config.position) {
      SonnerPosition.topLeft || SonnerPosition.bottomLeft => config.offset.left,
      SonnerPosition.topCenter ||
      SonnerPosition.bottomCenter => (size.width - config.width) / 2,
      SonnerPosition.topRight || SonnerPosition.bottomRight =>
        size.width - config.offset.right - config.width,
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
            config.nearOffset + config.gap * depth(id) + lift(id) * expansion,
        expandedEnd:
            config.nearOffset +
            config.gap * depth(id) +
            lift(id) +
            (natural(id) ?? own),
        pinned: pinnedHeights != null || screen != null,
        pinnedDistance: distance != null,
        place: pinnedHeights?.place,
        screen: screen,
      ));

      final weight = (1 - covered) * presence(id);
      coveringHeight += weight * covers;
      covered += weight;
    }

    final layerFar = size.height - config.farOffset;
    final far = _far(size, placed, layerFar);
    final (:pixels, :overflows, :extent) = _scroll(size, placed, far);
    final scrolled = pixels + unscrolled;

    Rect? around;
    var drawnReach = 0.0;
    var drawnNear = double.infinity;
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

      drawnReach = math.max(drawnReach, fromEdge + toast.height);
      drawnNear = math.min(drawnNear, fromEdge);
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

    final empty = this.empty;
    if (empty != null && hasChild(empty)) {
      final card = layoutChild(
        empty,
        BoxConstraints.tightFor(width: config.width),
      );
      final top = config.position.isTop
          ? config.nearOffset
          : size.height - config.nearOffset - card.height;
      final drawn = Rect.fromLTWH(left, top, config.width, card.height);
      positionChild(empty, drawn.topLeft);
      around = around?.expandToInclude(drawn) ?? drawn;
    }

    // Both ends are keyed on where toasts are drawn rather than on the scroll
    // overflowing: the toasts beyond the window leave the deck the moment the
    // pointer does, while they are still fanned out and fading.
    final cap = config.deckCap;
    final fade = cap?.fade ?? 0;
    DeckCutEnd? farEnd;
    if (cap != null && far < layerFar && drawnReach > far) {
      final newest = _newestEnd(placed);
      farEnd = (
        at: far,
        fadeFrom: math.max(far - fade, math.min(far, newest ?? 0)),
      );
    }
    // The near end holds with no cap at all: a deck taller than the layer
    // scrolls and overruns the edge just the same, and with no cap there is no
    // `fade` to run, so it cuts hard. Kept short of the far end's own fade, so
    // the two marks never cross in a window shorter than two fades.
    DeckCutEnd? nearEnd;
    if (drawnNear < config.nearOffset) {
      nearEnd = (
        at: config.nearOffset,
        fadeFrom: math.max(
          config.nearOffset,
          math.min(config.nearOffset + fade, farEnd?.fadeFrom ?? far),
        ),
      );
    }
    onCut?.call(
      nearEnd == null && farEnd == null ? null : (near: nearEnd, far: farEnd),
    );

    final thumb = _layOutScrollbar(
      size,
      left,
      overflows: overflows,
      far: far,
      pixels: pixels,
      extent: extent,
    );

    final control = dismissAllSize?.call();
    final dismissAll = around == null || control == null
        ? null
        : _placeDismissAll(size, around, far, control);
    onDismissAll?.call(dismissAll);

    var deck = Rect.zero;
    if (around != null) {
      // A deck being scrolled moves its own ends across the margins, and must
      // not slide out from under the pointer resting there. With no pointer on
      // it nothing scrolls, and the margins are the app's.
      if (overflows && follows) {
        final reach = math.min(size.height, far + config.farOffset);
        around = config.position.isTop
            ? Rect.fromLTRB(around.left, 0, around.right, reach)
            : Rect.fromLTRB(
                around.left,
                size.height - reach,
                around.right,
                size.height,
              );
        if (thumb != null && config.scrollbar!.draggable) {
          around = around.expandToInclude(thumb);
        }
      }
      if (dismissAll != null) around = around.expandToInclude(dismissAll);
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

  /// How far from the edge the deck reaches before its toasts scroll: the cap
  /// `config.deckCap` gives, never short of the newest toast's far end, and
  /// never past [layerFar].
  double _far(Size size, List<_Placed<T>> placed, double layerFar) {
    final cap = config.deckCap;
    if (cap == null) return layerFar;
    final capped = switch (cap) {
      DeckCap(:final pixels?) => config.nearOffset + pixels,
      DeckCap(:final share?) => size.height * share - config.farOffset,
      DeckCap(:final toasts?) => _endOf(placed, toasts) ?? layerFar,
      _ => layerFar,
    };
    return math.min(layerFar, math.max(capped, _newestEnd(placed) ?? 0));
  }

  /// Where the [count]th toast, newest first, ends once expanded; null when
  /// there are fewer. The toasts beyond the window count too, since they
  /// leave the deck with the pointer while still drawn fanned out.
  double? _endOf(List<_Placed<T>> placed, int count) {
    var seen = 0;
    for (final toast in placed) {
      if (toast.pinned) continue;
      if (++seen == count) return toast.expandedEnd;
    }
    return null;
  }

  double? _newestEnd(List<_Placed<T>> placed) => _endOf(placed, 1);

  /// Where a dismiss-all control of [control]'s size sits: `gap` past the far
  /// end of the deck's box [around] — cut to [far] from the edge — aligned to
  /// the position's side, and kept on the layer.
  Rect _placeDismissAll(Size size, Rect around, double far, Size control) {
    final isTop = config.position.isTop;
    final farEnd = isTop
        ? math.min(around.bottom, far)
        : math.max(around.top, size.height - far);
    final x = switch (config.position) {
      SonnerPosition.topLeft || SonnerPosition.bottomLeft => around.left,
      SonnerPosition.topCenter ||
      SonnerPosition.bottomCenter => around.center.dx - control.width / 2,
      SonnerPosition.topRight ||
      SonnerPosition.bottomRight => around.right - control.width,
    };
    final y = isTop
        ? farEnd + config.gap
        : farEnd - config.gap - control.height;
    return Rect.fromLTWH(
      x.clamp(0.0, math.max(0.0, size.width - control.width)),
      y.clamp(0.0, math.max(0.0, size.height - control.height)),
      control.width,
      control.height,
    );
  }

  /// Lays out the [scrollbar] child as the thumb, or empty off the layer, and
  /// returns the box it takes the pointer in when laid out as the thumb.
  Rect? _layOutScrollbar(
    Size size,
    double left, {
    required bool overflows,
    required double far,
    required double pixels,
    required double extent,
  }) {
    final id = scrollbar;
    if (id == null || !hasChild(id)) return null;
    final bar = config.scrollbar;
    final track = far - config.nearOffset;
    if (bar == null || !overflows || !follows || extent <= 0 || track <= 0) {
      layoutChild(id, BoxConstraints.tight(Size.zero));
      positionChild(id, Offset(size.width, size.height));
      onScrollbar?.call(null);
      return null;
    }
    final double length = (track * track / (track + extent)).clamp(
      math.min(_minThumb, track),
      track,
    );
    final along = (pixels / extent).clamp(0.0, 1.0) * (track - length);
    final fromEdge = config.nearOffset + along;
    final width = bar.thickness + 2 * _thumbReach;
    final right = left + config.width;
    final thumbLeft = switch (bar.placement) {
      DeckScrollbarPlacement.outside => right + 8,
      DeckScrollbarPlacement.inside => right - 6 - bar.thickness,
    };
    final double x = (thumbLeft - _thumbReach).clamp(
      0.0,
      math.max(0.0, size.width - width),
    );
    final y = config.position.isTop
        ? fromEdge
        : size.height - fromEdge - length;
    layoutChild(id, BoxConstraints.tight(Size(width, length)));
    positionChild(id, Offset(x, y));
    onScrollbar?.call((track: track, thumb: length, extent: extent));
    return Rect.fromLTWH(x, y, width, length);
  }

  /// Tells [scroll] how far the toasts in the deck reach past [far], keeps
  /// the anchored toast in place, and returns how far the deck is scrolled,
  /// whether it has anywhere to scroll and how far it could.
  ({double pixels, bool overflows, double extent}) _scroll(
    Size size,
    List<_Placed<T>> placed,
    double far,
  ) {
    final scroll = this.scroll;
    if (scroll == null) return (pixels: 0, overflows: false, extent: 0);

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
    final extent = math.max(0.0, reach - far);

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
      return (pixels: pixels, overflows: overflows, extent: extent);
    }
    if (kept == null) {
      for (final toast in placed) {
        if (toast.pinned || presence(toast.id) < 1) continue;
        if (toast.fromEdge + toast.height - pixels <= config.nearOffset) {
          continue;
        }
        kept = toast;
        break;
      }
    }
    onAnchor?.call(kept?.id, kept?.fromEdge ?? 0, pixels);
    return (pixels: pixels, overflows: overflows, extent: extent);
  }

  @override
  bool shouldRelayout(ToastDeckDelegate<T> oldDelegate) => true;
}

/// One end of the deck's cut, as distances from the edge the position names:
/// nothing is drawn past [at], and toasts fade out from [fadeFrom] to it. At
/// the far end [fadeFrom] is nearer the edge than [at]; at the near end it is
/// further.
typedef DeckCutEnd = ({double at, double fadeFrom});

/// Where the deck is cut: at its [near] end, its [far] end, or both. Reported
/// null only when neither end is cut.
typedef DeckCut = ({DeckCutEnd? near, DeckCutEnd? far});

/// The scrollbar's thumb as last laid out: the length of its [track], its own
/// length, and how far the deck can scroll.
typedef DeckScrollbarGeometry = ({double track, double thumb, double extent});

/// A toast as [ToastDeckDelegate] has laid it out: its `fromEdge` is before
/// scrolling unless it is `pinnedDistance`, and it is `pinned` when its
/// heights were given rather than measured.
typedef _Placed<T> = ({
  T id,
  double height,
  double covers,
  double fromEdge,
  double expandedEnd,
  bool pinned,
  bool pinnedDistance,
  double? place,
  Rect? screen,
});

/// Lays [child] out at the height its parent allows, stretched when it would
/// be shorter and squeezed when it would be taller, and reports through
/// [onMeasured] the height it takes on its own. What a squeezed child draws
/// past that height is clipped.
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

class RenderToastHeight extends RenderProxyBox with ClipsOverflow {
  RenderToastHeight(this.onMeasured);

  ValueChanged<double> onMeasured;

  /// The child's own height, as last measured.
  double _natural = 0;

  @override
  bool get overflows => _natural > size.height;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final natural = child?.getDryLayout(ownHeight(constraints)) ?? Size.zero;
    return constraints.constrain(natural);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(ownHeight(constraints), parentUsesSize: true);
    final natural = _natural = child.size.height;
    onMeasured(natural);
    final height = constraints.constrainHeight(natural);
    if (height != natural) {
      child.layout(
        constraints.copyWith(minHeight: height, maxHeight: height),
        parentUsesSize: true,
      );
    }
    size = constraints.constrain(Size(child.size.width, height));
  }
}

/// The two of `offset`'s edges a deck is measured along.
extension DeckOffsets on SonnerConfig {
  /// The distance from the edge the position names.
  double get nearOffset => position.isTop ? offset.top : offset.bottom;

  /// The distance from the edge opposite it, where the expanded deck stops.
  double get farOffset => position.isTop ? offset.bottom : offset.top;

  /// What holds something in the position's corner off the edges: `offset`,
  /// with neither side for a centered position.
  EdgeInsets get cornerOffset => switch (position) {
    SonnerPosition.topCenter ||
    SonnerPosition.bottomCenter => offset.copyWith(left: 0, right: 0),
    _ => offset,
  };
}
