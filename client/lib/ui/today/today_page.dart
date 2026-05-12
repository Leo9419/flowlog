import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../database/database.dart';
import '../../l10n/app_localizations.dart';

import '../widgets/task_row.dart';
import '../widgets/task_list_container.dart';
import '../task_sort.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    this.sortMode = TaskSortMode.createdDesc,
  });

  final TaskSortMode sortMode;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _completedExpanded = false;
  bool _overdueExpanded = true;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addTask(AppDatabase db) {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    final now = DateTime.now();
    final newTask = TasksCompanion(
      id: drift.Value(const Uuid().v4()),
      title: drift.Value(title),
      status: const drift.Value(0), // Todo
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
      // 简单起见，暂不设置 dueDate，默认逻辑上它出现在“今天”是因为它是新加的
      // 实际逻辑应该设置 dueDate 为今天
      dueDate: drift.Value(DateTime(now.year, now.month, now.day)),
      isAllDay: const drift.Value(true),
    );

    db.insertTask(newTask);
    _controller.clear();
    // 保持焦点以便继续输入
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final quickAddShadow = isDark
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ];

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 800;
      
      return Column(
        children: [
          // 快速添加栏
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
              boxShadow: quickAddShadow,
            ),
            child: Row(
              children: [
                Material(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => _addTask(db),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.add, size: 18, color: theme.colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: l.addTaskToToday,
                      border: InputBorder.none,
                      isDense: true,
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.45),
                      ),
                    ),
                    onSubmitted: (_) => _addTask(db),
                  ),
                ),
              ],
            ),
          ),
          
          // 任务列表
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: db.watchTodayTasks(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                final todayEnd = todayStart.add(const Duration(days: 1));

                final tasks = sortTasks(snapshot.data!, widget.sortMode);
                final overdueTasks = tasks.where((task) {
                  final dueDate = task.dueDate;
                  if (task.status != 0 || dueDate == null) return false;
                  return dueDate.isBefore(todayStart);
                }).toList();
                final activeTasks = tasks.where((task) {
                  final dueDate = task.dueDate;
                  if (task.status != 0 || dueDate == null) return false;
                  return !dueDate.isBefore(todayStart) && dueDate.isBefore(todayEnd);
                }).toList();
                final completedTasks = tasks.where((task) => task.status == 1).toList();

                if (overdueTasks.isEmpty && activeTasks.isEmpty && completedTasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wb_sunny_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(l.todayEmpty, style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  );
                }

                final children = <Widget>[
                  if (overdueTasks.isNotEmpty)
                    ExpansionTile(
                      key: const PageStorageKey('today_overdue'),
                      title: Text(l.overdue),
                      subtitle: Text(l.tasksCount(overdueTasks.length)),
                      initiallyExpanded: _overdueExpanded,
                      onExpansionChanged: (value) {
                        setState(() {
                          _overdueExpanded = value;
                        });
                      },
                      children: _buildTaskRows(overdueTasks, db, isWide),
                    ),
                  if (overdueTasks.isNotEmpty && activeTasks.isNotEmpty)
                    const Divider(height: 1, indent: 50),
                  ..._buildTaskRows(activeTasks, db, isWide),
                  if (completedTasks.isNotEmpty &&
                      (activeTasks.isNotEmpty || overdueTasks.isNotEmpty))
                    const Divider(height: 1, indent: 50),
                  if (completedTasks.isNotEmpty)
                    ExpansionTile(
                      key: const PageStorageKey('today_completed'),
                      title: Text(l.completed),
                      subtitle: Text(l.tasksCount(completedTasks.length)),
                      initiallyExpanded: _completedExpanded,
                      onExpansionChanged: (value) {
                        setState(() {
                          _completedExpanded = value;
                        });
                      },
                      children: _buildTaskRows(completedTasks, db, isWide),
                    ),
                ];

                return TaskListContainer(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
                    children: children,
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  List<Widget> _buildTaskRows(List<Task> tasks, AppDatabase db, bool isWide) {
    return [
      for (var i = 0; i < tasks.length; i++) ...[
        TaskRow(task: tasks[i], db: db, isWide: isWide),
        if (i != tasks.length - 1)
          const Divider(height: 1, indent: 50),
      ],
    ];
  }
}
