import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'
    show PointerEnterEventListener, PointerExitEventListener;
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
  static const _expandDuration = Duration(milliseconds: 400);

  /// Newest first, as the controller orders its toasts.
  List<_Slot> _slots = [];

  /// The pointer devices over the deck. While there are any, this host holds
  /// the controller's timers.
  final Set<int> _pointers = {};

  bool get _hovered => _pointers.isNotEmpty;

  /// Where the deck is, for hit testing: the toasts in the window, or every
  /// toast while the pointer is over it, and those exiting, and the gaps
  /// between them, as last laid out and cut to the layer.
  Rect _deck = Rect.zero;

  /// How far the deck is fanned out, from 0 collapsed to 1 expanded.
  late final _Eased _expand = _Eased(this, _expandTarget);

  double get _expandTarget =>
      _hovered || _controller.config.expandByDefault ? 1 : 0;

  /// How far the toasts beyond the window are drawn, from 0 hidden to 1 in
  /// full: they are while the pointer is over the deck.
  late final _Eased _reveal = _Eased(this, _revealTarget);

  double get _revealTarget => _hovered ? 1 : 0;

  final ScrollController _scroll = ScrollController();

  /// How far the deck was scrolled when the pointer left it; the scroll is
  /// back at the edge, and the deck is drawn this much of the way there.
  double _unscrollFrom = 0;
  late final _Eased _unscroll = _Eased(this, 1);

  /// The toast the scroll keeps in place while the pointer is over the deck,
  /// its distance from the edge before scrolling, and the scroll, as last laid
  /// out.
  _Slot? _anchor;
  double _anchorAt = 0;
  double _anchorPixels = 0;

  SonnerController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onToastsChanged);
    watchLifecycle(_controller);
    _sync();
  }

  @override
  void didUpdateWidget(ToastLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.controller;
    if (identical(previous, _controller)) return;
    previous.removeListener(_onToastsChanged);
    _controller.addListener(_onToastsChanged);
    watchLifecycle(_controller);
    if (_hovered) {
      releaseTimers(previous, this);
      holdTimers(_controller, this);
    }
    // Another controller's toasts are another deck, and start at the edge.
    _anchor = null;
    _anchorPixels = 0;
    _unscrollFrom = 0;
    _unscroll.jump(1);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _retarget();
    _sync();
  }

  @override
  void dispose() {
    _controller.removeListener(_onToastsChanged);
    // A region unmounted under the pointer reports no exit.
    if (_hovered) releaseTimers(_controller, this);
    for (final slot in _slots) {
      slot.dispose();
    }
    _expand.dispose();
    _reveal.dispose();
    _unscroll.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onToastsChanged() => setState(_sync);

  void _setPointer(int device, {required bool over}) {
    final was = _hovered;
    if (over) {
      _pointers.add(device);
    } else {
      _pointers.remove(device);
    }
    final hovered = _hovered;
    if (hovered == was) return;
    if (hovered) {
      holdTimers(_controller, this);
    } else {
      releaseTimers(_controller, this);
      _unscrollDeck();
    }
    _retarget();
  }

  /// Puts the scroll back at the edge, and eases the deck there over
  /// [_expandDuration] from where it was scrolled to.
  void _unscrollDeck() {
    _anchor = null;
    if (!_scroll.hasClients) return;
    final pixels = _scroll.position.pixels + _unscrolled;
    if (pixels == 0) return;
    _unscrollFrom = pixels;
    _scroll.jumpTo(0);
    _unscroll
      ..jump(0)
      ..retarget(1, _expandDuration);
  }

  /// How far the deck is drawn short of its scroll, on the way to the edge.
  double get _unscrolled => _unscrollFrom * (1 - _unscroll.value);

  /// Eases the deck from wherever it is toward expanded or collapsed, and the
  /// toasts beyond the window toward drawn or hidden, over [_expandDuration],
  /// when where each is headed has changed.
  void _retarget() {
    _expand.retarget(_expandTarget, _expandDuration);
    _reveal.retarget(_revealTarget, _expandDuration);
  }

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
        _expand,
        _reveal,
        _unscroll,
        for (final slot in _slots) ...[slot.animation, slot.resize],
      ]),
      builder: (context, _) => _buildDeck(context, config),
    );
  }

  Widget _buildDeck(BuildContext context, SonnerConfig config) {
    // An exiting toast keeps the depth it had when it was dismissed, and does
    // not count towards the window.
    //
    // The toasts entering and leaving run on clocks of different lengths, so
    // their presences can add up to more or less than either end; a depth
    // only ever moves toward its place, and stops there. A lift, the heights
    // of the toasts in front counted the same way, moves by the same rule.
    final expansion = _expand.value;
    final visible = config.visibleToasts;
    final hovered = _hovered;
    var sum = 0.0;
    var index = 0;
    var lifted = 0.0;
    var liftPlace = 0.0;
    // How much the toasts in front cover this one, the same running product
    // the deck's layout takes: 0 for the front, 1 behind one fully present.
    var covered = 0.0;
    for (final slot in _slots) {
      final covers = (slot.exiting ? slot.covers : slot.covering) ?? 0;
      if (!slot.exiting) {
        slot
          ..depth = _toward(slot.drawn ? slot.depth : sum, index, sum)
          ..lift = _toward(slot.drawn ? slot.lift : lifted, liftPlace, lifted)
          // A toast more than 20 deep would scale past nothing while the deck
          // collapses with it drawn.
          ..scale = math.max(0, 1 - 0.05 * slot.depth * (1 - expansion))
          ..drawn = true
          ..inDeck = index < visible || hovered
          ..index = index++;
        // Covered content is not drawn, and the expansion brings it back: the
        // deck fanned out draws every toast at its own height, to be read.
        slot.contentFade.value = 1 - covered * (1 - expansion);
        liftPlace += covers;
      }
      covered += (1 - covered) * slot.animation.value;
      sum += slot.animation.value;
      lifted += slot.animation.value * covers;
    }

    final reveal = _reveal.value;
    for (final slot in _slots) {
      slot.hidden =
          reveal == 0 &&
          (slot.exiting || slot.index >= visible) &&
          slot.depth >= visible;
    }
    final isTop = config.position.isTop;
    return _DeckRegion(
      deck: () => _deck,
      onEnter: (event) => _setPointer(event.device, over: true),
      onExit: (event) => _setPointer(event.device, over: false),
      child: NotificationListener<Notification>(
        // The deck's scroll is its own: an app watching for its content
        // scrolling under an app bar must not hear it.
        onNotification: (notification) => switch (notification) {
          ScrollNotification(:final context?) ||
          ScrollMetricsNotification(:final context) => identical(
            Scrollable.maybeOf(context)?.position,
            _scroll.position,
          ),
          _ => false,
        },
        child: Scrollable(
          controller: _scroll,
          axisDirection: isTop ? AxisDirection.down : AxisDirection.up,
          hitTestBehavior: HitTestBehavior.deferToChild,
          excludeFromSemantics: true,
          scrollBehavior: ScrollConfiguration.of(
            context,
          ).copyWith(scrollbars: false, overscroll: false),
          viewportBuilder: (context, position) => CustomMultiChildLayout(
            delegate: ToastDeckDelegate<_Slot>(
              config: config,
              order: _slots,
              expansion: expansion,
              presence: (slot) => slot.animation.value,
              depth: (slot) => slot.depth,
              lift: (slot) => slot.lift,
              natural: (slot) => slot.natural,
              covering: (slot) => slot.covering,
              pinned: (slot) => slot.pinned,
              inDeck: (slot) => slot.inDeck,
              onPlaced: (slot, height, covering, distance, place) => slot
                ..height = height
                ..covers = covering
                ..distance = distance
                ..place = place,
              onDeck: (deck) => _deck = deck,
              scroll: position,
              follows: hovered,
              unscrolled: _unscrolled,
              // Read at layout, which a scroll runs without a build.
              anchor: () => _hovered && _expand.value == 1
                  ? (id: _anchor, distance: _anchorAt, pixels: _anchorPixels)
                  : null,
              onAnchor: (slot, distance, pixels) {
                _anchor = slot;
                _anchorAt = distance;
                _anchorPixels = pixels;
              },
              backdrop: _backdrop,
            ),
            children: [
              LayoutId(id: _backdrop, child: const _Backdrop()),
              // Oldest first: children paint in order, so the newest is on top.
              for (final slot in _slots.reversed)
                LayoutId(id: slot, child: _buildToast(slot, config, visible)),
            ],
          ),
        ),
      ),
    );
  }

  /// The layout id of the box behind the deck that takes the wheel in the
  /// gaps between toasts.
  static const _backdrop = #backdrop;

  /// [value] kept between [from] and [place], so it only moves toward
  /// [place].
  static double _toward(double from, num place, double value) {
    final to = place.toDouble();
    return from < to ? value.clamp(from, to) : value.clamp(to, from);
  }

  Widget _buildToast(_Slot slot, SonnerConfig config, int visible) {
    // A toast crossing the edge of the window fades as it moves across it,
    // unless the pointer over the deck is drawing every toast.
    final reveal = _reveal.value;
    final fade = reveal + (1 - reveal) * (visible - slot.depth).clamp(0.0, 1.0);
    return Offstage(
      offstage: slot.hidden,
      child: IgnorePointer(
        ignoring: !slot.inDeck,
        child: Opacity(
          opacity: fade,
          child: FadeTransition(
            opacity: slot.animation,
            child: SlideTransition(
              position: slot.slide(fromTop: config.position.isTop),
              child: Transform.scale(
                scale: slot.scale,
                child: ToastHeight(
                  onMeasured: slot.measured,
                  child: slot.contentIn(config),
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

  /// The heights of the toasts in front of this one, each counted by its
  /// presence, that the expanded deck lifts it by. Frozen once it is
  /// [exiting].
  double lift = 0;

  /// The scale it is drawn at. Frozen once it is [exiting].
  double scale = 1;

  /// Whether [depth] has been worked out at least once.
  bool drawn = false;

  /// How much of its content the look draws: 1 in front of the collapsed deck
  /// or anywhere in the expanded one, 0 once a toast in front covers it. The
  /// card is not faded, so the deck stays a pile of cards. Frozen once it is
  /// [exiting], with the rest of what the deck drew it with.
  final _Driven contentFade = _Driven(1);

  /// Its place among the toasts that are not exiting, newest first. Frozen
  /// once it is [exiting].
  int index = 0;

  /// Whether it is part of the deck: in the window, or anywhere while the
  /// pointer is over the deck. It takes taps and counts towards the hover
  /// region only then. Frozen once it is [exiting].
  bool inDeck = true;

  /// Whether it is outside the window and faded out, so neither painted nor
  /// laid out anew.
  bool hidden = false;

  /// The height it was last drawn at. Frozen once it is [exiting].
  double? height;

  /// The height it last covered the toasts behind it with. Frozen once it is
  /// [exiting].
  double? covers;

  /// Its distance from the screen edge as last laid out. Frozen once it is
  /// [exiting].
  double? distance;

  /// Its distance from the edge before scrolling, as last laid out. Frozen
  /// once it is [exiting].
  double? place;

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
  /// [hidden], and its distance from the edge while it is [exiting]; null
  /// when it is laid out anew.
  ({double height, double covering, double? distance, double? place})?
  get pinned {
    final height = this.height;
    final covers = this.covers;
    if (!(exiting || hidden) || height == null || covers == null) return null;
    return (
      height: height,
      covering: covers,
      distance: exiting ? distance : null,
      place: exiting ? place : null,
    );
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
  SonnerConfig? _shownWith;
  Widget? _content;

  /// What the toast shows. Built again only when the record's state changes,
  /// or the config the look reads does, so an animation frame that moves the
  /// toast does not rebuild it; a new state fades in over the old one.
  Widget contentIn(SonnerConfig config) {
    final state = record.state;
    if (!identical(state, _shown) || config != _shownWith) {
      _shown = state;
      _shownWith = config;
      _content = Semantics(
        liveRegion: true,
        child: ContentFade(
          duration: _fadeDuration,
          child: DefaultToastLook(
            key: ObjectKey(state),
            state: state,
            config: config,
            fade: contentFade,
          ),
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

/// A value eased, `ease`, from wherever it is toward where it is headed.
class _Eased extends ChangeNotifier {
  _Eased(TickerProvider vsync, double value)
    : _from = value,
      _to = value,
      _progress = AnimationController(vsync: vsync, value: 1) {
    _progress.addListener(notifyListeners);
  }

  /// Runs from 0 to 1 while [value] eases from [_from] to [_to].
  final AnimationController _progress;
  double _from;
  double _to;

  double get value =>
      _from + (_to - _from) * Curves.ease.transform(_progress.value);

  /// Eases toward [target] over [duration], from wherever it is, when that is
  /// not already where it is headed.
  void retarget(double target, Duration duration) {
    if (target == _to) return;
    _from = value;
    _to = target;
    _progress.animateWith(_Progress(duration));
  }

  /// Puts it at [value] at once.
  void jump(double value) {
    _progress.stop();
    _from = value;
    _to = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }
}

/// Takes the pointer where it is laid out and draws nothing.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) =>
      const MetaData(behavior: HitTestBehavior.opaque);
}

/// An [Animation] whose value is set from outside, for one that follows the
/// whole deck rather than a clock of its own.
///
/// It is set while the deck builds, which a [FadeTransition] answers by
/// repainting rather than rebuilding — so the toast it belongs to keeps the
/// cached content that made [_Slot.content] worth caching.
class _Driven extends Animation<double>
    with AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {
  _Driven(this._value);

  double _value;

  @override
  double get value => _value;

  set value(double next) {
    if (next == _value) return;
    final was = status;
    _value = next;
    notifyListeners();
    if (status != was) notifyStatusListeners(status);
  }

  @override
  AnimationStatus get status {
    if (_value <= 0) return AnimationStatus.dismissed;
    if (_value >= 1) return AnimationStatus.completed;
    return AnimationStatus.forward;
  }

  @override
  void didRegisterListener() {}

  @override
  void didUnregisterListener() {}
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

/// A [MouseRegion] over the part of its child that [deck] names, gaps
/// included. It takes the taps that land there.
class _DeckRegion extends SingleChildRenderObjectWidget {
  const _DeckRegion({
    required this.deck,
    required this.onEnter,
    required this.onExit,
    super.child,
  });

  final Rect Function() deck;
  final PointerEnterEventListener onEnter;
  final PointerExitEventListener onExit;

  @override
  _RenderDeckRegion createRenderObject(BuildContext context) =>
      _RenderDeckRegion(deck, onEnter: onEnter, onExit: onExit);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDeckRegion renderObject,
  ) => renderObject
    ..deck = deck
    ..onEnter = onEnter
    ..onExit = onExit;
}

class _RenderDeckRegion extends RenderMouseRegion {
  _RenderDeckRegion(this.deck, {super.onEnter, super.onExit});

  Rect Function() deck;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final hitChild = hitTestChildren(result, position: position);
    final inDeck = deck().contains(position);
    if (inDeck) result.add(BoxHitTestEntry(this, position));
    return hitChild || inDeck;
  }
}
