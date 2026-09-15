import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_sonner/just_sonner.dart';

void main() => runApp(const ExampleApp());

/// A desktop harness for just_sonner: one button per behaviour that exists, so
/// each can be felt rather than only tested.
///
/// It grows one section at a time, alongside the package — the "Not built yet"
/// section lists what is still missing, and each entry becomes a section here
/// as it lands.
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  ThemeMode _themeMode = ThemeMode.light;
  SonnerConfig _config = const SonnerConfig();
  late SonnerController _controller = _attached(_config);

  SonnerController _attached(SonnerConfig config) =>
      SonnerController(config: config)..attach(_navigatorKey);

  /// `SonnerConfig` is fixed at construction today, so a change here builds a
  /// new controller and the toasts on screen go with the old one. Issue #28
  /// makes `config` settable, and this becomes an assignment.
  void _setConfig(SonnerConfig config) {
    final previous = _controller;
    setState(() {
      _config = config;
      _controller = _attached(config);
    });
    previous.dispose();
  }

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
    home: _Panel(
      controller: _controller,
      config: _config,
      onConfig: _setConfig,
      themeMode: _themeMode,
      onThemeMode: (mode) => setState(() => _themeMode = mode),
    ),
  );
}

class _Panel extends StatefulWidget {
  const _Panel({
    required this.controller,
    required this.config,
    required this.onConfig,
    required this.themeMode,
    required this.onThemeMode,
  });

  final SonnerController controller;
  final SonnerConfig config;
  final ValueChanged<SonnerConfig> onConfig;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  /// The id the update and replace buttons act on, so they can be pressed in
  /// any order against whatever "Show a toast to change" put up.
  static const ToastId _target = ToastId('target');

  ToastId? _last;
  Timer? _progress;

  SonnerController get _toast => widget.controller;

  @override
  void didUpdateWidget(_Panel old) {
    super.didUpdateWidget(old);
    // A new controller is a new set of toasts; the old id is on nothing.
    if (!identical(old.controller, widget.controller)) {
      _stopProgress();
      _last = null;
    }
  }

  @override
  void dispose() {
    _progress?.cancel();
    super.dispose();
  }

  void _stopProgress() {
    _progress?.cancel();
    _progress = null;
  }

  ToastId _show(String title, {String? description, Duration? duration}) =>
      _last = _toast.show(title, description: description, duration: duration);

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
        _Button('Dismiss the last one', () {
          final last = _last;
          if (last != null) _toast.dismiss(last);
        }),
        _Button('Dismiss all', _toast.dismissAll),
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
      title: 'Update and replace',
      issue: 21,
      note:
          'Both keep the place in the deck and restart the countdown. Update '
          'patches only the fields passed; replace swaps the content whole, so '
          'the description it is not given disappears.',
      children: [
        _Button(
          'Show a toast to change',
          () => _toast.show(
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
        _Button('Replace it whole', () => _toast.show('Signed in', id: _target)),
        _Button('Update in a loop (upload)', _runProgress),
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
      title: 'Config',
      issue: 28,
      note:
          'Fixed at construction today, so changing one of these builds a new '
          'controller and drops the toasts on screen. #28 makes it live.',
      children: [
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('expandByDefault'),
          value: config.expandByDefault,
          onChanged: (value) =>
              widget.onConfig(config.copyWith(expandByDefault: value)),
        ),
      ],
    ),
    const _Section(
      title: 'Not built yet',
      note: 'Each of these gets its own section here as it lands.',
      children: [
        _Missing(24, 'Loading toasts, the leading slot, and promise'),
        _Missing(25, 'The action slot, the close button, and dismissible'),
        _Missing(26, 'Swipe a toast away'),
        _Missing(27, 'Replace the look with a builder, and the flash adapter'),
        _Missing(28, 'Change the config while toasts are on screen'),
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

class _Missing extends StatelessWidget {
  const _Missing(this.issue, this.what);

  final int issue;
  final String what;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#$issue',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(child: Text(what, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
