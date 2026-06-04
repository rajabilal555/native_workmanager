// ignore_for_file: avoid_print
import 'dart:io';

/// Unified setup tool for native_workmanager.
///
/// Usage:
///   dart run native_workmanager:setup           # both platforms
///   dart run native_workmanager:setup --android # Android only
///   dart run native_workmanager:setup --ios     # iOS only
///   dart run native_workmanager:setup --check   # validate only, no writes
///   dart run native_workmanager:setup --help
void main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printHelp();
    return;
  }

  final checkOnly = args.contains('--check');
  final doAndroid = args.isEmpty || args.contains('--android');
  final doIos = args.isEmpty || args.contains('--ios');

  _banner();

  var hasError = false;

  if (doAndroid) {
    print('\n📱 Android');
    print('─' * 50);
    final ok = await _setupAndroid(checkOnly: checkOnly);
    if (!ok) hasError = true;
  }

  if (doIos) {
    print('\n🍎 iOS');
    print('─' * 50);
    final ok = await _setupIos(checkOnly: checkOnly);
    if (!ok) hasError = true;
  }

  print('\n${'─' * 50}');
  if (hasError) {
    print('⚠️  Setup completed with issues. Review output above.');
    exit(1);
  } else if (checkOnly) {
    print('✅ Validation passed.');
  } else {
    print('✅ Setup complete!');
    print('');
    print('Next steps:');
    print('  1. flutter clean && flutter pub get');
    print('  2. Run your app and test background tasks.');
    print('  3. See doc/ANDROID_SETUP.md / doc/IOS_BACKGROUND_LIMITS.md for advanced config.');
  }
}

// ─── Android ─────────────────────────────────────────────────────────────────

Future<bool> _setupAndroid({required bool checkOnly}) async {
  final manifestFile = File('android/app/src/main/AndroidManifest.xml');
  if (!manifestFile.existsSync()) {
    print('  ℹ️  No android/ directory found — skipping.');
    return true;
  }

  print('  ✅ Auto-init is handled by the plugin manifest (androidx.startup).');
  print('     No AndroidManifest.xml changes required for DartWorker support.');

  // Validate: check that the user hasn't accidentally removed our initializer.
  final content = manifestFile.readAsStringSync();
  final issues = <String>[];

  if (content.contains('NativeWorkManagerInitializer') &&
      content.contains('tools:node="remove"')) {
    issues.add(
      'Your AndroidManifest.xml removes NativeWorkManagerInitializer.\n'
      '     DartWorker will not survive app kill. Remove the tools:node="remove" entry\n'
      '     or set <meta-data android:name="native_workmanager.auto_init" android:value="false" />\n'
      '     and follow the manual setup guide in doc/ANDROID_SETUP.md.',
    );
  }

  if (content.contains('androidx.work.WorkManagerInitializer') &&
      !content.contains('tools:node="remove"')) {
    issues.add(
      'Your AndroidManifest.xml re-enables WorkManagerInitializer.\n'
      '     This conflicts with native_workmanager\'s auto-init. Remove the entry or\n'
      '     opt out of auto-init via native_workmanager.auto_init=false meta-data.',
    );
  }

  if (issues.isNotEmpty) {
    for (final issue in issues) {
      print('  ⚠️  $issue');
    }
    return false;
  }

  // Check custom worker setup hint.
  final mainActivityKt = _findMainActivity();
  if (mainActivityKt != null) {
    final activityContent = mainActivityKt.readAsStringSync();
    if (activityContent.contains('SimpleAndroidWorkerFactory.registerWorker') ||
        activityContent.contains('setUserFactory')) {
      print('  ✅ Custom worker registration detected in ${mainActivityKt.path}.');
    }
  }

  print('  ℹ️  Custom workers? Call SimpleAndroidWorkerFactory.registerWorker() in\n'
      '     MainActivity.configureFlutterEngine() before NativeWorkManager.initialize().');

  return true;
}

File? _findMainActivity() {
  final base = Directory('android/app/src/main/kotlin');
  if (!base.existsSync()) return null;
  try {
    return base
        .listSync(recursive: true)
        .whereType<File>()
        .firstWhere((f) => f.path.endsWith('MainActivity.kt'));
  } catch (_) {
    return null;
  }
}

