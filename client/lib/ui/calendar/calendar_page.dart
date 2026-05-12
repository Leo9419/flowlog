import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../task_sort.dart';
import '../widgets/task_row.dart';

/// 旧版日历视图，M1_04 之后由 [UpcomingPage]（在 sidebar/底部 Tab 上叫"日历"）
/// 接管同等职责并修复了"滚到今天"行为。本类暂留作回滚兜底，M2 视图重构
/// 阶段二选一删掉。
@Deprecated(
  'Use UpcomingPage (labeled "Calendar" in M1_04 shell). Will be removed in M2.',
)
class CalendarPage extends StatelessWidget {
  const CalendarPage({
    super.key,
    this.sortMode = TaskSortMode.createdDesc,
  });

  final TaskSortMode sortMode;

  DateTime _dayOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  int _dateKey(DateTime value) {
    return value.year * 10000 + value.month * 100 + value.day;
  }

  String _titleForLocale(BuildContext context, AppLocalizations l) {
    return l.calendar;
  }

  String _weekdayLabel(BuildContext context, DateTime day) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'zh') {
      const labels = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
      return labels[day.weekday - 1];
    }
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[day.weekday - 1];
  }

  String _relativeLabel(BuildContext context, DateTime day) {
    final now = DateTime.now();
    final today = _dayOnly(now);
    if (day == today) {
      return AppLocalizations.of(context).todayLabel;
    }
    if (day == today.add(const Duration(days: 1))) {
      final locale = Localizations.localeOf(context);
      return locale.languageCode == 'zh' ? '明天' : 'Tomorrow';
    }
    return _weekdayLabel(context, day);
  }

  Map<int, List<Task>> _groupTasks(List<Task> tasks) {
    final grouped = <int, List<Task>>{};
    for (final task in tasks) {
      final dueDate = task.dueDate ?? task.endDate;
      if (dueDate == null) continue;
      final day = _dayOnly(dueDate);
      grouped.putIfAbsent(_dateKey(day), () => <Task>[]).add(task);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = _titleForLocale(context, l);

    return StreamBuilder<List<Task>>(
      stream: db.watchAllTasks(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasksByDay = _groupTasks(snapshot.data!);
        final now = DateTime.now();
        final start = _dayOnly(now).add(const Duration(days: 1));
        final days =
            List.generate(45, (index) => start.add(Duration(days: index)));
        final isWide = MediaQuery.sizeOf(context).width > 800;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(72, 58, 72, 16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      color: theme.colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(72, 8, 72, 80),
              sliver: SliverList.builder(
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final day = days[index];
                  final tasks = sortTasks(
                    tasksByDay[_dateKey(day)] ?? const <Task>[],
                    sortMode,
                  );
                  return _PlanDaySection(
                    day: day,
                    relativeLabel: _relativeLabel(context, day),
                    tasks: tasks,
                    db: db,
                    isWide: isWide,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlanDaySection extends StatelessWidget {
  const _PlanDaySection({
    required this.day,
    required this.relativeLabel,
    required this.tasks,
    required this.db,
    required this.isWide,
  });

  final DateTime day;
  final String relativeLabel;
  final List<Task> tasks;
  final AppDatabase db;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayColor = theme.colorScheme.onSurface;
    final labelColor = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 38),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${day.day}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontSize: 42,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: dayColor,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    relativeLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 19),
                Divider(height: 1, color: theme.dividerColor),
                if (tasks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        for (var i = 0; i < tasks.length; i++) ...[
                          TaskRow(task: tasks[i], db: db, isWide: isWide),
                          if (i != tasks.length - 1)
                            Divider(
                                height: 1,
                                indent: 50,
                                color: theme.dividerColor),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
