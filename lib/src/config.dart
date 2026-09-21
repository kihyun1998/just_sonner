import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import 'dismiss_all_view.dart';
import 'stow_view.dart';
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

/// How far the expanded deck reaches from its edge before its toasts scroll,
/// measured in one of three ways.
///
/// The newest toast is never cut short **by the cap**: one shorter than it
/// reaches to its far end. A cap that reaches further than the layer allows
/// changes nothing. The deck is also cut at its near end, at the edge's own
/// `offset`, which is not the cap's doing and happens with no cap at all — a
/// toast scrolled past that edge is cut there whichever toast it is.
@immutable
class DeckCap {
  /// The deck's own height, from the edge's `offset` to its far end.
  const DeckCap.pixels(double this.pixels, {this.fade = 24})
    : share = null,
      toasts = null,
      assert(pixels > 0, 'A cap must have a height.'),
      assert(fade >= 0, 'A fade cannot be negative.');

  /// A share of the layer's height, the far edge's `offset` included.
  const DeckCap.share(double this.share, {this.fade = 24})
    : pixels = null,
      toasts = null,
      assert(share > 0 && share <= 1, 'A share is above 0, and at most 1.'),
      assert(fade >= 0, 'A fade cannot be negative.');

  /// As far as the far end of the newest [toasts] toasts in the deck, at the
  /// heights they are drawn at.
  const DeckCap.toasts(int this.toasts, {this.fade = 24})
    : pixels = null,
      share = null,
      assert(toasts >= 1, 'A cap holds at least one toast.'),
      assert(fade >= 0, 'A fade cannot be negative.');

  /// Set when the cap is given in pixels.
  final double? pixels;

  /// Set when the cap is given as a share of the layer.
  final double? share;

  /// Set when the cap is given as a number of toasts.
  final int? toasts;

  /// How far before each end of the cut the toasts fade out; 0 cuts them
  /// hard. At the far end it runs inward from the cap; at the near end, inward
  /// from the edge's own `offset`. With no cap there is no fade, and the near
  /// end cuts hard.
  final double fade;

  @override
  bool operator ==(Object other) =>
      other is DeckCap &&
      other.pixels == pixels &&
      other.share == share &&
      other.toasts == toasts &&
      other.fade == fade;

  @override
  int get hashCode => Object.hash(pixels, share, toasts, fade);

  @override
  String toString() => switch (this) {
    DeckCap(:final pixels?) => 'DeckCap.pixels($pixels, fade: $fade)',
    DeckCap(:final share?) => 'DeckCap.share($share, fade: $fade)',
    _ => 'DeckCap.toasts($toasts, fade: $fade)',
  };
}

/// Which side of the deck's right edge a [DeckScrollbar] sits on.
enum DeckScrollbarPlacement {
  /// In the margin beyond the deck's right edge.
  outside,

  /// Over the toasts, just inside the deck's right edge.
  inside,
}

/// What is drawn behind the deck while it is fanned out.
///
/// It is drawn under the fanned-out toasts and the gaps between them, over the
/// deck's own box and [padding] further. [blur] and [dim] both follow the expansion, so a
/// collapsed deck draws neither and there is nothing to see until the pointer
/// fans the deck out.
///
/// What it draws over takes no pointer of its own: a click in the [padding] it
/// reaches into still reaches the app.
@immutable
class DeckBackdrop {
  const DeckBackdrop({
    this.blur = 4,
    this.dim = 0,
    this.padding = const EdgeInsets.all(12),
    this.radius = 16,
    this.color,
  }) : assert(blur >= 0, 'A blur cannot be negative.'),
       assert(dim >= 0 && dim <= 1, 'A dim is a fraction.'),
       assert(radius >= 0, 'A radius cannot be negative.');

  /// The filter's sigma at full expansion. 0 draws no blur.
  ///
  /// It blurs **what the app painted**, not the desktop behind the window: a
  /// `BackdropFilter` reaches the content under it inside the window, and the
  /// wallpaper needs a transparent native window, which is the app's decision
  /// and not this package's.
  final double blur;

  /// How much of [color] is laid over the blur at full expansion, 0 to 1.
  final double dim;

  /// How far past the deck's own box it reaches, per edge. The deck's box is
  /// the toasts and the gaps between them, so with no padding the blur stops
  /// exactly at the cards' edges.
  final EdgeInsets padding;

  /// The corner radius of what is drawn. 0 is a hard rectangle.
  final double radius;

