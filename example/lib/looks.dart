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

/// A see-through card: a 65 % background, a border blue while it asks and
/// green once the node answers, a spinner then a check. It animates its own
/// border, icon and text, which shows when `ContentChange.keep` keeps its
/// element across a change.
final ToastBuilder seeThroughLook = toastCardBuilder(
  card: (context, toast, child) {
    final asking = toast.state.title.contains('Requesting');
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        end: asking ? const Color(0xFF3B82F6) : const Color(0xFF22C55E),
      ),
      duration: const Duration(milliseconds: 300),
      builder: (context, border, child) => Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border!, width: 2),
          ),
          child: child,
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  },
  content: (context, toast) {
    const onCard = Colors.white;
    final description = toast.state.description;
    return Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: toast.state.isLoading
              ? const SizedBox.square(
                  key: ValueKey('loading'),
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: onCard,
                  ),
                )
              : const Icon(
                  Icons.check_circle,
                  key: ValueKey('done'),
                  color: Color(0xFF22C55E),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, ?current],
            ),
            child: Column(
              key: ValueKey(toast.state.title),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(toast.state.title, style: const TextStyle(color: onCard)),
                if (description != null)
                  Text(
                    description,
                    style: const TextStyle(color: Color(0xB3FFFFFF)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  },
);
