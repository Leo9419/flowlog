import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('macOS Claude Code entitlements', () {
    test('desktop builds are allowed to execute local CLI tools', () {
      for (final path in [
        'macos/Runner/DebugProfile.entitlements',
        'macos/Runner/Release.entitlements',
      ]) {
        final file = File(path);
        final xml = file.readAsStringSync();

        expect(
          _boolForKey(xml, 'com.apple.security.app-sandbox'),
          isNot(true),
          reason: '$path enables App Sandbox, which blocks local Claude Code',
        );
      }
    });
  });
}

bool? _boolForKey(String xml, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<(true|false)\\s*/>',
  ).firstMatch(xml);
  final value = match?.group(1);
  if (value == null) return null;
  return value == 'true';
}
