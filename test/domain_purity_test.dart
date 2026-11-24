import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `lib/domain/` is the whole of the business logic and must stay runnable
/// without a device, so this test fails the build if a Flutter import ever
/// creeps into it.
void main() {
  final domain = Directory('lib/domain');

  test('the domain directory exists and holds the rules', () {
    expect(domain.existsSync(), isTrue);
    final files = domain
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files.length, greaterThanOrEqualTo(5));
  });

  test('no file in lib/domain imports Flutter or anything platform-bound', () {
    const banned = <String>[
      'package:flutter/',
      'package:flutter_test/',
      'dart:ui',
      'dart:io',
      'package:shared_preferences/',
      'package:speech_to_text/',
      'package:share_plus/',
    ];

    final offences = <String>[];
    for (final file in domain.listSync().whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final line in source.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('import ') && !trimmed.startsWith('export ')) {
          continue;
        }
        for (final needle in banned) {
          if (trimmed.contains(needle)) {
            offences.add('${file.path}: $trimmed');
          }
        }
      }
    }

    expect(offences, isEmpty);
  });

  test('no file anywhere in lib makes a network call', () {
    // The app has no backend. Nothing should reach for a socket or an HTTP
    // client, in the domain or anywhere else.
    const banned = <String>[
      'package:http/',
      'dart:html',
      'HttpClient',
      'Socket.connect',
      'WebSocket',
    ];

    final offences = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final needle in banned) {
        if (source.contains(needle)) {
          offences.add('${entity.path}: $needle');
        }
      }
    }

    expect(offences, isEmpty);
  });
}
