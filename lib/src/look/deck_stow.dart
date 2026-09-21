import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../config.dart';
import 'deck_dismiss_all.dart';
import '../stow_view.dart';

/// The deck drawn as far out of sight as [view] says, by the motion
/// [DeckStowMotion] names or by its builder.
///
/// The pointer is kept off a stowed deck by the host, not here.
class DeckStowMotionBox extends StatelessWidget {
  const DeckStowMotionBox({
    super.key,
    required this.motion,
    required this.view,
    required this.deck,
  });

  final DeckStowMotion motion;
  final DeckStowMotionView view;
  final Widget deck;

  /// Where the deck's position puts the corner a shrink pulls toward.
  static Alignment cornerOf(SonnerPosition position) => switch (position) {
    SonnerPosition.topLeft => Alignment.topLeft,
    SonnerPosition.topCenter => Alignment.topCenter,
    SonnerPosition.topRight => Alignment.topRight,
    SonnerPosition.bottomLeft => Alignment.bottomLeft,
    SonnerPosition.bottomCenter => Alignment.bottomCenter,
    SonnerPosition.bottomRight => Alignment.bottomRight,
  };

  @override
  Widget build(BuildContext context) {
    final builder = motion.builder;
    if (builder != null) return builder(context, view, deck);
    final stowed = view.stowed.value;
    final transform = switch (motion.look) {
      DeckStowMotionLook.slide => Matrix4.translationValues(
        0,
        (view.position.isTop ? -1 : 1) * stowed * (view.reach + _past),
        0,
      ),
      DeckStowMotionLook.fade => Matrix4.identity(),
      DeckStowMotionLook.shrink => Matrix4.diagonal3Values(
        1 - _shrinkBy * stowed,
        1 - _shrinkBy * stowed,
        1,
      ),
    };
    return Opacity(
      opacity: 1 - stowed,
      child: _StowTransform(
        transform: transform,
        alignment: cornerOf(view.position),
        child: deck,
      ),
    );
  }

  /// How far past the edge a slide carries the deck, beyond its own reach.
  static const _past = 24.0;

  /// How much of itself a shrink leaves at the end.
  static const _shrinkBy = 0.4;
}

/// A [Transform] the host's tests, which find a toast's own transform by
/// type, do not take for it.
class _StowTransform extends SingleChildRenderObjectWidget {
  const _StowTransform({
    required this.transform,
    required this.alignment,
    super.child,
  });

  final Matrix4 transform;
  final Alignment alignment;

  @override
  RenderTransform createRenderObject(BuildContext context) =>
      RenderTransform(transform: transform, alignment: alignment);

  @override
  void updateRenderObject(BuildContext context, RenderTransform renderObject) =>
      renderObject
        ..transform = transform
        ..alignment = alignment;
}

/// The stow control on its own: the pill or the chevron, or its builder's
/// widget. A [DeckStowLook.header] is drawn by [DeckFarEndBar] instead, since
/// the bar it wants is the one the dismiss-all control shares.
class DeckStowButton extends StatelessWidget {
  const DeckStowButton({
    super.key,
    required this.control,
    required this.count,
    required this.onStow,
    required this.expansion,
    required this.isTop,
  });

  final DeckStowControl control;

  /// How many toasts [onStow] would put away.
  final int count;
  final VoidCallback onStow;

  /// How far the deck is fanned out; the built-in looks fade with it.
  final Animation<double> expansion;

  /// Which way the chevron points: at the edge the deck sits at.
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    final builder = control.builder;
    if (builder != null) {
      return builder(
        context,
        DeckStowView(count: count, stow: onStow, expansion: expansion),
      );
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final side = BorderSide(color: colors.outlineVariant);
    return FadeTransition(
      opacity: expansion,
      child: switch (control.look) {
        DeckStowLook.icon => Material(
          color: colors.surfaceContainerHigh,
          shape: CircleBorder(side: side),
          child: Semantics(
            button: true,
            container: true,
            label: control.label,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onStow,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  isTop ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 20,
                  color: colors.onSurface,
                ),
              ),
            ),
          ),
        ),
        // A header is drawn by the bar, which is where its count goes.
        DeckStowLook.pill || DeckStowLook.header => Material(
          color: colors.surfaceContainerHigh,
          shape: StadiumBorder(side: side),
          child: Semantics(
            button: true,
            container: true,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onStow,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  control.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      },
    );
  }
}

/// The one bar past the deck's far end, drawn when either control asks for a
/// [DeckStowLook.header] or a [DeckDismissAllLook.header]: the count, then
/// whichever of the two controls is showing.
class DeckFarEndBar extends StatelessWidget {
  const DeckFarEndBar({
    super.key,
    required this.width,
    required this.countText,
    required this.expansion,
    this.stow,
    this.dismissAll,
  });

  final double width;
  final String countText;
  final Animation<double> expansion;

