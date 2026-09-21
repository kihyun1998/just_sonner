import 'package:flutter/widgets.dart';

import 'config.dart';

/// Draws the control that hides the zone, in place of the built-in looks.
typedef DeckHideBuilder =
    Widget Function(BuildContext context, DeckHideView view);

/// Takes the [deck] out of sight and back, in place of the built-in motions.
typedef DeckHideMotionBuilder =
    Widget Function(BuildContext context, DeckHideMotionView view, Widget deck);

/// What a [DeckHideBuilder] is handed.
class DeckHideView {
  const DeckHideView({
    required this.count,
    required this.hide,
    required this.expansion,
  });

  /// How many toasts [hide] would take out of sight: every toast on screen,
  /// whether or not the user may dismiss it.
  final int count;

  /// Hides the zone.
  final VoidCallback hide;

  /// How far the deck is fanned out, from 0 collapsed to 1 expanded, which a
  /// look answers by repainting.
  final Animation<double> expansion;
}

/// What a [DeckHideMotionBuilder] is handed.
class DeckHideMotionView {
  const DeckHideMotionView({
    required this.hidden,
    required this.position,
    required this.reach,
  });

  /// How far the deck is out of sight, from 0 drawn to 1 hidden. It runs to 1
  /// as the zone is hidden and back to 0 as the deck comes back.
  final Animation<double> hidden;

  /// Where the deck sits, which names the edge it would leave by.
  final SonnerPosition position;

  /// How far the deck reached from its edge when it was hidden, in pixels.
  final double reach;
}
