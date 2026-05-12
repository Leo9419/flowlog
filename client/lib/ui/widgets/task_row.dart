import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../../state/selection_store.dart';
import '../../ui/shell/breakpoints.dart';
import '../task_detail/task_detail_sheet.dart';
import '../task_repeat.dart';

/// 决定 tap 一个任务行后是开 modal sheet 还是把任务塞给 DesktopShell
/// 的 DetailPane。
///
/// Desktop 档（width ≥ tabletMax，对应 `DesktopShell`）才走 SelectionStore
/// 路径——只有这一档常驻三栏布局；mobile / tablet 仍然弹模态详情，与
/// 用户在小屏的预期一致。
void _openTaskDetail(BuildContext context, Task task, AppDatabase db) {
  final width = MediaQuery.sizeOf(context).width;
  if (layoutForWidth(width) == ShellLayout.desktop) {
    // 不持有 listen，避免任意一行被点都触发整页重建。
    final store = Provider.of<SelectionStore>(context, listen: false);
    store.selectTask(task.id);
    return;
  }
  showTaskDetailSheet(context: context, task: task, db: db);
}

class TaskRow extends StatefulWidget {
  final Task task;
  final AppDatabase db;
  final bool isWide;

  const TaskRow({
    super.key,
    required this.task,
    required this.db,
    this.isWide = false,
  });

  @override
  State<TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<TaskRow> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final db = widget.db;
    final isDone = task.status == 1;
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mutedTextColor = theme.colorScheme.onSurface.withOpacity(0.6);

