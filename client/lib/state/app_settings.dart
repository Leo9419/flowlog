import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GlobalHotkeyConfig {
  const GlobalHotkeyConfig({
    required this.key,
    required this.meta,
    required this.alt,
    required this.shift,
    required this.control,
  });

  final String key;
  final bool meta;
  final bool alt;
  final bool shift;
  final bool control;

  Map<String, dynamic> toJson() => {
        'key': key,
        'meta': meta,
        'alt': alt,
        'shift': shift,
        'control': control,
      };

  factory GlobalHotkeyConfig.fromJson(Map<String, dynamic> json) {
    return GlobalHotkeyConfig(
      key: json['key'] as String? ?? 'N',
      meta: json['meta'] as bool? ?? true,
      alt: json['alt'] as bool? ?? true,
      shift: json['shift'] as bool? ?? false,
      control: json['control'] as bool? ?? false,
    );
  }

  List<String> keyCaps() {
    return [
      if (meta) 'Cmd',
      if (alt) 'Option',
      if (shift) 'Shift',
      if (control) 'Ctrl',
      key,
    ];
  }
}

enum AiProviderType { local, cloud, claudeCode }

extension AiProviderTypeValue on AiProviderType {
  String get id {
    switch (this) {
      case AiProviderType.local:
        return 'local';
      case AiProviderType.cloud:
        return 'cloud';
      case AiProviderType.claudeCode:
        return 'claude_code';
    }
  }

  static AiProviderType fromId(String? id) {
    switch (id) {
      case 'cloud':
        return AiProviderType.cloud;
      case 'claude_code':
        return AiProviderType.claudeCode;
      case 'local':
      default:
        return AiProviderType.local;
    }
  }
}

