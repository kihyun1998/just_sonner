import 'package:flutter/material.dart';

import 'toast_state.dart';

/// The look a toast has when no builder replaces it.
///
/// Colours and text come from the ambient [Theme]; padding, the title's weight
/// and the gap under it follow sonner's styled toast.
///
/// [fade] is how much of the content is drawn: 1 in front of the deck or while
/// it is expanded, 0 once the collapsed deck covers the toast. The card keeps
/// its surface and border either way, so the deck stays a pile of cards — only
/// what is written on them goes. sonner fades the children of a collapsed
/// non-front toast the same way, and only for its own styled look.
class DefaultToastLook extends StatelessWidget {
  const DefaultToastLook({super.key, required this.state, required this.fade});

  final ToastState state;
  final Animation<double> fade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    final description = state.description;

    return Material(
      color: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: FadeTransition(
        opacity: fade,
        // A covered toast is still on screen and still a live region: what the
        // deck hides is the reading, not the announcement.
        alwaysIncludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                state.title,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 2),
                Text(
                  description,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
