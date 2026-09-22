import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:just_sonner/just_sonner.dart';

import 'flash_adapter.dart';

/// A look of the example's own: a dark card, given apart from what is written
/// on it, so the package fits the text to the card and fades it while the
/// deck covers the toast.
final ToastBuilder ownLook = toastCardBuilder(
  card: (context, toast, child) => Material(
    color: Theme.of(context).colorScheme.inverseSurface,
    borderRadius: BorderRadius.circular(12),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
  content: (context, toast) {
    final onCard = Theme.of(context).colorScheme.onInverseSurface;
    final description = toast.state.description;
    return Row(
      children: [
        Icon(Icons.rocket_launch, color: onCard),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(toast.state.title, style: TextStyle(color: onCard)),
              if (description != null)
                Text(description, style: TextStyle(color: onCard)),
            ],
          ),
        ),
      ],
    );
  },
);

/// A `FlashBar` through the adapter, its text faded by `covered`, with
/// flash's own swipe or the toast's.
ToastBuilder flashBar({required bool swipe}) =>
    flashToast((context, controller, toast) {
      final shown = ReverseAnimation(toast.covered);
      return FlashBar(
        controller: controller,
        dismissDirections: swipe ? FlashDismissDirection.values : const [],
        title: FadeTransition(opacity: shown, child: const Text('FlashBar')),
        content: FadeTransition(opacity: shown, child: Text(toast.state.title)),
      );
    });

/// An app's own dismiss-all control, handed the count and a way to dismiss.
Widget ownDismissAll(BuildContext context, DeckDismissAllView view) =>
    FadeTransition(
      opacity: view.expansion,
      child: Material(
        color: Colors.transparent,
        child: TextButton.icon(
          onPressed: view.dismiss,
          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
          label: Text('Dismiss ${view.count}'),
        ),
      ),
    );

String koreanCount(int count) => '알림 $count개';

/// An app's own hide control, handed the count and a way to hide.
Widget ownHide(BuildContext context, DeckHideView view) => FadeTransition(
  opacity: view.expansion,
  child: Material(
    color: Colors.transparent,
    child: TextButton.icon(
      onPressed: view.hide,
      icon: const Icon(Icons.visibility_off_outlined, size: 18),
      label: Text('Put ${view.count} away'),
    ),
  ),
);

/// An app's own motion: the deck spins a quarter turn as it goes.
Widget ownHideMotion(
  BuildContext context,
  DeckHideMotionView view,
  Widget deck,
) => Opacity(
  opacity: 1 - view.hidden.value,
  child: Transform.rotate(
    angle: view.hidden.value * 0.25,
    alignment: view.position.isTop
        ? Alignment.topCenter
        : Alignment.bottomCenter,
    child: deck,
  ),
);

/// An app's own empty card, fading in with the zone.
Widget ownEmpty(BuildContext context, ZoneEmptyView view) => FadeTransition(
  opacity: view.shown,
  child: const Card(
    child: ListTile(
      leading: Icon(Icons.inbox_outlined),
      title: Text('All caught up'),
    ),
  ),
);