  /// The stow control as it sits in the bar, and the dismiss-all control the
  /// same way; either is null while that control is not showing.
  final Widget? stow;
  final Widget? dismissAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return FadeTransition(
      opacity: expansion,
      child: SizedBox(
        width: width,
        child: Material(
          color: colors.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 14, right: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    countText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                ?stow,
                ?dismissAll,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A control's place in a [DeckFarEndBar]: a text button, or the chevron for
/// [DeckStowLook.icon].
class DeckBarButton extends StatelessWidget {
  const DeckBarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;

  /// Drawn in place of the label, which then labels it for semantics.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    if (icon == null) {
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        child: Text(label),
      );
    }
    return IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      tooltip: null,
      icon: Icon(icon, size: 20, semanticLabel: label),
    );
  }
}

/// What a stowed deck leaves at its edge.
class DeckStowHandleButton extends StatelessWidget {
  const DeckStowHandleButton({
    super.key,
    required this.handle,
    required this.count,
    required this.onUnstow,
    required this.shown,
    required this.position,
  });

  final DeckStowHandle handle;
  final int count;
  final VoidCallback onUnstow;

  /// How far the handle is out, 0 with the deck drawn to 1 with it stowed.
  final Animation<double> shown;
  final SonnerPosition position;

  @override
  Widget build(BuildContext context) {
    final view = DeckStowHandleView(
      count: count,
      unstow: onUnstow,
      shown: shown,
      position: position,
    );
    final builder = handle.builder;
    if (builder != null) return builder(context, view);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final label = handle.countLabel?.call(count) ?? '$count hidden';
    return FadeTransition(
      opacity: shown,
      child: Material(
        color: colors.surfaceContainerHigh,
        elevation: 2,
        shape: StadiumBorder(side: BorderSide(color: colors.outlineVariant)),
        child: Semantics(
          button: true,
          container: true,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onUnstow,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    position.isTop
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 18,
                    color: colors.onSurface,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The controls past the deck's far end — the stow control, the dismiss-all
/// control, or both — or null while neither shows.
///
/// The two share one bar where either asks for a header look; otherwise they
/// sit side by side, with the dismiss-all control on the side the position
/// names, and a chevron at the other end of the deck's width.
Widget? farEndControls({
  required SonnerConfig config,
  required Animation<double> expansion,
  required bool showStow,
  required bool showDismissAll,
  required int stowCount,
  required int dismissCount,
  required VoidCallback onStow,
  required VoidCallback onDismissAll,
}) {
  final stow = showStow ? config.stowControl : null;
  final dismiss = showDismissAll ? config.dismissAll : null;
  if (stow == null && dismiss == null) return null;

  // A builder draws whatever it likes, so its control asks for no bar.
  final stowBar =
      stow != null && stow.builder == null && stow.look == DeckStowLook.header;
  final dismissBar =
      dismiss != null &&
      dismiss.builder == null &&
      dismiss.look == DeckDismissAllLook.header;
  final isTop = config.position.isTop;

  Widget? stowAlone() => stow == null
      ? null
      : DeckStowButton(
          control: stow,
          count: stowCount,
          onStow: onStow,
          expansion: expansion,
          isTop: isTop,
        );
  Widget? dismissAlone() => dismiss == null
      ? null
      : DeckDismissAllButton(
          control: dismiss,
          count: dismissCount,
          expansion: expansion,
          width: config.width,
          onDismiss: onDismissAll,
        );

  // A header stow control draws the bar whether or not the dismiss-all
  // control is showing, and takes that control in where it is. A header
  // dismiss-all control on its own keeps drawing its own bar, as it did
  // before there was a stow control at all.
  if (stowBar || (dismissBar && stow != null)) {
    final countLabel = stowBar ? stow.countLabel : dismiss!.countLabel;
    final count = stowBar ? stowCount : dismissCount;
    return DeckFarEndBar(
      width: config.width,
      countText: countLabel?.call(count) ?? '$count notifications',
      expansion: expansion,
      stow: stow.builder != null
          ? stowAlone()
          : DeckBarButton(
              label: stow.label,
              onPressed: onStow,
              icon: stow.look == DeckStowLook.icon
                  ? (isTop
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down)
                  : null,
            ),
      dismissAll: dismiss == null
          ? null
          : dismiss.builder != null
          ? dismissAlone()
          : DeckBarButton(label: dismiss.label, onPressed: onDismissAll),
    );
  }

  if (stow == null) return dismissAlone();
  if (dismiss == null && stow.look != DeckStowLook.icon) return stowAlone();
  if (dismiss == null && stow.builder != null) return stowAlone();

  final onTheLeft = switch (config.position) {
    SonnerPosition.topLeft || SonnerPosition.bottomLeft => true,
    _ => false,
  };
  // A chevron sits at the far end of the deck's width, away from the side the
  // toasts are aligned to; anything else sits beside the dismiss-all control.
  if (stow.look == DeckStowLook.icon && stow.builder == null) {
    return SizedBox(
      width: config.width,
      child: Row(
        children: [
          if (onTheLeft) ...[?dismissAlone(), const Spacer()],
          stowAlone()!,
          if (!onTheLeft) ...[const Spacer(), ?dismissAlone()],
        ],
      ),
    );
  }
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (onTheLeft) ...[?dismissAlone(), const SizedBox(width: 8)],
      stowAlone()!,
      if (!onTheLeft) ...[const SizedBox(width: 8), ?dismissAlone()],
    ],
  );
}