  /// What is laid over the blur, at [dim]'s opacity. Null for the theme's
  /// `colorScheme.scrim`, which is Material's own role for what covers the
  /// content behind a surface and follows light and dark for free.
  ///
  /// The colour's own alpha is not read: [dim] is the one handle on how much
  /// of it there is.
  final Color? color;

  /// A copy with the fields given changed. [color] is given as a function,
  /// since null is a value it can take: `copyWith(color: () => null)` follows
  /// the theme again.
  DeckBackdrop copyWith({
    double? blur,
    double? dim,
    EdgeInsets? padding,
    double? radius,
    ValueGetter<Color?>? color,
  }) => DeckBackdrop(
    blur: blur ?? this.blur,
    dim: dim ?? this.dim,
    padding: padding ?? this.padding,
    radius: radius ?? this.radius,
    color: color == null ? this.color : color(),
  );

  @override
  bool operator ==(Object other) =>
      other is DeckBackdrop &&
      other.blur == blur &&
      other.dim == dim &&
      other.padding == padding &&
      other.radius == radius &&
      other.color == color;

  @override
  int get hashCode => Object.hash(blur, dim, padding, radius, color);

  @override
  String toString() =>
      'DeckBackdrop(blur: $blur, dim: $dim, padding: $padding, '
      'radius: $radius, color: $color)';
}

/// The scrollbar drawn beside the expanded deck while its toasts scroll.
@immutable
class DeckScrollbar {
  const DeckScrollbar({
    this.placement = DeckScrollbarPlacement.outside,
    this.alwaysShown = true,
    this.draggable = true,
    this.thickness = 4,
    this.color,
  }) : assert(thickness > 0, 'A scrollbar must have a thickness.');

  final DeckScrollbarPlacement placement;

  /// Whether it shows all the while the deck can scroll; otherwise it shows
  /// while the deck scrolls, and fades a moment after.
  final bool alwaysShown;

  /// Whether dragging its thumb scrolls the deck. One that is not takes no
  /// pointer.
  final bool draggable;

  final double thickness;

  /// Null for the theme's `colorScheme.onSurface`, faded.
  final Color? color;

  /// A copy with the fields given changed. [color] is given as a function,
  /// since null is a value it can take: `copyWith(color: () => null)` follows
  /// the theme again.
  DeckScrollbar copyWith({
    DeckScrollbarPlacement? placement,
    bool? alwaysShown,
    bool? draggable,
    double? thickness,
    ValueGetter<Color?>? color,
  }) => DeckScrollbar(
    placement: placement ?? this.placement,
    alwaysShown: alwaysShown ?? this.alwaysShown,
    draggable: draggable ?? this.draggable,
    thickness: thickness ?? this.thickness,
    color: color == null ? this.color : color(),
  );

  @override
  bool operator ==(Object other) =>
      other is DeckScrollbar &&
      other.placement == placement &&
      other.alwaysShown == alwaysShown &&
      other.draggable == draggable &&
      other.thickness == thickness &&
      other.color == color;

  @override
  int get hashCode =>
      Object.hash(placement, alwaysShown, draggable, thickness, color);
}

/// The built-in looks of the [DeckDismissAll] control.
enum DeckDismissAllLook {
  /// A small rounded button reading its label.
  pill,

  /// A bar as wide as the deck: the count, and a button reading its label.
  header,
}

/// The control at the expanded deck's far end that dismisses every toast the
/// user may dismiss. It shows while the pointer holds the deck or the app has
/// expanded it, and at least two such toasts are on screen.
@immutable
class DeckDismissAll {
  const DeckDismissAll({
    this.look = DeckDismissAllLook.pill,
    this.label = 'Clear all',
    this.countLabel,
    this.builder,
  });

  final DeckDismissAllLook look;

  /// What the button reads.
  final String label;

  /// What a [DeckDismissAllLook.header] reads for the count. Null reads
  /// `'$count notifications'`.
  final String Function(int count)? countLabel;

  /// Draws the control in place of [look].
  final DeckDismissAllBuilder? builder;

  /// A copy with the fields given changed. [countLabel] and [builder] are
  /// given as functions, since null is a value each can take.
  DeckDismissAll copyWith({
    DeckDismissAllLook? look,
    String? label,
    ValueGetter<String Function(int count)?>? countLabel,
    ValueGetter<DeckDismissAllBuilder?>? builder,
  }) => DeckDismissAll(
    look: look ?? this.look,
    label: label ?? this.label,
    countLabel: countLabel == null ? this.countLabel : countLabel(),
    builder: builder == null ? this.builder : builder(),
  );

  @override
  bool operator ==(Object other) =>
      other is DeckDismissAll &&
      other.look == look &&
      other.label == label &&
      other.countLabel == countLabel &&
      other.builder == builder;

