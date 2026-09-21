part of 'main.dart';

/// A `bool?` argument as a control: unset, on or off.
enum _Tri {
  unset('unset — the config and the toast decide', null),
  on('true', true),
  off('false', false);

  const _Tri(this.label, this.value);

  final String label;
  final bool? value;
}

/// A `Duration?` argument as a control, `SonnerConfig.configDuration` among
/// them.
enum _Length {
  config('configDuration — the config’s, or on update the toast’s own'),
  two('2 s'),
  four('4 s'),
  eight('8 s'),
  none('null — until dismissed');

  const _Length(this.label);

  final String label;

  Duration? get value => switch (this) {
    config => SonnerConfig.configDuration,
    two => const Duration(seconds: 2),
    four => const Duration(seconds: 4),
    eight => const Duration(seconds: 8),
    none => null,
  };
}

enum _Leading { none, icon, spinner }

enum _Action { none, undo, retry }

enum _Look { none, own, flashBar }

/// Every argument of `show` on a control, and the three calls that take them:
/// a new toast, a replace at the last id, and an update of it.
class _Playground extends StatefulWidget {
  const _Playground({required this.controller, required this.onShown});

  final SonnerController controller;

  /// Told of every id this section shows, so the panel's own "Dismiss the
  /// newest" reaches its toasts too.
  final ValueChanged<ToastId> onShown;

  @override
  State<_Playground> createState() => _PlaygroundState();
}

class _PlaygroundState extends State<_Playground> {
  final _title = TextEditingController(text: 'Composed by hand');
  final _description = TextEditingController();
  bool _isLoading = false;
  _Leading _leading = _Leading.none;
  _Length _duration = _Length.config;
  _Tri _dismissible = _Tri.unset;
  _Action _action = _Action.none;
  _Tri _closeButton = _Tri.unset;
  _Look _look = _Look.none;

  /// The id Show last returned, which Replace and Update act on.
  ToastId? _last;

  /// What the last Update returned, while it is the last thing pressed.
  bool? _updated;

  SonnerController get _toast => widget.controller;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  String? get _descriptionNow =>
      _description.text.isEmpty ? null : _description.text;

  Widget? get _leadingNow => switch (_leading) {
    _Leading.none => null,
    _Leading.icon => const Icon(Icons.check_circle_outline),
    _Leading.spinner => const CircularProgressIndicator(strokeWidth: 2),
  };

  ToastSlot? get _actionNow => switch (_action) {
    _Action.none => null,
    _Action.undo => (context, t) => TextButton(
      onPressed: t.dismiss,
      child: const Text('Undo'),
    ),
    _Action.retry => (context, t) => TextButton(
      onPressed: () => _toast.update(t.id, title: 'Retrying…', isLoading: true),
      child: const Text('Retry'),
    ),
  };

  ToastBuilder? get _builderNow => switch (_look) {
    _Look.none => null,
    _Look.own => _PanelState._ownLook,
    _Look.flashBar => _PanelState._flashBar(swipe: false),
  };

  /// A new toast when [id] is null, and a replace of the toast at [id]
  /// otherwise.
  void _show({ToastId? id}) {
    final shown = _toast.show(
      _title.text,
      description: _descriptionNow,
      isLoading: _isLoading,
      leading: _leadingNow,
      duration: _duration.value,
      dismissible: _dismissible.value,
      action: _actionNow,
      closeButton: _closeButton.value,
      id: id,
      builder: _builderNow,
    );
    widget.onShown(shown);
    setState(() {
      _last = shown;
      _updated = null;
    });
  }

  void _update() {
    final last = _last;
    if (last == null) return;
    final updated = _toast.update(
      last,
      title: _title.text,
      description: _descriptionNow,
      isLoading: _isLoading,
      leading: _leadingNow,
      duration: _duration.value,
      dismissible: _dismissible.value,
      action: _actionNow,
      closeButton: _closeButton.value,
      builder: _builderNow,
    );
    setState(() => _updated = updated);
  }

  @override
  Widget build(BuildContext context) {
    final last = _last;
    return _Section(
      title: 'Playground',
      issue: 29,
      note:
          'Every argument of show on a control. Show puts up a new toast; '
          'Replace shows at the last id, taking these controls whole; Update '
          'passes them to update, which reads an empty or unset one as “keep '
          'what it has”. So only a replace can take a description or a '
          'leading widget away.',
      children: [
        _Field(label: 'title', controller: _title),
        _Field(label: 'description', controller: _description),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('isLoading'),
          value: _isLoading,
          onChanged: (value) => setState(() => _isLoading = value),
        ),
        _Dropdown<_Leading>(
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
        _Dropdown<_Length>(
          label: 'duration',
          value: _duration,
          values: _Length.values,
          nameOf: (value) => value.label,
          onChanged: (value) => setState(() => _duration = value),
        ),
        _Dropdown<_Tri>(
          label: 'dismissible',
          value: _dismissible,
          values: _Tri.values,
          nameOf: (value) => value.label,
          onChanged: (value) => setState(() => _dismissible = value),
        ),
        _Dropdown<_Tri>(
          label: 'closeButton',
          value: _closeButton,
          values: _Tri.values,
          nameOf: (value) => value.label,
          onChanged: (value) => setState(() => _closeButton = value),
        ),
        _Dropdown<_Action>(
          label: 'action',
          value: _action,
          values: _Action.values,
          nameOf: (value) => switch (value) {
            _Action.none => 'none',
            _Action.undo => 'Undo — dismisses it',
            _Action.retry => 'Retry — makes it load in place',
          },
          onChanged: (value) => setState(() => _action = value),
        ),
        _Dropdown<_Look>(
          label: 'builder',
          value: _look,
          values: _Look.values,
          nameOf: (value) => switch (value) {
            _Look.none => 'none — config.builder, or the default look',
            _Look.own => 'the panel’s own look',
            _Look.flashBar => 'a FlashBar through the adapter',
          },
          onChanged: (value) => setState(() => _look = value),
        ),
        _Button('Show', _show),
        _Button('Replace the last', () {
          if (last != null) _show(id: last);
        }),
        _Button('Update the last', _update),
        Text(switch ((last, _updated)) {
          (null, _) => 'Nothing shown yet.',
          (final id?, false) =>
            'update(${id.value}) returned false: it is gone.',
          (final id?, _) => 'The last: ${id.value}',
        }, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}
