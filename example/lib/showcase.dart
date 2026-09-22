import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_sonner/just_sonner.dart';

import 'harness.dart';
import 'looks.dart';
import 'settings.dart';

/// A `bool?` argument: unset, true or false.
enum _Tri {
  unset('unset'),
  on('true'),
  off('false');

  const _Tri(this.label);

  final String label;

  bool? get value => switch (this) {
    unset => null,
    on => true,
    off => false,
  };
}

/// Where a toast's `duration` comes from.
enum _Length {
  config('the config'),
  seconds('seconds'),
  none('none, until dismissed');

  const _Length(this.label);

  final String label;
}

enum _Leading { none, icon, spinner }

enum _Slot { none, undo, retry }

enum _Look { none, own, flashBar }

enum _Cap { none, pixels, share, toasts }

/// The colours a `Color?` option offers, null following the theme.
const _colours = <Color?>[null, Color(0xFF2E7D32), Color(0xFFC62828)];

String _colourName(Color? colour) => switch (colour?.toARGB32()) {
  null => 'the theme',
  0xFF2E7D32 => 'green',
  0xFFC62828 => 'red',
  _ => '$colour',
};

/// The example's main page: every option on the left, and buttons that show
/// toasts with them on the right.
class ShowcasePage extends StatefulWidget {
  const ShowcasePage({super.key, required this.settings});

  final ExampleSettings settings;

  @override
  State<ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<ShowcasePage> {
  final _title = TextEditingController(text: 'Event has been created');
  final _description = TextEditingController(
    text: 'Monday, January 3rd at 6:00pm',
  );
  bool _isLoading = false;
  _Leading _leading = _Leading.none;
  _Length _length = _Length.config;
  double _seconds = 4;
  _Tri _dismissible = _Tri.unset;
  _Tri _closeButton = _Tri.unset;
  _Slot _action = _Slot.none;
  _Look _look = _Look.none;

  /// Every id this page has shown, oldest first, for "Dismiss the newest".
  final List<ToastId> _shown = [];

  /// The id "Show" last returned, which "Update" and "Replace" act on.
  ToastId? _last;

  /// What the last "Update" returned, while it is the last thing pressed.
  bool? _updated;

  /// Bumped by "Reset", so every text field on the left takes its value
  /// again.
  int _resets = 0;

  final List<Timer> _timers = [];
  int _promises = 0;

  ExampleSettings get _settings => widget.settings;
  SonnerController get _toast => _settings.controller;
  SonnerConfig get _config => _settings.config;
  set _config(SonnerConfig value) => _settings.config = value;

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _after(Duration delay, VoidCallback action) {
    _timers.add(
      Timer(delay, () {
        if (mounted) action();
      }),
    );
  }

  // The toast the left side composes.

  String? get _descriptionNow =>
      _description.text.isEmpty ? null : _description.text;

  Widget? get _leadingNow => switch (_leading) {
    _Leading.none => null,
    _Leading.icon => const Icon(Icons.check_circle_outline),
    _Leading.spinner => const CircularProgressIndicator(strokeWidth: 2),
  };

  Duration? get _durationNow => switch (_length) {
    _Length.config => SonnerConfig.configDuration,
    _Length.seconds => Duration(milliseconds: (_seconds * 1000).round()),
    _Length.none => null,
  };

  ToastSlot? get _actionNow => switch (_action) {
    _Slot.none => null,
    _Slot.undo => (context, t) => TextButton(
      onPressed: t.dismiss,
      child: const Text('Undo'),
    ),
    _Slot.retry => (context, t) => TextButton(
      onPressed: () => _toast.update(t.id, title: 'Retrying…', isLoading: true),
      child: const Text('Retry'),
    ),
  };

  ToastBuilder? _builderOf(_Look look) => switch (look) {
    _Look.none => null,
    _Look.own => ownLook,
    _Look.flashBar => flashBar(swipe: false),
  };

  ToastId _show(
    String title, {
    String? description,
    bool isLoading = false,
    Widget? leading,
    Duration? duration = SonnerConfig.configDuration,
    bool? dismissible,
    ToastSlot? action,
    bool? closeButton,
    ToastId? id,
    ToastBuilder? builder,
  }) {
    final shown = _toast.show(
      title,
      description: description,
      isLoading: isLoading,
      leading: leading,
      duration: duration,
      dismissible: dismissible,
      action: action,
      closeButton: closeButton,
      id: id,
      builder: builder,
    );
    _shown.add(shown);
    return shown;
  }

  /// A new toast when [id] is null, and a replace of the toast at [id]
  /// otherwise.
  void _showComposed({ToastId? id, String suffix = ''}) {
    final shown = _show(
      '${_title.text}$suffix',
      description: _descriptionNow,
      isLoading: _isLoading,
      leading: _leadingNow,
      duration: _durationNow,
      dismissible: _dismissible.value,
      action: _actionNow,
      closeButton: _closeButton.value,
      id: id,
      builder: _builderOf(_look),
    );
    setState(() {
      _last = shown;
      _updated = null;
    });
  }

  void _updateComposed() {
    final last = _last;
    if (last == null) return;
    final updated = _toast.update(
      last,
      title: _title.text,
      description: _descriptionNow,
      isLoading: _isLoading,
      leading: _leadingNow,
      duration: _durationNow,
      dismissible: _dismissible.value,
      action: _actionNow,
      closeButton: _closeButton.value,
      builder: _builderOf(_look),
    );
    setState(() => _updated = updated);
  }

  /// Dismisses the newest toast still on screen. Nothing reports that a toast
  /// went away, so an update that changes nothing asks whether it is there.
  void _dismissNewest() {
    while (_shown.isNotEmpty) {
      final id = _shown.removeLast();
      if (!_toast.update(id)) continue;
      _toast.dismiss(id);
      return;
    }
  }

  void _promise<T>(
    Future<T> future, {
    required ToastContent loading,
    required ToastContent Function(T value) success,
    required ToastContent Function(Object error) error,
  }) {
    final id = ToastId('promise ${_promises++}');
    _shown.add(id);
    // `promise` hands the future's own error back; a button has no one to
    // hand it to.
    unawaited(
      _toast
          .promise(
            future,
            loading: loading,
            success: success,
            error: error,
            id: id,
          )
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }

  void _upload() {
    var percent = 0;
    final id = _show('Uploading 0%', description: 'Three files');
    late final Timer timer;
    timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return timer.cancel();
      percent += 10;
      if (percent < 100) {
        _toast.update(id, title: 'Uploading $percent%');
        return;
      }
      timer.cancel();
      _toast.update(id, title: 'Uploaded', description: '3 files, 1.2 MB');
    });
    _timers.add(timer);
  }

