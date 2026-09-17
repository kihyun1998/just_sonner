import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import 'toast_view.dart' show ToastBuilder;

/// Where on the screen the toasts sit.
enum SonnerPosition {
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomCenter,
  bottomRight;

  bool get isTop => this == topLeft || this == topCenter || this == topRight;

  /// The directions a swipe may take a toast in, from this position's own
  /// words: [topRight] allows up and right, [bottomLeft] down and left, and
  /// [topCenter] up only.
  Set<SwipeDirection> get swipeDirections => {
    isTop ? SwipeDirection.up : SwipeDirection.down,
    switch (this) {
      topLeft || bottomLeft => SwipeDirection.left,
      topRight || bottomRight => SwipeDirection.right,
      topCenter || bottomCenter => null,
    },
  }.nonNulls.toSet();
}

/// A direction a toast can be swiped away in.
enum SwipeDirection {
  up,
  down,
  left,
  right;

  /// Whether it runs along [Axis.horizontal] rather than up or down.
  bool get isHorizontal => this == left || this == right;
}

/// How the default look draws a toast's time left.
enum TimeLeftLook {
  /// The card's outline, running out round the card from [ToastTimeLeft.start].
  border,

  /// A bar along the bottom of the card, running out toward its start edge.
  bottomBar,

  /// A bar along the top of the card, running out toward its start edge.
  topBar,

  /// A small ring in the card's bottom end corner.
  cornerRing,

  /// A ring in the leading slot: round the leading widget, or on its own in
  /// the slot when the toast has none.
  leadingRing,
}

/// Where on the card's outline a [TimeLeftLook.border] starts: the corners
/// and the middle of each side, with start and end following the text
/// direction.
enum TimeLeftStart {
  topStart,
  topCenter,
  topEnd,
  centerEnd,
  bottomEnd,
  bottomCenter,
  bottomStart,
  centerStart,
}

/// How the default look draws each toast's time left.
@immutable
class ToastTimeLeft {
  const ToastTimeLeft({
    this.look = TimeLeftLook.border,
    this.start = TimeLeftStart.topStart,
    this.clockwise = true,
    this.strokeWidth = 2,
    this.color,
    this.keepBorder = true,
    this.easeRestart = true,
    this.fadeWhenCovered = true,
  }) : assert(strokeWidth > 0, 'A stroke must have a width.');

  final TimeLeftLook look;

  /// Where a [TimeLeftLook.border] starts. The other looks do not read it.
  final TimeLeftStart start;

  /// Whether a [TimeLeftLook.border]'s gap opens clockwise from [start];
  /// otherwise the line runs back toward it. The other looks do not read it.
  final bool clockwise;

  /// The width of the border's line, a bar's height and a ring's stroke.
  final double strokeWidth;

  /// Null for the theme's `colorScheme.primary`.
  final Color? color;

  /// Whether the card keeps its own border under a [TimeLeftLook.border].
  final bool keepBorder;

  /// Whether a countdown started again, by an update or a replace, eases the
  /// time left back up over 400 ms rather than jumping to full.
  final bool easeRestart;

  /// Whether the time left fades with the content while the deck covers the
  /// toast, rather than staying on the card. A [TimeLeftLook.leadingRing] sits
  /// in the leading slot, which is content, and fades with it either way.
  final bool fadeWhenCovered;

  /// A copy with the fields given changed. [color] is given as a function,
  /// since null is a value it can take: `copyWith(color: () => null)` follows
  /// the theme again.
  ToastTimeLeft copyWith({
    TimeLeftLook? look,
    TimeLeftStart? start,
    bool? clockwise,
    double? strokeWidth,
    ValueGetter<Color?>? color,
    bool? keepBorder,
    bool? easeRestart,
    bool? fadeWhenCovered,
  }) => ToastTimeLeft(
    look: look ?? this.look,
    start: start ?? this.start,
    clockwise: clockwise ?? this.clockwise,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    color: color == null ? this.color : color(),
    keepBorder: keepBorder ?? this.keepBorder,
    easeRestart: easeRestart ?? this.easeRestart,
    fadeWhenCovered: fadeWhenCovered ?? this.fadeWhenCovered,
  );

  @override
  bool operator ==(Object other) =>
      other is ToastTimeLeft &&
      other.look == look &&
      other.start == start &&
      other.clockwise == clockwise &&
      other.strokeWidth == strokeWidth &&
      other.color == color &&
      other.keepBorder == keepBorder &&
      other.easeRestart == easeRestart &&
      other.fadeWhenCovered == fadeWhenCovered;

  @override
  int get hashCode => Object.hash(
    look,
    start,
    clockwise,
    strokeWidth,
    color,
    keepBorder,
    easeRestart,
    fadeWhenCovered,
  );
}

/// How a controller's toasts are laid out and how long they stay.
@immutable
class SonnerConfig {
  const SonnerConfig({
    this.position = SonnerPosition.bottomRight,
    this.width = 356,
    this.gap = 14,
    this.offset = 24,
    this.visibleToasts = 3,
    this.duration = const Duration(seconds: 4),
    this.expandByDefault = false,
    this.loadingIndicator = const CircularProgressIndicator(strokeWidth: 2),
    this.leadingSize = 20,
    this.closeButton = false,
    this.swipeDirections,
    this.builder,
    this.timeLeft = const ToastTimeLeft(),
  });

