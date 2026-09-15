import 'package:flutter/widgets.dart';

import 'config.dart';
import 'content_fade.dart';
import 'controller.dart';
import 'default_look.dart';
import 'deck_layout.dart';
import 'toast_state.dart';

/// Mount mode 2: draws [controller]'s toasts above [child], or the exported
/// `toast`'s when [controller] is null.
class SonnerHost extends StatelessWidget {
  const SonnerHost({super.key, this.controller, required this.child});

  final SonnerController? controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      Positioned.fill(child: ToastLayer(controller: controller ?? toast)),
    ],
  );
}

/// Lays out and animates [controller]'s toasts over whatever it is given to
/// fill. Both mount modes draw their toasts with one.
class ToastLayer extends StatefulWidget {
  const ToastLayer({super.key, required this.controller});

  final SonnerController controller;

  @override
  State<ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends State<ToastLayer> with TickerProviderStateMixin {
  static const _enterDuration = Duration(milliseconds: 400);
  static const _exitDuration = Duration(milliseconds: 200);

  /// Newest first, as the controller orders its toasts.
  List<_Slot> _slots = [];

  SonnerController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onToastsChanged);
    _sync();
  }

  @override
  void didUpdateWidget(ToastLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.controller;
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
    return _Slot(
      record,
      controller..forward(),
      AnimationController(vsync: this),
    );
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
    return ListenableBuilder(
      listenable: Listenable.merge([
        for (final slot in _slots) ...[slot.animation, slot.resize],
      ]),
      builder: (context, _) => _buildDeck(config),
    );
  }

  Widget _buildDeck(SonnerConfig config) {
    // An exiting toast keeps the depth it had when it was dismissed, and does
    // not count towards the window.
    //
    // The toasts entering and leaving run on clocks of different lengths, so
    // their presences can add up to more or less than either end; a depth
    // only ever moves toward its place, and stops there.
    var sum = 0.0;
    var index = 0;
    for (final slot in _slots) {
      if (!slot.exiting) {
        final from = slot.drawn ? slot.depth : sum;
        final place = index.toDouble();
        slot.depth = from < place
            ? sum.clamp(from, place)
            : sum.clamp(place, from);
        slot.drawn = true;
        slot.index = index++;
      }
      sum += slot.animation.value;
    }

    final visible = config.visibleToasts;
    for (final slot in _slots) {
      slot.hidden =
          (slot.exiting || slot.index >= visible) && slot.depth >= visible;
    }
    return CustomMultiChildLayout(
      delegate: ToastDeckDelegate<_Slot>(
        config: config,
        order: _slots,
        presence: (slot) => slot.animation.value,
        depth: (slot) => slot.depth,
        natural: (slot) => slot.natural,
        covering: (slot) => slot.covering,
        pinned: (slot) => slot.pinned,
        onPlaced: (slot, height, covering) => slot
          ..height = height
          ..covers = covering,
      ),
      // Oldest first: children paint in order, so the newest is on top.
      children: [
        for (final slot in _slots.reversed)
          LayoutId(id: slot, child: _buildToast(slot, config, visible)),
      ],
    );
  }

  Widget _buildToast(_Slot slot, SonnerConfig config, int visible) {
    // A toast crossing the edge of the window fades as it moves across it.
    final fade = (visible - slot.depth).clamp(0.0, 1.0);
    return Offstage(
      offstage: slot.hidden,
      child: IgnorePointer(
        ignoring: slot.index >= visible,
        child: Opacity(
          opacity: fade,
          child: FadeTransition(
            opacity: slot.animation,
            child: SlideTransition(
              position: slot.slide(fromTop: config.position.isTop),
              child: Transform.scale(
                scale: 1 - 0.05 * slot.depth,
                child: ToastHeight(
                  onMeasured: slot.measured,
                  child: slot.content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A toast as the host draws it: the controller's record, and the animations
/// that bring it in and take it out and that ease the height it covers with.
class _Slot {
  _Slot(this.record, this.controller, this.resize)
    : animation = CurvedAnimation(parent: controller, curve: Curves.ease),
      _resizeCurve = CurvedAnimation(parent: resize, curve: Curves.ease);

  static const _fadeDuration = Duration(milliseconds: 200);
  static const _resizeDuration = Duration(milliseconds: 400);

  final ToastRecord record;
  final AnimationController controller;
  final CurvedAnimation animation;

  /// Runs from 0 to 1 while [covering] eases from the height the toast had to
  /// the height it measures now.
  final AnimationController resize;
  final CurvedAnimation _resizeCurve;

  /// Whether the controller has let go of this toast and its exit has started.
  bool exiting = false;

  /// How many toasts sit in front of this one, each counted by its presence.
  /// Frozen once it is [exiting], so the toasts moving around it do not carry
  /// it along.
  double depth = 0;

  /// Whether [depth] has been worked out at least once.
  bool drawn = false;

  /// Its place among the toasts that are not exiting, newest first. Frozen
  /// once it is [exiting].
  int index = 0;

  /// Whether it is outside the window and faded out, so neither painted nor
  /// laid out anew.
  bool hidden = false;

  /// The height it was last drawn at. Frozen once it is [exiting].
  double? height;

  /// The height it last covered the toasts behind it with. Frozen once it is
  /// [exiting].
  double? covers;

  /// The height it last measured on its own, whatever it was drawn at.
  double? natural;

  /// Where [covering] eases from.
  double _resizeFrom = 0;

  /// The height the toast covers the ones behind it with: its [natural]
  /// height, or on the way to it for 400 ms after that changed.
  double? get covering {
    final natural = this.natural;
    if (natural == null || !resize.isAnimating) return natural;
    return _resizeFrom + (natural - _resizeFrom) * _resizeCurve.value;
  }

  /// The heights it is drawn at and covers with while it is [exiting] or
  /// [hidden], or null when it is laid out anew.
  ({double height, double covering})? get pinned {
    final height = this.height;
    final covers = this.covers;
    if (!(exiting || hidden) || height == null || covers == null) return null;
    return (height: height, covering: covers);
  }

  void measured(double height) {
    final previous = natural;
    if (previous != null && previous != height) {
      _resizeFrom = covering!;
      // Measured during layout. `animateWith` starts from 0 without notifying
      // the builder that is laying the toast out, and counts from this frame.
      resize.animateWith(_Progress(_resizeDuration));
    }
    natural = height;
  }

  ToastState? _shown;
  Widget? _content;

  /// What the toast shows. Built again only when the record's state changes,
  /// so an animation frame that moves the toast does not rebuild it; a new
  /// state fades in over the old one.
  Widget get content {
    final state = record.state;
    if (!identical(state, _shown)) {
      _shown = state;
      _content = Semantics(
        liveRegion: true,
        child: ContentFade(
          duration: _fadeDuration,
          child: DefaultToastLook(key: ObjectKey(state), state: state),
        ),
      );
    }
    return _content!;
  }

  Animation<Offset>? _slide;
  bool? _slideFromTop;

  /// Its enter and exit slide, from the edge [fromTop] names.
  Animation<Offset> slide({required bool fromTop}) {
    if (_slideFromTop != fromTop) {
      _slideFromTop = fromTop;
      _slide = animation.drive(
        Tween(begin: Offset(0, fromTop ? -1 : 1), end: Offset.zero),
      );
    }
    return _slide!;
  }

  void dispose() {
    animation.dispose();
    controller.dispose();
    _resizeCurve.dispose();
    resize.dispose();
  }
}

/// Runs from 0 to 1 over [duration], at a constant rate.
class _Progress extends Simulation {
  _Progress(Duration duration)
    : _seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;

  final double _seconds;

  @override
  double x(double time) => (time / _seconds).clamp(0.0, 1.0);

  @override
  double dx(double time) => time < _seconds ? 1 / _seconds : 0;

  @override
  bool isDone(double time) => time > _seconds;
}