  @override
  int get hashCode => Object.hash(look, label, countLabel, builder);
}

/// The built-in looks of the [DeckStowControl].
enum DeckStowLook {
  /// A small rounded button reading its label.
  pill,

  /// A bar as wide as the deck: the count, a button reading its label, and
  /// the dismiss-all control's button where that control shows too.
  header,

  /// A round button with a chevron pointing at the edge the deck sits at, at
  /// the other end of the deck's width from the dismiss-all control.
  icon,
}

/// The control at the expanded deck's far end that stows the deck. It shows
/// while the pointer holds the deck or the app has expanded it, and at least
/// one toast is on screen, whether or not the user may dismiss it.
@immutable
class DeckStowControl {
  const DeckStowControl({
    this.look = DeckStowLook.pill,
    this.label = 'Hide',
    this.countLabel,
    this.builder,
  });

  final DeckStowLook look;

  /// What the button reads, and what an icon is labelled for semantics.
  final String label;

  /// What a [DeckStowLook.header] reads for the count. Null reads
  /// `'$count notifications'`.
  final String Function(int count)? countLabel;

  /// Draws the control in place of [look].
  final DeckStowBuilder? builder;

  /// A copy with the fields given changed. [countLabel] and [builder] are
  /// given as functions, since null is a value each can take.
  DeckStowControl copyWith({
    DeckStowLook? look,
    String? label,
    ValueGetter<String Function(int count)?>? countLabel,
    ValueGetter<DeckStowBuilder?>? builder,
  }) => DeckStowControl(
    look: look ?? this.look,
    label: label ?? this.label,
    countLabel: countLabel == null ? this.countLabel : countLabel(),
    builder: builder == null ? this.builder : builder(),
  );

  @override
  bool operator ==(Object other) =>
      other is DeckStowControl &&
      other.look == look &&
      other.label == label &&
      other.countLabel == countLabel &&
      other.builder == builder;

  @override
  int get hashCode => Object.hash(look, label, countLabel, builder);
}

/// The built-in motions a deck goes out of sight by.
enum DeckStowMotionLook {
  /// Past the edge it sits at, fading.
  slide,

  /// Fading where it is.
  fade,

  /// Shrinking into the corner it sits in, fading.
  shrink,
}

/// How the deck goes out of sight, and comes back the same way reversed. It
/// is not nullable: an app calling `stow()` needs a motion whether or not a
/// [DeckStowControl] is configured.
@immutable
class DeckStowMotion {
  const DeckStowMotion({this.look = DeckStowMotionLook.slide, this.builder});

  final DeckStowMotionLook look;

  /// Takes the deck out of sight in place of [look]. A stowed deck takes no
  /// pointer whatever a builder draws.
  final DeckStowMotionBuilder? builder;

  /// A copy with the fields given changed. [builder] is given as a function,
  /// since null is a value it can take.
  DeckStowMotion copyWith({
    DeckStowMotionLook? look,
    ValueGetter<DeckStowMotionBuilder?>? builder,
  }) => DeckStowMotion(
    look: look ?? this.look,
    builder: builder == null ? this.builder : builder(),
  );

  @override
  bool operator ==(Object other) =>
      other is DeckStowMotion && other.look == look && other.builder == builder;

  @override
  int get hashCode => Object.hash(look, builder);
}

/// What a stowed deck leaves at its edge: a button reading how many toasts it
/// is keeping, which brings them back. It takes the pointer only while the
/// deck is stowed.
@immutable
class DeckStowHandle {
  const DeckStowHandle({this.countLabel, this.builder});

  /// What the button reads. Null reads `'$count hidden'`.
  final String Function(int count)? countLabel;

  /// Draws the handle in place of the built-in look.
  final DeckStowHandleBuilder? builder;

  /// A copy with the fields given changed. Both are given as functions, since
  /// null is a value each can take.
  DeckStowHandle copyWith({
    ValueGetter<String Function(int count)?>? countLabel,
    ValueGetter<DeckStowHandleBuilder?>? builder,
  }) => DeckStowHandle(
    countLabel: countLabel == null ? this.countLabel : countLabel(),
    builder: builder == null ? this.builder : builder(),
  );

  @override
  bool operator ==(Object other) =>
      other is DeckStowHandle &&
      other.countLabel == countLabel &&
      other.builder == builder;

  @override
  int get hashCode => Object.hash(countLabel, builder);
}

