import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../task_repeat.dart';

enum RepeatEditScope { thisTask, thisAndFuture, all }

Future<void> showTaskDetailSheet({
  required BuildContext context,
  required Task task,
  required AppDatabase db,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return TaskDetailSheet(task: task, db: db);
    },
  );
}

class TaskDetailSheet extends StatefulWidget {
  const TaskDetailSheet({
    super.key,
    required this.task,
    required this.db,
  });

  final Task task;
  final AppDatabase db;

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  late final TextEditingController _titleController;
  final TextEditingController _subtaskController = TextEditingController();
  final FocusNode _subtaskFocusNode = FocusNode();
  DateTime? _subtaskDueDate;
  bool _subtaskIsAllDay = true;
  TimeOfDay _subtaskLastTime = const TimeOfDay(hour: 17, minute: 0);
  DateTime? _dueDate;
  DateTime? _endDate;
  bool _isAllDay = false;
  bool _endIsAllDay = false;
  bool _allDayTouched = false;
  TimeOfDay _lastDueTime = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _lastEndTime = const TimeOfDay(hour: 17, minute: 0);
  int _priority = 0;
  String? _projectId;
  String? _repeatRule;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _dueDate = widget.task.dueDate;
    _endDate = widget.task.endDate;
    _isAllDay =
        widget.task.isAllDay || (_dueDate != null && _isDateOnly(_dueDate!));
    _endIsAllDay = _endDate != null && _isDateOnly(_endDate!);
    if (_dueDate != null) {
      _lastDueTime = TimeOfDay.fromDateTime(_dueDate!);
      if (_isAllDay) {
        _lastDueTime = const TimeOfDay(hour: 17, minute: 0);
      }
    }
    if (_endDate != null) {
      _lastEndTime = TimeOfDay.fromDateTime(_endDate!);
      if (_endIsAllDay) {
        _lastEndTime = const TimeOfDay(hour: 17, minute: 0);
      }
    }
    _priority = widget.task.priority;
    _projectId = widget.task.projectId;
    _repeatRule = widget.task.repeatRule;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtaskController.dispose();
    _subtaskFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final initial = _dueDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (_dueDate == null) {
          _isAllDay = true;
          _allDayTouched = true;
          _dueDate = DateTime(picked.year, picked.month, picked.day);
          return;
        }
        final hour = _isAllDay ? 0 : _dueDate!.hour;
        final minute = _isAllDay ? 0 : _dueDate!.minute;
        _dueDate =
            DateTime(picked.year, picked.month, picked.day, hour, minute);
      });
    }
  }

  Future<void> _pickDueTime() async {
    if (_dueDate == null) return;
    final initial = TimeOfDay.fromDateTime(_dueDate!);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        _isAllDay = false;
        _allDayTouched = true;
        _lastDueTime = picked;
        _dueDate = DateTime(
          _dueDate!.year,
          _dueDate!.month,
          _dueDate!.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _toggleAllDay(bool value) {
    if (_dueDate == null) return;
    setState(() {
      _isAllDay = value;
      _allDayTouched = true;
      if (value) {
        _lastDueTime = TimeOfDay.fromDateTime(_dueDate!);
        _dueDate = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);
      } else {
        _dueDate = DateTime(
          _dueDate!.year,
          _dueDate!.month,
          _dueDate!.day,
          _lastDueTime.hour,
          _lastDueTime.minute,
        );
      }
    });
  }

  Future<void> _pickEndDate() async {
    final initial = _endDate ?? _dueDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (_endDate == null) {
          _endIsAllDay = true;
          _endDate = DateTime(picked.year, picked.month, picked.day);
          return;
        }
        final hour = _endIsAllDay ? 0 : _endDate!.hour;
        final minute = _endIsAllDay ? 0 : _endDate!.minute;
        _endDate =
            DateTime(picked.year, picked.month, picked.day, hour, minute);
      });
    }
  }

  Future<void> _pickEndTime() async {
    if (_endDate == null) return;
    final initial = TimeOfDay.fromDateTime(_endDate!);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        _endIsAllDay = false;
        _lastEndTime = picked;
        _endDate = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _toggleEndAllDay(bool value) {
    if (_endDate == null) return;
    setState(() {
      _endIsAllDay = value;
      if (value) {
        _lastEndTime = TimeOfDay.fromDateTime(_endDate!);
        _endDate = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      } else {
        _endDate = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          _lastEndTime.hour,
          _lastEndTime.minute,
        );
      }
    });
  }

  bool _isDateOnly(DateTime date) {
    return date.hour == 0 &&
        date.minute == 0 &&
        date.second == 0 &&
        date.millisecond == 0 &&
        date.microsecond == 0;
  }

  String _formatSubtaskDueDate(DateTime date, bool isAllDay) {
    final dateLabel = "${date.month}/${date.day}";
    final dateOnly = _isDateOnly(date);
    if (isAllDay || dateOnly) {
      return dateLabel;
    }
    final timeLabel = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
    );
    return "$dateLabel $timeLabel";
  }

  Future<void> _pickSubtaskDueDate() async {
    final initial = _subtaskDueDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      final hour = _subtaskIsAllDay ? 0 : _subtaskLastTime.hour;
      final minute = _subtaskIsAllDay ? 0 : _subtaskLastTime.minute;
      _subtaskDueDate =
          DateTime(picked.year, picked.month, picked.day, hour, minute);
    });
  }

  Future<void> _pickSubtaskDueTime() async {
    final dueDate = _subtaskDueDate;
    if (dueDate == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(dueDate),
    );
    if (picked == null) return;
    setState(() {
      _subtaskIsAllDay = false;
      _subtaskLastTime = picked;
      _subtaskDueDate = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _clearSubtaskDueDate() {
    setState(() {
      _subtaskDueDate = null;
      _subtaskIsAllDay = true;
    });
  }

  Future<void> _addSubtask() async {
    final title = _subtaskController.text.trim();
    if (title.isEmpty) return;
    final now = DateTime.now();
    final parentTags = await widget.db.getTagIdsForTask(widget.task.id);
    final subtaskId = const Uuid().v4();
    await widget.db.insertTask(
      TasksCompanion(
        id: drift.Value(subtaskId),
        title: drift.Value(title),
        status: const drift.Value(0),
        parentId: drift.Value(widget.task.id),
        projectId: drift.Value(widget.task.projectId),
        dueDate: drift.Value(_subtaskDueDate),
        isAllDay: drift.Value(_subtaskDueDate != null && _subtaskIsAllDay),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    if (parentTags.isNotEmpty) {
      await widget.db.setTagsForTask(subtaskId, parentTags);
    }
    _subtaskController.clear();
    _clearSubtaskDueDate();
    _subtaskFocusNode.requestFocus();
  }

  Widget _buildSubtaskSection(AppLocalizations l) {
    return StreamBuilder<List<Task>>(
      stream: widget.db.watchSubtasks(widget.task.id),
      builder: (context, snapshot) {
        final subtasks = snapshot.data ?? const <Task>[];
        final total = subtasks.length;
        final done = subtasks.where((task) => task.status == 1).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.subtasks,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (total > 0)
                  Text(
                    l.subtaskProgress(done, total),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.blue),
                        onPressed: _addSubtask,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _subtaskController,
                          focusNode: _subtaskFocusNode,
                          decoration: InputDecoration(
                            hintText: l.addSubtask,
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addSubtask(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.event_outlined),
                        tooltip: l.dueDate,
                        onPressed: _pickSubtaskDueDate,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      if (_subtaskDueDate != null)
                        IconButton(
                          icon: const Icon(Icons.access_time),
                          tooltip: l.dueTime,
                          onPressed: _pickSubtaskDueTime,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                    ],
                  ),
                  if (_subtaskDueDate != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InputChip(
                        label: Text(
                          _formatSubtaskDueDate(
                            _subtaskDueDate!,
                            _subtaskIsAllDay,
                          ),
                        ),
                        onDeleted: _clearSubtaskDueDate,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (subtasks.isEmpty)
              Text(
                l.subtasksEmpty,
                style: TextStyle(color: Colors.grey[500]),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subtasks.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 50),
                itemBuilder: (context, index) {
                  final subtask = subtasks[index];
                  final isDone = subtask.status == 1;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => showTaskDetailSheet(
                      context: context,
                      task: subtask,
                      db: widget.db,
                    ),
                    leading: Checkbox(
                      value: isDone,
                      onChanged: (value) {
                        widget.db.toggleTaskStatus(subtask.id, value ?? false);
                      },
                    ),
                    title: Text(
                      subtask.title,
                      style: TextStyle(
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? Colors.grey : Colors.black87,
                      ),
                    ),
                    subtitle: subtask.dueDate == null
                        ? null
                        : Text(
                            _formatSubtaskDueDate(
                                subtask.dueDate!, subtask.isAllDay),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: l.edit,
                          onPressed: () => showTaskDetailSheet(
                            context: context,
                            task: subtask,
                            db: widget.db,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: l.delete,
                          onPressed: () => widget.db.deleteTask(subtask.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildParentTaskSection(AppLocalizations l) {
    final parentId = widget.task.parentId;
    if (parentId == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return StreamBuilder<Task?>(
      stream: (widget.db.select(widget.db.tasks)
            ..where((t) => t.id.equals(parentId)))
          .watchSingleOrNull(),
      builder: (context, snapshot) {
        final parentTask = snapshot.data;
        final title = parentTask?.title ?? l.parentTaskMissing;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.parentTask,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.subdirectory_arrow_right,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.subtaskNoNested,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickRepeatRule() async {
    final l = AppLocalizations.of(context);
    const noneValue = 'none';
    final selection = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        final options = [
          _RepeatOption(value: noneValue, label: l.repeatNone),
          _RepeatOption(value: repeatRuleDaily, label: l.repeatDaily),
          _RepeatOption(value: repeatRuleWeekly, label: l.repeatWeekly),
          _RepeatOption(value: repeatRuleMonthly, label: l.repeatMonthly),
          _RepeatOption(value: repeatRuleYearly, label: l.repeatYearly),
          _RepeatOption(value: repeatRuleCustom, label: l.repeatCustom),
        ];
        final current = _repeatRule ?? noneValue;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.repeat,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              ...options.map((option) {
                final selected = option.value == current;
                return ListTile(
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  title: Text(option.label),
                  onTap: () => Navigator.of(context).pop(option.value),
                );
              }),
            ],
          ),
        );
      },
    );

    if (selection == null) return;
    setState(() {
      _repeatRule = selection == noneValue ? null : selection;
    });
  }

  Future<RepeatEditScope?> _pickRepeatEditScope() async {
    final l = AppLocalizations.of(context);
    return showModalBottomSheet<RepeatEditScope>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.repeatEditScopeTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.looks_one_outlined),
                title: Text(l.repeatEditScopeThis),
                onTap: () =>
                    Navigator.of(context).pop(RepeatEditScope.thisTask),
              ),
              ListTile(
                leading: const Icon(Icons.looks_two_outlined),
                title: Text(l.repeatEditScopeThisAndFuture),
                onTap: () =>
                    Navigator.of(context).pop(RepeatEditScope.thisAndFuture),
              ),
              ListTile(
                leading: const Icon(Icons.all_inclusive),
                title: Text(l.repeatEditScopeAll),
                onTap: () => Navigator.of(context).pop(RepeatEditScope.all),
              ),
            ],
          ),
        );
      },
    );
  }

  String _repeatScopeAppliedLabel(AppLocalizations l, RepeatEditScope scope) {
    switch (scope) {
      case RepeatEditScope.thisTask:
        return l.repeatScopeAppliedThis;
      case RepeatEditScope.thisAndFuture:
        return l.repeatScopeAppliedThisAndFuture;
      case RepeatEditScope.all:
        return l.repeatScopeAppliedAll;
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.titleRequired)),
      );
      return;
    }

    final effectiveIsAllDay = _allDayTouched ? _isAllDay : widget.task.isAllDay;
    final hasChanges = title != widget.task.title ||
        _dueDate != widget.task.dueDate ||
        _endDate != widget.task.endDate ||
        effectiveIsAllDay != widget.task.isAllDay ||
        _priority != widget.task.priority ||
        _projectId != widget.task.projectId ||
        _repeatRule != widget.task.repeatRule;

    RepeatEditScope? scope;
    if (hasRepeatRule(widget.task.repeatRule) && hasChanges) {
      scope = await _pickRepeatEditScope();
      if (scope == null) {
        return;
      }
    }

    await (widget.db.update(widget.db.tasks)
          ..where((t) => t.id.equals(widget.task.id)))
        .write(
      TasksCompanion(
        title: drift.Value(title),
        dueDate: drift.Value(_dueDate),
        endDate: drift.Value(_endDate),
        isAllDay: drift.Value(effectiveIsAllDay),
        priority: drift.Value(_priority),
        projectId: drift.Value(_projectId),
        repeatRule: drift.Value(_repeatRule),
        isDirty: const drift.Value(true),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );

    if (!mounted) return;
    if (scope != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_repeatScopeAppliedLabel(l, scope))),
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await widget.db.deleteTask(widget.task.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _editTags() async {
    final l = AppLocalizations.of(context);
    final tags = await widget.db.select(widget.db.tags).get();
    final working = await widget.db.getTagIdsForTask(widget.task.id);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.selectTags,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (tags.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          l.tagListEmpty,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tags.map((tag) {
                          final selected = working.contains(tag.id);
                          return FilterChip(
                            label: Text(tag.name),
                            selected: selected,
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  working.add(tag.id);
                                } else {
                                  working.remove(tag.id);
                                }
                              });
                            },
                            selectedColor: Color(tag.color).withOpacity(0.2),
                            checkmarkColor: Color(tag.color),
                            avatar: CircleAvatar(
                              radius: 6,
                              backgroundColor: Color(tag.color),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l.cancel),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await widget.db
                                .setTagsForTask(widget.task.id, working);
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          },
                          child: Text(l.save),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: constraints.maxHeight,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l.taskDetails,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: l.taskTitle,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _priority,
                          decoration: InputDecoration(labelText: l.priority),
                          items: [
                            DropdownMenuItem(
                              value: 0,
                              child: Text(l.priorityNone),
                            ),
                            DropdownMenuItem(
                              value: 1,
                              child: Text(l.priorityLow),
                            ),
                            DropdownMenuItem(
                              value: 2,
                              child: Text(l.priorityMedium),
                            ),
                            DropdownMenuItem(
                              value: 3,
                              child: Text(l.priorityHigh),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _priority = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<List<Project>>(
                          stream: widget.db.watchProjects(),
                          builder: (context, snapshot) {
                            final projects = snapshot.data ?? const <Project>[];
                            final hasProject = _projectId != null &&
                                projects
                                    .any((project) => project.id == _projectId);

                            final projectItems = [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(l.inbox),
                              ),
                              ...projects.map(
                                (project) => DropdownMenuItem<String?>(
                                  value: project.id,
                                  child: Text(project.name),
                                ),
                              ),
                              if (_projectId != null && !hasProject)
                                DropdownMenuItem<String?>(
                                  value: _projectId,
                                  child: Text(l.unknownProject),
                                ),
                            ];

                            return DropdownButtonFormField<String?>(
                              value: _projectId,
                              decoration: InputDecoration(labelText: l.project),
                              items: projectItems,
                              onChanged: (value) {
                                setState(() {
                                  _projectId = value;
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l.tags,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            TextButton(
                              onPressed: _editTags,
                              child: Text(l.editTags),
                            ),
                          ],
                        ),
                        StreamBuilder<List<Tag>>(
                          stream: widget.db.watchTagsForTask(widget.task.id),
                          builder: (context, snapshot) {
                            final tags = snapshot.data ?? const <Tag>[];
                            if (tags.isEmpty) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  l.noTags,
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              );
                            }
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: tags
                                  .map(
                                    (tag) => Chip(
                                      label: Text(tag.name),
                                      avatar: CircleAvatar(
                                        radius: 6,
                                        backgroundColor: Color(tag.color),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        if (widget.task.parentId == null) ...[
                          _buildSubtaskSection(l),
                          const SizedBox(height: 12),
                        ] else ...[
                          _buildParentTaskSection(l),
                          const SizedBox(height: 12),
                        ],
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_today_outlined),
                          title: Text(l.dueDate),
                          subtitle: Text(
                            _dueDate == null
                                ? l.noDueDate
                                : _isAllDay || _isDateOnly(_dueDate!)
                                    ? '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'
                                    : '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_dueDate!))}',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              if (_dueDate != null)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _dueDate = null;
                                      _isAllDay = false;
                                      _allDayTouched = true;
                                    });
                                  },
                                  child: Text(l.clear),
                                ),
                              TextButton(
                                onPressed: _pickDueDate,
                                child: Text(l.edit),
                              ),
                            ],
                          ),
                        ),
                        if (_dueDate != null) ...[
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary:
                                const Icon(Icons.event_available_outlined),
                            title: Text(l.allDay),
                            value: _isAllDay,
                            onChanged: _toggleAllDay,
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.schedule_outlined),
                            title: Text(l.dueTime),
                            subtitle: Text(
                              _isAllDay
                                  ? l.allDay
                                  : MaterialLocalizations.of(context)
                                      .formatTimeOfDay(
                                      TimeOfDay.fromDateTime(_dueDate!),
                                    ),
                            ),
                            enabled: !_isAllDay,
                            onTap: _isAllDay ? null : _pickDueTime,
                          ),
                        ],
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.flag_outlined),
                          title: Text(l.endDate),
                          subtitle: Text(
                            _endDate == null
                                ? l.noEndDate
                                : _endIsAllDay || _isDateOnly(_endDate!)
                                    ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
                                    : '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_endDate!))}',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              if (_endDate != null)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _endDate = null;
                                      _endIsAllDay = false;
                                    });
                                  },
                                  child: Text(l.clear),
                                ),
                              TextButton(
                                onPressed: _pickEndDate,
                                child: Text(l.edit),
                              ),
                            ],
                          ),
                        ),
                        if (_endDate != null) ...[
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary:
                                const Icon(Icons.event_available_outlined),
                            title: Text(l.allDay),
                            value: _endIsAllDay,
                            onChanged: _toggleEndAllDay,
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.schedule_outlined),
                            title: Text(l.endTime),
                            subtitle: Text(
                              _endIsAllDay
                                  ? l.allDay
                                  : MaterialLocalizations.of(context)
                                      .formatTimeOfDay(
                                      TimeOfDay.fromDateTime(_endDate!),
                                    ),
                            ),
                            enabled: !_endIsAllDay,
                            onTap: _endIsAllDay ? null : _pickEndTime,
                          ),
                        ],
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.repeat),
                          title: Text(l.repeat),
                          subtitle: Text(repeatRuleLabel(l, _repeatRule)),
                          trailing: TextButton(
                            onPressed: _pickRepeatRule,
                            child: Text(l.edit),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                AnimatedPadding(
                  duration: kThemeAnimationDuration,
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomInset),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _delete,
                        child: Text(l.delete),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l.cancel),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _save,
                        child: Text(l.save),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RepeatOption {
  const _RepeatOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}
