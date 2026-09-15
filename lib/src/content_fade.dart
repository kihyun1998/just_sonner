import 'package:flutter/widgets.dart';

/// Shows [child], and fades a child of another key in over the one before.
///
/// The one before stays fully opaque underneath until the new one is fully
/// in, then goes. A child that arrives mid-fade makes the half-faded one the
/// opaque base, so there are never more than two. The new child sets the size;
/// the base lies over it from the top, cut to that size, takes no pointer and
/// is left out of the semantics tree.
class ContentFade extends StatefulWidget {
  const ContentFade({super.key, required this.duration, required this.child});

  final Duration duration;
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
            child: _layer(base, opacity: kAlwaysCompleteAnimation, top: false),
          ),
        Positioned(
          key: _currentKey,
          child: _layer(_current, opacity: _fade, top: true),
        ),
      ],
    );
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
