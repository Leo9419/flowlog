import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/notification_service.dart';
import '../../state/app_settings.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = Provider.of<AppSettings>(context);
    final enabled = settings.notificationsEnabled;
    final upcomingEnabled = settings.upcomingReminderEnabled;
    final dailyEnabled = settings.dailyReportEnabled;
    final weeklyEnabled = settings.weeklyReportEnabled;
    final dueAtEnabled = settings.dueAtReminderEnabled;
    final timeFormatter = MaterialLocalizations.of(context);
    final weekdays = timeFormatter.narrowWeekdays;

    String weekdayLabel(int weekday) {
      final index = weekday % 7;
      return weekdays[index];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.notifications),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: Text(l.notificationsEnabled),
            value: enabled,
            onChanged: (value) async {
              if (!value) {
                await settings.setNotificationsEnabled(false);
                return;
              }
              final granted = await NotificationService.instance.requestPermissions();
              if (!context.mounted) return;
              if (!granted) {
                await settings.setNotificationsEnabled(false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.notificationsPermissionDenied)),
                );
                return;
              }
              await settings.setNotificationsEnabled(true);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.alarm_outlined),
            title: Text(l.upcomingReminder),
            value: upcomingEnabled,
            onChanged: enabled
                ? (value) {
                    settings.setUpcomingReminderEnabled(value);
                  }
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: Text(l.upcomingSummaryTitle),
            subtitle: Text(l.upcomingSummarySubtitle),
            enabled: enabled && upcomingEnabled,
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text(l.upcomingBeforeDueTitle),
            subtitle: Text(l.upcomingBeforeDueSubtitle),
            enabled: enabled && upcomingEnabled,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.event_outlined),
            title: Text(l.dueAtReminder),
            subtitle: Text(l.dueAtReminderSubtitle),
            value: dueAtEnabled,
            onChanged: enabled
                ? (value) {
                    settings.setDueAtReminderEnabled(value);
                  }
                : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.today_outlined),
            title: Text(l.dailyReportReminder),
            value: dailyEnabled,
            onChanged: enabled
                ? (value) {
                    settings.setDailyReportEnabled(value);
                  }
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: Text(l.dailyReportTime),
            subtitle: Text(timeFormatter.formatTimeOfDay(settings.dailyReportTime)),
            enabled: enabled && dailyEnabled,
            onTap: enabled && dailyEnabled
                ? () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: settings.dailyReportTime,
                    );
                    if (time != null) {
                      await settings.setDailyReportTime(time);
                    }
                  }
                : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.date_range_outlined),
            title: Text(l.weeklyReportReminder),
            value: weeklyEnabled,
            onChanged: enabled
                ? (value) {
                    settings.setWeeklyReportEnabled(value);
                  }
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: Text(l.weeklyReportDay),
            enabled: enabled && weeklyEnabled,
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: settings.weeklyReportWeekday,
                items: [
                  for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                    DropdownMenuItem(
                      value: day,
                      child: Text(weekdayLabel(day)),
                    ),
                ],
                onChanged: enabled && weeklyEnabled
                    ? (value) {
                        if (value != null) {
                          settings.setWeeklyReportWeekday(value);
                        }
                      }
                    : null,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: Text(l.weeklyReportTime),
            subtitle: Text(timeFormatter.formatTimeOfDay(settings.weeklyReportTime)),
            enabled: enabled && weeklyEnabled,
            onTap: enabled && weeklyEnabled
                ? () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: settings.weeklyReportTime,
                    );
                    if (time != null) {
                      await settings.setWeeklyReportTime(time);
                    }
                  }
                : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: Text(l.reminderSound),
            value: settings.reminderSoundEnabled,
            onChanged: enabled
                ? (value) {
                    settings.setReminderSoundEnabled(value);
                  }
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.bolt_outlined),
            title: Text(l.testNotification),
            enabled: enabled,
            onTap: enabled
                ? () async {
                    final granted = await NotificationService.instance.requestPermissions();
                    if (!context.mounted) return;
                    if (!granted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.notificationsPermissionDenied)),
                      );
                      return;
                    }
                    await NotificationService.instance.sendTestNotification(
                      l: l,
                      soundEnabled: settings.reminderSoundEnabled,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.testNotificationSent)),
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
