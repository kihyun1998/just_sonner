import 'package:flutter/material.dart';

import 'config.dart';
import 'time_left.dart';
import 'toast_view.dart';

/// The look a toast has when no builder replaces it.
///
/// Colours and text come from the ambient [Theme]; padding, the title's weight
/// and the gap under it follow sonner's styled toast. A toast counting down
/// draws its time left as `config.timeLeft` says.
///
/// [fade] is how much of the content is drawn: 1 in front of the deck or while
/// it is expanded, 0 once the collapsed deck covers the toast. The card keeps
/// its surface and border either way, so the deck stays a pile of cards — only
/// what is written on them goes. sonner fades the children of a collapsed
/// non-front toast the same way, and only for its own styled look.
class DefaultToastLook extends StatelessWidget {
  const DefaultToastLook({
    super.key,
    required this.toast,
    required this.config,
    required this.fade,
    required this.pressable,
  });

  /// The toast this draws, and what the `action` slot is handed.
  final ToastView toast;

  /// Read for the leading slot, the close button and their sizes.
  final SonnerConfig config;

  final Animation<double> fade;

  /// Whether the buttons are there to be used. They are not while the deck
  /// covers the toast: what is not drawn is not pressable, or an invisible
  /// button in the strip a covered toast leaves above the front would answer a
  /// press aimed at nothing.
  ///
  /// A covered toast announces its **content** and not its controls, so the
  /// buttons leave the semantics tree along with the pointer. The card goes on
  /// taking taps, so the deck still stops a press reaching the app underneath,
  /// and the title and description keep their place — but a screen reader is
  /// not offered a Close that does nothing, nor told the word at all.
  final bool pressable;

  /// The space between the leading slot and the title. Provisional, like the
  /// rest of §9's dimensions: settled by feel in the example app.
  static const _slotGap = 12.0;

  /// The space between the text and the action slot.
  static const _actionGap = 12.0;

  static const _radius = 8.0;

  /// The time left drawn over the card: faded with the content while the deck
  /// covers the toast, unless [drawn] keeps it on the card.
  Widget _covered(ToastTimeLeft drawn, Widget child) => drawn.fadeWhenCovered
      ? FadeTransition(opacity: fade, child: child)
      : child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    final state = toast.state;
    final description = state.description;
    // While it is loading the slot holds the indicator, whatever `leading` is.
    final leading = state.isLoading ? config.loadingIndicator : state.leading;
    final action = state.action;
    final closeButton = state.closeButtonNow(config.closeButton);
    final timeLeft = toast.timeLeft;
    final drawn = timeLeft == null ? null : config.timeLeft;
    final color = drawn?.color ?? colors.primary;
    final textDirection = Directionality.of(context);
    final ring = timeLeft == null || drawn == null
        ? null
        : TimeLeftRingPainter(
            timeLeft: timeLeft,
            color: color,
            strokeWidth: drawn.strokeWidth,
          );
    final ringed = drawn?.look == TimeLeftLook.leadingRing;

    final content = FadeTransition(
      opacity: fade,
      // A covered toast is still on screen and still a live region: what
      // the deck hides is the reading, not the announcement.
      alwaysIncludeSemantics: true,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A toast with neither a leading widget nor the indicator
                // has no slot at all, so its title starts at the padding
                // edge.
                if (leading != null || ringed) ...[
                  SizedBox.square(
                    dimension: config.leadingSize,
                    child: ringed
                        ? CustomPaint(
                            painter: ring,
                            child: Center(
                              // Inside the ring rather than under it.
                              child: leading == null
                                  ? null
                                  : Transform.scale(scale: 0.6, child: leading),
                            ),
                          )
                        : Center(child: leading),
                  ),
                  const SizedBox(width: _slotGap),
                ],
                Expanded(
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
                if (action != null) ...[
                  const SizedBox(width: _actionGap),
                  _Usable(pressable, child: action(context, toast)),
                ],
              ],
            ),
          ),
          if (closeButton)
            Positioned(
              top: 0,
              right: 0,
              child: _Usable(
                pressable,
                child: _CloseButton(onPressed: toast.dismiss),
              ),
            ),
        ],
      ),
    );

    return Material(
      color: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        // A border sweep without keepBorder is the card's border itself.
        side: drawn?.look == TimeLeftLook.border && !drawn!.keepBorder
            ? BorderSide.none
            : BorderSide(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: timeLeft == null || drawn == null || ringed
          ? content
          : Stack(
              children: [
                content,
                if (drawn.look == TimeLeftLook.cornerRing)
                  PositionedDirectional(
                    end: 8,
                    bottom: 8,
                    width: 12,
                    height: 12,
                    child: _covered(drawn, CustomPaint(painter: ring)),
                  )
                else
                  Positioned.fill(
                    child: _covered(
                      drawn,
                      CustomPaint(
                        painter: switch (drawn.look) {
                          TimeLeftLook.bottomBar ||
                          TimeLeftLook.topBar => TimeLeftBarPainter(
                            timeLeft: timeLeft,
                            color: color,
                            strokeWidth: drawn.strokeWidth,
                            atTop: drawn.look == TimeLeftLook.topBar,
                            textDirection: textDirection,
                            radius: _radius,
                          ),
                          _ => TimeLeftBorderPainter(
                            timeLeft: timeLeft,
                            color: color,
                            strokeWidth: drawn.strokeWidth,
                            start: drawn.start,
                            clockwise: drawn.clockwise,
                            textDirection: textDirection,
                            radius: _radius,
                          ),
                        },
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// The X in the corner: the package's own, since it is the pointer equivalent
/// of a swipe rather than caller content.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // A label rather than a tooltip: a tooltip needs an Overlay above it, and
    // in mount mode 2 the host sits above the app's Navigator, so there is
    // none. sonner labels its close button the same way (`aria-label`).
    return Semantics(
      label: MaterialLocalizations.of(context).closeButtonTooltip,
      child: IconButton(
        onPressed: onPressed,
        iconSize: 14,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        icon: Icon(Icons.close, color: colors.onSurfaceVariant),
      ),
    );
  }
}

/// A control that is only there while the toast it sits on is drawn: out of
/// the pointer's reach and out of the semantics tree otherwise.
class _Usable extends StatelessWidget {
  const _Usable(this.usable, {required this.child});

  final bool usable;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    excluding: !usable,
    child: IgnorePointer(ignoring: !usable, child: child),
  );
}