  Future<void> _openDialog() async {
    _after(const Duration(seconds: 1), () {
      _show(
        'Shown while the dialog is open',
        description: 'It sits above the barrier.',
      );
    });
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('A dialog'),
        content: const Text(
          'A toast comes up in a second. Toasts sit in the root overlay, '
          'above every route and dialog.',
        ),
        actions: [
          TextButton(
            onPressed: () => _show('From inside the dialog'),
            child: const Text('Show a toast'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('just_sonner'),
      actions: [
        IconButton(
          tooltip: 'Harness',
          onPressed: () => Navigator.of(context).push(harnessRoute(_settings)),
          icon: const Icon(Icons.science_outlined),
        ),
        IconButton(
          tooltip: _settings.themeMode == ThemeMode.dark ? 'Light' : 'Dark',
          onPressed: () =>
              _settings.themeMode = _settings.themeMode == ThemeMode.dark
              ? ThemeMode.light
              : ThemeMode.dark,
          icon: Icon(
            _settings.themeMode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 400,
            child: ListView(
              key: ValueKey(_resets),
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _options(_config),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Wrap(spacing: 16, runSpacing: 16, children: _actions()),
            ),
          ),
        ],
      ),
    ),
  );

  // The left side: every option.

  List<Widget> _options(SonnerConfig c) => [
    _Options(
      title: 'Toast',
      subtitle: 'What show is given',
      initiallyExpanded: true,
      children: [
        _Field(label: 'title', controller: _title),
        _Field(label: 'description', controller: _description),
        _Toggle(
          'isLoading',
          _isLoading,
          (value) => setState(() => _isLoading = value),
        ),
        _Pick<_Leading>(
          label: 'leading',
          value: _leading,
          values: _Leading.values,
          nameOf: (value) => switch (value) {
            _Leading.none => 'none',
            _Leading.icon => 'an icon',
            _Leading.spinner => 'a spinner of the app’s own',
          },
          onChanged: (value) => setState(() => _leading = value),
        ),
        _Pick<_Length>(
          label: 'duration',
          value: _length,
          values: _Length.values,
          nameOf: (value) => value.label,
          onChanged: (value) => setState(() => _length = value),
        ),
        if (_length == _Length.seconds)
          _Slide(
            label: 'seconds',
            value: _seconds,
            min: 1,
            max: 20,
            divisions: 19,
            onChanged: (value) => setState(() => _seconds = value),
          ),
        _Pick<_Tri>(
          label: 'dismissible',
          value: _dismissible,
          values: _Tri.values,
          nameOf: (value) => value.label,
          onChanged: (value) => setState(() => _dismissible = value),
        ),
        _Pick<_Tri>(
          label: 'closeButton',
          value: _closeButton,
          values: _Tri.values,
          nameOf: (value) => value.label,
          onChanged: (value) => setState(() => _closeButton = value),
        ),
        _Pick<_Slot>(
          label: 'action',
          value: _action,
          values: _Slot.values,
          nameOf: (value) => switch (value) {
            _Slot.none => 'none',
            _Slot.undo => 'Undo, which dismisses it',
            _Slot.retry => 'Retry, which makes it load',
          },
          onChanged: (value) => setState(() => _action = value),
        ),
        _Pick<_Look>(
          label: 'builder',
          value: _look,
          values: _Look.values,
          nameOf: _lookName,
          onChanged: (value) => setState(() => _look = value),
        ),
      ],
    ),
    _Options(
      title: 'Position and size',
      children: [
        _Pick<SonnerPosition>(
          label: 'position',
          value: c.position,
          values: SonnerPosition.values,
          nameOf: (value) => value.name,
          onChanged: (value) => _config = c.copyWith(position: value),
        ),
        _Slide(
          label: 'width',
          value: c.width,
          min: 240,
          max: 560,
          divisions: 32,
          onChanged: (value) => _config = c.copyWith(width: value),
        ),
        _Slide(
          label: 'gap',
          value: c.gap,
          min: 0,
          max: 40,
          divisions: 40,
          onChanged: (value) => _config = c.copyWith(gap: value),
        ),
        for (final (edge, value, set) in [
          ('offset top', c.offset.top, (double v) => c.offset.copyWith(top: v)),
          (
            'offset right',
            c.offset.right,
            (double v) => c.offset.copyWith(right: v),
          ),
          (
            'offset bottom',
            c.offset.bottom,
            (double v) => c.offset.copyWith(bottom: v),
          ),
          (
            'offset left',
            c.offset.left,
            (double v) => c.offset.copyWith(left: v),
          ),
        ])
          _Slide(
            label: edge,
            value: value,
            min: 0,
            max: 200,
            divisions: 50,
            onChanged: (v) => _config = c.copyWith(offset: set(v)),
          ),
        _Toggle(
          'A title bar of the app’s own, 60 px',
          _settings.titleBar,
          (value) => _settings.titleBar = value,
        ),
      ],
    ),
    _Options(
      title: 'Deck',
      children: [
        _Slide(
          label: 'visibleToasts',
          value: c.visibleToasts.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          onChanged: (value) =>
              _config = c.copyWith(visibleToasts: value.round()),
        ),
        _Toggle(
          'expandByDefault',
          c.expandByDefault,
          (value) => _config = c.copyWith(expandByDefault: value),
        ),
        _Toggle(
          'duration: null, every toast stays',
          c.duration == null,
          (on) => _config = c.copyWith(
            duration: () => on ? null : const Duration(seconds: 4),
          ),
        ),
        if (c.duration case final duration?)
          _Slide(
            label: 'duration, seconds',
            value: duration.inMilliseconds / 1000,
            min: 1,
            max: 20,
            divisions: 19,
            onChanged: (value) => _config = c.copyWith(
              duration: () => Duration(milliseconds: (value * 1000).round()),
            ),
          ),
      ],
    ),
    _Options(
      title: 'Look',
      children: [
        _Pick<_Look>(
          label: 'builder, for every toast',
          value: switch (c.builder) {
            null => _Look.none,
            final builder when identical(builder, ownLook) => _Look.own,
            _ => _Look.flashBar,
          },
          values: _Look.values,
          nameOf: _lookName,
          onChanged: (value) =>
              _config = c.copyWith(builder: () => _builderOf(value)),
        ),
        _Pick<String>(
          label: 'loadingIndicator',
          value: _indicators.keys.firstWhere(
            (name) => identical(_indicators[name], c.loadingIndicator),
          ),
          values: _indicators.keys.toList(),
          nameOf: (value) => value,
          onChanged: (value) =>
              _config = c.copyWith(loadingIndicator: _indicators[value]),
        ),
        _Slide(
          label: 'leadingSize',
          value: c.leadingSize,
          min: 12,
          max: 40,
          divisions: 28,
          onChanged: (value) => _config = c.copyWith(leadingSize: value),
        ),
        _Toggle(
          'closeButton',
          c.closeButton,
          (value) => _config = c.copyWith(closeButton: value),
        ),
      ],
    ),
    _timeLeftOptions(c),
    _Options(
      title: 'Swipe',
      children: [
        _Toggle(
          'swipeDirections from the position',
          c.swipeDirections == null,
          (on) => _config = c.copyWith(
            swipeDirections: () => on ? null : c.swipeDirectionsNow,
          ),
        ),
        if (c.swipeDirections case final directions?)
          Wrap(
            spacing: 8,
            children: [
              for (final direction in SwipeDirection.values)
                FilterChip(
                  label: Text(direction.name),
                  selected: directions.contains(direction),
                  onSelected: (on) => _config = c.copyWith(
                    swipeDirections: () => on
                        ? {...directions, direction}
                        : ({...directions}..remove(direction)),
                  ),
                ),
            ],
          ),
      ],
    ),
    _capOptions(c),
    _scrollbarOptions(c),
    _backdropOptions(c),
    _dismissAllOptions(c),
    _hideOptions(c),
    _zoneEmptyOptions(c),
    Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton(
        onPressed: () {
          _config = const SonnerConfig();
          setState(() => _resets++);
        },
        child: const Text('Reset the config'),
      ),
    ),
  ];

  static String _lookName(_Look look) => switch (look) {
    _Look.none => 'none, the default look',
    _Look.own => 'the example’s own',
    _Look.flashBar => 'a FlashBar through the adapter',
  };

  /// The loading indicators on offer, by name, the default read off the
  /// config.
  static final _indicators = <String, Widget>{
    'a thin spinner, the default': const SonnerConfig().loadingIndicator,
    'a thick red spinner': const CircularProgressIndicator(
      strokeWidth: 4,
      color: Color(0xFFC62828),
    ),
    'an hourglass, which settles': const Icon(Icons.hourglass_top),
  };

  Widget _timeLeftOptions(SonnerConfig c) {
    final left = c.timeLeft;
    void set(ToastTimeLeft? value) =>
        _config = c.copyWith(timeLeft: () => value);
    return _Options(
      title: 'Time left',
      children: [
        _Toggle(
          'timeLeft',
          left != null,
          (on) => set(on ? const ToastTimeLeft() : null),
        ),
        if (left != null) ...[
          _Pick<TimeLeftLook>(
            label: 'look',
            value: left.look,
            values: TimeLeftLook.values,
            nameOf: (value) => value.name,
            onChanged: (value) => set(left.copyWith(look: value)),
          ),
          _Pick<TimeLeftStart>(
            label: 'start, for the border',
            value: left.start,
            values: TimeLeftStart.values,
            nameOf: (value) => value.name,
            onChanged: (value) => set(left.copyWith(start: value)),
          ),
          _Toggle(
            'clockwise, for the border',
            left.clockwise,
            (value) => set(left.copyWith(clockwise: value)),
          ),
          _Slide(
            label: 'strokeWidth',
            value: left.strokeWidth,
            min: 1,
            max: 8,
            divisions: 14,
            onChanged: (value) => set(left.copyWith(strokeWidth: value)),
          ),
          _Pick<Color?>(
            label: 'color',
            value: left.color,
            values: _colours,
            nameOf: _colourName,
            onChanged: (value) => set(left.copyWith(color: () => value)),
          ),
          _Toggle(
            'keepBorder',
            left.keepBorder,
            (value) => set(left.copyWith(keepBorder: value)),
          ),
          _Toggle(
            'easeRestart',
            left.easeRestart,
            (value) => set(left.copyWith(easeRestart: value)),
          ),
          _Toggle(
            'fadeWhenCovered',
            left.fadeWhenCovered,
            (value) => set(left.copyWith(fadeWhenCovered: value)),
          ),
        ],
      ],
    );
  }

  Widget _capOptions(SonnerConfig c) {
    final cap = c.deckCap;
    final kind = switch (cap) {
      null => _Cap.none,
      DeckCap(pixels: _?) => _Cap.pixels,
      DeckCap(share: _?) => _Cap.share,
      _ => _Cap.toasts,
    };
    final fade = cap?.fade ?? 24;
    void set(DeckCap? value) => _config = c.copyWith(deckCap: () => value);
    return _Options(
      title: 'Deck cap',
      subtitle: 'How far the fanned-out deck reaches',
      children: [
        _Pick<_Cap>(
          label: 'deckCap',
          value: kind,
          values: _Cap.values,
          nameOf: (value) => switch (value) {
            _Cap.none => 'none, as far as the window',
            _Cap.pixels => 'pixels',
            _Cap.share => 'a share of the window',
            _Cap.toasts => 'a number of toasts',
          },
          onChanged: (value) => set(switch (value) {
            _Cap.none => null,
            _Cap.pixels => DeckCap.pixels(400, fade: fade),
            _Cap.share => DeckCap.share(0.6, fade: fade),
            _Cap.toasts => DeckCap.toasts(5, fade: fade),
          }),
        ),
        if (cap?.pixels case final pixels?)
          _Slide(
            label: 'pixels',
            value: pixels,
            min: 120,
            max: 800,
            divisions: 34,
            onChanged: (value) => set(DeckCap.pixels(value, fade: fade)),
          ),
        if (cap?.share case final share?)
          _Slide(
            label: 'share',
            value: share,
            min: 0.2,
            max: 1,
            divisions: 16,
            format: (value) => '${(value * 100).round()} %',
            onChanged: (value) => set(DeckCap.share(value, fade: fade)),
          ),
        if (cap?.toasts case final toasts?)
          _Slide(
            label: 'toasts',
            value: toasts.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (value) =>
                set(DeckCap.toasts(value.round(), fade: fade)),
          ),
        if (cap != null)
          _Slide(
            label: 'fade',
            value: fade,
            min: 0,
            max: 64,
            divisions: 16,
            onChanged: (value) => set(switch (cap) {
              DeckCap(:final pixels?) => DeckCap.pixels(pixels, fade: value),
              DeckCap(:final share?) => DeckCap.share(share, fade: value),
              _ => DeckCap.toasts(cap.toasts!, fade: value),
            }),
          ),
      ],
    );
  }

  Widget _scrollbarOptions(SonnerConfig c) {
    final bar = c.scrollbar;
    void set(DeckScrollbar? value) =>
        _config = c.copyWith(scrollbar: () => value);
    return _Options(
      title: 'Scrollbar',
      subtitle: 'Beside a fanned-out deck that scrolls',
      children: [
        _Toggle(
          'scrollbar',
          bar != null,
          (on) => set(on ? const DeckScrollbar() : null),
        ),
        if (bar != null) ...[
          _Pick<DeckScrollbarPlacement>(
            label: 'placement',
            value: bar.placement,
            values: DeckScrollbarPlacement.values,
            nameOf: (value) => value.name,
            onChanged: (value) => set(bar.copyWith(placement: value)),
          ),
          _Toggle(
            'alwaysShown',
            bar.alwaysShown,
            (value) => set(bar.copyWith(alwaysShown: value)),
          ),
          _Toggle(
            'draggable',
            bar.draggable,
            (value) => set(bar.copyWith(draggable: value)),
          ),
          _Slide(
            label: 'thickness',
            value: bar.thickness,
            min: 2,
            max: 12,
            divisions: 10,
            onChanged: (value) => set(bar.copyWith(thickness: value)),
          ),
          _Pick<Color?>(
            label: 'color',
            value: bar.color,
            values: _colours,
            nameOf: _colourName,
            onChanged: (value) => set(bar.copyWith(color: () => value)),
          ),
        ],
      ],
    );
  }

  Widget _backdropOptions(SonnerConfig c) {
    final backdrop = c.deckBackdrop;
    void set(DeckBackdrop? value) =>
        _config = c.copyWith(deckBackdrop: () => value);
    return _Options(
      title: 'Backdrop',
      subtitle: 'Behind the fanned-out deck',
      children: [
        _Toggle(
          'deckBackdrop',
          backdrop != null,
          (on) => set(on ? const DeckBackdrop() : null),
        ),
        if (backdrop != null) ...[
          _Slide(
            label: 'blur',
            value: backdrop.blur,
            min: 0,
            max: 32,
            divisions: 32,
            onChanged: (value) => set(backdrop.copyWith(blur: value)),
          ),
          _Slide(
            label: 'dim',
            value: backdrop.dim,
            min: 0,
            max: 0.6,
            divisions: 30,
            format: (value) => '${(value * 100).round()} %',
            onChanged: (value) => set(backdrop.copyWith(dim: value)),
          ),
          _Slide(
            label: 'padding',
            value: backdrop.padding.top,
            min: 0,
            max: 48,
            divisions: 24,
            onChanged: (value) =>
                set(backdrop.copyWith(padding: EdgeInsets.all(value))),
          ),
          _Slide(
            label: 'radius',
            value: backdrop.radius,
            min: 0,
            max: 32,
            divisions: 32,
            onChanged: (value) => set(backdrop.copyWith(radius: value)),
          ),
          _Pick<Color?>(
            label: 'color',
            value: backdrop.color,
            values: const [null, Color(0xFF000000), Color(0xFFFFFFFF)],
            nameOf: (value) => switch (value?.toARGB32()) {
              null => 'the theme’s scrim',
              0xFF000000 => 'black',
              _ => 'white',
            },
            onChanged: (value) => set(backdrop.copyWith(color: () => value)),
          ),
        ],
      ],
    );
  }

  Widget _dismissAllOptions(SonnerConfig c) {
    final control = c.dismissAll;
    void set(DeckDismissAll? value) =>
        _config = c.copyWith(dismissAll: () => value);
    return _Options(
      title: 'Dismiss all',
      subtitle: 'At the fanned-out deck’s far end',
      children: [
        _Toggle(
          'dismissAll',
          control != null,
          (on) => set(on ? const DeckDismissAll() : null),
        ),
        if (control != null) ...[
          _Pick<DeckDismissAllLook>(
            label: 'look',
            value: control.look,
            values: DeckDismissAllLook.values,
            nameOf: (value) => value.name,
            onChanged: (value) => set(control.copyWith(look: value)),
          ),
          _Field(
            label: 'label',
            initialValue: control.label,
            onChanged: (value) => set(control.copyWith(label: value)),
          ),
          _Toggle(
            'countLabel in Korean, for the header',
            control.countLabel != null,
            (on) => set(
              control.copyWith(countLabel: () => on ? koreanCount : null),
            ),
          ),
          _Toggle(
            'builder of the app’s own',
            control.builder != null,
            (on) =>
                set(control.copyWith(builder: () => on ? ownDismissAll : null)),
          ),
        ],
      ],
    );
  }

  Widget _hideOptions(SonnerConfig c) {
    final control = c.hideControl;
    final motion = c.hideMotion;
    void set(DeckHideControl? value) =>
        _config = c.copyWith(hideControl: () => value);
    void setMotion(DeckHideMotion value) =>
        _config = c.copyWith(hideMotion: value);
    return _Options(
      title: 'Hide',
      subtitle: 'Taking the deck out of sight, its toasts kept',
      children: [
        _Toggle(
          'hideControl',
          control != null,
          (on) => set(on ? const DeckHideControl() : null),
        ),
        if (control != null) ...[
          _Pick<DeckHideLook>(
            label: 'look',
            value: control.look,
            values: DeckHideLook.values,
            nameOf: (value) => value.name,
            onChanged: (value) => set(control.copyWith(look: value)),
          ),
          _Field(
            label: 'label',
            initialValue: control.label,
            onChanged: (value) => set(control.copyWith(label: value)),
          ),
          _Toggle(
            'countLabel in Korean, for the header',
            control.countLabel != null,
            (on) => set(
              control.copyWith(countLabel: () => on ? koreanCount : null),
            ),
          ),
          _Toggle(
            'builder of the app’s own',
            control.builder != null,
            (on) => set(control.copyWith(builder: () => on ? ownHide : null)),
          ),
        ],
        _Pick<DeckHideMotionLook>(
          label: 'hideMotion',
          value: motion.look,
          values: DeckHideMotionLook.values,
          nameOf: (value) => value.name,
          onChanged: (value) => setMotion(motion.copyWith(look: value)),
        ),
        _Toggle(
          'hideMotion builder of the app’s own: a quarter turn',
          motion.builder != null,
          (on) => setMotion(
            motion.copyWith(builder: () => on ? ownHideMotion : null),
          ),
        ),
      ],
    );
  }

  Widget _zoneEmptyOptions(SonnerConfig c) {
    final empty = c.zoneEmpty;
    void set(ZoneEmpty? value) => _config = c.copyWith(zoneEmpty: () => value);
    return _Options(
      title: 'Zone empty',
      subtitle: 'What an open zone draws with no toast',
      children: [
        _Toggle(
          'zoneEmpty',
          empty != null,
          (on) => set(on ? const ZoneEmpty() : null),
        ),
        if (empty != null) ...[
          _Field(
            label: 'label',
            initialValue: empty.label,
            onChanged: (value) => set(empty.copyWith(label: value)),
          ),
          _Toggle(
            'builder of the app’s own',
            empty.builder != null,
            (on) => set(empty.copyWith(builder: () => on ? ownEmpty : null)),
          ),
        ],
      ],
    );
  }

  // The right side: buttons.

  List<Widget> _actions() {
    final last = _last;
    return [
      _Group(
        title: 'Toast',
        caption: 'Shows what the Toast options on the left compose.',
        footer: switch ((last, _updated)) {
          (null, _) => 'Nothing shown yet.',
          (final id?, false) => 'update(${id.value}) returned false: gone.',
          (final id?, _) => 'The last: ${id.value}',
        },
        children: [
          _Action('Show', _showComposed),
          _Action('Show three', () {
            for (var n = 1; n <= 3; n++) {
              _showComposed(suffix: ' ($n of 3)');
            }
          }),
          _Action('Update the last', _updateComposed),
          _Action('Replace the last', () {
            if (last != null) _showComposed(id: last);
          }),
          _Action('Dismiss the newest', _dismissNewest),
          _Action('Dismiss all', _toast.dismissAll),
        ],
      ),
      _Group(
        title: 'Flows',
        caption: 'One toast changing in place.',
        children: [
          _Action('Loading, then done', () {
            final id = _show('Saving…', isLoading: true);
            _after(const Duration(seconds: 2), () {
              _toast.update(
                id,
                title: 'Saved',
                isLoading: false,
                leading: const Icon(Icons.check_circle_outline),
              );
            });
          }),
          _Action('Three steps at one id', () {
            final id = _show('Checking credentials…', isLoading: true);
            _after(const Duration(seconds: 2), () {
              _toast.update(id, title: 'Opening the session…');
            });
            _after(const Duration(seconds: 4), () {
              _toast.update(id, title: 'Connected', isLoading: false);
            });
          }),
          _Action('promise that succeeds', () {
            _promise(
              Future.delayed(const Duration(seconds: 2), () => 3),
              loading: const ToastContent('Uploading…'),
              success: (files) => ToastContent('Uploaded $files files'),
              error: (e) => ToastContent('Upload failed', description: '$e'),
            );
          }),
          _Action('promise that fails', () {
            _promise<void>(
              Future.delayed(
                const Duration(seconds: 2),
                () => throw Exception('connection refused'),
              ),
              loading: const ToastContent('Connecting…'),
              success: (_) => const ToastContent('Connected'),
              error: (e) =>
                  ToastContent('Could not connect', description: '$e'),
            );
          }),
          _Action('Upload, updated every 400 ms', _upload),
        ],
      ),
      _Group(
        title: 'Zone',
        caption: 'The layer the deck lives in, opened and closed by the app.',
        footer: '',
        status: ListenableBuilder(
          listenable: _toast,
          builder: (context, _) => Text(
            'state: ${_toast.zone.state.name} · held: ${_toast.zone.held}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        children: [
          _Action('open()', _toast.zone.open),
          _Action('close()', _toast.zone.close),
          _Action('hide()', _toast.zone.hide),
          _Action('reveal()', _toast.zone.reveal),
        ],
      ),
      _Group(
        title: 'Scenarios',
        caption: 'Situations worth watching, whatever the options are.',
        children: [
          _Action('A burst of twelve', () {
            for (var n = 1; n <= 12; n++) {
              _show('Burst $n of 12');
            }
          }),
          _Action('Twenty that stay', () {
            for (var n = 1; n <= 20; n++) {
              _show('Staying $n of 20', duration: null);
            }
          }),
          _Action('A tall one, then a short one', () {
            _show(
              'A tall one',
              description: 'With a line under it, and another under that.',
              duration: null,
            );
            _after(const Duration(milliseconds: 600), () {
              _show('A short one', duration: null);
            });
          }),
          _Action('In 2 s, under a still pointer', () {
            _after(const Duration(seconds: 2), () {
              _show(
                'Landed under a still pointer',
                description: 'It counts down until the mouse moves.',
              );
            });
          }),
          _Action('Eight, 1.5 s apart', () {
            for (var i = 0; i < 8; i++) {
              _after(Duration(milliseconds: 1500 * i), () {
                _show(
                  'Stream ${i + 1} of 8',
                  duration: const Duration(seconds: 3),
                );
              });
            }
          }),
          _Action('Over a dialog', _openDialog),
        ],
      ),
    ];
  }
}

/// One group of options on the left, folded away until it is opened.
class _Options extends StatelessWidget {
  const _Options({
    required this.title,
    this.subtitle,
    this.initiallyExpanded = false,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final bool initiallyExpanded;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return ExpansionTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      initiallyExpanded: initiallyExpanded,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// A group of buttons on the right.
class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.caption,
    this.footer,
    this.status,
    required this.children,
  });

  final String title;
  final String caption;
  final String? footer;
  final Widget? status;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final footer = this.footer;
    final status = this.status;
    return SizedBox(
      width: 360,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                caption,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: children),
              if (status != null) ...[const SizedBox(height: 12), status],
              if (footer != null && footer.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(footer, style: theme.textTheme.labelLarge),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      FilledButton.tonal(onPressed: onPressed, child: Text(label));
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.label, this.value, this.onChanged);

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(label),
    value: value,
    onChanged: onChanged,
  );
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    this.format,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double value)? format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final shown = format?.call(value) ?? _plain(value);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: shown,
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 48, child: Text(shown, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  static String _plain(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1);
}

class _Pick<T> extends StatelessWidget {
  const _Pick({
    required this.label,
    required this.value,
    required this.values,
    required this.nameOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) nameOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: DropdownButtonFormField<T>(
      // Keyed by the value, so a change from elsewhere, such as a reset,
      // shows here.
      key: ValueKey(value),
      initialValue: value,
      isDense: true,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final value in values)
          DropdownMenuItem(value: value, child: Text(nameOf(value))),
      ],
      onChanged: (value) => onChanged(value as T),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    this.controller,
    this.initialValue,
    this.onChanged,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      controller: controller,
      initialValue: initialValue,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}
