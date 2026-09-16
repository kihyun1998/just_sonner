import 'package:flutter/widgets.dart';

import 'config.dart';

/// A swipe under way on one toast: how far it has taken the toast from where
/// the deck put it, and whether letting go there dismisses it.
///
/// The swipe locks to one axis on its first move and follows the pointer along
/// it, in a direction [directions] allows. A drag the other way is **damped,
/// not blocked** — it moves a little and never dismisses — so the toast
/// answers the hand without going anywhere.
class SwipeDrag {
  SwipeDrag({required this.directions, required Duration at})
    : _startedAt = at,
      _lastAt = at;

  /// Past this far, letting go dismisses.
  static const threshold = 45.0;

  /// Above this, in pixels per millisecond over the whole drag, letting go
  /// dismisses however short the drag was.
  static const speed = 0.11;

  /// The directions this toast may be swiped away in.
  final Set<SwipeDirection> directions;

  final Duration _startedAt;
  Duration _lastAt;

  /// Everywhere the pointer has gone since it went down.
  Offset _delta = Offset.zero;

  /// The axis the swipe locked to, or null before it has moved.
  Axis? _axis;

  /// How far the toast is drawn from its place: along the locked axis only,
  /// and damped where that way is not allowed.
  Offset get offset => switch (_axis) {
    null => Offset.zero,
    Axis.horizontal => Offset(
      _along(_delta.dx, SwipeDirection.left, SwipeDirection.right),
      0,
    ),
    Axis.vertical => Offset(
      0,
      _along(_delta.dy, SwipeDirection.up, SwipeDirection.down),
    ),
  };

  /// The direction letting go dismisses in, or null to spring back.
  SwipeDirection? get outcome {
    final axis = _axis;
    if (axis == null) return null;
    final amount = axis == Axis.horizontal ? offset.dx : offset.dy;
    if (amount == 0) return null;
    final direction = switch (axis) {
      Axis.horizontal =>
        amount > 0 ? SwipeDirection.right : SwipeDirection.left,
      Axis.vertical => amount > 0 ? SwipeDirection.down : SwipeDirection.up,
    };
    // The damping lets a flick the wrong way still read as fast, so the
    // direction is asked first.
    if (!directions.contains(direction)) return null;
    final took = (_lastAt - _startedAt).inMicroseconds / 1000;
    final fast = took > 0 && amount.abs() / took > speed;
    return amount.abs() >= threshold || fast ? direction : null;
  }

  /// Takes the pointer [by] further, at [at] where the drag carries a time.
  void moveBy(Offset by, {Duration? at}) {
    _delta += by;
    if (at != null) _lastAt = at;
    if (_axis != null) return;
    // The axis locks on the first move of more than a pixel, and holds for
    // the rest of the drag.
    if (_delta.dx.abs() > 1 || _delta.dy.abs() > 1) {
      _axis = _delta.dx.abs() > _delta.dy.abs()
          ? Axis.horizontal
          : Axis.vertical;
    }
  }

  /// [delta] along an axis whose two directions are [back] and [forth], as far
  /// as the toast follows it.
  double _along(double delta, SwipeDirection back, SwipeDirection forth) {
    if (!directions.contains(back) && !directions.contains(forth)) return 0;
    if (directions.contains(delta < 0 ? back : forth)) return delta;
    final damped = delta / (1.5 + delta.abs() / 20);
    // Never further than the pointer itself went, so taking up the damping
    // does not jump the toast.
    return damped.abs() < delta.abs() ? damped : delta;
  }
}

/// Which way a toast leaves, once a swipe has dismissed it.
extension SwipeStep on SwipeDirection {
  /// The way it goes, as a unit offset.
  Offset get step => switch (this) {
    SwipeDirection.up => const Offset(0, -1),
    SwipeDirection.down => const Offset(0, 1),
    SwipeDirection.left => const Offset(-1, 0),
    SwipeDirection.right => const Offset(1, 0),
  };
}
