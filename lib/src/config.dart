import 'package:flutter/foundation.dart';

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
  });

  final SonnerPosition position;

  /// The width of every toast.
  final double width;

  /// The space between two toasts.
  final double gap;

  /// The distance from the screen edges to the toasts.
  final double offset;

  /// How many toasts the deck draws. The rest are kept, undrawn, until the
  /// ones in front leave.
  final int visibleToasts;

  /// How long a toast shown without a `duration` stays. [Duration.zero] keeps
  /// it until it is dismissed.
  final Duration duration;

  /// Whether the deck is fanned out without the pointer over it. It does not
  /// pause the timers; only the pointer over the deck does.
  final bool expandByDefault;

  SonnerConfig copyWith({
    SonnerPosition? position,
    double? width,
    double? gap,
    double? offset,
    int? visibleToasts,
    Duration? duration,
    bool? expandByDefault,
  }) => SonnerConfig(
    position: position ?? this.position,
    width: width ?? this.width,
    gap: gap ?? this.gap,
    offset: offset ?? this.offset,
    visibleToasts: visibleToasts ?? this.visibleToasts,
    duration: duration ?? this.duration,
    expandByDefault: expandByDefault ?? this.expandByDefault,
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
      other.expandByDefault == expandByDefault;

  @override
  int get hashCode => Object.hash(
    position,
    width,
    gap,
    offset,
    visibleToasts,
    duration,
    expandByDefault,
  );
}
