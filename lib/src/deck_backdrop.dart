import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'config.dart';

/// Draws what [backdrop] says behind the fanned-out deck: over the box [at]
/// reports, and [DeckBackdrop.padding] further.
///
/// **It is drawn outside the deck's own cut**, under it. A cut that fades is a
/// `ShaderMask`, which the engine draws as a save layer, and a `BackdropFilter`
/// inside one filters that fresh transparent layer rather than the app — so a
/// backdrop drawn among the toasts blurs nothing at exactly the deck heights
/// that overflow the cap. Measured: with the default `DeckCap`'s `fade` of 24
/// the stripes behind a ten-toast deck kept a contrast of 255 with the blur on,
/// against 5 with a hard cut and 5 with no cap.
///
/// It takes no pointer. The deck claims the clicks in its gaps with the opaque
/// box its own layout places, which this never widens: a click in the padding
/// this reaches into still reaches the app.
///
/// Both the blur and the dim follow [expansion], so a collapsed deck draws
/// neither and there is nothing to see until the pointer fans the deck out.
class DeckBackdropBox extends StatelessWidget {
  const DeckBackdropBox({
    super.key,
    required this.at,
    required this.expansion,
    required this.backdrop,
  });

  /// The deck's own box, as its layout last reported it; null before the first
  /// layout.
  final ValueListenable<Rect?> at;

  /// The deck's collapse-to-expand value, 0 collapsed and 1 fanned out. A
  /// plain value: the host rebuilds the whole layer on its own expansion
  /// already, so following it a second time here would buy nothing.
  final double expansion;

  final DeckBackdrop backdrop;

  @override
  Widget build(BuildContext context) {
    final reach = expansion.clamp(0.0, 1.0);
    if (reach == 0) return const SizedBox.shrink();
    final sigma = backdrop.blur * reach;
    return IgnorePointer(
      child: _BackdropClip(
        at: at,
        padding: backdrop.padding,
        radius: backdrop.radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (sigma > 0)
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: const SizedBox.expand(),
              ),
            if (backdrop.dim > 0)
              ColoredBox(
                color: (backdrop.color ?? Theme.of(context).colorScheme.scrim)
                    .withValues(alpha: backdrop.dim * reach),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fills the layer and draws [child] only inside the deck's box, [padding]
/// further out and rounded by [radius].
///
/// The deck reports its box **while it lays out**, so following it with a
/// builder would schedule a build mid-frame, and a layout delegate reading it
/// would mutate a sibling subtree during layout. Flutter raises on both. So the
/// box is read at **paint**, the way `DeckCutBox` and `DeckLayers` read theirs.
///
/// The clip is a plain rounded clip, never `antiAliasWithSaveLayer`: a save
/// layer here would trap the child's `BackdropFilter`, which is the whole
/// reason this is drawn outside the deck's cut.
class _BackdropClip extends SingleChildRenderObjectWidget {
  const _BackdropClip({
    required this.at,
    required this.padding,
    required this.radius,
    required super.child,
  });

  final ValueListenable<Rect?> at;
  final EdgeInsets padding;
  final double radius;

  @override
  _RenderBackdropClip createRenderObject(BuildContext context) =>
      _RenderBackdropClip(at: at, padding: padding, radius: radius);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBackdropClip renderObject,
  ) => renderObject
    ..at = at
    ..padding = padding
    ..radius = radius;
}

class _RenderBackdropClip extends RenderProxyBox {
  _RenderBackdropClip({
    required ValueListenable<Rect?> at,
    required EdgeInsets padding,
    required double radius,
  }) : _at = at,
       _padding = padding,
       _radius = radius;

  ValueListenable<Rect?> get at => _at;
  ValueListenable<Rect?> _at;
  set at(ValueListenable<Rect?> value) {
    if (identical(value, _at)) return;
    if (attached) {
      _at.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _at = value;
    markNeedsPaint();
  }

  EdgeInsets get padding => _padding;
  EdgeInsets _padding;
  set padding(EdgeInsets value) {
    if (value == _padding) return;
    _padding = value;
    markNeedsPaint();
  }

  double get radius => _radius;
  double _radius;
  set radius(double value) {
    if (value == _radius) return;
    _radius = value;
    markNeedsPaint();
  }

  final _clip = LayerHandle<ClipRRectLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _at.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _at.removeListener(markNeedsPaint);
    super.detach();
  }

  /// It draws under everything and takes no pointer, so it is never hit.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final deck = _at.value;
    final child = this.child;
    if (child == null || deck == null || deck.isEmpty) {
      _clip.layer = null;
      return;
    }
    final box = _padding.inflateRect(deck);
    _clip.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      box,
      RRect.fromRectAndRadius(box, Radius.circular(_radius)),
      (context, offset) => context.paintChild(child, offset),
      oldLayer: _clip.layer,
    );
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}
