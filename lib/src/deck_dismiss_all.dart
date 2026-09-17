import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'config.dart';
import 'dismiss_all_view.dart';

/// The [DeckDismissAll] control: its builder's widget, or the look it names.
class DeckDismissAllButton extends StatelessWidget {
  const DeckDismissAllButton({
    super.key,
    required this.control,
    required this.count,
    required this.onDismiss,
    required this.expansion,
    required this.width,
  });

  final DeckDismissAll control;

  /// How many toasts [onDismiss] dismisses.
  final int count;
  final VoidCallback onDismiss;

  /// How far the deck is fanned out; the built-in looks fade with it.
  final Animation<double> expansion;

  /// The deck's width, which a [DeckDismissAllLook.header] takes.
  final double width;

  @override
  Widget build(BuildContext context) {
    final builder = control.builder;
    if (builder != null) {
      return builder(
        context,
        DeckDismissAllView(
          count: count,
          dismiss: onDismiss,
          expansion: expansion,
        ),
      );
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final side = BorderSide(color: colors.outlineVariant);
    return FadeTransition(
      opacity: expansion,
      child: switch (control.look) {
        DeckDismissAllLook.pill => Material(
          color: colors.surfaceContainerHigh,
          shape: StadiumBorder(side: side),
          child: Semantics(
            button: true,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onDismiss,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  control.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
        DeckDismissAllLook.header => SizedBox(
          width: width,
          child: Material(
            color: colors.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              side: side,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      control.countLabel?.call(count) ?? '$count notifications',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onDismiss,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(control.label),
                  ),
                ],
              ),
            ),
          ),
        ),
      },
    );
  }
}

/// The two children of [DeckLayers].
enum DeckLayerSlot { deck, control }

/// The [deck] filling the layer, and over it a [control] laid out loose and
/// drawn at the place [at] holds.
///
/// The control is laid out first and its size reported through
/// [onControlSize], so the deck's own layout can place it in the same frame;
/// it is drawn outside the deck, so nothing that cuts the deck cuts it.
class DeckLayers
    extends SlottedMultiChildRenderObjectWidget<DeckLayerSlot, RenderBox> {
  const DeckLayers({
    super.key,
    required this.deck,
    required this.control,
    required this.at,
    required this.onControlSize,
  });

  final Widget deck;
  final Widget? control;
  final ValueListenable<Rect?> at;
  final ValueChanged<Size?> onControlSize;

  @override
  Iterable<DeckLayerSlot> get slots => DeckLayerSlot.values;

  @override
  Widget? childForSlot(DeckLayerSlot slot) => switch (slot) {
    DeckLayerSlot.deck => deck,
    DeckLayerSlot.control => control,
  };

  @override
  RenderDeckLayers createRenderObject(BuildContext context) =>
      RenderDeckLayers(at: at, onControlSize: onControlSize);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderDeckLayers renderObject,
  ) => renderObject
    ..at = at
    ..onControlSize = onControlSize;
}

class RenderDeckLayers extends RenderBox
    with SlottedContainerRenderObjectMixin<DeckLayerSlot, RenderBox> {
  RenderDeckLayers({
    required ValueListenable<Rect?> at,
    required this.onControlSize,
  }) : _at = at;

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

  ValueChanged<Size?> onControlSize;

  RenderBox? get _deck => childForSlot(DeckLayerSlot.deck);
  RenderBox? get _control => childForSlot(DeckLayerSlot.control);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    // The place is reported while the deck lays out, which can follow a paint
    // of this box that read the one before.
    _at.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _at.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.biggest;

  @override
  void performLayout() {
    size = constraints.biggest;
    final control = _control;
    if (control == null) {
      onControlSize(null);
    } else {
      control.layout(BoxConstraints.loose(size), parentUsesSize: true);
      onControlSize(control.size);
    }
    _deck?.layout(BoxConstraints.tight(size));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final deck = _deck;
    if (deck != null) context.paintChild(deck, offset);
    final control = _control;
    final at = _at.value;
    if (control != null && at != null) {
      context.paintChild(control, offset + at.topLeft);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final control = _control;
    final at = _at.value;
    if (control != null &&
        at != null &&
        result.addWithPaintOffset(
          offset: at.topLeft,
          position: position,
          hitTest: (result, transformed) =>
              control.hitTest(result, position: transformed),
        )) {
      return true;
    }
    return _deck?.hitTest(result, position: position) ?? false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final at = _at.value;
    if (identical(child, _control) && at != null) {
      transform.translateByDouble(at.left, at.top, 0, 1);
    }
  }
}
