import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../state/app_commands.dart';
import '../state/app_settings.dart';

class GlobalHotkeyService {
  GlobalHotkeyService._();

  static final GlobalHotkeyService instance = GlobalHotkeyService._();
  static const MethodChannel _channel = MethodChannel('flowlog/hotkey');

  AppSettings? _settings;
  AppCommandBus? _commands;
  void Function()? _settingsListener;

  Future<void> bind({
    required AppSettings settings,
    required AppCommandBus commands,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.macOS) return;
    _settings = settings;
    _commands = commands;
    _channel.setMethodCallHandler(_handleMethodCall);
    _settingsListener = _applySettings;
    settings.addListener(_settingsListener!);
    await _applySettings();
  }

  Future<void> dispose() async {
    if (_settingsListener != null && _settings != null) {
      _settings!.removeListener(_settingsListener!);
    }
    _settingsListener = null;
  }

  Future<void> _applySettings() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) return;
    final settings = _settings;
    if (settings == null) return;

    if (!settings.globalQuickAddEnabled) {
      try {
        await _channel.invokeMethod('unregister');
      } catch (_) {}
      return;
    }

    final hotkey = settings.globalQuickAddHotkey;
    final args = <String, dynamic>{
      'key': hotkey.key,
      'modifiers': [
        if (hotkey.meta) 'meta',
        if (hotkey.alt) 'alt',
        if (hotkey.shift) 'shift',
        if (hotkey.control) 'control',
      ],
    };

    try {
      await _channel.invokeMethod('register', args);
    } catch (_) {}
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'trigger') {
      QuickAddTarget target = QuickAddTarget.inbox;
      final args = call.arguments;
      if (args is Map) {
        final targetValue = args['target'];
        if (targetValue == 'today') {
          target = QuickAddTarget.today;
        } else if (targetValue == 'current') {
          target = QuickAddTarget.current;
        }
      }
      _commands?.triggerQuickAdd(target);
    }
  }
}
