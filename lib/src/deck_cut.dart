import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'deck_layout.dart';

/// Draws [child] only within the band the [cut] its layout last reported
/// leaves, fading it out toward each end, and passes the pointer to [child]
/// only up to [margin] past that cut's **far** end.
///
/// Distances are from the edge: the top of the layer when [fromTop], the
/// bottom otherwise. Either end may be absent, and with no cut at all [child]
/// is drawn and takes the pointer as usual. A cut that fades needs its own
/// layer, so [fades] says whether any cut reported can.
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
    // The far end alone. The pointer nearer than the near end is already the
    // deck's: a deck that can scroll and is held by the pointer stretches its
    // box to the layer's edge so it cannot slide out from under a resting
    // pointer, and the near cut is a paint cut only.
    final far = _cut.value?.far;
    if (far != null) {
      final past = fromTop
          ? position.dy > _down(far.at + margin)
          : position.dy < _down(far.at + margin);
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
    final near = cut.near;
    final far = cut.far;
    final nearAt = near == null ? null : _down(near.at);
    final farAt = far == null ? null : _down(far.at);
    final shown = Rect.fromLTRB(
      -_unbounded,
      (fromTop ? nearAt : farAt) ?? -_unbounded,
      _unbounded,
      (fromTop ? farAt : nearAt) ?? _unbounded,
    );
    final nearFades = _fades && near != null && near.fadeFrom > near.at;
    final farFades = _fades && far != null && far.fadeFrom < far.at;
    if (!nearFades && !farFades) {
      _mask.layer = null;
      _clip.layer = context.pushClipRect(
        needsCompositing,
        offset,
        shown,
        super.paint,
        oldLayer: _clip.layer,
      );
      return;
    }
    final height = size.height;
    const kept = Color(0xFFFFFFFF);
    const gone = Color(0x00FFFFFF);
    // Marks down the gradient by distance from the deck's own edge, which the
    // box spans from 0 to its height, and reversed for a deck at the bottom.
    final marks = <(double, Color)>[(0, nearFades ? gone : kept)];
    if (near != null && nearFades) {
      marks.add((near.at, gone));
      marks.add((near.fadeFrom, kept));
    }
    if (far != null && farFades) {
      marks.add((far.fadeFrom, kept));
      marks.add((far.at, gone));
    }
    marks.add((height, farFades ? gone : kept));
    final stops = [
      for (final mark in marks) (_down(mark.$1) / height).clamp(0.0, 1.0),
    ];
    final colors = [for (final mark in marks) mark.$2];
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: fromTop ? colors : colors.reversed.toList(),
      stops: fromTop ? stops : stops.reversed.toList(),
    );
    _mask.layer = (_mask.layer ?? ShaderMaskLayer())
      ..shader = gradient.createShader(Offset.zero & size)
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    // The mask reaches only as far as the box, so what is laid out beyond it
    // is cut by the same clip as a hard cut.
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      shown,
      (context, offset) => context.pushLayer(_mask.layer!, super.paint, offset),
      oldLayer: _clip.layer,
    );
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
