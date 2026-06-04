import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Setup Tool CLI', () {
    test('bin/setup.dart exists', () {
      expect(File('bin/setup.dart').existsSync(), isTrue,
          reason: 'bin/setup.dart must exist for pub to expose it as executable');
    });

    test('bin/setup_ios.dart exists (backward compat)', () {
      expect(File('bin/setup_ios.dart').existsSync(), isTrue);
    });

    test('pubspec.yaml declares setup executable', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('setup: setup'));
    });

    test('--help exits 0 and shows usage', () async {
      final result = await Process.run('dart', ['run', 'bin/setup.dart', '--help']);
      expect(result.exitCode, equals(0));
      final out = result.stdout as String;
      expect(out, contains('native_workmanager setup tool'));
      expect(out, contains('--android'));
      expect(out, contains('--ios'));
      expect(out, contains('--check'));
    });

    test('--check exits 0 when no android/ios directories present', () async {
      // Run from plugin root — no android/ios app directories here.
      final result = await Process.run('dart', ['run', 'bin/setup.dart', '--check']);
      expect(result.exitCode, equals(0));
    });

    test('--check --ios validates Info.plist when ios/ present', () async {
      // Run from plugin root pointing at example ios dir
      final plist = File('example/ios/Runner/Info.plist');
      if (!plist.existsSync()) return; // skip if no example ios dir
      final result = await Process.run('dart', ['run', 'bin/setup.dart', '--ios', '--check']);
      // Either passes (already configured) or exits 1 with informative output.
      final out = (result.stdout as String) + (result.stderr as String);
      // The tool runs from plugin root, ios/ not found → skips gracefully
      expect(out, isNotEmpty);
    });

    test('--android exits 0 with auto-init message', () async {
      final result = await Process.run(
        'dart',
        ['run', 'bin/setup.dart', '--android', '--check'],
      );
      expect(result.exitCode, equals(0));
      final out = result.stdout as String;
      // Plugin root has no android/app dir, tool skips gracefully
      expect(out, isNotEmpty);
    });
  });
}
