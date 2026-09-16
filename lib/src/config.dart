import 'package:flutter/material.dart';

/// Where on the screen the toasts sit.
enum SonnerPosition {
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomCenter,
  bottomRight;

  bool get isTop => this == topLeft || this == topCenter || this == topRight;
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

  /// The side of the leading slot's box. The box is fixed at this size, so a
  /// look that imposes a minimum width cannot stretch the indicator into an
  /// ellipse, and a toast with a slot lines its title up with every other.
  final double leadingSize;

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
      other.closeButton == closeButton;

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
  );
}