  final SonnerPosition position;

  /// The width of every toast.
  final double width;

  /// The space between two toasts.
  final double gap;

  /// The distance from the screen edges to the toasts.
  final double offset;

  /// How many toasts the deck draws while the pointer is away from it. The
  /// rest are kept, undrawn, until the ones in front leave or the pointer
  /// comes over the deck, which draws every toast; they count down all the
  /// while the pointer is away.
  final int visibleToasts;

  /// How long a toast shown without a `duration` stays. [Duration.zero] keeps
  /// it until it is dismissed.
  final Duration duration;

  /// Whether the deck is fanned out without the pointer over it. It draws only
  /// [visibleToasts], and does not pause the timers; the pointer over the deck
  /// does both.
  final bool expandByDefault;

  /// What the leading slot holds while a toast is loading, in place of its
  /// `leading` widget. One spinner style for the whole app.
  ///
  /// The default never settles, as an indefinite progress indicator does not.
  /// A widget test with a loading toast on screen must pump by hand rather
  /// than `pumpAndSettle`, which waits for a frame that never stops being
  /// scheduled — the same as any Flutter test with a spinner in the tree.
  /// Pass an indicator that ends, or none at all, to settle.
  final Widget loadingIndicator;

  /// Whether toasts carry a close button. `show(closeButton:)` wins over it,
  /// and a toast the user may not dismiss has none either way.
  final bool closeButton;

  /// The directions a swipe may take a toast in, or null for the ones
  /// [position]'s own words name. Read through [swipeDirectionsNow].
  ///
  /// An empty set takes the swipe away and leaves the close button, which is
  /// `dismissible`'s to govern rather than this.
  final Set<SwipeDirection>? swipeDirections;

  /// The directions a swipe may take a toast in now: [swipeDirections], or
  /// the ones [position] names while that is unset — so changing the position
  /// changes them.
  Set<SwipeDirection> get swipeDirectionsNow =>
      swipeDirections ?? position.swipeDirections;

  /// What draws every toast that has no builder of its own, in place of the
  /// default look, or null for the default look.
  final ToastBuilder? builder;

  /// The side of the leading slot's box. The box is fixed at this size, so a
  /// look that imposes a minimum width cannot stretch the indicator into an
  /// ellipse, and a toast with a slot lines its title up with every other.
  final double leadingSize;

  /// How the default look draws each toast's time left, or null to draw none.
  /// A builder is handed `ToastView.timeLeft` either way, and frames run for
  /// it while a toast counts down whatever this says.
  final ToastTimeLeft? timeLeft;

  /// A copy with the fields given changed.
  ///
  /// [swipeDirections], [builder] and [timeLeft] are given as functions, since
  /// null is a value each can take: `copyWith(swipeDirections: () => null)`
  /// follows the position again, `copyWith(builder: () => null)` the default
  /// look, and `copyWith(timeLeft: () => null)` draws no time left.
  SonnerConfig copyWith({
    SonnerPosition? position,
    double? width,
    double? gap,
    double? offset,
    int? visibleToasts,
    Duration? duration,
    bool? expandByDefault,
    Widget? loadingIndicator,
    double? leadingSize,
    bool? closeButton,
    ValueGetter<Set<SwipeDirection>?>? swipeDirections,
    ValueGetter<ToastBuilder?>? builder,
    ValueGetter<ToastTimeLeft?>? timeLeft,
  }) => SonnerConfig(
    position: position ?? this.position,
    width: width ?? this.width,
    gap: gap ?? this.gap,
    offset: offset ?? this.offset,
    visibleToasts: visibleToasts ?? this.visibleToasts,
    duration: duration ?? this.duration,
    expandByDefault: expandByDefault ?? this.expandByDefault,
    loadingIndicator: loadingIndicator ?? this.loadingIndicator,
    leadingSize: leadingSize ?? this.leadingSize,
    closeButton: closeButton ?? this.closeButton,
    swipeDirections: swipeDirections == null
        ? this.swipeDirections
        : swipeDirections(),
    builder: builder == null ? this.builder : builder(),
    timeLeft: timeLeft == null ? this.timeLeft : timeLeft(),
  );

  @override
  bool operator ==(Object other) =>
      other is SonnerConfig &&
      other.position == position &&
      other.width == width &&
      other.gap == gap &&
      other.offset == offset &&
      other.visibleToasts == visibleToasts &&
      other.duration == duration &&
      other.expandByDefault == expandByDefault &&
      other.loadingIndicator == loadingIndicator &&
      other.leadingSize == leadingSize &&
      other.closeButton == closeButton &&
      setEquals(other.swipeDirections, swipeDirections) &&
      other.builder == builder &&
      other.timeLeft == timeLeft;

  @override
  int get hashCode => Object.hash(
    position,
    width,
    gap,
    offset,
    visibleToasts,
    duration,
    expandByDefault,
    loadingIndicator,
    leadingSize,
    closeButton,
    swipeDirections == null ? null : Object.hashAllUnordered(swipeDirections!),
    builder,
    timeLeft,
  );
}
