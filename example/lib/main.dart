import 'dart:async';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:just_sonner/just_sonner.dart';

import 'flash_adapter.dart';

void main() => runApp(const ExampleApp());

/// A desktop harness for just_sonner: one button per behaviour that exists, so
/// each can be felt rather than only tested.
///
/// It grew one section at a time, alongside the package, and each section names
/// the issue it came from.
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  ThemeMode _themeMode = ThemeMode.light;
  late final SonnerController _controller = SonnerController()
    ..attach(_navigatorKey);

  /// Whether the app draws its own title bar over everything, as a desktop app
  /// that hides the system one does.
  bool _titleBar = false;

  /// Assigned to the one controller, so the toasts on screen stay and follow.
  void _setConfig(SonnerConfig config) =>
      setState(() => _controller.config = config);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'just_sonner',
    navigatorKey: _navigatorKey,
    debugShowCheckedModeBanner: false,
    themeMode: _themeMode,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.dark,
      ),
    ),
    builder: (context, child) =>
        Stack(children: [child!, if (_titleBar) const _TitleBar()]),
    home: _Panel(
      controller: _controller,
      config: _controller.config,
      onConfig: _setConfig,
      themeMode: _themeMode,
      onThemeMode: (mode) => setState(() => _themeMode = mode),
      titleBar: _titleBar,
      onTitleBar: (value) => setState(() => _titleBar = value),
    ),
  );
}