// ─── iOS ─────────────────────────────────────────────────────────────────────

Future<bool> _setupIos({required bool checkOnly}) async {
  final infoPlistFile = File('ios/Runner/Info.plist');
  if (!infoPlistFile.existsSync()) {
    print('  ℹ️  No ios/Runner/Info.plist found — skipping.');
    return true;
  }

  String content = infoPlistFile.readAsStringSync();
  final patches = <String>[];

  // 1. UIBackgroundModes
  if (!content.contains('<key>UIBackgroundModes</key>')) {
    patches.add('Add UIBackgroundModes (fetch, processing)');
    if (!checkOnly) {
      content = content.replaceFirst(
        '</dict>',
        '''\t<key>UIBackgroundModes</key>
\t<array>
\t\t<string>fetch</string>
\t\t<string>processing</string>
\t</array>
</dict>''',
      );
    }
  } else {
    for (final mode in ['fetch', 'processing']) {
      if (!content.contains('<string>$mode</string>')) {
        patches.add('Add "$mode" to UIBackgroundModes');
        if (!checkOnly) {
          content = content.replaceFirst(
            '<key>UIBackgroundModes</key>\n\t<array>',
            '<key>UIBackgroundModes</key>\n\t<array>\n\t\t<string>$mode</string>',
          );
        }
      }
    }
  }

  // 2. BGTaskSchedulerPermittedIdentifiers
  final identifiers = [
    'dev.brewkits.native_workmanager.task',
    'dev.brewkits.native_workmanager.refresh',
  ];

  if (!content.contains('<key>BGTaskSchedulerPermittedIdentifiers</key>')) {
    patches.add('Add BGTaskSchedulerPermittedIdentifiers');
    if (!checkOnly) {
      final idStr = identifiers.map((id) => '\t\t<string>$id</string>').join('\n');
      content = content.replaceFirst(
        '</dict>',
        '''\t<key>BGTaskSchedulerPermittedIdentifiers</key>
\t<array>
$idStr
\t</array>
</dict>''',
      );
    }
  } else {
    for (final id in identifiers) {
      if (!content.contains('<string>$id</string>')) {
        patches.add('Add missing identifier: $id');
        if (!checkOnly) {
          content = content.replaceFirst(
            '<key>BGTaskSchedulerPermittedIdentifiers</key>\n\t<array>',
            '<key>BGTaskSchedulerPermittedIdentifiers</key>\n\t<array>\n\t\t<string>$id</string>',
          );
        }
      }
    }
  }

  if (patches.isEmpty) {
    print('  ✅ Info.plist already configured correctly.');
    return true;
  }

  if (checkOnly) {
    for (final p in patches) {
      print('  ⚠️  Missing: $p');
    }
    print('  Run without --check to apply these changes.');
    return false;
  }

  await infoPlistFile.writeAsString(content);
  for (final p in patches) {
    print('  ➕ $p');
  }
  print('  ✅ Info.plist updated.');
  return true;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

void _banner() {
  print('');
  print('  native_workmanager setup');
  print('  ════════════════════════');
}

void _printHelp() {
  print('''
native_workmanager setup tool

Usage:
  dart run native_workmanager:setup           Setup both Android + iOS
  dart run native_workmanager:setup --android Android only
  dart run native_workmanager:setup --ios     iOS only
  dart run native_workmanager:setup --check   Validate without writing files
  dart run native_workmanager:setup --help    Show this help

What it does:

  Android
    Verifies your project is compatible with native_workmanager auto-init.
    DartWorker support after app-kill requires NO manual steps — the plugin
    ships an androidx.startup Initializer that runs automatically.

    Conflict detection:
      - Warns if your manifest accidentally removes NativeWorkManagerInitializer
      - Warns if WorkManagerInitializer is re-enabled (conflicts with auto-init)

    To opt out of auto-init (custom WorkManager setup):
      Add to AndroidManifest.xml <application>:
        <meta-data android:name="native_workmanager.auto_init"
                   android:value="false" />
      Then follow doc/ANDROID_SETUP.md.

  iOS
    Patches ios/Runner/Info.plist with:
      - UIBackgroundModes: fetch, processing
      - BGTaskSchedulerPermittedIdentifiers: 2 required task identifiers
''');
}
