import 'package:flutter/widgets.dart';

/// Draws the control that dismisses every toast the user may dismiss, in
/// place of the built-in looks.
typedef DeckDismissAllBuilder =
    Widget Function(BuildContext context, DeckDismissAllView view);

/// What a [DeckDismissAllBuilder] is handed.
class DeckDismissAllView {
  const DeckDismissAllView({
    required this.count,
    required this.dismiss,
    required this.expansion,
  });

  /// How many toasts [dismiss] would dismiss: every one the user may dismiss,
  /// the ones beyond the window included.
  final int count;

  /// Dismisses those toasts. Toasts loading or not dismissible stay.
  final VoidCallback dismiss;

  /// How far the deck is fanned out, from 0 collapsed to 1 expanded, which a
  /// look answers by repainting.
  final Animation<double> expansion;
}
