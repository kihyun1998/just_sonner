import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart'
    show
        DragStartBehavior,
        DragStartDetails,
        DragUpdateDetails,
        PanGestureRecognizer,
        PointerDeviceKind,
        PointerScrollEvent;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart'
    show SchedulerBinding, SchedulerPhase, Ticker;
import 'package:flutter/services.dart'
    show
        PointerEnterEventListener,
        PointerExitEventListener,
        PointerHoverEventListener;
import 'package:flutter/widgets.dart';

import 'config.dart';
import 'content_fade.dart';
import 'controller.dart';
import 'default_look.dart';
import 'deck_cut.dart';
import 'deck_dismiss_all.dart';
import 'deck_layout.dart';
import 'deck_scrollbar.dart';
import 'deck_stow.dart';
import 'stow_view.dart';
import 'swipe.dart';
import 'time_left.dart';
import 'toast_id.dart';
import 'toast_state.dart';
import 'toast_view.dart';

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
  static const _glideDuration = Duration(milliseconds: 400);

  /// How long a toast let go of short of the threshold takes to come back.
  static const _springDuration = Duration(milliseconds: 400);

  /// A swipe takes pointer drags and never a trackpad pan, which scrolls the
  /// expanded deck instead.
  static const _swipeDevices = {
    PointerDeviceKind.mouse,
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };

  /// The slide of a toast that stays where it is put.
  static const _still = AlwaysStoppedAnimation(Offset.zero);

  /// Newest first, as the controller orders its toasts.
  List<_Slot> _slots = [];

  /// The pointer devices over the deck's hover region, moved or not.
  final Set<int> _pointers = {};

  /// The pointer devices that have moved, pressed or scrolled over the deck
  /// since they entered its hover region. While there are any, this host
  /// holds the controller's timers and fans the deck out. A pointer the deck
  /// appeared under, and that has not moved since, is not among them.
  final Set<int> _moved = {};

  bool get _hovered => _moved.isNotEmpty;

  /// The pointer devices pressed on the deck. A press keeps the deck as it
  /// found it until it lets go, wherever it travels in between — dragging a
  /// toast out from under the pointer must not fold the deck up around the
  /// hand doing it.
  final Set<int> _pressed = {};

  /// Whether the deck is under a pointer, or under a press that started
  /// there: it is fanned out, draws every toast and keeps its scroll while
  /// either holds.
  bool get _interacting => _hovered || _pressed.isNotEmpty;

  /// Where the deck is, for hit testing: the toasts in the window, or every
  /// toast while the pointer is over it, and those exiting, and the gaps
  /// between them, as last laid out and cut to the layer.
  Rect _deck = Rect.zero;

  /// How far the deck is fanned out, from 0 collapsed to 1 expanded.
  late final _Eased _expand = _Eased(this, _expandTarget);

  double get _expandTarget =>
      _interacting || _controller.config.expandByDefault ? 1 : 0;

  /// How far the toasts beyond the window are drawn, from 0 hidden to 1 in
  /// full: they are while the pointer is over the deck.
  late final _Eased _reveal = _Eased(this, _revealTarget);

  double get _revealTarget => _interacting ? 1 : 0;

  final ScrollController _scroll = ScrollController();

  /// How far the deck was scrolled when the pointer left it; the scroll is
  /// back at the edge, and the deck is drawn this much of the way there.
  double _unscrollFrom = 0;
  late final _Eased _unscroll = _Eased(this, 1);

  /// Where the deck is cut, as its layout last reported.
  final _cut = ValueNotifier<DeckCut?>(null);

  /// The scrollbar's thumb as the deck last laid it out, for turning a drag
  /// into a scroll.
  DeckScrollbarGeometry? _thumb;

  /// How much of a scrollbar that is not always shown is showing: all of it
  /// while the deck scrolls, fading out a moment after.
  late final _scrollbarShown = AnimationController(
    vsync: this,
    duration: _scrollbarFade,
  );
  Timer? _scrollbarHide;

  /// Material's desktop scrollbar: shown for 600 ms after a scroll, then
  /// faded over 300 ms.
  static const _scrollbarLinger = Duration(milliseconds: 600);
  static const _scrollbarFade = Duration(milliseconds: 300);

  /// The toast the scroll keeps in place while the pointer is over the deck,
  /// its distance from the edge before scrolling, and the scroll, as last laid
  /// out.
  _Slot? _anchor;
  double _anchorAt = 0;
  double _anchorPixels = 0;

  SonnerController get _controller => widget.controller;

  /// The config the deck was last told of, and the one it is drawn with, so an
  /// assigned one can be told apart from any other change to the toasts.
  late SonnerConfig _config;

  /// How far the toasts are on their way from where they were drawn to where
  /// the config assigned last puts them, from 0 to 1.
  late final _Eased _glide = _Eased(this, 1);

  /// How far the deck is out of sight, from 0 drawn to 1 stowed.
  late final _Eased _stow = _Eased(this, 0);

  /// How far out of sight the deck is drawn, for the motion and the handle.
  final _stowed = _Driven(0);

  /// Whether the deck is drawn stowed. It outlasts the controller's stow once
  /// no toast is left, so the last one timing out does not bring an empty
  /// deck back into sight.
  bool _stowShown = false;

  /// How far the deck reached from its edge when it was stowed, which the
  /// slide carries it past.
  double _stowReach = 0;

  static const _stowDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _config = _controller.config;
    _controller.addListener(_onToastsChanged);
    watchLifecycle(_controller);
    _scroll.addListener(_showScrollbar);
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
    // Another controller's toasts are another deck, and start at the edge,
    // stowed or drawn as that controller has them rather than easing there.
    _config = _controller.config;
    _stowShown = _controller.stowed;
    _stow.jump(_stowShown ? 1 : 0);
    _glide.jump(1);
    _resetScroll();
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
    _timeLeftTicker.dispose();
    _expand.dispose();
    _reveal.dispose();
    _glide.dispose();
    _stow.dispose();
    _unscroll.dispose();
    _scroll
      ..removeListener(_showScrollbar)
      ..dispose();
    _cut.dispose();
    _dismissAllAt.dispose();
    _scrollbarHide?.cancel();
    _scrollbarShown.dispose();
    super.dispose();
  }

  void _onToastsChanged() {
    // During a build, layout or paint the deck can neither rebuild nor move
    // its animations, so the change waits for the end of the frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onToastsChanged();
      }, debugLabel: 'ToastLayer.onToastsChanged');
      return;
    }
    // A hold a widget took with `holdTimer` lasts until its toast is updated,
    // replaced or dismissed, and every one of those arrives here.
    for (final slot in _slots) {
      slot.releaseIfChanged();
      // A toast the user may no longer dismiss loses its recognizer at the
      // next build, and a recognizer taken away mid-drag reports nothing: the
      // drag ends here instead, and the toast goes back to its place.
      if (slot.drag != null && !slot.record.state.dismissibleNow) {
        slot.endDrag();
        slot.swipe.springBack(_springDuration);
      }
    }
    _followConfig();
    _followStow();
    // An assigned config can move where the deck is headed.
    _retarget();
    setState(_sync);
  }

  /// Starts the deck on its way out of sight, or back, when the controller
  /// has stowed it or brought it back.
  ///
  /// Stowing lets go of the pointer: nothing drawn is hovered, so the hold the
  /// pointer had on the timers goes, and a swipe under way is called off —
  /// its toast is no longer under the hand dragging it.
  void _followStow() {
    final live = toastsOf(_controller).isNotEmpty;
    final stow = _controller.stowed || (_stowShown && !live);
    if (stow == _stowShown) return;
    _stowShown = stow;
    if (!stow) {
      _stow.retarget(0, _stowDuration);
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final height = (box?.hasSize ?? false) ? box!.size.height : 0.0;
    _stowReach = _controller.config.position.isTop
        ? _deck.bottom
        : height - _deck.top;
    for (final slot in _slots) {
      if (slot.drag == null) continue;
      slot.endDrag();
      slot.swipe.springBack(_springDuration);
    }
    final was = _interacting;
    _pressed.clear();
    _setHovered(_moved.clear);
    if (was && !_interacting) _unscrollDeck();
    _stow.retarget(1, _stowDuration);
  }

  /// Starts the toasts on their way to a config assigned since the last
  /// change, from wherever each is drawn now. A toast already exiting stays
  /// where it is on screen.
  void _followConfig() {
    final config = _controller.config;
    if (config == _config) return;
    final flipped = config.position.isTop != _config.position.isTop;
    _config = config;
    for (final slot in _slots) {
      slot.windowFadeFrom = slot.windowFade;
      if (slot.exiting) {
        slot.screenPin ??= slot.drawnAt;
      } else {
        slot.glideFrom = slot.drawnAt;
      }
    }
    // The scroll runs the other way from the other edge.
    if (flipped) _resetScroll();
    _glide
      ..jump(0)
      ..retarget(1, _glideDuration);
  }

  /// Puts the deck at the edge, with nothing kept in view.
  void _resetScroll() {
    _anchor = null;
    _anchorPixels = 0;
    _unscrollFrom = 0;
    _unscroll.jump(1);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _setPointer(int device, {required bool over}) {
    if (over) {
      _pointers.add(device);
      return;
    }
    _pointers.remove(device);
    _setHovered(() => _moved.remove(device));
  }

  /// Counts [device] as over the deck once it acts there: moves, presses or
  /// scrolls. Entering the region is not enough, since the region also moves
  /// under a pointer that stays where it is — a toast shown under it, or the
  /// deck closing a gap.
  void _movePointer(int device) {
    if (!_pointers.contains(device)) return;
    _setHovered(() => _moved.add(device));
  }

  void _setHovered(VoidCallback change) {
    final was = _hovered;
    change();
    final hovered = _hovered;
    if (hovered == was) return;
    if (hovered) {
      holdTimers(_controller, this);
    } else {
      releaseTimers(_controller, this);
      if (!_interacting) _unscrollDeck();
    }
    _retarget();
  }

  /// Takes a press on the deck, or lets one go. It holds no timer of its own:
  /// a press that stays is a pointer over the deck, which pauses already, and
  /// one that becomes a swipe is held by the drag.
  void _setPressed(int device, {required bool down}) {
    // The hit test a press was routed through outlives this host: a pointer
    // that went down on the deck reports going up through it even once the
    // host has left the tree, and nothing here is alive to answer with.
    if (!mounted) return;
    if (down) _movePointer(device);
    final was = _interacting;
    if (down) {
      _pressed.add(device);
    } else {
      _pressed.remove(device);
    }
    if (_interacting == was) return;
    if (!_interacting) _unscrollDeck();
    _retarget();
  }

  void _showScrollbar() {
    if (_config.scrollbar?.alwaysShown ?? true) return;
    _scrollbarShown.forward();
    _scrollbarHide?.cancel();
    _scrollbarHide = Timer(_scrollbarLinger, _scrollbarShown.reverse);
  }

  /// Scrolls the deck by a wheel turned over the control past its far end.
  ///
  /// The control is drawn outside the deck, so the wheel never reaches the
  /// deck's own viewport — but the control is inside the hover region, which
  /// is where a hand holding the deck open rests.
  void _scrollFromControl(PointerScrollEvent event) {
    final at = _dismissAllAt.value;
    if (at == null || !at.contains(event.localPosition)) return;
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    // The deck scrolls away from its edge, which runs up the screen at a
    // bottom position, as `Scrollable` reverses a reversed axis itself.
    final delta = _config.position.isTop
        ? event.scrollDelta.dy
        : -event.scrollDelta.dy;
    position.jumpTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  /// Scrolls the deck as far as a drag of the scrollbar's thumb by [delta],
  /// down the screen, carries it along its track.
  void _dragScrollbar(double delta) {
    final thumb = _thumb;
    if (thumb == null || !_scroll.hasClients) return;
    final travel = thumb.track - thumb.thumb;
    if (travel <= 0) return;
    // Away from the edge is up the screen from the bottom, down from the top.
    final away = _config.position.isTop ? delta : -delta;
    final position = _scroll.position;
    position.jumpTo(
      (position.pixels + away * thumb.extent / travel).clamp(
        0.0,
        position.maxScrollExtent,
      ),
    );
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

  /// The recognizer that swipes [slot] away.
  GestureRecognizerFactoryWithHandlers<PanGestureRecognizer> _swipeOf(
    _Slot slot,
  ) => GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
    () =>
        PanGestureRecognizer(debugOwner: this, supportedDevices: _swipeDevices),
    (recognizer) {
      // Measured from where and when the pointer went down, so a flick counts
      // for as long as the hand was on the toast.
      recognizer.dragStartBehavior = DragStartBehavior.down;
      recognizer.onStart = (details) => _swipeStart(slot, details);
      recognizer.onUpdate = (details) => _swipeUpdate(slot, details);
      recognizer.onEnd = (_) => _swipeEnd(slot);
      recognizer.onCancel = () => _swipeEnd(slot);
    },
  );

  void _swipeStart(_Slot slot, DragStartDetails details) {
    slot.drag = SwipeDrag(
      directions: _controller.config.swipeDirectionsNow,
      at: details.sourceTimeStamp ?? Duration.zero,
    );
    // The drag holds the timers itself, so they keep pausing once it has
    // carried the pointer off the deck.
    holdTimers(_controller, slot.dragHold);
  }

  void _swipeUpdate(_Slot slot, DragUpdateDetails details) {
    final drag = slot.drag;
    if (drag == null) return;
    drag.moveBy(details.delta, at: details.sourceTimeStamp);
    slot.swipe.follow(drag.offset);
  }

  void _swipeEnd(_Slot slot) {
    final drag = slot.drag;
    if (drag == null) return;
    slot.endDrag();
    final out = drag.outcome;
    if (out == null) {
      slot.swipe.springBack(_springDuration);
      return;
    }
    slot.swipedOut = out;
    _controller.dismiss(slot.record.id);
  }

  /// Matches the slots to the controller's toasts. A toast the controller no
  /// longer holds keeps its slot, in its place, until its exit animation ends.
  void _sync() {
    final existing = {for (final slot in _slots) slot.record: slot};
    final next = [
      for (final record in toastsOf(_controller))
        _reuseOrEnter(record, existing),
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
    if (!_timeLeftTicker.isActive && _slots.any(_counting)) {
      _timeLeftTicker.start();
    }
  }

  static bool _counting(_Slot slot) =>
      !slot.exiting && slot.record.remaining != null;

  /// Runs on every frame while a toast counts down, for [_Slot.timeLeft].
  late final Ticker _timeLeftTicker = createTicker((_) {
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    final paused = timersPaused(_controller);
    final easeRestart = (_config.timeLeft ?? const ToastTimeLeft()).easeRestart;
    var counting = false;
    for (final slot in _slots) {
      if (slot.exiting) continue;
      // Followed without a timer too, so one that starts counting starts full.
      slot.timeLeftFollower.follow(
        now,
        slot.record,
        paused: paused,
        easeRestart: easeRestart,
      );
      counting = counting || _counting(slot);
    }
    if (!counting) _timeLeftTicker.stop();
  });

  _Slot _reuseOrEnter(ToastRecord record, Map<ToastRecord, _Slot> existing) {
    final slot = existing.remove(record);
    if (slot == null) return _enter(record);
    if (slot.exiting) _resume(slot);
    return slot;
  }

  void _resume(_Slot slot) {
    slot
      ..exiting = false
      ..screenPin = null;
    final onExit = slot.onExit;
    if (onExit != null) {
      slot.controller.removeStatusListener(onExit);
      slot.onExit = null;
    }
    slot.controller.forward();
  }

  _Slot _enter(ToastRecord record) {
    final controller = AnimationController(
      vsync: this,
      duration: _enterDuration,
    );
    final slot = _Slot(
      record,
      controller..forward(),
      AnimationController(vsync: this),
      _Sprung(this),
      _controller,
      TimeLeftFollower(this),
    );
    // A builder may take its toast out itself, flinging the animation to 0
    // as flash's swipe does before it says anything.
    controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !slot.exiting) {
        slot.owner.dismiss(record.id);
      }
    });
    return slot;
  }

  /// Runs the exit over the full [_exitDuration] from wherever the enter got
  /// to, then removes the slot.
  void _exit(_Slot slot) {
    slot.exiting = true;
    slot.timeLeftFollower.stop(slot.record);
    if (_glide.value < 1) slot.screenPin ??= slot.drawnAt;
    // A toast dismissed under a drag takes its recognizer with it, and a
    // recognizer disposed of reports nothing.
    slot.endDrag();
    late final AnimationStatusListener onExit;
    onExit = (status) {
      if (status != AnimationStatus.dismissed) return;
      slot.controller.removeStatusListener(onExit);
      slot.onExit = null;
      setState(() => _slots.remove(slot));
      slot.dispose();
    };
    slot.onExit = onExit;
    // A toast already at rest at 0 reports no change of status to wait for.
    if (slot.controller.status == AnimationStatus.dismissed) {
      onExit(AnimationStatus.dismissed);
      return;
    }
    slot.controller
      ..addStatusListener(onExit)
      ..animateBack(0, duration: _exitDuration);
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _expand,
        _reveal,
        _unscroll,
        _glide,
        _stow,
        for (final slot in _slots) ...[slot.animation, slot.resize, slot.swipe],
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
    final interacting = _interacting;
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
          ..inDeck = index < visible || interacting
          ..index = index++;
        // Covered content is not drawn, and the expansion brings it back: the
        // deck fanned out draws every toast at its own height, to be read.
        slot.contentFade.value = 1 - covered * (1 - expansion);
        liftPlace += covers;
      }
      covered += (1 - covered) * slot.presence.value;
      sum += slot.presence.value;
      lifted += slot.presence.value * covers;
    }

    final reveal = _reveal.value;
    final glide = _glide.value;
    for (final slot in _slots) {
      // A toast crossing the edge of the window fades as it moves across it;
      // one a newly assigned window puts on the other side fades on the
      // glide's clock.
      final fade = (visible - slot.depth).clamp(0.0, 1.0);
      final from = slot.windowFadeFrom;
      slot.windowFade = from == null || glide >= 1
          ? fade
          : from + (fade - from) * glide;
      slot.hidden =
          reveal == 0 &&
          (slot.exiting || slot.index >= visible) &&
          slot.windowFade == 0;
    }
    final isTop = config.position.isTop;
    // The toasts the user may dismiss, the window's and beyond.
    final dismissible = [
      for (final slot in _slots)
        if (!slot.exiting && slot.record.state.dismissibleNow) slot,
    ];
    final dismissAll = config.dismissAll;
    _dismissAllExpansion.value = expansion;
    _stowed.value = _stow.value;
    // Every toast on screen is one the stow would put away, whether or not
    // the user may dismiss it.
    final live = _slots.where((slot) => !slot.exiting).length;
    final control = farEndControls(
      config: config,
      expansion: _dismissAllExpansion,
      // A stowed deck is not interacting: stowing let the pointer go.
      showStow: live >= 1 && interacting,
      showDismissAll:
          dismissAll != null && dismissible.length >= 2 && interacting,
      stowCount: live,
      dismissCount: dismissible.length,
      onStow: _controller.stow,
      onDismissAll: () {
        for (final slot in dismissible) {
          _controller.dismiss(slot.id);
        }
      },
    );
    final handle = config.stowHandle;
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildLayer(context, config, isTop, expansion, interacting, control),
        if (handle != null && _stow.value > 0 && live > 0)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_stowShown,
              child: Padding(
                padding: EdgeInsets.all(config.offset),
                child: Align(
                  alignment: DeckStowMotionBox.cornerOf(config.position),
                  child: DeckStowHandleButton(
                    handle: handle,
                    count: live,
                    onUnstow: _controller.unstow,
                    shown: _stowed,
                    position: config.position,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The deck itself, with the controls past its far end, drawn as far out of
  /// sight as it is stowed and taking no pointer once it is.
  Widget _buildLayer(
    BuildContext context,
    SonnerConfig config,
    bool isTop,
    double expansion,
    bool interacting,
    Widget? control,
  ) {
    return Listener(
      onPointerDown: (event) => _setPressed(event.device, down: true),
      onPointerUp: (event) => _setPressed(event.device, down: false),
      onPointerCancel: (event) => _setPressed(event.device, down: false),
      onPointerSignal: (event) {
        _movePointer(event.device);
        if (event is PointerScrollEvent) _scrollFromControl(event);
      },
      child: _DeckRegion(
        deck: () => _stowShown ? Rect.zero : _deck,
        onEnter: (event) => _setPointer(event.device, over: true),
        onExit: (event) => _setPointer(event.device, over: false),
        onHover: (event) => _movePointer(event.device),
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
          child: IgnorePointer(
            ignoring: _stowShown,
            child: DeckStowMotionBox(
              motion: config.stowMotion,
              view: DeckStowMotionView(
                stowed: _stowed,
                position: config.position,
                reach: _stowReach,
              ),
              deck: DeckLayers(
                at: _dismissAllAt,
                onControlSize: (size) => _dismissAllSize = size,
                control: control,
                deck: DeckCutBox(
                  cut: _cut,
                  fromTop: isTop,
                  margin: config.offset,
                  fades: (config.deckCap?.fade ?? 0) > 0,
                  child: Scrollable(
                    controller: _scroll,
                    axisDirection: isTop
                        ? AxisDirection.down
                        : AxisDirection.up,
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
                        presence: (slot) => slot.presence.value,
                        depth: (slot) => slot.depth,
                        lift: (slot) => slot.lift,
                        natural: (slot) => slot.natural,
                        covering: (slot) => slot.covering,
                        pinned: (slot) => slot.pinned,
                        inDeck: (slot) => slot.inDeck,
                        onPlaced: (slot, height, covering, distance, place) =>
                            slot
                              ..height = height
                              ..covers = covering
                              ..distance = distance
                              ..place = place,
                        onDeck: (deck) => _deck = deck,
                        glide: _glide.value,
                        glideFrom: (slot) => slot.glideFrom,
                        screenPinned: (slot) => slot.screenPin,
                        onDrawn: (slot, drawn) => slot.drawnAt = drawn,
                        scroll: position,
                        follows: interacting,
                        unscrolled: _unscrolled,
                        // Read at layout, which a scroll runs without a build.
                        anchor: () => _interacting && _expand.value == 1
                            ? (
                                id: _anchor,
                                distance: _anchorAt,
                                pixels: _anchorPixels,
                              )
                            : null,
                        onAnchor: (slot, distance, pixels) {
                          _anchor = slot;
                          _anchorAt = distance;
                          _anchorPixels = pixels;
                        },
                        backdrop: _backdrop,
                        scrollbar: _scrollbarId,
                        onCut: (cut) => _cut.value = cut,
                        onScrollbar: (thumb) => _thumb = thumb,
                        dismissAllSize: () => _dismissAllSize,
                        onDismissAll: (at) => _dismissAllAt.value = at,
                      ),
                      children: [
                        LayoutId(id: _backdrop, child: const _Backdrop()),
                        // Oldest first: children paint in order, so the newest is on top.
                        for (final slot in _slots.reversed)
                          LayoutId(id: slot, child: _buildToast(slot, config)),
                        if (config.scrollbar case final scrollbar?)
                          LayoutId(
                            id: _scrollbarId,
                            child: DeckScrollbarThumb(
                              scrollbar: scrollbar,
                              opacity: scrollbar.alwaysShown
                                  ? kAlwaysCompleteAnimation
                                  : _scrollbarShown,
                              onDrag: _dragScrollbar,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The layout id of the box behind the deck that takes the wheel in the
  /// gaps between toasts.
  static const _backdrop = #backdrop;

  /// The layout id of the scrollbar's thumb.
  static const _scrollbarId = #scrollbar;

  /// Where the dismiss-all control is placed, as the deck's layout last
  /// reported, and its size as it last laid itself out.
  final _dismissAllAt = ValueNotifier<Rect?>(null);
  Size? _dismissAllSize;

  /// How far the deck is fanned out, for the dismiss-all control.
  final _dismissAllExpansion = _Driven(0);

  /// [value] kept between [from] and [place], so it only moves toward
  /// [place].
  static double _toward(double from, num place, double value) {
    final to = place.toDouble();
    return from < to ? value.clamp(from, to) : value.clamp(to, from);
  }

  Widget _buildToast(_Slot slot, SonnerConfig config) {
    // Faded at the window's edge, unless the pointer over the deck is drawing
    // every toast.
    final reveal = _reveal.value;
    final fade = reveal + (1 - reveal) * slot.windowFade;
    final swipe = slot.swipeOffset(config);
    return Offstage(
      offstage: slot.hidden,
      child: IgnorePointer(
        ignoring: !slot.inDeck,
        child: Opacity(
          opacity: fade,
          child: FadeTransition(
            opacity: slot.presence,
            child: SlideTransition(
              // A toast swiped away leaves the way the swipe took it, and not
              // toward the edge every other toast enters and leaves by.
              position: slot.swipedOut == null
                  ? slot.slide(fromTop: config.position.isTop)
                  : _still,
              // The swipe and the deck's scale in one transform: where a
              // toast is drawn is one answer.
              child: Transform(
                transform: Matrix4.translationValues(swipe.dx, swipe.dy, 0)
                  ..scaleByDouble(slot.scale, slot.scale, 1, 1),
                alignment: Alignment.center,
                child: RawGestureDetector(
                  // A toast the user may not dismiss takes no swipe; its
                  // recognizer goes rather than turning itself off, so no
                  // pointer of its own is claimed.
                  gestures: slot.record.state.dismissibleNow && !slot.exiting
                      ? {PanGestureRecognizer: _swipeOf(slot)}
                      : const {},
                  child: ToastHeight(
                    onMeasured: slot.measured,
                    // Read after `_buildDeck` has set it for this frame.
                    child: slot.contentIn(
                      config,
                      pressable: slot.contentFade.value > 0,
                    ),
                  ),
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
final class _Slot implements ToastView {
  _Slot(
    this.record,
    this.controller,
    this.resize,
    this.swipe,
    this.owner,
    this.timeLeftFollower,
  ) : presence = CurvedAnimation(parent: controller, curve: Curves.ease),
      _resizeCurve = CurvedAnimation(parent: resize, curve: Curves.ease);

  static const _fadeDuration = Duration(milliseconds: 200);
  static const _resizeDuration = Duration(milliseconds: 400);

  final ToastRecord record;

  final AnimationController controller;

  /// How far in it is, 0 to 1, on the eased curve the enter and exit run.
  final CurvedAnimation presence;

  @override
  AnimationController get animation => controller;

  @override
  late final Animation<double> covered = ReverseAnimation(contentFade);

  /// Follows the countdown for [timeLeft].
  final TimeLeftFollower timeLeftFollower;

  @override
  Animation<double>? get timeLeft =>
      record.remaining == null ? null : timeLeftFollower.animation;

  /// The controller whose toast this is, for [dismiss] and [holdTimer].
  final SonnerController owner;

  /// Completes once the toast has left the tree, for [dismiss].
  final Completer<void> _removed = Completer<void>();

  /// The content the toast held when [holdTimer] took the timers, so the hold
  /// can be let go once it is updated or replaced.
  ToastState? _heldAt;

  @override
  ToastId get id => record.id;

  @override
  ToastState get state => record.state;

  @override
  Future<void> dismiss() {
    dismissRecord(owner, record);
    return _removed.future;
  }

  @override
  void holdTimer() {
    if (exiting) return;
    _heldAt = record.state;
    holdTimers(owner, this);
  }

  /// Lets go of a [holdTimer] hold once the toast has been updated, replaced
  /// or dismissed. A hold on content that has not changed stays.
  void releaseIfChanged() {
    final held = _heldAt;
    if (held == null) return;
    if (identical(held, record.state) && !exiting) return;
    _heldAt = null;
    releaseTimers(owner, this);
  }

  /// Where a swipe has taken it from the place the deck gives it.
  final _Sprung swipe;

  /// The swipe under way on it, or null while none is.
  SwipeDrag? drag;

  /// The direction a swipe dismissed it in, or null when none did.
  SwipeDirection? swipedOut;

  /// What holds the timers while a swipe drags it — its own, so a hold a
  /// widget took with [holdTimer] and a drag do not let go of each other's.
  late final Object dragHold = Object();

  /// Ends any drag under way, letting the timers it held go.
  void endDrag() {
    if (drag == null) return;
    drag = null;
    releaseTimers(owner, dragHold);
  }

  /// Where the swipe draws it: as far as the drag has taken it, and, once a
  /// swipe has dismissed it, a whole toast further on its way out.
  Offset swipeOffset(SonnerConfig config) {
    final out = swipedOut;
    if (out == null) return swipe.value;
    final size = out.isHorizontal ? config.width : height ?? 0;
    final left = 1 - Curves.easeOut.transform(controller.value);
    return swipe.value + out.step * size * left;
  }

  /// Runs from 0 to 1 while [covering] eases from the height the toast had to
  /// the height it measures now.
  final AnimationController resize;
  final CurvedAnimation _resizeCurve;

  /// Whether the controller has let go of this toast and its exit has started.
  bool exiting = false;

  AnimationStatusListener? onExit;

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

  /// How much of it the window draws, 0 outside to 1 inside, and what that was
  /// when the config last assigned was.
  double windowFade = 1;
  double? windowFadeFrom;

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

  /// Where on the layer it was last drawn.
  Rect? drawnAt;

  /// Where it was drawn when the config last assigned was, which the glide
  /// takes it from.
  Rect? glideFrom;

  /// Where on the layer it stays until it is removed, once a config was
  /// assigned while it was exiting, or while it was on its way to one when it
  /// was dismissed.
  Rect? screenPin;

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
  bool? _shownPressable;
  Widget? _content;

  /// What the toast shows. Built again only when the record's state changes,
  /// when the config the look reads does, or when the deck covering it takes
  /// its content out of reach — so an animation frame that only moves the
  /// toast does not rebuild it, and a new state fades in over the old one.
  Widget contentIn(SonnerConfig config, {required bool pressable}) {
    final state = record.state;
    if (!identical(state, _shown) ||
        config != _shownWith ||
        pressable != _shownPressable) {
      _shown = state;
      _shownWith = config;
      _shownPressable = pressable;
      _content = Semantics(
        liveRegion: true,
        child: ContentFade(
          duration: _fadeDuration,
          child: switch (state.builder ?? config.builder) {
            final builder? => Builder(
              key: ValueKey((state, builder)),
              builder: (context) => builder(context, this),
            ),
            null => DefaultToastLook(
              key: ObjectKey(state),
              toast: this,
              config: config,
              fade: contentFade,
              pressable: pressable,
            ),
          },
        ),
      );
    }
    return _content!;
  }

  Animation<Offset>? _slide;
  bool? _slideFromTop;

  /// Its enter and exit slide, from the edge [fromTop] names.
  Animation<Offset> slide({required bool fromTop}) {
    // An exiting toast leaves toward the edge it entered from.
    if (exiting && _slide != null) return _slide!;
    if (_slideFromTop != fromTop) {
      _slideFromTop = fromTop;
      _slide = animation.drive(
        Tween(begin: Offset(0, fromTop ? -1 : 1), end: Offset.zero),
      );
    }
    return _slide!;
  }

  void dispose() {
    endDrag();
    if (_heldAt != null) {
      _heldAt = null;
      releaseTimers(owner, this);
    }
    final onExit = this.onExit;
    if (onExit != null) controller.removeStatusListener(onExit);
    if (!_removed.isCompleted) _removed.complete();
    presence.dispose();
    controller.dispose();
    timeLeftFollower.dispose();
    _resizeCurve.dispose();
    resize.dispose();
    swipe.dispose();
  }
}

/// Where a swipe draws a toast, from the place the deck gives it: set as the
/// drag moves it, and eased back to nothing when the drag lets go short of
/// dismissing it.
class _Sprung extends ChangeNotifier {
  _Sprung(TickerProvider vsync)
    : _progress = AnimationController(vsync: vsync, value: 1) {
    _progress.addListener(notifyListeners);
  }

  /// Runs from 0 to 1 while [value] eases from [_from] to [_to].
  final AnimationController _progress;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;

  Offset get value =>
      Offset.lerp(_from, _to, Curves.ease.transform(_progress.value))!;

  /// Draws the toast [offset] from its place, from now until it is told
  /// otherwise.
  void follow(Offset offset) {
    _progress.stop();
    _from = offset;
    _to = offset;
    notifyListeners();
  }

  /// Eases back to the toast's place over [duration].
  void springBack(Duration duration) {
    if (value == Offset.zero) return;
    _from = value;
    _to = Offset.zero;
    _progress.animateWith(_Progress(duration));
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
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
    required this.onHover,
    super.child,
  });

  final Rect Function() deck;
  final PointerEnterEventListener onEnter;
  final PointerExitEventListener onExit;
  final PointerHoverEventListener onHover;

  @override
  _RenderDeckRegion createRenderObject(BuildContext context) =>
      _RenderDeckRegion(
        deck,
        onEnter: onEnter,
        onExit: onExit,
        onHover: onHover,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDeckRegion renderObject,
  ) => renderObject
    ..deck = deck
    ..onEnter = onEnter
    ..onExit = onExit
    ..onHover = onHover;
}

class _RenderDeckRegion extends RenderMouseRegion {
  _RenderDeckRegion(this.deck, {super.onEnter, super.onExit, super.onHover});

  Rect Function() deck;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final hitChild = hitTestChildren(result, position: position);
    final inDeck = deck().contains(position);
    if (inDeck) result.add(BoxHitTestEntry(this, position));
    return hitChild || inDeck;
  }
}
