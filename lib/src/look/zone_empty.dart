import 'package:flutter/material.dart';

import '../config.dart';
import '../zone_view.dart';

/// What an open zone with no toast draws: [empty]'s builder's widget, or a
/// card as wide as a toast reading its label, fading with [shown].
class ZoneEmptyCard extends StatelessWidget {
  const ZoneEmptyCard({super.key, required this.empty, required this.shown});

  final ZoneEmpty empty;

  /// How far the card is drawn, from 0 gone to 1 in full.
  final Animation<double> shown;

  @override
  Widget build(BuildContext context) {
    final builder = empty.builder;
    if (builder != null) return builder(context, ZoneEmptyView(shown: shown));
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return FadeTransition(
      opacity: shown,
      child: Material(
        color: colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Semantics(
          container: true,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              empty.label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
