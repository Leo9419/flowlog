import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../state/app_settings.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _dailySummaryId = 1000;
  static const _dailyReportId = 1100;
  static const _weeklyReportId = 1200;
  static const _taskReminderBaseId = 2000;
  static const _taskReminderRange = 1000000;
  static const _taskDueAtBaseId = _taskReminderBaseId + _taskReminderRange;
  static const _testNotificationId = 9999;
  static const _androidChannelId = 'flowlog_reminders';
  static const _androidChannelName = 'FlowLog Reminders';
  static const _androidChannelDescription = 'Task reminders and daily summary';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<List<Task>>? _taskSubscription;
  void Function()? _settingsListener;
  Timer? _debounceTimer;
  List<Task> _latestTasks = const [];
  AppSettings? _settings;
  bool _initialized = false;
  bool _androidExactAlarmsAllowed = false;

  Future<void> bind({
    required AppDatabase db,
    required AppSettings settings,
  }) async {
    if (_settingsListener != null && _settings != null) {
      _settings!.removeListener(_settingsListener!);
    }
    _settings = settings;
    await _init();
    await _attachListeners(db, settings);
    _scheduleNotifications();
  }

  Future<void> dispose() async {
    await _taskSubscription?.cancel();
    _taskSubscription = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (_settings != null && _settingsListener != null) {
      _settings!.removeListener(_settingsListener!);
    }
    _settingsListener = null;
  }

  Future<void> _init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    // M1_02：在装好时区数据后把 tz.local 校到设备本地时区，避免
    // `tz.TZDateTime.from(DateTime, tz.local)` 在某些设备上回退 UTC。
    try {
      // flutter_timezone 5.x 返回 TimezoneInfo（含 identifier / name），
      // 这里只用 IANA identifier 喂 timezone 包。
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (error, stackTrace) {
      // 单平台失败（如旧版 macOS / iOS 模拟器特殊）不应阻止通知初始化；
      // 退回 tz.local 的默认（UTC）但仍能调度大致正确的提醒。
      debugPrint('Local timezone resolution failed: $error');
      debugPrint(stackTrace.toString());
    }
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      // 把权限请求延后到首次 reminderAt / Onboarding "开启提醒" 等真实
      // 用户行为发生时（参见 [requestPermissions]）。Apple 审核会拒绝
      // 启动即弹权限的应用，Android 13+ 也是同理。
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    await _init();
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final androidGranted =
          await androidPlugin.requestNotificationsPermission();
      final exactGranted =
          await _requestAndroidExactAlarmPermission(androidPlugin);
      if (exactGranted != null) {
        _androidExactAlarmsAllowed = exactGranted;
      }
      return androidGranted ?? true;
    }
    final macosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    if (macosGranted != null) {
      return macosGranted;
    }
    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return iosGranted ?? true;
  }

  Future<bool?> _requestAndroidExactAlarmPermission(
    AndroidFlutterLocalNotificationsPlugin androidPlugin,
  ) async {
    try {
      return await androidPlugin.requestExactAlarmsPermission();
    } on PlatformException {
      return null;
    }
  }

  Future<void> _attachListeners(AppDatabase db, AppSettings settings) async {
    await _taskSubscription?.cancel();
    _taskSubscription = db.watchActiveTasks().listen((tasks) {
      _latestTasks = tasks;
      _scheduleNotifications();
    });

    _settingsListener = _scheduleNotifications;
    settings.addListener(_settingsListener!);
  }

  void _scheduleNotifications() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _applySchedule();
    });
  }

  Future<void> _applySchedule() async {
    final settings = _settings;
    if (settings == null) return;

    await _init();
    await _plugin.cancelAll();

    if (!settings.notificationsEnabled) {
      return;
    }

    final l = AppLocalizations(settings.locale);
    final soundEnabled = settings.reminderSoundEnabled;

    if (settings.upcomingReminderEnabled) {
      await _scheduleDailySummary(
        tasks: _latestTasks,
        l: l,
        soundEnabled: soundEnabled,
      );
      await _scheduleTaskReminders(
        tasks: _latestTasks,
        l: l,
        soundEnabled: soundEnabled,
      );
    }
    if (settings.dueAtReminderEnabled) {
      await _scheduleDueAtReminders(
        tasks: _latestTasks,
        l: l,
        soundEnabled: soundEnabled,
      );
    }
    if (settings.dailyReportEnabled) {
      await _scheduleDailyReport(
        tasks: _latestTasks,
        l: l,
        soundEnabled: soundEnabled,
        scheduledTime: settings.dailyReportTime,
      );
    }
    if (settings.weeklyReportEnabled) {
      await _scheduleWeeklyReport(
        tasks: _latestTasks,
        l: l,
        soundEnabled: soundEnabled,
        scheduledTime: settings.weeklyReportTime,
        weekday: settings.weeklyReportWeekday,
      );
    }
  }

  Future<void> _scheduleDailySummary({
    required List<Task> tasks,
    required AppLocalizations l,
    required bool soundEnabled,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 17);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final windowStart = DateTime(
      scheduled.year,
      scheduled.month,
      scheduled.day,
      scheduled.hour,
      scheduled.minute,
    );
    final windowEnd = windowStart.add(const Duration(hours: 24));
    final count = _countTasksInWindow(tasks, windowStart, windowEnd);
    final title = l.upcomingSummaryNotificationTitle;
    final body = count == 0
        ? l.upcomingSummaryNotificationEmpty
        : l.upcomingSummaryNotificationBody(count);

    await _zonedScheduleSafe(
      id: _dailySummaryId,
      title: title,
      body: body,
      scheduled: scheduled,
      details: _notificationDetails(soundEnabled),
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleTaskReminders({
    required List<Task> tasks,
    required AppLocalizations l,
    required bool soundEnabled,
  }) async {
    final now = DateTime.now();
    for (final task in tasks) {
      final dueDate = _effectiveReminderDate(task);
      if (dueDate == null) continue;
      final normalizedDue = _normalizeReminderDate(task, dueDate);
      final reminderTime = normalizedDue.subtract(const Duration(minutes: 30));
      if (!reminderTime.isAfter(now)) {
        continue;
      }
      final scheduled = tz.TZDateTime.from(reminderTime, tz.local);
      final id =
          _taskReminderBaseId + (_stableId(task.id) % _taskReminderRange);
      final title = l.dueSoonNotificationTitle;
      final body = l.dueSoonNotificationBody(task.title);

      await _zonedScheduleSafe(
        id: id,
        title: title,
        body: body,
        scheduled: scheduled,
        details: _notificationDetails(soundEnabled),
      );
    }
  }

  Future<void> _scheduleDueAtReminders({
    required List<Task> tasks,
    required AppLocalizations l,
    required bool soundEnabled,
  }) async {
    final now = DateTime.now();
    for (final task in tasks) {
      if (task.status != 0) continue;
      final dueDate = _effectiveReminderDate(task);
      if (dueDate == null) continue;
      final normalizedDue = _normalizeReminderDate(task, dueDate);
      if (!normalizedDue.isAfter(now)) {
        continue;
      }
      final scheduled = tz.TZDateTime.from(normalizedDue, tz.local);
      final id = _taskDueAtBaseId + (_stableId(task.id) % _taskReminderRange);
      final title = l.dueNowNotificationTitle;
      final body = l.dueNowNotificationBody(task.title);

      await _zonedScheduleSafe(
        id: id,
        title: title,
        body: body,
        scheduled: scheduled,
        details: _notificationDetails(soundEnabled),
      );
    }
  }

  Future<void> _scheduleDailyReport({
    required List<Task> tasks,
    required AppLocalizations l,
    required bool soundEnabled,
    required TimeOfDay scheduledTime,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      scheduledTime.hour,
      scheduledTime.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final dayStart = DateTime(scheduled.year, scheduled.month, scheduled.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dueToday = _countDueInRange(tasks, dayStart, dayEnd);
    final doneToday = _countCompletedInRange(tasks, dayStart, dayEnd);
    final overdue = _countOverdue(tasks, dayStart);
    final title = l.dailyReportNotificationTitle;
    final body = l.dailyReportNotificationBody(dueToday, doneToday, overdue);

    await _zonedScheduleSafe(
      id: _dailyReportId,
      title: title,
      body: body,
      scheduled: scheduled,
      details: _notificationDetails(soundEnabled),
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleWeeklyReport({
    required List<Task> tasks,
    required AppLocalizations l,
    required bool soundEnabled,
    required TimeOfDay scheduledTime,
    required int weekday,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      scheduledTime.hour,
      scheduledTime.minute,
    );
    final deltaDays = (weekday - scheduled.weekday + 7) % 7;
    scheduled = scheduled.add(Duration(days: deltaDays));
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }

    final rangeEnd = DateTime(
      scheduled.year,
      scheduled.month,
      scheduled.day,
      scheduled.hour,
      scheduled.minute,
    );
    final rangeStart = rangeEnd.subtract(const Duration(days: 7));
    final done = _countCompletedInRange(tasks, rangeStart, rangeEnd);
    final created = _countCreatedInRange(tasks, rangeStart, rangeEnd);
    final due = _countDueInRange(tasks, rangeStart, rangeEnd);
    final open = _countOpen(tasks);
    final title = l.weeklyReportNotificationTitle;
    final body = l.weeklyReportNotificationBody(
      done: done,
      created: created,
      due: due,
      open: open,
    );

    await _zonedScheduleSafe(
      id: _weeklyReportId,
      title: title,
      body: body,
      scheduled: scheduled,
      details: _notificationDetails(soundEnabled),
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> _zonedScheduleSafe({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduled,
    required NotificationDetails details,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: _resolveAndroidScheduleMode(),
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } on PlatformException catch (error) {
      if (error.code == 'exact_alarms_not_permitted' &&
          defaultTargetPlatform == TargetPlatform.android) {
        _androidExactAlarmsAllowed = false;
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduled,
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: matchDateTimeComponents,
        );
      } else {
        debugPrint('Notification schedule failed: $error');
      }
    }
  }

  AndroidScheduleMode _resolveAndroidScheduleMode() {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    return _androidExactAlarmsAllowed
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  NotificationDetails _notificationDetails(bool soundEnabled) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: soundEnabled,
        enableVibration: soundEnabled,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: soundEnabled,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: soundEnabled,
      ),
    );
  }

  Future<void> sendTestNotification({
    required AppLocalizations l,
    required bool soundEnabled,
  }) async {
    await _init();
    await _plugin.show(
      _testNotificationId,
      l.testNotificationTitle,
      l.testNotificationBody,
      _notificationDetails(soundEnabled),
    );
  }

  DateTime? _effectiveReminderDate(Task task) {
    return task.endDate ?? task.dueDate;
  }

  DateTime _normalizeReminderDate(Task task, DateTime dueDate) {
    final isDateOnly = dueDate.hour == 0 &&
        dueDate.minute == 0 &&
        dueDate.second == 0 &&
        dueDate.millisecond == 0 &&
        dueDate.microsecond == 0;
    if (task.isAllDay || isDateOnly) {
      return DateTime(dueDate.year, dueDate.month, dueDate.day, 17);
    }
    return dueDate;
  }

  int _countTasksInWindow(List<Task> tasks, DateTime start, DateTime end) {
    var count = 0;
    for (final task in tasks) {
      final dueDate = _effectiveReminderDate(task);
      if (dueDate == null) continue;
      final normalizedDue = _normalizeReminderDate(task, dueDate);
      if (!normalizedDue.isBefore(start) && normalizedDue.isBefore(end)) {
        count++;
      }
    }
    return count;
  }

  int _countDueInRange(List<Task> tasks, DateTime start, DateTime end) {
    var count = 0;
    for (final task in tasks) {
      if (task.status != 0) continue;
      final dueDate = _effectiveReminderDate(task);
      if (dueDate == null) continue;
      final normalizedDue = _normalizeReminderDate(task, dueDate);
      if (!normalizedDue.isBefore(start) && normalizedDue.isBefore(end)) {
        count++;
      }
    }
    return count;
  }

  int _countCompletedInRange(List<Task> tasks, DateTime start, DateTime end) {
    var count = 0;
    for (final task in tasks) {
      if (task.status != 1) continue;
      final completedAt = task.completedAt;
      if (completedAt == null) continue;
      if (!completedAt.isBefore(start) && completedAt.isBefore(end)) {
        count++;
      }
    }
    return count;
  }

  int _countCreatedInRange(List<Task> tasks, DateTime start, DateTime end) {
    var count = 0;
    for (final task in tasks) {
      final createdAt = task.createdAt;
      if (!createdAt.isBefore(start) && createdAt.isBefore(end)) {
        count++;
      }
    }
    return count;
  }

  int _countOverdue(List<Task> tasks, DateTime before) {
    var count = 0;
    for (final task in tasks) {
      if (task.status != 0) continue;
      final dueDate = _effectiveReminderDate(task);
      if (dueDate == null) continue;
      final normalizedDue = _normalizeReminderDate(task, dueDate);
      if (normalizedDue.isBefore(before)) {
        count++;
      }
    }
    return count;
  }

  int _countOpen(List<Task> tasks) {
    var count = 0;
    for (final task in tasks) {
      if (task.status == 0) {
        count++;
      }
    }
    return count;
  }

  int _stableId(String input) {
    var hash = 0;
    for (final unit in input.codeUnits) {
      hash = 0x1fffffff & (hash + unit);
      hash = 0x1fffffff & (hash + ((hash << 10) & 0x1fffffff));
      hash ^= (hash >> 6);
    }
    hash = 0x1fffffff & (hash + ((hash << 3) & 0x1fffffff));
    hash ^= (hash >> 11);
    hash = 0x1fffffff & (hash + ((hash << 15) & 0x1fffffff));
    return hash & 0x7fffffff;
  }
}