/// A 60 px title bar with window buttons in its top-right corner, drawn over
/// the toasts as an app's own chrome is.
class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 60,
      child: IgnorePointer(
        child: Material(
          color: scheme.inverseSurface.withValues(alpha: 0.92),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Text(
                'The app’s own title bar, 60 px',
                style: TextStyle(color: scheme.onInverseSurface),
              ),
              const Spacer(),
              for (final icon in [Icons.remove, Icons.crop_square, Icons.close])
                SizedBox(
                  width: 35,
                  child: Icon(icon, size: 16, color: scheme.onInverseSurface),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatefulWidget {
  const _Panel({
    required this.controller,
    required this.config,
    required this.onConfig,
    required this.themeMode,
    required this.onThemeMode,
    required this.titleBar,
    required this.onTitleBar,
  });

  final SonnerController controller;
  final SonnerConfig config;
  final ValueChanged<SonnerConfig> onConfig;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;
  final bool titleBar;
  final ValueChanged<bool> onTitleBar;

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  /// The id the update and replace buttons act on, so they can be pressed in
  /// any order against whatever "Show a toast to change" put up.
  static const ToastId _target = ToastId('target');

  /// Every id this panel has shown, oldest first. The package does not report
  /// that a toast went away (#16) and has no way to ask what is on screen, so
  /// finding the newest toast still up means walking this back and probing.
  final List<ToastId> _shown = [];

  Timer? _progress;

  /// Names the toasts the promise buttons drive, since `promise` returns the
  /// future rather than an id.
  int _promises = 0;

  SonnerController get _toast => widget.controller;

  /// Whether this panel collapses the app's expansion once the pointer has
  /// held the deck and let go, and whether it held it at the last change.
  bool _foldOnLeave = false;
  bool _wasHeld = false;

  void _foldUpWhenLeft() {
    final held = _toast.held;
    if (_foldOnLeave && _wasHeld && !held) _toast.collapse();
    _wasHeld = held;
  }

  @override
  void initState() {
    super.initState();
    _toast.addListener(_foldUpWhenLeft);
  }

  /// What is drawn behind the deck once it fans out, and every field of
  /// `SonnerConfig.deckBackdrop` that draws it.
  Widget _backdropSection(SonnerConfig config) {
    final backdrop = config.deckBackdrop;
    void set(DeckBackdrop? value) =>
        widget.onConfig(config.copyWith(deckBackdrop: () => value));

    return _Section(
      title: 'Behind the fanned-out deck',
      issue: 78,
      note:
          'Hover the deck and watch what is behind it. It is drawn to the '
          'deck\'s own box and reaches padding further, and it follows the '
          'expansion, so a collapsed deck draws none of it. Off is the '
          'default.',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('deckBackdrop'),
          value: backdrop != null,
          onChanged: (on) => set(on ? const DeckBackdrop() : null),
        ),
        if (backdrop != null) ...[
          _Dropdown<double>(
            label: 'blur',
            value: backdrop.blur,
            values: {0.0, 4.0, 8.0, 12.0, 20.0, 32.0, backdrop.blur}.toList()
              ..sort(),
            nameOf: (value) =>
                value == 0 ? 'none (dim only)' : 'sigma ${value.round()}',
            onChanged: (value) => set(backdrop.copyWith(blur: value)),
          ),
          _Dropdown<double>(
            label: 'dim',
            value: backdrop.dim,
            values: {0.0, 0.06, 0.12, 0.2, 0.32, backdrop.dim}.toList()..sort(),
            nameOf: (value) => value == 0
                ? 'none (blur only)'
                : '${(value * 100).round()} % of the colour',
            onChanged: (value) => set(backdrop.copyWith(dim: value)),
          ),
          Builder(
            builder: (context) => _Dropdown<Color?>(
              label: 'colour',
              value: backdrop.color,
              // A set, so a colour set from code that is already offered here
              // does not become a second item with the same value.
              values: {
                null,
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.inverseSurface,
                const Color(0xFF000000),
                const Color(0xFFFFFFFF),
                backdrop.color,
              }.toList(),
              nameOf: (value) => switch (value) {
                null => "the theme's scrim",
                const Color(0xFF000000) => 'black',
                const Color(0xFFFFFFFF) => 'white',
                _ when value == Theme.of(context).colorScheme.primary =>
                  'colorScheme.primary',
                _ when value == Theme.of(context).colorScheme.inverseSurface =>
                  'colorScheme.inverseSurface',
                _ => value.toString(),
              },
              onChanged: (value) => set(backdrop.copyWith(color: () => value)),
            ),
          ),
          _Dropdown<EdgeInsets>(
            label: 'padding',
            value: backdrop.padding,
            values: {
              EdgeInsets.zero,
              const EdgeInsets.all(6),
              const EdgeInsets.all(12),
              const EdgeInsets.all(20),
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              backdrop.padding,
            }.toList(),
            nameOf: (value) => value == EdgeInsets.zero
                ? 'none — stops at the cards'
                : 'L${value.left.round()} T${value.top.round()} '
                      'R${value.right.round()} B${value.bottom.round()}',
            onChanged: (value) => set(backdrop.copyWith(padding: value)),
          ),
          _Dropdown<double>(
            label: 'radius',
            value: backdrop.radius,
            values: {0.0, 8.0, 12.0, 16.0, 24.0, backdrop.radius}.toList()
              ..sort(),
            nameOf: (value) =>
                value == 0 ? 'a hard rectangle' : value.round().toString(),
            onChanged: (value) => set(backdrop.copyWith(radius: value)),
          ),
        ],
        _Button('Show three to hover', () {
          for (final line in [
            ('Build finished', 'main · 2 m 14 s'),
            ('Tests passed', '318 of 318'),
            ('Deploy finished', 'staging · 41 s'),
          ]) {
            _show(line.$1, description: line.$2, duration: Duration.zero);
          }
        }),
        _Button('Show ten, so the deck is tall', () {
          for (var n = 0; n < 10; n++) {
            _show(
              'Toast $n',
              description: 'one of ten',
              duration: Duration.zero,
            );
          }
        }),
      ],
    );
  }

  /// The offsets the "Offset per edge" section offers, by name.
  static final _offsets = {
    const EdgeInsets.all(24): 'all 24 (the default)',
    const EdgeInsets.fromLTRB(24, 68, 16, 24):
        'clear a title bar: top 68, right 16',
    const EdgeInsets.fromLTRB(160, 24, 8, 24): 'wide left: left 160, right 8',
  };

  @override
  void didUpdateWidget(_Panel old) {
    super.didUpdateWidget(old);
    // A new controller is a new set of toasts; the old id is on nothing.
    if (!identical(old.controller, widget.controller)) {
      _stopProgress();
      _shown.clear();
      old.controller.removeListener(_foldUpWhenLeft);
      widget.controller.addListener(_foldUpWhenLeft);
      _wasHeld = false;
    }
  }

  @override
  void dispose() {
    _progress?.cancel();
    _toast.removeListener(_foldUpWhenLeft);
    super.dispose();
  }

  void _stopProgress() {
    _progress?.cancel();
    _progress = null;
  }

  ToastId _show(
    String title, {
    String? description,
    bool isLoading = false,
    Widget? leading,
    Duration? duration,
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

  /// Drives one `promise` and keeps its toast reachable from "Dismiss the
  /// newest".
  ///
  /// `promise` returns the future's own outcome, so the error it rethrows is
  /// this panel's to handle — an unhandled one would reach the app, which is
  /// the point of the rule rather than a wrinkle in it. It also returns no id,
  /// so the panel names the toast itself.
  void _promise<T>(
    Future<T> future, {
    required ToastContent loading,
    required ToastContent Function(T value) success,
    required ToastContent Function(Object error) error,
    ToastId? id,
  }) {
    final at = id ?? ToastId('promise ${_promises++}');
    _shown.add(at);
    unawaited(
      _toast
          .promise(
            future,
            id: at,
            loading: loading,
            success: success,
            error: error,
          )
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }

  /// Dismisses the newest toast still on screen.
  ///
  /// An id outlives its toast — it stays valid to hold and useless to dismiss —
  /// and nothing tells the panel when one expires, so the ids it kept go stale
  /// silently. `update` is the only public answer to "is this one still up?":
  /// it returns false once the toast is gone. Walking back to the first id that
  /// answers yes finds the newest toast on screen.
  void _dismissNewest() {
    while (_shown.isNotEmpty) {
      final id = _shown.removeLast();
      // A no-op update, so it only asks; it does restart that toast's
      // countdown, which the dismiss on the next line makes moot.
      if (!_toast.update(id)) continue;
      _toast.dismiss(id);
      return;
    }
  }

  /// Updates one toast ten times, 400 ms apart. Each update restarts the
  /// countdown, so it stays up while they keep coming and goes its full
  /// duration after the last one.
  void _runProgress() {
    _stopProgress();
    var percent = 0;
    final id = _show(
      'Uploading 0%',
      description: 'Each update restarts the countdown.',
    );
    _progress = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      percent += 10;
      if (percent < 100) {
        _toast.update(id, title: 'Uploading $percent%');
        return;
      }
      timer.cancel();
      _progress = null;
      _toast.update(id, title: 'Uploaded', description: '3 files, 1.2 MB');
    });
  }

  Future<void> _openDialog({bool toastAfter = false}) async {
    if (toastAfter) {
      Timer(const Duration(seconds: 1), () {
        if (!mounted) return;
        _show(
          'Shown while the dialog is open',
          description: 'Mount mode 1 keeps it above the barrier.',
        );
      });
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('A dialog'),
        content: const Text(
          'Toasts live in the root overlay, so they sit above this dialog and '
          'its barrier.',
        ),
        actions: [
          TextButton(
            onPressed: () => _show(
              'From inside the dialog',
              description: 'Still above the barrier.',
            ),
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
          tooltip: widget.themeMode == ThemeMode.dark ? 'Light' : 'Dark',
          onPressed: () => widget.onThemeMode(
            widget.themeMode == ThemeMode.dark
                ? ThemeMode.light
                : ThemeMode.dark,
          ),
          icon: Icon(
            widget.themeMode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth - 48;
        final width = room >= 664 ? 320.0 : room;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              for (final section in _sections(widget.config))
                SizedBox(width: width, child: section),
            ],
          ),
        );
      },
    ),
  );

  /// A look of the panel's own: a dark card, given apart from what is written
  /// on it, so the package fits the text to the card and fades it while the
  /// deck covers the toast.
  static final ToastBuilder _ownLook = toastCardBuilder(
    card: (context, toast, child) => Material(
      color: Theme.of(context).colorScheme.inverseSurface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
    content: (context, toast) {
      final onCard = Theme.of(context).colorScheme.onInverseSurface;
      final description = toast.state.description;
      return Row(
        children: [
          Icon(Icons.rocket_launch, color: onCard),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(toast.state.title, style: TextStyle(color: onCard)),
                if (description != null)
                  Text(description, style: TextStyle(color: onCard)),
              ],
            ),
          ),
        ],
      );
    },
  );

  /// A `FlashBar` through the adapter, its text faded by `covered`, with
  /// flash's own swipe or the toast's.
  static ToastBuilder _flashBar({required bool swipe}) => flashToast((
    context,
    controller,
    toast,
  ) {
    final shown = ReverseAnimation(toast.covered);
    return FlashBar(
      controller: controller,
      dismissDirections: swipe ? FlashDismissDirection.values : const [],
      title: FadeTransition(opacity: shown, child: const Text('FlashBar')),
      content: FadeTransition(opacity: shown, child: Text(toast.state.title)),
    );
  });

  /// A control for each field of `config.timeLeft`, and one to take it away.
  /// An app's own dismiss-all control, handed the count and a way to dismiss.
  static Widget _ownDismissAll(BuildContext context, DeckDismissAllView view) =>
      FadeTransition(
        opacity: view.expansion,
        child: Material(
          color: Colors.transparent,
          child: TextButton.icon(
            onPressed: view.dismiss,
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: Text('Dismiss ${view.count}'),
          ),
        ),
      );

  static String _koreanCount(int count) => '알림 $count개';

  static String _koreanHidden(int count) => '$count개 숨김';

  /// An app's own stow control, handed the count and a way to stow.
  static Widget _ownStow(BuildContext context, DeckStowView view) =>
      FadeTransition(
        opacity: view.expansion,
        child: Material(
          color: Colors.transparent,
          child: TextButton.icon(
            onPressed: view.stow,
            icon: const Icon(Icons.visibility_off_outlined, size: 18),
            label: Text('Put ${view.count} away'),
          ),
        ),
      );

  /// An app's own motion: the deck spins a quarter turn as it goes.
  static Widget _ownStowMotion(
    BuildContext context,
    DeckStowMotionView view,
    Widget deck,
  ) => Opacity(
    opacity: 1 - view.stowed.value,
    child: Transform.rotate(
      angle: view.stowed.value * 0.25,
      alignment: view.position.isTop
          ? Alignment.topCenter
          : Alignment.bottomCenter,
      child: deck,
    ),
  );

  /// An app's own handle, handed the count and a way to bring the deck back.
  static Widget _ownStowHandle(BuildContext context, DeckStowHandleView view) =>
      FadeTransition(
        opacity: view.shown,
        child: FloatingActionButton.extended(
          onPressed: view.unstow,
          icon: const Icon(Icons.inbox_outlined),
          label: Text('${view.count} waiting'),
        ),
      );

  /// A control for each field of `config.stowControl`, `stowMotion` and
  /// `stowHandle`, and one to take each of the two nullable ones away.
  List<Widget> _stowControls(SonnerConfig config) {
    final control = config.stowControl;
    final motion = config.stowMotion;
    final handle = config.stowHandle;
    void setControl(DeckStowControl? value) =>
        widget.onConfig(config.copyWith(stowControl: () => value));
    void setMotion(DeckStowMotion value) =>
        widget.onConfig(config.copyWith(stowMotion: value));
    void setHandle(DeckStowHandle? value) =>
        widget.onConfig(config.copyWith(stowHandle: () => value));
    return [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('stowControl'),
        value: control != null,
        onChanged: (on) => setControl(on ? const DeckStowControl() : null),
      ),
      if (control != null) ...[
        _Dropdown<DeckStowLook>(
          label: 'look (stowControl)',
          value: control.look,
          values: DeckStowLook.values,
          nameOf: (value) => value.name,
          onChanged: (value) => setControl(control.copyWith(look: value)),
        ),
        _Dropdown<String>(
          label: 'label (stowControl)',
          value: control.label,
          values: {'Hide', '숨기기', control.label}.toList(),
          nameOf: (value) => value,
          onChanged: (value) => setControl(control.copyWith(label: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("countLabel: '알림 N개' (header)"),
          value: control.countLabel != null,
          onChanged: (on) => setControl(
            control.copyWith(countLabel: () => on ? _koreanCount : null),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("builder: the app's own control"),
          value: control.builder != null,
          onChanged: (on) =>
              setControl(control.copyWith(builder: () => on ? _ownStow : null)),
        ),
      ],
      _Dropdown<DeckStowMotionLook>(
        label: 'look (stowMotion)',
        value: motion.look,
        values: DeckStowMotionLook.values,
        nameOf: (value) => value.name,
        onChanged: (value) => setMotion(motion.copyWith(look: value)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text("builder: the app's own motion (a quarter turn)"),
        value: motion.builder != null,
        onChanged: (on) => setMotion(
          motion.copyWith(builder: () => on ? _ownStowMotion : null),
        ),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('stowHandle'),
        value: handle != null,
        onChanged: (on) => setHandle(on ? const DeckStowHandle() : null),
      ),
      if (handle != null) ...[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("countLabel: 'N개 숨김'"),
          value: handle.countLabel != null,
          onChanged: (on) => setHandle(
            handle.copyWith(countLabel: () => on ? _koreanHidden : null),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("builder: the app's own handle"),
          value: handle.builder != null,
          onChanged: (on) => setHandle(
            handle.copyWith(builder: () => on ? _ownStowHandle : null),
          ),
        ),
      ],
    ];
  }

  /// A control for each field of `config.dismissAll`, and one to take it away.
  List<Widget> _dismissAllControls(SonnerConfig config) {
    final control = config.dismissAll;
    void set(DeckDismissAll? value) =>
        widget.onConfig(config.copyWith(dismissAll: () => value));
    return [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('dismissAll'),
        value: control != null,
        onChanged: (on) => set(on ? const DeckDismissAll() : null),
      ),
      if (control != null) ...[
        _Dropdown<DeckDismissAllLook>(
          label: 'look (dismissAll)',
          value: control.look,
          values: DeckDismissAllLook.values,
          nameOf: (value) => value.name,
          onChanged: (value) => set(control.copyWith(look: value)),
        ),
        _Dropdown<String>(
          label: 'label',
          value: control.label,
          values: {'Clear all', '모두 지우기', control.label}.toList(),
          nameOf: (value) => value,
          onChanged: (value) => set(control.copyWith(label: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("countLabel: '알림 N개' (header)"),
          value: control.countLabel != null,
          onChanged: (on) =>
              set(control.copyWith(countLabel: () => on ? _koreanCount : null)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("builder: the app's own"),
          value: control.builder != null,
          onChanged: (on) =>
              set(control.copyWith(builder: () => on ? _ownDismissAll : null)),
        ),
      ],
    ];
  }

  /// A control for each field of `config.deckCap` and `config.scrollbar`,
  /// and one to take each away.
  List<Widget> _deckCapControls(SonnerConfig config) {
    final cap = config.deckCap;
    final bar = config.scrollbar;
    void setCap(DeckCap? value) =>
        widget.onConfig(config.copyWith(deckCap: () => value));
    void setBar(DeckScrollbar? value) =>
        widget.onConfig(config.copyWith(scrollbar: () => value));
    final fade = cap?.fade ?? 24;
    return [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('deckCap'),
        value: cap != null,
        onChanged: (on) => setCap(on ? const DeckCap.pixels(400) : null),
      ),
      if (cap != null) ...[
        _Dropdown<DeckCap>(
          label: 'cap',
          value: cap,
          values: {
            for (final value in [240.0, 320.0, 400.0, 480.0])
              DeckCap.pixels(value, fade: fade),
            for (final value in [0.33, 0.5, 0.66])
              DeckCap.share(value, fade: fade),
            for (final value in [3, 4, 5, 6]) DeckCap.toasts(value, fade: fade),
            cap,
          }.toList(),
          nameOf: (value) => switch (value) {
            DeckCap(:final pixels?) => '${pixels.round()} px',
            DeckCap(:final share?) =>
              '${(share * 100).round()} % of the window',
            _ => '${value.toasts} toasts',
          },
          onChanged: setCap,
        ),
        _Dropdown<double>(
          label: 'fade',
          value: fade,
          values: {0.0, 24.0, 48.0, fade}.toList(),
          nameOf: (value) =>
              value == 0 ? 'a hard cut' : 'over ${value.round()} px',
          onChanged: (value) => setCap(switch (cap) {
            DeckCap(:final pixels?) => DeckCap.pixels(pixels, fade: value),
            DeckCap(:final share?) => DeckCap.share(share, fade: value),
            _ => DeckCap.toasts(cap.toasts!, fade: value),
          }),
        ),
      ],
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('scrollbar'),
        value: bar != null,
        onChanged: (on) => setBar(on ? const DeckScrollbar() : null),
      ),
      if (bar != null) ...[
        _Dropdown<DeckScrollbarPlacement>(
          label: 'placement',
          value: bar.placement,
          values: DeckScrollbarPlacement.values,
          nameOf: (value) => switch (value) {
            DeckScrollbarPlacement.outside => "outside the deck's right edge",
            DeckScrollbarPlacement.inside => "inside the deck's right edge",
          },
          onChanged: (value) => setBar(bar.copyWith(placement: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('alwaysShown (off: while scrolling)'),
          value: bar.alwaysShown,
          onChanged: (value) => setBar(bar.copyWith(alwaysShown: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('draggable'),
          value: bar.draggable,
          onChanged: (value) => setBar(bar.copyWith(draggable: value)),
        ),
        _Dropdown<double>(
          label: 'thickness',
          value: bar.thickness,
          values: {2.0, 4.0, 6.0, 8.0, bar.thickness}.toList(),
          nameOf: (value) => '$value px',
          onChanged: (value) => setBar(bar.copyWith(thickness: value)),
        ),
        _Dropdown<Color?>(
          label: 'color',
          value: bar.color,
          values: const [null, Color(0xFF2E7D32), Color(0xFFC62828)],
          nameOf: (value) => switch (value) {
            null => "the theme's onSurface, faded",
            const Color(0xFF2E7D32) => 'green',
            _ => 'red',
          },
          onChanged: (value) => setBar(bar.copyWith(color: () => value)),
        ),
      ],
    ];
  }

  List<Widget> _timeLeftControls(SonnerConfig config) {
    final left = config.timeLeft;
    void set(ToastTimeLeft? value) =>
        widget.onConfig(config.copyWith(timeLeft: () => value));
    return [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('timeLeft'),
        value: left != null,
        onChanged: (on) => set(on ? const ToastTimeLeft() : null),
      ),
      if (left != null) ...[
        _Dropdown<TimeLeftLook>(
          label: 'look',
          value: left.look,
          values: TimeLeftLook.values,
          nameOf: (value) => value.name,
          onChanged: (value) => set(left.copyWith(look: value)),
        ),
        _Dropdown<TimeLeftStart>(
          label: 'start (border)',
          value: left.start,
          values: TimeLeftStart.values,
          nameOf: (value) => value.name,
          onChanged: (value) => set(left.copyWith(start: value)),
        ),
        _Dropdown<bool>(
          label: 'clockwise (border)',
          value: left.clockwise,
          values: const [true, false],
          nameOf: (value) => value
              ? 'the gap opens clockwise from the start'
              : 'the line runs back to the start',
          onChanged: (value) => set(left.copyWith(clockwise: value)),
        ),
        _Dropdown<double>(
          label: 'strokeWidth',
          value: left.strokeWidth,
          values: const [1, 1.5, 2, 3],
          nameOf: (value) => '$value px',
          onChanged: (value) => set(left.copyWith(strokeWidth: value)),
        ),
        _Dropdown<Color?>(
          label: 'color',
          value: left.color,
          values: const [null, Color(0xFF2E7D32), Color(0xFFC62828)],
          nameOf: (value) => switch (value) {
            null => "the theme's primary",
            const Color(0xFF2E7D32) => 'green',
            _ => 'red',
          },
          onChanged: (value) => set(left.copyWith(color: () => value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("keepBorder (the card's own, under a border)"),
          value: left.keepBorder,
          onChanged: (value) => set(left.copyWith(keepBorder: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('easeRestart'),
          value: left.easeRestart,
          onChanged: (value) => set(left.copyWith(easeRestart: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('fadeWhenCovered'),
          value: left.fadeWhenCovered,
          onChanged: (value) => set(left.copyWith(fadeWhenCovered: value)),
        ),
      ],
    ];
  }

  /// The deck's ways out in words, and whose words they are.
  String _waysOut(SonnerConfig config) {
    final ways = config.swipeDirectionsNow.isEmpty
        ? 'nothing'
        : config.swipeDirectionsNow.map((it) => it.name).join(' and ');
    return config.swipeDirections == null
        ? '${config.position.name} allows $ways'
        : 'swipeDirections allows $ways';
  }

  List<Widget> _sections(SonnerConfig config) => [
    _Section(
      title: 'Show and dismiss',
      issue: 17,
      note:
          'A toast counts itself down from config.duration unless it is given '
          'its own.',
      children: [
        _Button('Show a toast', () => _show('Event has been created')),
        _Button(
          'With a description',
          () => _show(
            'Event has been created',
            description: 'Monday, January 3rd at 6:00pm',
          ),
        ),
        _Button(
          'Short (1 s)',
          () => _show('Gone in a second', duration: const Duration(seconds: 1)),
        ),
        _Button(
          'Stays until dismissed',
          () => _show(
            'This one waits for you',
            description: 'duration: Duration.zero',
            duration: Duration.zero,
          ),
        ),
        _Button('Dismiss the newest', _dismissNewest),
        _Button('Dismiss all', () {
          _toast.dismissAll();
          _shown.clear();
        }),
      ],
    ),
    _Section(
      title: 'The deck',
      issue: 19,
      note:
          'Rest the pointer on the deck: it fans out, draws every toast rather '
          'than config.visibleToasts, and the timers stop while it is there. '
          'A deck taller than the screen scrolls.',
      children: [
        _Button('Five in a row', () {
          for (var i = 1; i <= 5; i++) {
            _show('Toast $i of 5');
          }
        }),
        _Button('Burst of 12', () {
          for (var i = 1; i <= 12; i++) {
            _show(
              'Burst $i of 12',
              description: 'Beyond visibleToasts, and counting down.',
            );
          }
        }),
        _Button('Twenty, staying', () {
          for (var i = 1; i <= 20; i++) {
            _show('Toast $i of 20', duration: Duration.zero);
          }
        }),
      ],
    ),
    _Section(
      title: 'Time left',
      issue: 38,
      note:
          'A toast counting down draws its time left, as config.timeLeft says. '
          'Rest the pointer on the deck and every one stands still: the pause '
          'is the whole deck. Put three up to see a covered toast.',
      children: [
        _Button(
          'One, 8 s',
          () => _show(
            'Counting down',
            description: 'Rest the pointer here and it stands still.',
            duration: const Duration(seconds: 8),
          ),
        ),
        _Button('Three: 4 s, 7 s, 10 s', () {
          for (final seconds in const [10, 7, 4]) {
            _show('$seconds seconds', duration: Duration(seconds: seconds));
          }
        }),
        _Button('Updated at 3 s: counts from the top again', () {
          final id = _show(
            'Will be updated',
            description: 'In 3 s its content changes.',
            duration: const Duration(seconds: 8),
          );
          Timer(const Duration(seconds: 3), () {
            if (mounted) {
              _toast.update(id, description: 'Updated: counting again.');
            }
          });
        }),
        _Button('Loading for 2 s, then counting', () {
          final id = _show('Saving…', isLoading: true);
          Timer(const Duration(seconds: 2), () {
            if (mounted) {
              _toast.update(
                id,
                title: 'Saved',
                isLoading: false,
                duration: const Duration(seconds: 6),
              );
            }
          });
        }),
        _Button(
          'With a leading icon',
          () => _show(
            'Signed in',
            leading: const Icon(Icons.check_circle, size: 20),
            duration: const Duration(seconds: 8),
          ),
        ),
        _Button(
          'No timer: nothing to draw',
          () => _show('Stays until dismissed', duration: Duration.zero),
        ),
        ..._timeLeftControls(config),
      ],
    ),
    _Section(
      title: 'Deck cap and scrollbar',
      issue: 62,
      note:
          'Put twenty up and rest the pointer on the deck: it reaches no '
          'further than the cap, the rest scroll with the wheel or the '
          'scrollbar, and nothing shows past the cut — not even while the '
          'deck folds up as the pointer leaves.',
      children: [
        _Button('Twenty, staying', () {
          for (var i = 1; i <= 20; i++) {
            _show('Capped $i of 20', duration: Duration.zero);
          }
        }),
        _Button('Eight of mixed heights, staying', () {
          for (var i = 1; i <= 8; i++) {
            _show(
              'Mixed $i of 8',
              description: i.isEven ? 'A second line\nand a third' : null,
              duration: Duration.zero,
            );
          }
        }),
        _Button('A newest toast taller than a small cap', () {
          for (var i = 1; i <= 4; i++) {
            _show('Behind $i of 4', duration: Duration.zero);
          }
          _show(
            'Read me whole',
            description: [
              for (var line = 1; line <= 8; line++) 'Line $line',
            ].join('\n'),
            duration: Duration.zero,
          );
        }),
        ..._deckCapControls(config),
      ],
    ),
    _backdropSection(config),
    _Section(
      title: 'Dismiss all',
      issue: 59,
      note:
          'Put two or more up and rest the pointer on the deck: past its far '
          'end, a control dismisses every toast you may dismiss. A loading '
          'toast stays. With twenty up it waits at the cap as they scroll.',
      children: [
        _Button('Five, staying', () {
          for (var i = 1; i <= 5; i++) {
            _show('Staying $i of 5', duration: Duration.zero);
          }
        }),
        _Button('Three staying and one loading', () {
          for (var i = 1; i <= 3; i++) {
            _show('Kept $i of 3', duration: Duration.zero);
          }
          _show('Saving…', isLoading: true);
        }),
        _Button('Twenty, staying (past the cap)', () {
          for (var i = 1; i <= 20; i++) {
            _show('Many $i of 20', duration: Duration.zero);
          }
        }),
        ..._dismissAllControls(config),
      ],
    ),
    _Section(
      title: 'Stow the deck',
      issue: 60,
      note:
          'Put toasts up, rest the pointer on the deck and press Hide: the '
          'deck goes, its toasts stay and keep counting down. Only a new '
          'toast brings it back — an update does not — or the app, or the '
          'handle when one is configured. Once no toast is left, the stow '
          'ends.',
      children: [
        _Button('Three staying and one loading', () {
          for (var i = 1; i <= 3; i++) {
            _show('Kept $i of 3', duration: Duration.zero);
          }
          _show('Saving…', isLoading: true);
        }),
        _Button('Four counting: 4 s, 6 s, 8 s, 10 s', () {
          for (final seconds in const [10, 8, 6, 4]) {
            _show('$seconds seconds', duration: Duration(seconds: seconds));
          }
        }),
        _Button('Loading, done in 5 s (an update: the deck stays away)', () {
          final id = _show('Uploading…', isLoading: true);
          Timer(const Duration(seconds: 5), () {
            if (mounted) {
              _toast.update(
                id,
                title: 'Uploaded',
                isLoading: false,
                duration: const Duration(seconds: 6),
              );
            }
          });
        }),
        _Button('In 3 s: a new toast (it brings the deck back)', () {
          Timer(const Duration(seconds: 3), () {
            if (mounted) _show('A new one', description: 'The deck is back.');
          });
        }),
        _Button('The app: stow()', _toast.stow),
        _Button('The app: unstow()', _toast.unstow),
        ListenableBuilder(
          listenable: _toast,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'stowed: ${_toast.stowed}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        ..._stowControls(config),
      ],
    ),
    _Section(
      title: 'The app expands the deck',
      issue: 88,
      note:
          'Put five toasts up and press expand(): the deck fans out with no '
          'pointer, every toast drawn and the controls past its far end, and '
          'keeps counting down. Only collapse() or the last toast leaving '
          'ends it. With the switch on, the deck folds up once the pointer '
          'has been on it and left — the app composing its own rule over '
          'held.',
      children: [
        _Button('Five toasts, 10 s each', () {
          for (var n = 1; n <= 5; n++) {
            _show('Toast $n of 5', duration: const Duration(seconds: 10));
          }
        }),
        _Button('The app: expand()', _toast.expand),
        _Button('The app: collapse()', _toast.collapse),
        _Button('A notification button: unstow(); expand()', () {
          _toast.unstow();
          _toast.expand();
        }),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fold up once the pointer has left'),
          value: _foldOnLeave,
          onChanged: (on) => setState(() {
            _foldOnLeave = on;
            _wasHeld = _toast.held;
          }),
        ),
        ListenableBuilder(
          listenable: _toast,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'expanded: ${_toast.expanded} · held: ${_toast.held}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
      ],
    ),
    _Section(
      title: 'A still pointer',
      issue: 39,
      note:
          'Press a button, move the mouse to where toasts appear and leave it '
          'there. A toast that lands under a still pointer counts down and '
          'goes, the deck collapsed; move the mouse, press or turn the wheel '
          'and it fans out and stops.',
      children: [
        _Button('In 2 s: one, 4 s', () {
          Timer(const Duration(seconds: 2), () {
            if (mounted) {
              _show(
                'Landed under a still pointer',
                description: 'Counting 4 s until the mouse moves.',
                duration: const Duration(seconds: 4),
              );
            }
          });
        }),
        _Button('In 2 s: one every 1.5 s, eight times, 3 s each', () {
          for (var i = 0; i < 8; i++) {
            Timer(Duration(milliseconds: 2000 + 1500 * i), () {
              if (mounted) {
                _show(
                  'Stream ${i + 1} of 8',
                  duration: const Duration(seconds: 3),
                );
              }
            });
          }
        }),
      ],
    ),
    _Section(
      title: 'Mixed heights',
      issue: 19,
      note:
          'Press one, then the other. A toast behind the front is drawn at the '
          'front’s height — stretched when it is shorter, squeezed when '
          'it is taller, its card whole either way (#72) — and eases to it '
          'over the 400 ms the new one takes to enter. Watch that 400 ms, not '
          'just where it lands.',
      children: [
        _Button(
          'A tall one, staying',
          () => _show(
            'Event has been created',
            description: 'Monday, January 3rd at 6:00pm',
            duration: Duration.zero,
          ),
        ),
        _Button(
          'A short one, staying',
          () => _show('Event has been created', duration: Duration.zero),
        ),
      ],
    ),
    _Section(
      title: 'Loading and the leading slot',
      issue: 24,
      note:
          'A loading toast holds the config’s indicator in its slot and has '
          'no timer — it waits for its work, not a clock. The slot is '
          'otherwise the caller’s, and a toast with neither gets no slot at '
          'all, so its title starts at the padding edge.',
      children: [
        _Button(
          'A leading widget',
          () => _show(
            'Event has been created',
            description: 'Monday, January 3rd at 6:00pm',
            leading: const Icon(Icons.check_circle_outline, size: 20),
          ),
        ),
        _Button(
          'No slot at all',
          () => _show(
            'Event has been created',
            description: 'Its title starts at the padding edge.',
          ),
        ),
        _Button('Loading, then done', () {
          final id = _show('Checking credentials…', isLoading: true);
          Timer(const Duration(seconds: 2), () {
            if (!mounted) return;
            _toast.update(
              id,
              title: 'Signed in',
              description: 'It counts down only now.',
              isLoading: false,
              leading: const Icon(Icons.check_circle_outline, size: 20),
            );
          });
        }),
        _Button('Loading, and staying', () {
          _show(
            'Uploading…',
            description: 'No timer while it loads.',
            isLoading: true,
          );
        }),
        _Button('Three steps at one id', () {
          final id = _show('Checking credentials…', isLoading: true);
          Timer(const Duration(seconds: 2), () {
            if (!mounted) return;
            _toast.update(id, title: 'Opening the session…');
          });
          Timer(const Duration(seconds: 4), () {
            if (!mounted) return;
            _toast.update(id, title: 'Connected', isLoading: false);
          });
        }),
      ],
    ),
    _Section(
      title: 'promise',
      issue: 46,
      note:
          'One toast for the whole arc: loading, then the result. The future’s '
          'own value or error goes back to the caller untouched — nothing the '
          'toast does can change what your await sees, so a button that drives '
          'one has to handle the error itself.',
      children: [
        _Button('Loading, then done', () {
          _promise(
            Future.delayed(const Duration(seconds: 2), () => 3),
            loading: const ToastContent(
              'Uploading…',
              description: 'No timer while it works.',
            ),
            success: (value) => ToastContent(
              'Uploaded $value files',
              description: 'Now it counts down.',
              leading: const Icon(Icons.check_circle_outline, size: 20),
            ),
            error: (e) => ToastContent('Upload failed', description: '$e'),
          );
        }),
        _Button('Loading, then failed', () {
          _promise(
            Future<int>.delayed(
              const Duration(seconds: 2),
              () => throw Exception('connection refused'),
            ),
            loading: const ToastContent('Connecting…'),
            success: (value) => const ToastContent('Connected'),
            error: (e) => ToastContent(
              'Could not connect',
              description: '$e',
              leading: const Icon(Icons.error_outline, size: 20),
            ),
          );
        }),
        _Button('Two at once', () {
          _promise(
            Future.delayed(const Duration(seconds: 2), () => 'fast'),
            loading: const ToastContent('Fast one…'),
            success: (value) => ToastContent('Done: $value'),
            error: (e) => ToastContent('Failed: $e'),
          );
          _promise(
            Future.delayed(const Duration(seconds: 5), () => 'slow'),
            loading: const ToastContent('Slow one…'),
            success: (value) => ToastContent('Done: $value'),
            error: (e) => ToastContent('Failed: $e'),
          );
        }),
        _Button('Hand a running toast to promise', () {
          final id = _show('Checking credentials…', isLoading: true);
          Timer(const Duration(seconds: 2), () {
            if (!mounted) return;
            _toast.update(id, title: 'Opening the session…');
          });
          Timer(const Duration(seconds: 4), () {
            if (!mounted) return;
            _promise(
              Future.delayed(const Duration(seconds: 2), () {}),
              id: id,
              loading: const ToastContent('Connecting…'),
              success: (_) => const ToastContent(
                'Connected',
                leading: Icon(Icons.check_circle_outline, size: 20),
              ),
              error: (e) => ToastContent('Failed', description: '$e'),
            );
          });
        }),
        _Button('Dismiss it while it works', () {
          _promise(
            Future.delayed(const Duration(seconds: 3), () => 1),
            loading: const ToastContent(
              'Dismiss me before this finishes',
              description: 'Press “Dismiss the newest”.',
            ),
            success: (value) => const ToastContent(
              'It arrived anyway',
              description:
                  'A new toast: you swept away the progress, not this.',
            ),
            error: (e) => ToastContent('Failed: $e'),
          );
        }),
      ],
    ),
    _Section(
      title: 'Update and replace',
      issue: 21,
      note:
          'Both keep the place in the deck and restart the countdown. Update '
          'patches only the fields passed; replace swaps the content whole, so '
          'the description it is not given disappears.',
      children: [
        _Button(
          'Show a toast to change',
          () => _show(
            'Checking credentials…',
            description: 'A description that a replace will drop.',
            duration: Duration.zero,
            id: _target,
          ),
        ),
        _Button(
          'Update the title',
          () => _toast.update(_target, title: 'Opening the session…'),
        ),
        _Button(
          'Update, and count down again',
          () => _toast.update(
            _target,
            title: 'Session open',
            duration: const Duration(seconds: 4),
          ),
        ),
        _Button('Replace it whole', () => _show('Signed in', id: _target)),
        _Button('Update in a loop (upload)', _runProgress),
      ],
    ),
    _Section(
      title: 'Action slot and close button',
      issue: 25,
      note:
          'The action slot is yours: it is handed the toast, so the widget in '
          'it decides whether pressing also dismisses. The close button is the '
          'package’s, because it is the pointer equivalent of a swipe — and '
          '`dismissible` governs both, unset meaning “not while it loads”.',
      children: [
        _Button('Undo — the button closes it', () {
          _show(
            'Item deleted',
            description: 'Monday, January 3rd at 6:00pm',
            duration: Duration.zero,
            action: (context, t) =>
                TextButton(onPressed: t.dismiss, child: const Text('Undo')),
          );
        }),
        _Button('Retry — the button keeps it', () {
          _show(
            'Connection failed',
            duration: Duration.zero,
            action: (context, t) => TextButton(
              onPressed: () =>
                  _toast.update(t.id, title: 'Retrying…', isLoading: true),
              child: const Text('Retry'),
            ),
          );
        }),
        _Button('Two buttons in the one slot', () {
          _show(
            'Discard your changes?',
            duration: Duration.zero,
            action: (context, t) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: t.dismiss, child: const Text('Keep')),
                TextButton(onPressed: t.dismiss, child: const Text('Discard')),
              ],
            ),
          );
        }),
        _Button('With a close button', () {
          _show(
            'Event has been created',
            description: 'The X is the package’s, not yours.',
            duration: Duration.zero,
            closeButton: true,
          );
        }),
        _Button('Loading, so no close button yet', () {
          final id = _show(
            'Uploading…',
            description: 'The X arrives when it stops loading.',
            isLoading: true,
            closeButton: true,
          );
          Timer(const Duration(seconds: 3), () {
            if (!mounted) return;
            _toast.update(
              id,
              title: 'Uploaded',
              description: 'Now you can close it.',
              isLoading: false,
              duration: Duration.zero,
            );
          });
        }),
        _Button('Pinned — dismissible: false', () {
          _show(
            'You cannot close this one',
            description: 'Use “Dismiss all”. dismissible governs the user.',
            duration: Duration.zero,
            dismissible: false,
            closeButton: true,
          );
        }),
      ],
    ),
    _Section(
      title: 'Swipe',
      issue: 26,
      note:
          'Drag a toast off and it goes; a drag that is short and slow springs '
          'it back. The way out comes from the position’s own words unless '
          '“swipeDirections” names its own — ${_waysOut(config)} — '
          'and a drag any other way is damped rather than blocked, so the '
          'toast answers the hand without going anywhere. Past 45 px, or '
          'faster than 0.11 px/ms, it leaves the way it was pushed. Change '
          '“position” and “swipeDirections” below to try the rest.',
      children: [
        _Button('One to swipe', () {
          _show(
            'Drag me off the screen',
            description: 'A short, slow drag comes back.',
            duration: Duration.zero,
          );
        }),
        _Button('Three to swipe', () {
          for (var i = 3; i >= 1; i--) {
            _show('Swipe $i of 3', duration: Duration.zero);
          }
        }),
        _Button('Pinned — dismissible: false', () {
          _show(
            'This one does not move',
            description: 'dismissible governs the swipe as well as the X.',
            duration: Duration.zero,
            dismissible: false,
          );
        }),
        _Button('Loading, then swipeable', () {
          final id = _show(
            'Uploading…',
            description: 'No swipe while it loads.',
            isLoading: true,
          );
          Timer(const Duration(seconds: 3), () {
            if (!mounted) return;
            _toast.update(
              id,
              title: 'Uploaded',
              description: 'Now it takes a swipe, with no second call.',
              isLoading: false,
              duration: Duration.zero,
            );
          });
        }),
      ],
    ),
    _Section(
      title: 'Builder',
      issue: 27,
      note:
          'A builder replaces the whole look and is handed the toast. The toast '
          'still enters, leaves, stacks and swipes on its own; the builder '
          'reads `covered` to draw no content while the deck covers it, as the '
          'default look does. The panel’s own look is built by '
          '`toastCardBuilder`, which does that and fits the text to the card, so '
          'a tall one behind a short one keeps its whole card (#72). A FlashBar comes through the flash adapter, '
          'which keeps flash’s own motion at rest — give it '
          '`dismissDirections: const []` to keep the toast’s swipe, or leave '
          'flash’s and it wins, dismissible or not.',
      children: [
        _Button('A look of your own', () {
          _show('Deployed', duration: Duration.zero, builder: _ownLook);
        }),
        _Button('A tall one in your look, then a short one', () {
          _show(
            'Deployed to three regions',
            description: 'us-east\neu-west\nap-south',
            duration: Duration.zero,
            builder: _ownLook,
          );
          _show('Rolled back', duration: Duration.zero, builder: _ownLook);
        }),
        _Button('Change its look in place', () {
          final id = _show(
            'Changing look',
            duration: Duration.zero,
            builder: _ownLook,
          );
          Timer(const Duration(seconds: 1), () {
            if (mounted) _toast.update(id, builder: _flashBar(swipe: false));
          });
        }),
        _Button(
          config.builder == null
              ? 'Every toast in your look (config.builder)'
              : 'Back to the default look',
          () => widget.onConfig(
            config.copyWith(
              builder: () => config.builder == null ? _ownLook : null,
            ),
          ),
        ),
        _Button('FlashBar, keeping the toast’s swipe', () {
          _show(
            'Saved through the adapter',
            duration: Duration.zero,
            builder: _flashBar(swipe: false),
          );
        }),
        _Button('FlashBar with flash’s own swipe', () {
          _show(
            'Flash swipes this one',
            duration: Duration.zero,
            builder: _flashBar(swipe: true),
          );
        }),
        _Button('FlashBar, dismissible: false', () {
          _show(
            'Springs back from any swipe',
            duration: Duration.zero,
            dismissible: false,
            builder: _flashBar(swipe: true),
          );
        }),
      ],
    ),
    _Section(
      title: 'Over a dialog',
      issue: 20,
      note:
          'Mount mode 1: the toasts sit in the root navigator’s overlay, '
          'above every route and dialog.',
      children: [
        _Button('Open a dialog', _openDialog),
        _Button(
          'Open a dialog, toast after 1 s',
          () => _openDialog(toastAfter: true),
        ),
      ],
    ),
    _Section(
      title: 'Offset per edge',
      issue: 74,
      note:
          'Turn the title bar on and put a few up at topRight: with 24 all '
          'round they sit under it. "Clear a title bar" holds them 68 from '
          'the top and still 16 from the right. "Wide left" moves a left '
          'deck and not a centered one.',
      children: [
        _Button('Five that stay, at topRight', () {
          widget.onConfig(config.copyWith(position: SonnerPosition.topRight));
          for (var i = 5; i >= 1; i--) {
            _show('Offset $i of 5', duration: Duration.zero);
          }
        }),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('A 60 px title bar the app draws'),
          value: widget.titleBar,
          onChanged: widget.onTitleBar,
        ),
        _Dropdown<EdgeInsets>(
          label: 'offset',
          value: config.offset,
          values: _offsets.keys.toList(),
          nameOf: (value) => _offsets[value]!,
          onChanged: (value) => widget.onConfig(config.copyWith(offset: value)),
        ),
      ],
    ),
    _Section(
      title: 'Config',
      issue: 28,
      note:
          'Assigned to the controller with the toasts on screen: they stay, '
          'and move to the new config in place. Put a few up first.',
      children: [
        _Button('Three that stay', () {
          for (var i = 3; i >= 1; i--) {
            _show('Watch me move ($i of 3)', duration: Duration.zero);
          }
        }),
        _Dropdown<SonnerPosition>(
          label: 'position',
          value: config.position,
          values: SonnerPosition.values,
          nameOf: (value) => value.name,
          onChanged: (value) =>
              widget.onConfig(config.copyWith(position: value)),
        ),
        _Dropdown<int>(
          label: 'visibleToasts',
          value: config.visibleToasts,
          values: const [1, 2, 3, 4, 5, 6],
          nameOf: (value) => '$value',
          onChanged: (value) =>
              widget.onConfig(config.copyWith(visibleToasts: value)),
        ),
        _Dropdown<int>(
          label: 'duration',
          value: config.duration.inSeconds,
          values: const [1, 2, 4, 8, 0],
          nameOf: (value) => value == 0 ? 'until dismissed' : '$value s',
          onChanged: (value) => widget.onConfig(
            config.copyWith(duration: Duration(seconds: value)),
          ),
        ),
        _Dropdown<Set<SwipeDirection>?>(
          label: 'swipeDirections',
          value: config.swipeDirections,
          values: const [
            null,
            {SwipeDirection.up},
            {SwipeDirection.down},
            {SwipeDirection.left},
            {SwipeDirection.right},
            {SwipeDirection.left, SwipeDirection.right},
            {
              SwipeDirection.up,
              SwipeDirection.down,
              SwipeDirection.left,
              SwipeDirection.right,
            },
            <SwipeDirection>{},
          ],
          nameOf: (value) => switch (value) {
            null => 'from the position',
            final set when set.isEmpty => 'none',
            final set when set.length == SwipeDirection.values.length => 'all',
            final set => set.map((it) => it.name).join(', '),
          },
          onChanged: (value) =>
              widget.onConfig(config.copyWith(swipeDirections: () => value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('expandByDefault'),
          value: config.expandByDefault,
          onChanged: (value) =>
              widget.onConfig(config.copyWith(expandByDefault: value)),
        ),
      ],
    ),
  ];
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    this.issue,
    required this.note,
    required this.children,
  });

  final String title;
  final int? issue;
  final String note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final issue = this.issue;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                if (issue != null)
                  Text(
                    '#$issue',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              note,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: OutlinedButton(
      onPressed: onPressed,
      child: Align(alignment: Alignment.centerLeft, child: Text(label)),
    ),
  );
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
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
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isDense: true,
      // The longest value ('until dismissed') is wider than the field at the
      // one-column width, and a dropdown does not shrink its items on its own.
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final value in values)
          DropdownMenuItem(value: value, child: Text(nameOf(value))),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    ),
  );
}
