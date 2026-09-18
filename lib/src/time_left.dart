import 'dart:math' as math;
import 'dart:ui' show PathMetric, clampDouble;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

import 'config.dart' show TimeLeftStart;
import 'controller.dart' show ToastRecord, countdownTick;

/// A toast's time left as a value drawn on every frame: 1 when its countdown
/// starts, 0 when it runs out.
///
/// The controller counts in whole ticks and reads no clock (§7), so this fills
/// in the frames between two ticks from their own time stamps, and stands
/// still wherever the controller does not count: while the timers are paused,
/// and for the partial tick a toast lets pass uncounted.
///
/// What it fills in is only ever the way into the tick under way, never more:
/// each tick puts the drawn value back on [ToastRecord.remaining], the number
/// of record. So the drawn value cannot drift from the countdown, and a span
/// of frames this never saw — the host stops following while nothing counting
/// is drawn — costs one tick at most, which the next tick takes back.
class TimeLeftFollower {
  TimeLeftFollower(TickerProvider vsync)
    : animation = AnimationController(vsync: vsync, value: 1);

  /// What a look reads.
  final AnimationController animation;

  /// The time left the controller last reported, and the frame it was drawn
  /// on.
  Duration? _remaining;
  Duration? _lastFrame;

  /// How far into the tick under way the drawn value is, from zero at the tick
  /// that anchored it to [countdownTick] at the next one. Never past it.
  Duration _into = Duration.zero;

  /// Where a restart's ease started, and on which frame; null when none runs.
  double? _easeFrom;
  Duration _easeAt = Duration.zero;

  static const _easeDuration = Duration(milliseconds: 400);

  /// Follows [record] at the frame time stamp [now], standing still while the
  /// timers are [paused]. A countdown started again eases back up when
  /// [easeRestart], and jumps to full otherwise.
  void follow(
    Duration now,
    ToastRecord record, {
    required bool paused,
    required bool easeRestart,
  }) {
    final remaining = record.remaining;
    final duration = record.duration;
    final previous = _remaining;
    final lastFrame = _lastFrame;
    _remaining = remaining;
    _lastFrame = now;
    if (remaining == null || duration <= Duration.zero) return;
    if (previous == null) {
      _into = Duration.zero;
      _easeFrom = null;
    } else if (remaining > previous ||
        (remaining == duration && remaining != previous)) {
      // Started again: an update or a replace, with any duration.
      _into = Duration.zero;
      _easeFrom = easeRestart ? animation.value : null;
      _easeAt = now;
    } else if (remaining != previous) {
      // A tick landed: back onto the controller's number.
      _into = Duration.zero;
    } else if (!paused && !record.skipTick && lastFrame != null) {
      // A tick the controller will pass by uncounted is not time going. The
      // way in stops at the tick, so the frames between two of them run the
      // value down exactly one tick's worth however many of them there were.
      final into = _into + (now - lastFrame);
      _into = into < countdownTick ? into : countdownTick;
    }
    final value = clampDouble(
      (remaining - _into).inMicroseconds / duration.inMicroseconds,
      0,
      1,
    );
    final from = _easeFrom;
    final t = (now - _easeAt).inMicroseconds / _easeDuration.inMicroseconds;
    if (from == null || t >= 1) {
      _easeFrom = null;
      animation.value = value;
    } else {
      animation.value = from + (value - from) * Curves.ease.transform(t);
    }
  }

  /// Stops following, where the toast was dismissed: empty when its timer ran
  /// out, and where it stood otherwise.
  void stop(ToastRecord record) {
    final remaining = record.remaining;
    if (remaining != null && remaining <= Duration.zero) animation.value = 0;
  }

  void dispose() => animation.dispose();
}