    return StreamBuilder<List<Task>>(
      stream: db.watchSubtasks(task.id),
      builder: (context, snapshot) {
        final subtasks = snapshot.data ?? const <Task>[];
        final totalSubtasks = subtasks.length;
        final completedSubtasks =
            subtasks.where((subtask) => subtask.status == 1).length;
        final hasSubtasks = totalSubtasks > 0;
        final isExpanded = _isExpanded && hasSubtasks;

        return Column(
          children: [
            GestureDetector(
              onSecondaryTapUp: (details) {
                showMenu(
                  context: context,
                  position: RelativeRect.fromLTRB(
                    details.globalPosition.dx,
                    details.globalPosition.dy,
                    details.globalPosition.dx,
                    details.globalPosition.dy,
                  ),
                  items: [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: const [
                          Icon(Icons.delete_outline,
                              size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                      onTap: () {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          db.deleteTask(task.id);
                        });
                      },
                    ),
                    PopupMenuItem(
                      child: const Text('Priority'),
                      enabled: false,
                    ),
                    PopupMenuItem(
                      value: 'p3',
                      child: Row(
                        children: const [
                          Icon(Icons.flag, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('High'),
                        ],
                      ),
                      onTap: () {
                        (db.update(db.tasks)
                              ..where((t) => t.id.equals(task.id)))
                            .write(
                          TasksCompanion(priority: const drift.Value(3)),
                        );
                      },
                    ),
                    PopupMenuItem(
                      value: 'p2',
                      child: Row(
                        children: const [
                          Icon(Icons.flag, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text('Medium'),
                        ],
                      ),
                      onTap: () {
                        (db.update(db.tasks)
                              ..where((t) => t.id.equals(task.id)))
                            .write(
                          TasksCompanion(priority: const drift.Value(2)),
                        );
                      },
                    ),
                    PopupMenuItem(
                      value: 'p1',
                      child: Row(
                        children: const [
                          Icon(Icons.flag, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text('Low'),
                        ],
                      ),
                      onTap: () {
                        (db.update(db.tasks)
                              ..where((t) => t.id.equals(task.id)))
                            .write(
                          TasksCompanion(priority: const drift.Value(1)),
                        );
                      },
                    ),
                    PopupMenuItem(
                      value: 'p0',
                      child: Row(
                        children: const [
                          Icon(Icons.flag_outlined,
                              color: Colors.grey, size: 20),
                          SizedBox(width: 8),
                          Text('None'),
                        ],
                      ),
                      onTap: () {
                        (db.update(db.tasks)
                              ..where((t) => t.id.equals(task.id)))
                            .write(
                          TasksCompanion(priority: const drift.Value(0)),
                        );
                      },
                    ),
                  ],
                );
              },
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openTaskDetail(context, task, db),
                  hoverColor: theme.colorScheme.primary.withOpacity(0.05),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            db.toggleTaskStatus(task.id, !isDone);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 20,
                            height: 20,
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDone
                                    ? Colors.grey
                                    : _getPriorityColor(task.priority),
                                width: 2,
                              ),
                              color: isDone
                                  ? Colors.grey.withOpacity(0.15)
                                  : Colors.transparent,
                            ),
                            child: isDone
                                ? const Icon(Icons.check,
                                    size: 14, color: Colors.grey)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: (theme.textTheme.bodyMedium ??
                                        const TextStyle(fontSize: 15))
                                    .copyWith(
                                  fontWeight: FontWeight.w500,
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isDone
                                      ? mutedTextColor
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                              if (task.dueDate != null) ...[
                                const SizedBox(height: 2),
                                _buildDueDateChip(
                                  context,
                                  task.dueDate!,
                                  task.isAllDay,
                                  label: l.dueDate,
                                ),
                              ],
                              if (task.endDate != null) ...[
                                const SizedBox(height: 2),
                                _buildDueDateChip(
                                  context,
                                  task.endDate!,
                                  false,
                                  label: l.endDate,
                                  icon: Icons.flag_outlined,
                                ),
                              ],
                              if (hasRepeatRule(task.repeatRule)) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.repeat,
                                        size: 12, color: mutedTextColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      repeatRuleLabel(l, task.repeatRule),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: mutedTextColor),
                                    ),
                                  ],
                                ),
                              ],
                              StreamBuilder<List<Tag>>(
                                stream: db.watchTagsForTask(task.id),
                                builder: (context, snapshot) {
                                  final tags = snapshot.data ?? const <Tag>[];
                                  if (tags.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: -4,
                                      children: tags
                                          .map(
                                            (tag) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Color(tag.color)
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: Color(tag.color)
                                                      .withOpacity(0.3),
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: Text(
                                                tag.name,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: Color(tag.color)),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  );
                                },
                              ),
                              if (hasSubtasks) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.list_alt_outlined,
                                        size: 12, color: mutedTextColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${l.subtasks} ${l.subtaskProgress(completedSubtasks, totalSubtasks)}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: mutedTextColor),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (hasSubtasks)
                          IconButton(
                            icon: Icon(isExpanded
                                ? Icons.expand_less
                                : Icons.expand_more),
                            color: mutedTextColor,
                            onPressed: () {
                              setState(() {
                                _isExpanded = !isExpanded;
                              });
                            },
                          ),
                        if (widget.isWide) ...[
                          const SizedBox(width: 16),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (hasSubtasks && isExpanded) _buildSubtaskList(subtasks, db),
          ],
        );
      },
    );
  }

  Widget _buildDueDateChip(
    BuildContext context,
    DateTime dueDate,
    bool isAllDay, {
    bool isCompact = false,
    String? label,
    IconData icon = Icons.calendar_today,
  }) {
    final theme = Theme.of(context);
    final color = _getDueDateColor(dueDate);
    final padding = isCompact
        ? const EdgeInsets.symmetric(horizontal: 5, vertical: 1)
        : const EdgeInsets.symmetric(horizontal: 6, vertical: 2);
    final iconSize = isCompact ? 10.0 : 11.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 4),
          Text(
            label == null
                ? _formatDate(context, dueDate, isAllDay)
                : '$label ${_formatDate(context, dueDate, isAllDay)}',
            style: (theme.textTheme.bodySmall ?? const TextStyle(fontSize: 11))
                .copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtaskList(List<Task> subtasks, AppDatabase db) {
    return Column(
      children: [
        const Divider(height: 1, indent: 50),
        for (var i = 0; i < subtasks.length; i++) ...[
          _buildSubtaskRow(subtasks[i], db),
          if (i != subtasks.length - 1) const Divider(height: 1, indent: 72),
        ],
      ],
    );
  }

  Widget _buildSubtaskRow(Task subtask, AppDatabase db) {
    final isDone = subtask.status == 1;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _openTaskDetail(context, subtask, db),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(52, 4, 16, 4),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: isDone,
                onChanged: (value) {
                  db.toggleTaskStatus(subtask.id, value ?? false);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtask.title,
                    style: TextStyle(
                      fontSize: 13,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone
                          ? theme.colorScheme.onSurface.withOpacity(0.5)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (subtask.dueDate != null) ...[
                    const SizedBox(height: 2),
                    _buildDueDateChip(
                      context,
                      subtask.dueDate!,
                      subtask.isAllDay,
                      isCompact: true,
                      label: AppLocalizations.of(context).dueDate,
                    ),
                  ],
                  if (subtask.endDate != null) ...[
                    const SizedBox(height: 2),
                    _buildDueDateChip(
                      context,
                      subtask.endDate!,
                      false,
                      isCompact: true,
                      label: AppLocalizations.of(context).endDate,
                      icon: Icons.flag_outlined,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(int? priority) {
    switch (priority) {
      case 3:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 1:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getDueDateColor(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);

    if (taskDate.isBefore(today)) {
      return Colors.red;
    } else if (taskDate.isAtSameMomentAs(today)) {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }

  String _formatDate(BuildContext context, DateTime date, bool isAllDay) {
    final dateLabel = "${date.month}/${date.day}";
    final isDateOnly = date.hour == 0 &&
        date.minute == 0 &&
        date.second == 0 &&
        date.millisecond == 0 &&
        date.microsecond == 0;
    if (isAllDay || isDateOnly) {
      return dateLabel;
    }
    final timeLabel = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
    );
    return "$dateLabel $timeLabel";
  }
}
