import 'dart:async';

import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter/widgets.dart';

import 'config.dart';
import 'controller.dart';
import 'host.dart' show ToastLayer;

/// The title of a warm-up's stand-in toast.
const warmUpTitle = 'Warming up';

/// The description of a warm-up's stand-in toast.
const warmUpDescription = 'Drawn once, out of sight.';

/// One warm-up: a deck of its own, holding one stand-in toast, that a host
/// draws under the app's screen and fans out, then lets go of. The deck is a
/// controller of its own, not the one that started the run.
final class WarmUpRun with WidgetsBindingObserver {
  WarmUpRun(SonnerConfig config, {required VoidCallback onEnd})
    : deck = SonnerController(config: config),
      _onEnd = onEnd {
    deck.show(warmUpTitle, description: warmUpDescription, duration: null);
  }

  /// The frames drawn with the deck collapsed before its zone opens.
  static const framesBeforeOpen = 2;

  /// The frames the zone is held open for.
  static const framesOpen = 20;

  /// The controller whose deck the host draws.
  final SonnerController deck;

  final VoidCallback _onEnd;
  final Completer<void> _done = Completer<void>();

  /// How many hosts draw [deck] now.
  int _layers = 0;

  int _frames = 0;
  bool _ended = false;
  bool _deckDisposed = false;

  /// Whether the zone was held open for all of [framesOpen].
  bool get finished => _finished;
  bool _finished = false;

  /// Completes once the run has ended, however it ended.
  Future<void> get done => _done.future;

  /// Starts counting frames, at the end of the frame during a build. Ends at
  /// once while the app draws no frames.
  void start() {
    final binding = WidgetsBinding.instance;
    if (!binding.framesEnabled) {
      end();
      return;
    }
    binding.addObserver(this);
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) {
        if (!_ended) _nextFrame();
      }, debugLabel: 'WarmUpRun.start');
      return;
    }
    _nextFrame();
  }

  void _nextFrame() {
    SchedulerBinding.instance
      ..addPostFrameCallback(_onFrame, debugLabel: 'WarmUpRun.frame')
      ..scheduleFrame();
  }

  void _onFrame(Duration _) {
    if (_ended) return;
    if (_layers == 0) {
      end();
      return;
    }
    _frames++;
    if (_frames == framesBeforeOpen) deck.zone.open();
    if (_frames == framesBeforeOpen + framesOpen) {
      _finished = true;
      end();
      return;
    }
    _nextFrame();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        end();
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        break;
    }
  }

  /// Ends the run and completes [done]. The deck is disposed once no host
  /// draws it.
  void end() {
    if (_ended) return;
    _ended = true;
    WidgetsBinding.instance.removeObserver(this);
    _onEnd();
    _disposeIfLetGo();
    _done.complete();
  }

  void _layerBuilt() => _layers++;

  void _layerGone() {
    _layers--;
    _disposeIfLetGo();
  }

  void _disposeIfLetGo() {
    if (!_ended || _layers > 0 || _deckDisposed) return;
    _deckDisposed = true;
    deck.dispose();
  }
}

/// Draws the deck of [controller]'s warm-up while one runs, and nothing
/// otherwise. A host lays it under the app's screen.
class WarmUpDeck extends StatefulWidget {
  const WarmUpDeck({super.key, required this.controller});

  final SonnerController controller;

  @override
  State<WarmUpDeck> createState() => _WarmUpDeckState();
}

class _WarmUpDeckState extends State<WarmUpDeck> {
  @override
  void initState() {
    super.initState();
    warmUpOf(widget.controller).addListener(_onRun);
  }

  @override
  void didUpdateWidget(WarmUpDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    warmUpOf(oldWidget.controller).removeListener(_onRun);
    warmUpOf(widget.controller).addListener(_onRun);
  }

  @override
  void dispose() {
    warmUpOf(widget.controller).removeListener(_onRun);
    super.dispose();
  }

  /// Rebuilds for the run now under way, at the end of the frame when the
  /// run changes during one.
  void _onRun() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onRun();
      }, debugLabel: 'WarmUpDeck.onRun');
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) =>
      switch (warmUpOf(widget.controller).value) {
        final run? => _HiddenDeck(key: ObjectKey(run), run: run),
        null => const SizedBox.shrink(),
      };
}

/// [run]'s deck, taking no pointer, no focus and no part in semantics.
class _HiddenDeck extends StatefulWidget {
  const _HiddenDeck({super.key, required this.run});

  final WarmUpRun run;

  @override
  State<_HiddenDeck> createState() => _HiddenDeckState();
}

class _HiddenDeckState extends State<_HiddenDeck> {
  @override
  void initState() {
    super.initState();
    widget.run._layerBuilt();
  }

  @override
  void dispose() {
    widget.run._layerGone();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: ExcludeFocus(child: ToastLayer(controller: widget.run.deck)),
    ),
  );
}
