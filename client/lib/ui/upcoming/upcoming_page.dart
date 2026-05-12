import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database.dart';
import '../task_detail/task_detail_sheet.dart';
import '../task_sort.dart';
import '../widgets/task_list_container.dart';

class UpcomingPage extends StatefulWidget {
  const UpcomingPage({
    super.key,
    this.sortMode = TaskSortMode.createdDesc,
  });

  final TaskSortMode sortMode;

  @override
  State<UpcomingPage> createState() => _UpcomingPageState();
}

class _UpcomingPageState extends State<UpcomingPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _todayKey = GlobalKey();
  bool _didScrollToToday = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);

    return LayoutBuilder(builder: (context, constraints) {
      return StreamBuilder<List<Task>>(
        stream: db.watchPlanTasks(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final model = _PlanModel.build(
            tasks: sortTasks(snapshot.data!, TaskSortMode.dueDateAsc),
            today: _dateOnly(DateTime.now()),
          );
          _scrollToTodayAfterBuild();

          // 用 SingleChildScrollView + Column 强制 eager mount：ListView 的
          // SliverList 即使 children 列表 up-front 给出，仍按视口懒 mount
          // Element，导致 _todayKey.currentContext 在初始视口外时永远为 null，
          // Scrollable.ensureVisible 拿不到 RenderObject。今天大概率在中段
          // （±7 天 + 月分组），所以原地永远滚不到。改 eager 后第一帧 today
          // 已 mount，ensureVisible 立刻生效。约 30~80 widget 量级，性能 OK。
          return TaskListContainer(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final month in model.pastMonths)
                    _MonthSection(month: month, db: db),
                  for (final day in model.days)
                    _DaySection(
                      key: day.isToday ? _todayKey : null,
                      day: day,
                      db: db,
                    ),
                  for (final month in model.futureMonths)
                    _MonthSection(month: month, db: db),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  void _scrollToTodayAfterBuild() {
    if (_didScrollToToday) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didScrollToToday) return;
      final ctx = _todayKey.currentContext;
      if (ctx == null) return;
      _didScrollToToday = true;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.05,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _PlanModel {
  const _PlanModel({
    required this.pastMonths,
    required this.days,
    required this.futureMonths,
  });

  final List<_MonthGroup> pastMonths;
  final List<_DayGroup> days;
  final List<_MonthGroup> futureMonths;

  static _PlanModel build({
    required List<Task> tasks,
    required DateTime today,
  }) {
    final start = today.subtract(const Duration(days: 7));
    final end = today.add(const Duration(days: 7));
    final dayTasks = <DateTime, List<Task>>{};
    final pastMonthTasks = <DateTime, List<Task>>{};
    final futureMonthTasks = <DateTime, List<Task>>{};

    for (final task in tasks) {
      if (task.status == 2) continue;
      final dueDate = task.dueDate ?? task.endDate;
      if (dueDate == null) continue;
      final day = _dateOnly(dueDate);
      if (day.isBefore(start)) {
        final month = DateTime(day.year, day.month);
        pastMonthTasks.putIfAbsent(month, () => <Task>[]).add(task);
      } else if (day.isAfter(end)) {
        final month = DateTime(day.year, day.month);
        futureMonthTasks.putIfAbsent(month, () => <Task>[]).add(task);
      } else {
        dayTasks.putIfAbsent(day, () => <Task>[]).add(task);
      }
    }

    final days = <_DayGroup>[];
    for (var offset = -7; offset <= 7; offset++) {
      final day = today.add(Duration(days: offset));
      days.add(
        _DayGroup(
          date: day,
          tasks: dayTasks[day] ?? const <Task>[],
          isToday: offset == 0,
        ),
      );
    }

    return _PlanModel(
      pastMonths: _monthGroups(pastMonthTasks),
      days: days,
      futureMonths: _monthGroups(futureMonthTasks),
    );
  }

  static List<_MonthGroup> _monthGroups(Map<DateTime, List<Task>> groups) {
    final keys = groups.keys.toList()..sort();
    return [
      for (final key in keys) _MonthGroup(month: key, tasks: groups[key]!),
    ];
  }
}

class _DayGroup {
  const _DayGroup({
    required this.date,
    required this.tasks,
    required this.isToday,
  });

  final DateTime date;
  final List<Task> tasks;
  final bool isToday;
}

class _MonthGroup {
  const _MonthGroup({
    required this.month,
    required this.tasks,
  });

  final DateTime month;
  final List<Task> tasks;
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    super.key,
    required this.day,
    required this.db,
  });

  final _DayGroup day;
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final labelColor = day.isToday
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(0.82);

    return LayoutBuilder(
      builder: (context, constraints) {
        final dateColumnWidth = constraints.maxWidth < 420 ? 132.0 : 168.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: dateColumnWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isZh ? '${day.date.day}日' : '${day.date.day}',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Text(
                            _weekdayLabel(context, day.date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.58),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 68),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final task in day.tasks)
                          _PlanTaskTile(task: task, db: db, showDay: false),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.month,
    required this.db,
  });

  final _MonthGroup month;
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _monthTitle(context, month.month),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.86),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final task in month.tasks)
              _PlanTaskTile(task: task, db: db, showDay: true),
          ],
        ),
      ),
    );
  }
}

class _PlanTaskTile extends StatelessWidget {
  const _PlanTaskTile({
    required this.task,
    required this.db,
    required this.showDay,
  });

  final Task task;
  final AppDatabase db;
  final bool showDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = task.status == 1;
    final dueDate = task.dueDate ?? task.endDate;
    final dateColor = _priorityColor(task.priority);

    return InkWell(
      onTap: () => showTaskDetailSheet(context: context, task: task, db: db),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            if (showDay && dueDate != null) ...[
              SizedBox(
                width: 54,
                child: Text(
                  '${dueDate.day.toString().padLeft(2, '0')}日',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: dateColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            InkWell(
              onTap: () => db.toggleTaskStatus(task.id, !isDone),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDone ? Colors.grey : dateColor,
                    width: 2,
                  ),
                  color: isDone
                      ? Colors.grey.withOpacity(0.15)
                      : Colors.transparent,
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 12, color: Colors.grey)
                    : null,
              ),
            ),
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDone
                      ? theme.colorScheme.onSurface.withOpacity(0.48)
                      : theme.colorScheme.onSurface.withOpacity(0.68),
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _weekdayLabel(BuildContext context, DateTime day) {
  const zhWeekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  const enWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final index = day.weekday - DateTime.monday;
  if (Localizations.localeOf(context).languageCode == 'zh') {
    return zhWeekdays[index];
  }
  return enWeekdays[index];
}

String _monthTitle(BuildContext context, DateTime month) {
  if (Localizations.localeOf(context).languageCode == 'zh') {
    return '${month.month}月';
  }
  return MaterialLocalizations.of(context).formatMonthYear(month);
}

Color _priorityColor(int? priority) {
  switch (priority) {
    case 3:
      return Colors.red;
    case 2:
      return Colors.orange;
    case 1:
      return Colors.blue;
    default:
      return const Color(0xFFD326E8);
  }
}
