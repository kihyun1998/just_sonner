import 'package:flutter/widgets.dart';

/// Shows [child], and fades a child of another key in over the one before.
///
/// The one before fades out on the curve that keeps two layers of a card of
/// [cardOpacity] covering as one such card does, and goes once the new one is
/// fully in; at a card opacity of 1 it stays fully opaque until then. A child
/// that arrives mid-fade makes the half-faded one the base, at full opacity,
/// so there are never more than two. A [duration] of zero puts the new child
/// in place of the one before in one frame. The new child sets the size;
/// the base lies over it from the top, cut to that size, takes no pointer and
/// is left out of the semantics tree.
class ContentFade extends StatefulWidget {
  const ContentFade({
    super.key,
    required this.duration,
    this.cardOpacity = 1,
    required this.child,
  });

  final Duration duration;

  /// The opacity of the card each child draws, 0 to 1.
  final double cardOpacity;
  final Widget child;

  @override
  State<ContentFade> createState() => _ContentFadeState();
}

class _ContentFadeState extends State<ContentFade>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  )..addStatusListener(_onFadeStatus);

  late Widget _current = widget.child;
  Widget? _base;

  // Each layer keeps its key when it moves from on top to underneath, so its
  // subtree is not built again from scratch.
  int _serial = 0;
  late Key _currentKey = ValueKey(_serial);
  Key? _baseKey;

  @override
  void didUpdateWidget(ContentFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fade.duration = widget.duration;
    if (Widget.canUpdate(widget.child, _current)) {
      _current = widget.child;
      return;
    }
    _base = _current;
    _baseKey = _currentKey;
    _current = widget.child;
    _currentKey = ValueKey(++_serial);
    _fade.forward(from: 0);
  }

  void _onFadeStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _base == null) return;
    setState(() {
      _base = null;
      _baseKey = null;
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = _base;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (base != null)
          Positioned(
            key: _baseKey,
            top: 0,
            left: 0,
            right: 0,
            child: _layer(base, opacity: _baseOpacity(), top: false),
          ),
        Positioned(
          key: _currentKey,
          child: _layer(_current, opacity: _fade, top: true),
        ),
      ],
    );
  }

  Animation<double>? _baseFade;
  double? _baseFadeFor;

  /// The base's opacity against the new child's.
  Animation<double> _baseOpacity() {
    final alpha = widget.cardOpacity;
    if (alpha >= 1) return kAlwaysCompleteAnimation;
    if (_baseFadeFor != alpha) {
      _baseFadeFor = alpha;
      _baseFade = _fade.drive(_BaseFade(alpha));
    }
    return _baseFade!;
  }

  Widget _layer(
    Widget child, {
    required Animation<double> opacity,
    required bool top,
  }) => IgnorePointer(
    ignoring: !top,
    child: ExcludeSemantics(
      excluding: !top,
      child: FadeTransition(
        opacity: opacity,
        alwaysIncludeSemantics: true,
        child: child,
      ),
    ),
  );
}

/// The base's opacity at the new child's opacity `t`: the one at which two
/// layers of a card of [alpha] cover as one such card does.
class _BaseFade extends Animatable<double> {
  const _BaseFade(this.alpha);

  final double alpha;

  @override
  double transform(double t) => (1 - t) / (1 - alpha * t);
}
