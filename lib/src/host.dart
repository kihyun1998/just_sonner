import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'default_look.dart';
import 'stack_layout.dart';

/// Mount mode 2: draws [controller]'s toasts above [child], or the exported
/// `toast`'s when [controller] is null.
class SonnerHost extends StatefulWidget {
  const SonnerHost({super.key, this.controller, required this.child});

  final SonnerController? controller;
  final Widget child;

  @override
  State<SonnerHost> createState() => _SonnerHostState();
}

class _SonnerHostState extends State<SonnerHost> with TickerProviderStateMixin {
  static const _enterDuration = Duration(milliseconds: 400);
  static const _exitDuration = Duration(milliseconds: 200);

  /// Newest first, as the controller orders its toasts.
  List<_Slot> _slots = [];

  SonnerController get _controller => widget.controller ?? toast;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onToastsChanged);
    _sync();
  }

  @override
  void didUpdateWidget(SonnerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.controller ?? toast;
    if (identical(previous, _controller)) return;
    previous.removeListener(_onToastsChanged);
    _controller.addListener(_onToastsChanged);
    _sync();
  }

  @override
  void dispose() {
    _controller.removeListener(_onToastsChanged);
    for (final slot in _slots) {
      slot.dispose();
    }
    super.dispose();
  }

  void _onToastsChanged() => setState(_sync);

  /// Matches the slots to the controller's toasts. A toast the controller no
  /// longer holds keeps its slot, in its place, until its exit animation ends.
  void _sync() {
    final existing = {for (final slot in _slots) slot.record: slot};
    final next = [
      for (final record in toastsOf(_controller))
        existing.remove(record) ?? _enter(record),
    ];

    // Walk the old order backwards, so each exiting slot goes in front of the
    // slot that followed it.
    final leaving = <_Slot>[];
    for (var i = _slots.length - 1; i >= 0; i--) {
      final slot = _slots[i];
      if (!existing.containsKey(slot.record)) continue;
      final follower = i + 1 < _slots.length ? next.indexOf(_slots[i + 1]) : -1;
      next.insert(follower < 0 ? next.length : follower, slot);
      if (!slot.exiting) leaving.add(slot);
    }
    _slots = next;

    // After the assignment: a toast that has not entered at all reports
    // `dismissed` synchronously, and removes itself from `_slots` as it does.
    for (final slot in leaving) {
      _exit(slot);
    }
  }

  _Slot _enter(ToastRecord record) {
    final controller = AnimationController(
      vsync: this,
      duration: _enterDuration,
    );
    return _Slot(record, controller..forward());
  }

  /// Runs the exit over the full [_exitDuration] from wherever the enter got
  /// to, then removes the slot.
  void _exit(_Slot slot) {
    slot.exiting = true;
    slot.controller
      ..addStatusListener((status) {
        if (status != AnimationStatus.dismissed) return;
        setState(() => _slots.remove(slot));
        slot.dispose();
      })
      ..animateBack(0, duration: _exitDuration);
  }

  @override
  Widget build(BuildContext context) {
    final config = _controller.config;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: CustomMultiChildLayout(
            delegate: ToastStackDelegate<_Slot>(
              config: config,
              order: _slots,
              presence: (slot) => slot.animation.value,
              pinned: (slot) => slot.exiting ? slot.fromEdge : null,
              onPlaced: (slot, fromEdge) => slot.fromEdge = fromEdge,
              relayout: Listenable.merge([
                for (final slot in _slots) slot.animation,
              ]),
            ),
            // Oldest first: children paint in order, so the newest is on top.
            children: [
              for (final slot in _slots.reversed)
                LayoutId(
                  id: slot,
                  child: FadeTransition(
                    opacity: slot.animation,
                    child: SlideTransition(
                      position: slot.animation.drive(
                        Tween(
                          begin: Offset(0, config.position.isTop ? -1 : 1),
                          end: Offset.zero,
                        ),
                      ),
                      child: Semantics(
                        liveRegion: true,
                        child: DefaultToastLook(state: slot.record.state),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A toast as the host draws it: the controller's record, and the animation
/// that brings it in and takes it out.
class _Slot {
  _Slot(this.record, this.controller)
    : animation = CurvedAnimation(parent: controller, curve: Curves.ease);

  final ToastRecord record;
  final AnimationController controller;
  final CurvedAnimation animation;

  /// Whether the controller has let go of this toast and its exit has started.
  bool exiting = false;

  /// How far from the screen edge the toast was last laid out. Frozen once it
  /// is [exiting], so the toasts moving around it do not carry it along.
  double? fromEdge;

  void dispose() {
    animation.dispose();
    controller.dispose();
  }
}