/// The part of a card's rounded outline a [TimeLeftLook.border] draws, for
/// [value] of the time left.
///
/// The line runs half its width in from the card's edge. Clockwise, the gap
/// opens from [start] going clockwise, so the line ends at [start]; otherwise
/// it begins at [start] and runs back toward it. [start]'s start and end follow
/// [textDirection]; clockwise is the screen's.
class TimeLeftSweep {
  factory TimeLeftSweep(
    Size size, {
    required double radius,
    required double strokeWidth,
    required double value,
    required TimeLeftStart start,
    required bool clockwise,
    required TextDirection textDirection,
  }) {
    final inset = strokeWidth / 2;
    final rect = (Offset.zero & size).deflate(inset);
    final r = clampDouble(
      radius - inset,
      0,
      math.min(rect.width, rect.height) / 2,
    );
    final corner = Radius.circular(r);
    // Clockwise from where the top edge leaves the top left corner.
    final outline = Path()
      ..moveTo(rect.left + r, rect.top)
      ..lineTo(rect.right - r, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + r), radius: corner)
      ..lineTo(rect.right, rect.bottom - r)
      ..arcToPoint(Offset(rect.right - r, rect.bottom), radius: corner)
      ..lineTo(rect.left + r, rect.bottom)
      ..arcToPoint(Offset(rect.left, rect.bottom - r), radius: corner)
      ..lineTo(rect.left, rect.top + r)
      ..arcToPoint(Offset(rect.left + r, rect.top), radius: corner);
    final metric = outline.computeMetrics().first;
    final top = rect.width - 2 * r;
    final side = rect.height - 2 * r;
    final arc = metric.length - 2 * top - 2 * side;
    final from = textDirection == TextDirection.rtl ? _mirrored(start) : start;
    final at = switch (from) {
      TimeLeftStart.topCenter => top / 2,
      TimeLeftStart.topEnd => top + arc / 8,
      TimeLeftStart.centerEnd => top + arc / 4 + side / 2,
      TimeLeftStart.bottomEnd => top + 3 * arc / 8 + side,
      TimeLeftStart.bottomCenter => top * 1.5 + arc / 2 + side,
      TimeLeftStart.bottomStart => 2 * top + 5 * arc / 8 + side,
      TimeLeftStart.centerStart => 2 * top + 3 * arc / 4 + side * 1.5,
      TimeLeftStart.topStart => metric.length - arc / 8,
    };
    final length = metric.length * clampDouble(value, 0, 1);
    final begin = clockwise ? at + metric.length - length : at;
    return TimeLeftSweep._(metric, begin % metric.length, length);
  }

  TimeLeftSweep._(this._metric, this._begin, this.length);

  static TimeLeftStart _mirrored(TimeLeftStart start) => switch (start) {
    TimeLeftStart.topStart => TimeLeftStart.topEnd,
    TimeLeftStart.topEnd => TimeLeftStart.topStart,
    TimeLeftStart.centerEnd => TimeLeftStart.centerStart,
    TimeLeftStart.centerStart => TimeLeftStart.centerEnd,
    TimeLeftStart.bottomEnd => TimeLeftStart.bottomStart,
    TimeLeftStart.bottomStart => TimeLeftStart.bottomEnd,
    TimeLeftStart.topCenter || TimeLeftStart.bottomCenter => start,
  };

  final PathMetric _metric;
  final double _begin;

  /// How long the drawn line is.
  final double length;

  /// How long the whole outline is.
  double get perimeter => _metric.length;

  /// Where the drawn line begins, going clockwise.
  Offset get from => _pointAt(_begin);

  /// Where it ends.
  Offset get to => _pointAt(_begin + length);

  Offset _pointAt(double distance) =>
      _metric.getTangentForOffset(distance % perimeter)!.position;

  /// The drawn line.
  Path get path {
    final path = Path();
    var at = _begin;
    var rest = length;
    while (rest > 0) {
      final piece = math.min(rest, perimeter - at);
      path.addPath(_metric.extractPath(at, at + piece), Offset.zero);
      rest -= piece;
      at = 0;
    }
    return path;
  }
}

/// Paints a toast's time left in the default look.
sealed class TimeLeftPainter extends CustomPainter {
  TimeLeftPainter({
    required this.timeLeft,
    required this.color,
    required this.strokeWidth,
  }) : super(repaint: timeLeft);

  final Animation<double> timeLeft;
  final Color color;
  final double strokeWidth;

  Paint get _paint => Paint()
    ..color = color
    ..strokeWidth = strokeWidth;

  /// Drawn over the card, it takes no pointer: what is under it does.
  @override
  bool hitTest(Offset position) => false;
}

/// [TimeLeftLook.border]: the card's outline, as [TimeLeftSweep] draws it.
class TimeLeftBorderPainter extends TimeLeftPainter {
  TimeLeftBorderPainter({
    required super.timeLeft,
    required super.color,
    required super.strokeWidth,
    required this.start,
    required this.clockwise,
    required this.textDirection,
    required this.radius,
  });

  final TimeLeftStart start;
  final bool clockwise;
  final TextDirection textDirection;

  /// The card's corner radius.
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final sweep = TimeLeftSweep(
      size,
      radius: radius,
      strokeWidth: strokeWidth,
      value: timeLeft.value,
      start: start,
      clockwise: clockwise,
      textDirection: textDirection,
    );
    canvas.drawPath(sweep.path, _paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(TimeLeftBorderPainter oldDelegate) =>
      oldDelegate.timeLeft != timeLeft ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.start != start ||
      oldDelegate.clockwise != clockwise ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.radius != radius;
}

/// [TimeLeftLook.bottomBar] and [TimeLeftLook.topBar]: a bar along the card's
/// edge, running out toward its start edge, cut to the card's corners.
class TimeLeftBarPainter extends TimeLeftPainter {
  TimeLeftBarPainter({
    required super.timeLeft,
    required super.color,
    required super.strokeWidth,
    required this.atTop,
    required this.textDirection,
    required this.radius,
  });

  final bool atTop;
  final TextDirection textDirection;

  /// The card's corner radius.
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width * clampDouble(timeLeft.value, 0, 1);
    final left = textDirection == TextDirection.rtl ? size.width - width : 0.0;
    final top = atTop ? 0.0 : size.height - strokeWidth;
    canvas
      ..save()
      ..clipRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      )
      ..drawRect(Rect.fromLTWH(left, top, width, strokeWidth), _paint)
      ..restore();
  }

  @override
  bool shouldRepaint(TimeLeftBarPainter oldDelegate) =>
      oldDelegate.timeLeft != timeLeft ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.atTop != atTop ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.radius != radius;
}

/// [TimeLeftLook.cornerRing] and [TimeLeftLook.leadingRing]: a ring running
/// out clockwise from its top, over a faint track of the whole ring.
class TimeLeftRingPainter extends TimeLeftPainter {
  TimeLeftRingPainter({
    required super.timeLeft,
    required super.color,
    required super.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ring = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = _paint..style = PaintingStyle.stroke;
    canvas
      ..drawOval(
        ring,
        _paint
          ..style = PaintingStyle.stroke
          ..color = color.withValues(alpha: color.a * 0.15),
      )
      ..drawArc(
        ring,
        -math.pi / 2,
        2 * math.pi * clampDouble(timeLeft.value, 0, 1),
        false,
        paint,
      );
  }

  @override
  bool shouldRepaint(TimeLeftRingPainter oldDelegate) =>
      oldDelegate.timeLeft != timeLeft ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