class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs) {
    _notificationsEnabled = _prefs.getBool(_keyNotificationsEnabled) ?? true;
    _upcomingReminderEnabled =
        _prefs.getBool(_keyUpcomingReminderEnabled) ?? true;
    _dailyReportEnabled = _prefs.getBool(_keyDailyReportEnabled) ?? true;
    _weeklyReportEnabled = _prefs.getBool(_keyWeeklyReportEnabled) ?? true;
    _dueAtReminderEnabled = _prefs.getBool(_keyDueAtReminderEnabled) ?? true;
    _reminderSoundEnabled = _prefs.getBool(_keyReminderSoundEnabled) ?? true;
    _dailyReportTimeMinutes = _prefs.getInt(_keyDailyReportTimeMinutes) ?? 540;
    _weeklyReportTimeMinutes =
        _prefs.getInt(_keyWeeklyReportTimeMinutes) ?? 540;
    _weeklyReportWeekday =
        _prefs.getInt(_keyWeeklyReportWeekday) ?? DateTime.monday;
    final lastShownMs = _prefs.getInt(_keyUpcomingPopupLastShown);
    _upcomingPopupLastShown = lastShownMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastShownMs);
    _globalQuickAddEnabled = _prefs.getBool(_keyGlobalQuickAddEnabled) ?? true;
    final hotkeyRaw = _prefs.getString(_keyGlobalQuickAddHotkey);
    if (hotkeyRaw != null) {
      try {
        _globalQuickAddHotkey = GlobalHotkeyConfig.fromJson(
          jsonDecode(hotkeyRaw) as Map<String, dynamic>,
        );
      } catch (_) {
        _globalQuickAddHotkey = const GlobalHotkeyConfig(
          key: 'N',
          meta: true,
          alt: true,
          shift: false,
          control: false,
        );
      }
    }
    _aiProvider = AiProviderTypeValue.fromId(
      _prefs.getString(_keyAiProvider),
    );
    _aiLocalEndpoint =
        _prefs.getString(_keyAiLocalEndpoint) ?? 'http://localhost:11434';
    _aiLocalModel = _prefs.getString(_keyAiLocalModel) ?? '';
    _aiCloudEndpoint =
        _prefs.getString(_keyAiCloudEndpoint) ?? 'https://api.openai.com';
    _aiCloudApiKey = _prefs.getString(_keyAiCloudApiKey) ?? '';
    _aiCloudModel = _prefs.getString(_keyAiCloudModel) ?? '';
    _aiClaudeCommand = _prefs.getString(_keyAiClaudeCommand) ?? 'claude';
    _aiTrustOverrides = _prefs.getString(_keyAiTrustOverrides) ?? '{}';
    _aiTodayMaxTasks = _prefs.getInt(_keyAiTodayMaxTasks) ?? 7;
    _aiMorningBriefingEnabled =
        _prefs.getBool(_keyAiMorningBriefingEnabled) ?? true;
    _aiEveningReviewEnabled =
        _prefs.getBool(_keyAiEveningReviewEnabled) ?? false;
    _aiEveningReviewTime = _prefs.getString(_keyAiEveningReviewTime) ?? '21:00';
    _aiHighPrivacyMode = _prefs.getBool(_keyAiHighPrivacyMode) ?? false;
    _aiIncludeNotesDefault = _prefs.getBool(_keyAiIncludeNotesDefault) ?? false;
    _aiLocalFallbackToCloud =
        _prefs.getBool(_keyAiLocalFallbackToCloud) ?? true;
    _aiInboxTriageThreshold = _prefs.getInt(_keyAiInboxTriageThreshold) ?? 3;
    _aiShowToolTrace = _prefs.getBool(_keyAiShowToolTrace) ?? false;
    _aiCloudModelLite = _prefs.getString(_keyAiCloudModelLite) ?? '';
    _onboardingCompleted = _prefs.getBool(_keyOnboardingCompleted) ?? false;

    // M1_04 fix：locale / themeMode 之前没持久化；从 prefs 还原。
    final savedLocale = _prefs.getString(_keyLocale);
    if (savedLocale != null && savedLocale.isNotEmpty) {
      _locale = Locale(savedLocale);
    }
    final savedThemeMode = _prefs.getString(_keyThemeMode);
    switch (savedThemeMode) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      case 'system':
        _themeMode = ThemeMode.system;
        break;
      // 不存或异常值都走默认 light
    }
  }

  static const _keyLocale = 'app_locale';
  static const _keyThemeMode = 'app_theme_mode';
  static const _keyNotificationsEnabled = 'notifications_enabled';
  static const _keyUpcomingReminderEnabled = 'upcoming_reminder_enabled';
  static const _keyDailyReportEnabled = 'daily_report_enabled';
  static const _keyWeeklyReportEnabled = 'weekly_report_enabled';
  static const _keyDueAtReminderEnabled = 'due_at_reminder_enabled';
  static const _keyReminderSoundEnabled = 'reminder_sound_enabled';
  static const _keyDailyReportTimeMinutes = 'daily_report_time_minutes';
  static const _keyWeeklyReportTimeMinutes = 'weekly_report_time_minutes';
  static const _keyWeeklyReportWeekday = 'weekly_report_weekday';
  static const _keyUpcomingPopupLastShown = 'upcoming_popup_last_shown';
  static const _keyGlobalQuickAddEnabled = 'global_quick_add_enabled';
  static const _keyGlobalQuickAddHotkey = 'global_quick_add_hotkey';
  static const _keyAiProvider = 'ai_provider';
  static const _keyAiLocalEndpoint = 'ai_local_endpoint';
  static const _keyAiLocalModel = 'ai_local_model';
  static const _keyAiCloudEndpoint = 'ai_cloud_endpoint';
  static const _keyAiCloudApiKey = 'ai_cloud_api_key';
  static const _keyAiCloudModel = 'ai_cloud_model';
  static const _keyAiClaudeCommand = 'ai_claude_command';
  static const _keyAiTrustOverrides = 'ai_trust_overrides';
  static const _keyAiTodayMaxTasks = 'ai_today_max_tasks';
  static const _keyAiMorningBriefingEnabled = 'ai_morning_briefing_enabled';
  static const _keyAiEveningReviewEnabled = 'ai_evening_review_enabled';
  static const _keyAiEveningReviewTime = 'ai_evening_review_time';
  static const _keyAiHighPrivacyMode = 'ai_high_privacy_mode';
  static const _keyAiIncludeNotesDefault = 'ai_include_notes_default';
  static const _keyAiLocalFallbackToCloud = 'ai_local_fallback_to_cloud';
  static const _keyAiInboxTriageThreshold = 'ai_inbox_triage_threshold';
  static const _keyAiShowToolTrace = 'ai_show_tool_trace';
  static const _keyAiCloudModelLite = 'ai_cloud_model_lite';
  static const _keyOnboardingCompleted = 'onboarding_completed';

  final SharedPreferences _prefs;

  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('zh');
  bool _notificationsEnabled = true;
  bool _upcomingReminderEnabled = true;
  bool _dailyReportEnabled = true;
  bool _weeklyReportEnabled = true;
  bool _dueAtReminderEnabled = true;
  bool _reminderSoundEnabled = true;
  int _dailyReportTimeMinutes = 540;
  int _weeklyReportTimeMinutes = 540;
  int _weeklyReportWeekday = DateTime.monday;
  DateTime? _upcomingPopupLastShown;
  bool _globalQuickAddEnabled = true;
  GlobalHotkeyConfig _globalQuickAddHotkey = const GlobalHotkeyConfig(
    key: 'N',
    meta: true,
    alt: true,
    shift: false,
    control: false,
  );
  AiProviderType _aiProvider = AiProviderType.local;
  String _aiLocalEndpoint = 'http://localhost:11434';
  String _aiLocalModel = '';
  String _aiCloudEndpoint = 'https://api.openai.com';
  String _aiCloudApiKey = '';
  String _aiCloudModel = '';
  String _aiClaudeCommand = 'claude';
  String _aiTrustOverrides = '{}';
  int _aiTodayMaxTasks = 7;
  bool _aiMorningBriefingEnabled = true;
  bool _aiEveningReviewEnabled = false;
  String _aiEveningReviewTime = '21:00';
  bool _aiHighPrivacyMode = false;
  bool _aiIncludeNotesDefault = false;
  bool _aiLocalFallbackToCloud = true;
  int _aiInboxTriageThreshold = 3;
  bool _aiShowToolTrace = false;
  String _aiCloudModelLite = '';
  bool _onboardingCompleted = false;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get upcomingReminderEnabled => _upcomingReminderEnabled;
  bool get dailyReportEnabled => _dailyReportEnabled;
  bool get weeklyReportEnabled => _weeklyReportEnabled;
  bool get dueAtReminderEnabled => _dueAtReminderEnabled;
  bool get reminderSoundEnabled => _reminderSoundEnabled;
  TimeOfDay get dailyReportTime => _minutesToTime(_dailyReportTimeMinutes);
  TimeOfDay get weeklyReportTime => _minutesToTime(_weeklyReportTimeMinutes);
  int get weeklyReportWeekday => _weeklyReportWeekday;
  DateTime? get upcomingPopupLastShown => _upcomingPopupLastShown;
  bool get globalQuickAddEnabled => _globalQuickAddEnabled;
  GlobalHotkeyConfig get globalQuickAddHotkey => _globalQuickAddHotkey;
  AiProviderType get aiProvider => _aiProvider;
  String get aiLocalEndpoint => _aiLocalEndpoint;
  String get aiLocalModel => _aiLocalModel;
  String get aiCloudEndpoint => _aiCloudEndpoint;
  String get aiCloudApiKey => _aiCloudApiKey;
  String get aiCloudModel => _aiCloudModel;
  String get aiClaudeCommand => _aiClaudeCommand;
  String get aiTrustOverrides => _aiTrustOverrides;
  int get aiTodayMaxTasks => _aiTodayMaxTasks;
  bool get aiMorningBriefingEnabled => _aiMorningBriefingEnabled;
  bool get aiEveningReviewEnabled => _aiEveningReviewEnabled;
  String get aiEveningReviewTime => _aiEveningReviewTime;
  bool get aiHighPrivacyMode => _aiHighPrivacyMode;
  bool get aiIncludeNotesDefault => _aiIncludeNotesDefault;
  bool get aiLocalFallbackToCloud => _aiLocalFallbackToCloud;
  int get aiInboxTriageThreshold => _aiInboxTriageThreshold;
  bool get aiShowToolTrace => _aiShowToolTrace;
  String get aiCloudModelLite => _aiCloudModelLite;
  bool get onboardingCompleted => _onboardingCompleted;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _prefs.setString(_keyThemeMode, mode.name);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    await _prefs.setString(_keyLocale, locale.languageCode);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    if (_notificationsEnabled == value) return;
    _notificationsEnabled = value;
    await _prefs.setBool(_keyNotificationsEnabled, value);
    notifyListeners();
  }

  Future<void> setUpcomingReminderEnabled(bool value) async {
    if (_upcomingReminderEnabled == value) return;
    _upcomingReminderEnabled = value;
    await _prefs.setBool(_keyUpcomingReminderEnabled, value);
    notifyListeners();
  }

  Future<void> setDailyReportEnabled(bool value) async {
    if (_dailyReportEnabled == value) return;
    _dailyReportEnabled = value;
    await _prefs.setBool(_keyDailyReportEnabled, value);
    notifyListeners();
  }

  Future<void> setWeeklyReportEnabled(bool value) async {
    if (_weeklyReportEnabled == value) return;
    _weeklyReportEnabled = value;
    await _prefs.setBool(_keyWeeklyReportEnabled, value);
    notifyListeners();
  }

  Future<void> setDueAtReminderEnabled(bool value) async {
    if (_dueAtReminderEnabled == value) return;
    _dueAtReminderEnabled = value;
    await _prefs.setBool(_keyDueAtReminderEnabled, value);
    notifyListeners();
  }

  Future<void> setReminderSoundEnabled(bool value) async {
    if (_reminderSoundEnabled == value) return;
    _reminderSoundEnabled = value;
    await _prefs.setBool(_keyReminderSoundEnabled, value);
    notifyListeners();
  }

  Future<void> setDailyReportTime(TimeOfDay value) async {
    final minutes = value.hour * 60 + value.minute;
    if (_dailyReportTimeMinutes == minutes) return;
    _dailyReportTimeMinutes = minutes;
    await _prefs.setInt(_keyDailyReportTimeMinutes, minutes);
    notifyListeners();
  }

  Future<void> setWeeklyReportTime(TimeOfDay value) async {
    final minutes = value.hour * 60 + value.minute;
    if (_weeklyReportTimeMinutes == minutes) return;
    _weeklyReportTimeMinutes = minutes;
    await _prefs.setInt(_keyWeeklyReportTimeMinutes, minutes);
    notifyListeners();
  }

  Future<void> setWeeklyReportWeekday(int value) async {
    if (_weeklyReportWeekday == value) return;
    _weeklyReportWeekday = value;
    await _prefs.setInt(_keyWeeklyReportWeekday, value);
    notifyListeners();
  }

  Future<void> setUpcomingPopupLastShown(DateTime value) async {
    _upcomingPopupLastShown = value;
    await _prefs.setInt(
        _keyUpcomingPopupLastShown, value.millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<void> setGlobalQuickAddEnabled(bool value) async {
    if (_globalQuickAddEnabled == value) return;
    _globalQuickAddEnabled = value;
    await _prefs.setBool(_keyGlobalQuickAddEnabled, value);
    notifyListeners();
  }

  Future<void> setGlobalQuickAddHotkey(GlobalHotkeyConfig value) async {
    _globalQuickAddHotkey = value;
    await _prefs.setString(
        _keyGlobalQuickAddHotkey, jsonEncode(value.toJson()));
    notifyListeners();
  }

  Future<void> setAiProvider(AiProviderType value) async {
    if (_aiProvider == value) return;
    _aiProvider = value;
    await _prefs.setString(_keyAiProvider, value.id);
    notifyListeners();
  }

  Future<void> setAiLocalEndpoint(String value) async {
    if (_aiLocalEndpoint == value) return;
    _aiLocalEndpoint = value;
    await _prefs.setString(_keyAiLocalEndpoint, value);
    notifyListeners();
  }

  Future<void> setAiLocalModel(String value) async {
    if (_aiLocalModel == value) return;
    _aiLocalModel = value;
    await _prefs.setString(_keyAiLocalModel, value);
    notifyListeners();
  }

  Future<void> setAiCloudEndpoint(String value) async {
    if (_aiCloudEndpoint == value) return;
    _aiCloudEndpoint = value;
    await _prefs.setString(_keyAiCloudEndpoint, value);
    notifyListeners();
  }

  Future<void> setAiCloudApiKey(String value) async {
    if (_aiCloudApiKey == value) return;
    _aiCloudApiKey = value;
    await _prefs.setString(_keyAiCloudApiKey, value);
    notifyListeners();
  }

  Future<void> setAiCloudModel(String value) async {
    if (_aiCloudModel == value) return;
    _aiCloudModel = value;
    await _prefs.setString(_keyAiCloudModel, value);
    notifyListeners();
  }

  Future<void> setAiClaudeCommand(String value) async {
    if (_aiClaudeCommand == value) return;
    _aiClaudeCommand = value;
    await _prefs.setString(_keyAiClaudeCommand, value);
    notifyListeners();
  }

  Future<void> setAiHighPrivacyMode(bool value) async {
    if (_aiHighPrivacyMode == value) return;
    _aiHighPrivacyMode = value;
    await _prefs.setBool(_keyAiHighPrivacyMode, value);
    notifyListeners();
  }

  Future<void> setAiShowToolTrace(bool value) async {
    if (_aiShowToolTrace == value) return;
    _aiShowToolTrace = value;
    await _prefs.setBool(_keyAiShowToolTrace, value);
    notifyListeners();
  }

  Future<void> setAiTodayMaxTasks(int value) async {
    final normalized = value.clamp(1, 50);
    if (_aiTodayMaxTasks == normalized) return;
    _aiTodayMaxTasks = normalized;
    await _prefs.setInt(_keyAiTodayMaxTasks, normalized);
    notifyListeners();
  }

  Future<void> setOnboardingCompleted(bool value) async {
    if (_onboardingCompleted == value) return;
    _onboardingCompleted = value;
    await _prefs.setBool(_keyOnboardingCompleted, value);
    notifyListeners();
  }

  TimeOfDay _minutesToTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return TimeOfDay(hour: hour, minute: minute);
  }
}
