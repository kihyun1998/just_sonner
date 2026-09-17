import 'package:flash/flash.dart';
import 'package:flutter/widgets.dart';
import 'package:just_sonner/just_sonner.dart';

/// Builds a widget made for flash's `FlashBar`, handed a toast as the
/// [FlashController] it takes, and the toast itself for what flash has no word
/// for: `covered`, `state`.
typedef FlashToastBuilder =
    Widget Function(
      BuildContext context,
      FlashController<void> controller,
      ToastView toast,
    );

/// A [ToastBuilder] that draws [builder]'s `FlashBar` through a [FlashToast].
///
/// ```dart
/// toast.show('Saved', builder: flashToast((context, controller, toast) =>
///     FlashBar(controller: controller, dismissDirections: const [], ...)));
/// ```
ToastBuilder flashToast(FlashToastBuilder builder) =>
    (context, toast) => FlashToast(toast: toast, builder: builder);

/// Hands [toast] to a `FlashBar` as a [FlashController]: the three members
/// flash calls, and nothing of the toast's own motion.
///
/// - `controller` is an animation of this widget's own, resting at 1. The toast
///   enters, leaves and takes its place in the deck on its own animation, so a
///   `FlashBar` fades and slides only while flash's swipe drags it.
/// - Flash's swipe taking that animation to 0 dismisses the toast, or springs
///   it back when the toast is not `dismissibleNow`.
/// - `dismiss` dismisses the toast; `deactivate`, which flash calls as a fling
///   starts, holds its timer.
///
/// A `FlashBar` swipes on every direction unless told otherwise, and its drag
/// wins over the toast's own swipe — `dismissible`, `swipeDirections` and the
/// rule that a trackpad pan scrolls the deck go with it. Give it
/// `dismissDirections: const []` to keep the toast's swipe.
///
/// A covered toast draws no content and keeps its card, and a `FlashBar` draws
/// both as one, so fading its content by `toast.covered` is the builder's.
class FlashToast extends StatefulWidget {
  const FlashToast({super.key, required this.toast, required this.builder});

  final ToastView toast;
  final FlashToastBuilder builder;

  @override
  State<FlashToast> createState() => _FlashToastState();
}

class _FlashToastState extends State<FlashToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  late final _Controller _controller = _Controller(this);

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 200),
    )..addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed) return;
    if (widget.toast.state.dismissibleNow) {
      widget.toast.dismiss();
    } else {
      _animation.forward();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _controller, widget.toast);
}

/// The [FlashController] a [FlashToast] hands out. Not the State itself, whose
/// own `deactivate` would clash with flash's.
class _Controller implements FlashController<void> {
  _Controller(this._state);

  final _FlashToastState _state;

  @override
  AnimationController get controller => _state._animation;

  @override
  Future<void> dismiss([void result]) => _state.widget.toast.dismiss();

  @override
  void deactivate() => _state.widget.toast.holdTimer();
}
