import 'package:flutter/widgets.dart';

/// Draws what an open zone with no toast shows, in place of the built-in card.
typedef ZoneEmptyBuilder =
    Widget Function(BuildContext context, ZoneEmptyView view);

/// What a [ZoneEmptyBuilder] is handed.
class ZoneEmptyView {
  const ZoneEmptyView({required this.shown});

  /// How far the card is drawn, from 0 gone to 1 in full: it fades in as the
  /// last toast leaves an open zone and out as a toast arrives or the zone
  /// closes, which a look answers by repainting.
  final Animation<double> shown;
}
