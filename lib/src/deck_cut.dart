import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'deck_layout.dart';

/// Draws [child] only up to the [cut] its layout last reported, fading it out
/// toward it, and passes the pointer to [child] only up to [margin] past it.
///
/// Distances are from the edge: the top of the layer when [fromTop], the
/// bottom otherwise. With no cut, [child] is drawn and takes the pointer as
/// usual. A cut that fades needs its own layer, so [fades] says whether any
/// cut reported can.
class DeckCutBox extends SingleChildRenderObjectWidget {
  const DeckCutBox({
    super.key,
    required this.cut,
    required this.fromTop,
    required this.margin,
    required this.fades,
    super.child,
  });

  final ValueListenable<DeckCut?> cut;
  final bool fromTop;
  final double margin;
  final bool fades;

  @override
  RenderDeckCut createRenderObject(BuildContext context) =>
      RenderDeckCut(cut: cut, fromTop: fromTop, margin: margin, fades: fades);

  @override
  void updateRenderObject(BuildContext context, RenderDeckCut renderObject) =>
      renderObject
        ..cut = cut
        ..fromTop = fromTop
        ..margin = margin
        ..fades = fades;
}

class RenderDeckCut extends RenderProxyBox {
  RenderDeckCut({
    required ValueListenable<DeckCut?> cut,
    required bool fromTop,
    required this.margin,
    required bool fades,
  }) : _cut = cut,
       _fromTop = fromTop,
       _fades = fades;

  ValueListenable<DeckCut?> get cut => _cut;
  ValueListenable<DeckCut?> _cut;
  set cut(ValueListenable<DeckCut?> value) {
    if (identical(value, _cut)) return;
    if (attached) {
      _cut.removeListener(_cutChanged);
      value.addListener(_cutChanged);
    }
    _cut = value;
    _cutChanged();
  }

  bool get fromTop => _fromTop;
  bool _fromTop;
  set fromTop(bool value) {
    if (value == _fromTop) return;
    _fromTop = value;
    markNeedsPaint();
  }

  double margin;

  final _clip = LayerHandle<ClipRectLayer>();
  final _mask = LayerHandle<ShaderMaskLayer>();

  // The cut is reported while the deck lays out, which can follow a paint of
  // this box that read the one before.
  void _cutChanged() => markNeedsPaint();

  bool get fades => _fades;
  bool _fades;
  set fades(bool value) {
    if (value == _fades) return;
    _fades = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _fades;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _cut.addListener(_cutChanged);
  }

  @override
  void detach() {
    _cut.removeListener(_cutChanged);
    super.detach();
  }

  /// [distance] from the edge as a position down the box.
  double _down(double distance) => fromTop ? distance : size.height - distance;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final cut = _cut.value;
    if (cut != null) {
      final past = fromTop
          ? position.dy > _down(cut.at + margin)
          : position.dy < _down(cut.at + margin);
      if (past) return false;
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final cut = _cut.value;
    if (child == null || cut == null || size.height == 0) {
      _clip.layer = null;
      _mask.layer = null;
      super.paint(context, offset);
      return;
    }
    if (!_fades || cut.fadeFrom >= cut.at) {
      _mask.layer = null;
      final at = _down(cut.at);
      final kept = fromTop
          ? Rect.fromLTRB(-_unbounded, -_unbounded, _unbounded, at)
          : Rect.fromLTRB(-_unbounded, at, _unbounded, _unbounded);
      _clip.layer = context.pushClipRect(
        needsCompositing,
        offset,
        kept,
        super.paint,
        oldLayer: _clip.layer,
      );
      return;
    }
    _clip.layer = null;
    final height = size.height;
    final at = (_down(cut.at) / height).clamp(0.0, 1.0);
    final from = (_down(cut.fadeFrom) / height).clamp(0.0, 1.0);
    const kept = Color(0xFFFFFFFF);
    const gone = Color(0x00FFFFFF);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: fromTop
          ? const [kept, kept, gone, gone]
          : const [gone, gone, kept, kept],
      stops: fromTop ? [0, from, at, 1] : [0, at, from, 1],
    );
    _mask.layer = (_mask.layer ?? ShaderMaskLayer())
      ..shader = gradient.createShader(Offset.zero & size)
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    context.pushLayer(_mask.layer!, super.paint, offset);
  }

  /// Far enough past the layer's sides that nothing drawn beside the deck is
  /// cut by them.
  static const _unbounded = 1e5;

  @override
  void dispose() {
    _clip.layer = null;
    _mask.layer = null;
    super.dispose();
  }
}
