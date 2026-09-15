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
    this.duration = const Duration(seconds: 4),
  });

  final SonnerPosition position;

  /// The width of every toast.
  final double width;

  /// The space between two toasts.
  final double gap;

  /// The distance from the screen edges to the toasts.
  final double offset;

  /// How long a toast shown without a `duration` stays. [Duration.zero] keeps
  /// it until it is dismissed.
  final Duration duration;

  SonnerConfig copyWith({
    SonnerPosition? position,
    double? width,
    double? gap,
    double? offset,
    Duration? duration,
  }) => SonnerConfig(
    position: position ?? this.position,
    width: width ?? this.width,
    gap: gap ?? this.gap,
    offset: offset ?? this.offset,
    duration: duration ?? this.duration,
  );

  @override
  bool operator ==(Object other) =>
      other is SonnerConfig &&
      other.position == position &&
      other.width == width &&
      other.gap == gap &&
      other.offset == offset &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(position, width, gap, offset, duration);
}