/// How a controller's toasts are laid out and how long they stay.
@immutable
class SonnerConfig {
  const SonnerConfig({
    this.position = SonnerPosition.bottomRight,
    this.width = 356,
    this.gap = 14,
    this.offset = const EdgeInsets.all(24),
    this.visibleToasts = 3,
    this.duration = const Duration(seconds: 4),
    this.expandByDefault = false,
    this.loadingIndicator = const CircularProgressIndicator(strokeWidth: 2),
    this.leadingSize = 20,
    this.closeButton = false,
    this.swipeDirections,
    this.builder,
    this.timeLeft = const ToastTimeLeft(),
    this.deckCap = const DeckCap.pixels(400),
    this.deckBackdrop,
    this.scrollbar = const DeckScrollbar(),
    this.dismissAll = const DeckDismissAll(),
    this.stowControl = const DeckStowControl(),
    this.stowMotion = const DeckStowMotion(),
    this.stowHandle,
  });

  final SonnerPosition position;

  /// The width of every toast.
  final double width;

  /// The space between two toasts.
  final double gap;

  /// The distance from each screen edge to the toasts.
  ///
  /// The edge the position names holds the deck off it, and the opposite one
  /// is where the expanded deck stops. Left and right place the deck on a
  /// left or right position; a centered one reads neither.
  final EdgeInsets offset;

  /// How many toasts the deck draws while the pointer is away from it and the
  /// app has not expanded it. The rest are kept, undrawn, until the ones in
  /// front leave, the pointer comes over the deck or the app expands it, each
  /// of which draws every toast; they count down all the while.
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
  /// An empty set lets no swipe dismiss: a drag still moves the toast a
  /// little, damped, and springs it back. Taking the drag away altogether is
  /// `dismissible`'s to govern, as the close button is.
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
  /// it while a toast counting down is drawn, whatever this says.
  final ToastTimeLeft? timeLeft;

  /// How far the expanded deck reaches before its toasts scroll. Null lets it
  /// reach as far as the layer, `offset` short of the far side.
  final DeckCap? deckCap;

  /// What is drawn behind the deck while it is fanned out. Null, the default,
  /// draws nothing.
  final DeckBackdrop? deckBackdrop;

  /// The scrollbar beside the expanded deck while its toasts scroll, capped
  /// or not. Null draws none.
  final DeckScrollbar? scrollbar;

  /// The control that dismisses every toast the user may dismiss, at the
  /// expanded deck's far end. Null draws none.
  final DeckDismissAll? dismissAll;

  /// The control that stows the deck, or null for none. The app can stow
  /// through the controller either way.
  final DeckStowControl? stowControl;

  /// How the deck goes out of sight and comes back.
  final DeckStowMotion stowMotion;

  /// What a stowed deck leaves at its edge, or null for nothing.
  final DeckStowHandle? stowHandle;

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
    EdgeInsets? offset,
    int? visibleToasts,
    Duration? duration,
    bool? expandByDefault,
    Widget? loadingIndicator,
    double? leadingSize,
    bool? closeButton,
    ValueGetter<Set<SwipeDirection>?>? swipeDirections,
    ValueGetter<ToastBuilder?>? builder,
    ValueGetter<ToastTimeLeft?>? timeLeft,
    ValueGetter<DeckCap?>? deckCap,
    ValueGetter<DeckBackdrop?>? deckBackdrop,
    ValueGetter<DeckScrollbar?>? scrollbar,
    ValueGetter<DeckDismissAll?>? dismissAll,
    ValueGetter<DeckStowControl?>? stowControl,
    DeckStowMotion? stowMotion,
    ValueGetter<DeckStowHandle?>? stowHandle,
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
    deckCap: deckCap == null ? this.deckCap : deckCap(),
    deckBackdrop: deckBackdrop == null ? this.deckBackdrop : deckBackdrop(),
    scrollbar: scrollbar == null ? this.scrollbar : scrollbar(),
    dismissAll: dismissAll == null ? this.dismissAll : dismissAll(),
    stowControl: stowControl == null ? this.stowControl : stowControl(),
    stowMotion: stowMotion ?? this.stowMotion,
    stowHandle: stowHandle == null ? this.stowHandle : stowHandle(),
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
      other.timeLeft == timeLeft &&
      other.deckCap == deckCap &&
      other.deckBackdrop == deckBackdrop &&
      other.scrollbar == scrollbar &&
      other.dismissAll == dismissAll &&
      other.stowControl == stowControl &&
      other.stowMotion == stowMotion &&
      other.stowHandle == stowHandle;

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
    deckCap,
    deckBackdrop,
    scrollbar,
    dismissAll,
    stowControl,
    stowMotion,
    stowHandle,
  );
}
