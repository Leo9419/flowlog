import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../task_sort.dart';
import '../widgets/task_row.dart';

class AllTasksPage extends StatefulWidget {
  const AllTasksPage({
    super.key,
    this.sortMode = TaskSortMode.createdDesc,
  });

  final TaskSortMode sortMode;

  @override
  State<AllTasksPage> createState() => _AllTasksPageState();
}

class _AllTasksPageState extends State<AllTasksPage> {
  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l = AppLocalizations.of(context);

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 800;

      return Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: db.watchAllTasks(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tasks = snapshot.data!;
                if (tasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.all_inbox_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(l.allEmpty, style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  );
                }

                final groups = _buildGroups(tasks);
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final sectionKey = group.key;

                    return ExpansionTile(
                      key: PageStorageKey(sectionKey),
                      title: Text(group.title),
                      subtitle: Text(l.tasksCount(group.tasks.length)),
                      initiallyExpanded: group.defaultExpanded,
                      children: _buildGroupChildren(group.tasks, db, isWide),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
    });
  }

  List<_TaskGroup> _buildGroups(List<Task> tasks) {
    final grouped = <DateTime?, List<Task>>{};
    for (final task in tasks) {
      final dueDate = task.dueDate;
      final key = dueDate == null
          ? null
          : DateTime(dueDate.year, dueDate.month, dueDate.day);
      grouped.putIfAbsent(key, () => []).add(task);
    }

    final datedKeys = grouped.keys.whereType<DateTime>().toList()
      ..sort((a, b) => b.compareTo(a));
    final groups = <_TaskGroup>[];

    for (var i = 0; i < datedKeys.length; i++) {
      final date = datedKeys[i];
      final key = _dateKey(date);
      final title = _formatDateTitle(date);
      final items = sortTasks(grouped[date] ?? const <Task>[], widget.sortMode);
      groups.add(
        _TaskGroup(
          key: key,
          title: title,
          tasks: items,
          defaultExpanded: i == 0,
        ),
      );
    }

    if (grouped.containsKey(null)) {
      final items = sortTasks(grouped[null] ?? const <Task>[], widget.sortMode);
      groups.add(
        _TaskGroup(
          key: 'no_due_date',
          title: AppLocalizations.of(context).noDueDate,
          tasks: items,
          defaultExpanded: datedKeys.isEmpty,
        ),
      );
    }

    return groups;
  }

  List<Widget> _buildGroupChildren(List<Task> tasks, AppDatabase db, bool isWide) {
    return [
      for (var i = 0; i < tasks.length; i++) ...[
        TaskRow(task: tasks[i], db: db, isWide: isWide),
        if (i != tasks.length - 1)
          const Divider(height: 1, indent: 50),
      ],
    ];
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTitle(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _TaskGroup {
  const _TaskGroup({
    required this.key,
    required this.title,
    required this.tasks,
    required this.defaultExpanded,
  });

  final String key;
  final String title;
  final List<Task> tasks;
  final bool defaultExpanded;
}
