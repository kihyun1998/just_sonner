import 'package:flutter/material.dart';

import 'toast_state.dart';

/// The look a toast has when no builder replaces it.
///
/// Colours and text come from the ambient [Theme]; padding, the title's weight
/// and the gap under it follow sonner's styled toast.
class DefaultToastLook extends StatelessWidget {
  const DefaultToastLook({super.key, required this.state});

  final ToastState state;

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
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
