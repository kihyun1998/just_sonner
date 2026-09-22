import 'package:flutter/material.dart';
import 'package:just_sonner/just_sonner.dart';

import 'settings.dart';
import 'showcase.dart';

void main() => runApp(const ExampleApp());

/// The just_sonner example: every option on the left, and buttons that show
/// toasts on the right. The harness each feature was verified in sits on a
/// page behind the app bar.
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final ExampleSettings _settings = ExampleSettings(
    SonnerController()..attach(_navigatorKey),
  );

  @override
  void dispose() {
    _settings.controller.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _settings,
    builder: (context, _) => MaterialApp(
      title: 'just_sonner',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: _settings.themeMode,
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
          Stack(children: [child!, if (_settings.titleBar) const _TitleBar()]),
      home: ShowcasePage(settings: _settings),
    ),
  );
}

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
