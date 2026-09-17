import 'package:flutter/widgets.dart';

import 'config.dart';

/// Draws the control that stows the deck, in place of the built-in looks.
typedef DeckStowBuilder =
    Widget Function(BuildContext context, DeckStowView view);

/// Takes the [deck] out of sight and back, in place of the built-in motions.
typedef DeckStowMotionBuilder =
    Widget Function(BuildContext context, DeckStowMotionView view, Widget deck);

/// Draws what a stowed deck leaves at the edge, in place of the built-in look.
typedef DeckStowHandleBuilder =
    Widget Function(BuildContext context, DeckStowHandleView view);

/// What a [DeckStowBuilder] is handed.
class DeckStowView {
  const DeckStowView({
    required this.count,
    required this.stow,
    required this.expansion,
  });

  /// How many toasts [stow] would put away: every toast on screen, whether or
  /// not the user may dismiss it.
  final int count;

  /// Stows the deck.
  final VoidCallback stow;

  /// How far the deck is fanned out, from 0 collapsed to 1 expanded, which a
  /// look answers by repainting.
  final Animation<double> expansion;
}

/// What a [DeckStowMotionBuilder] is handed.
class DeckStowMotionView {
  const DeckStowMotionView({
    required this.stowed,
    required this.position,
    required this.reach,
  });

  /// How far the deck is out of sight, from 0 drawn to 1 stowed. It runs to 1
  /// as the deck is stowed and back to 0 as it comes back.
  final Animation<double> stowed;

  /// Where the deck sits, which names the edge it would leave by.
  final SonnerPosition position;

  /// How far the deck reached from its edge when it was stowed, in pixels.
  final double reach;
}

/// What a [DeckStowHandleBuilder] is handed.
class DeckStowHandleView {
  const DeckStowHandleView({
    required this.count,
    required this.unstow,
    required this.shown,
    required this.position,
  });

  /// How many toasts the stowed deck is keeping.
  final int count;

  /// Brings the deck back.
  final VoidCallback unstow;

  /// How far the handle is out, from 0 with the deck drawn to 1 with it
  /// stowed, which a look answers by repainting.
  final Animation<double> shown;

  /// Where the deck sits, and so which corner the handle is drawn in.
  final SonnerPosition position;
}
