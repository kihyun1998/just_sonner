import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The controller counts down by subtracting ticks and reads no clock, so the
/// only time source a test has to fake is `Timer` (spec §7).
void main() {
  test('lib/ reads no clock', () {
    const forbidden = [
      'package:clock',
      'Stopwatch',
      'DateTime.now',
      'DateTime.timestamp',
    ];
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    expect(sources, isNotEmpty);

    final found = [
      for (final file in sources)
        for (final token in forbidden)
          if (file.readAsStringSync().contains(token)) '${file.path}: $token',
    ];

    expect(found, isEmpty);
  });
}
