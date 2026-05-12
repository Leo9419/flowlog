import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../database/database.dart';
import 'action_log_service.dart';
import 'trust_policy.dart';

class AiToolContext {
  const AiToolContext({
    required this.origin,
    this.conversationId,
  });

  final AiActionOrigin origin;
  final String? conversationId;
}

class AiToolResult {
  const AiToolResult({
    required this.ok,
    this.message,
    this.data = const <String, dynamic>{},
  });

  final bool ok;
  final String? message;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
        'ok': ok,
        if (message != null) 'message': message,
        'data': data,
      };
}

typedef AiToolExecutor = Future<AiToolResult> Function(
  Map<String, dynamic> params,
  AiToolContext context,
);

class AiToolDefinition {
  const AiToolDefinition({
    required this.name,
    required this.paramsSchema,
    required this.trustLevel,
    required this.execute,
  });

  final String name;
  final Map<String, dynamic> paramsSchema;
  final AiTrustLevel trustLevel;
  final AiToolExecutor execute;
}

class AiToolRegistry {
  AiToolRegistry(this._db) {
    _registerPhase1Tools();
  }

  final AppDatabase _db;
  final Map<String, AiToolDefinition> _tools = {};

  List<String> get toolNames => _tools.keys.toList(growable: false)..sort();

  AiToolDefinition require(String name) {
    final tool = _tools[name];
    if (tool == null) {
      throw ArgumentError.value(name, 'name', 'Unknown AI tool');
    }
    return tool;
  }

  void _register(AiToolDefinition tool) {
    _tools[tool.name] = tool;
  }

  void _registerPhase1Tools() {
    _register(_readTool('search_tasks', _searchTasks));
    _register(_readTool('get_view_tasks', _getViewTasks));
    _register(_readTool('get_today_summary', _getTodaySummary));
    _register(_readTool('get_overdue', _getOverdue));
    _register(_readTool('get_completed_in_range', _getCompletedInRange));
    _register(_writeTool('set_when', AiTrustLevel.low, _setWhen));
    _register(_writeTool('set_tags', AiTrustLevel.low, _setTags));
    _register(_writeTool('set_priority', AiTrustLevel.low, _setPriority));
    _register(_writeTool('complete', AiTrustLevel.low, _complete));
    _register(_writeTool('create_task', AiTrustLevel.medium, _createTask));
    _register(
        _writeTool('move_to_project', AiTrustLevel.medium, _moveToProject));
    _register(_writeTool('set_deadline', AiTrustLevel.medium, _setDeadline));
    _register(_writeTool('set_reminder', AiTrustLevel.medium, _setReminder));
    _register(_writeTool('delete', AiTrustLevel.high, _delete));
    _register(_writeTool('bulk_update', AiTrustLevel.high, _bulkUpdate));
  }

  AiToolDefinition _readTool(String name, AiToolExecutor execute) {
    return AiToolDefinition(
      name: name,
      paramsSchema: const {'type': 'object'},
      trustLevel: AiTrustLevel.low,
      execute: execute,
    );
  }

  AiToolDefinition _writeTool(
    String name,
    AiTrustLevel trustLevel,
    AiToolExecutor execute,
  ) {
    return AiToolDefinition(
      name: name,
      paramsSchema: const {'type': 'object'},
      trustLevel: trustLevel,
      execute: execute,
    );
  }

  Future<AiToolResult> _searchTasks(
    Map<String, dynamic> params,
    AiToolContext context,
  ) async {
    final query = (params['query'] as String? ?? '').trim();
    final limit = _intParam(params, 'limit') ?? 20;
    final rows = await _db.searchTasksForChat(query, limit: limit);
    return AiToolResult(ok: true, data: {'tasks': _tasksJson(rows)});
  }

  Future<AiToolResult> _getViewTasks(
    Map<String, dynamic> params,
    AiToolContext context,
  ) async {
    final view = (params['view'] as String? ?? 'all').trim();
    final rows = await _db.fetchTasksForSummary();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final filtered = rows.where((task) {
      switch (view) {
        case 'today':
          final due = task.dueDate;
          return task.status == 0 &&
              (task.whenType == WhenType.today.value ||
                  task.whenType == WhenType.thisEvening.value ||
                  (due != null &&
                      !due.isBefore(today) &&
                      due.isBefore(tomorrow)));
        case 'inbox':
          return task.status == 0 &&
              task.projectId == null &&
              task.dueDate == null;
        case 'overdue':
          final due = task.deadline ?? task.dueDate;
          return task.status == 0 && due != null && due.isBefore(today);
        default:
          return true;
      }
    }).toList();
    return AiToolResult(ok: true, data: {'tasks': _tasksJson(filtered)});
  }

  Future<AiToolResult> _getTodaySummary(
    Map<String, dynamic> params,
    AiToolContext context,
  ) async {
    final tasks = await _db.fetchTasksForSummary();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final todayTasks = tasks.where((task) {
      final due = task.dueDate;
      return task.status == 0 &&
          (task.whenType == WhenType.today.value ||
              task.whenType == WhenType.thisEvening.value ||
              (due != null && !due.isBefore(today) && due.isBefore(tomorrow)));
    }).toList();
    final overdue = tasks.where((task) {
      final due = task.deadline ?? task.dueDate;
      return task.status == 0 && due != null && due.isBefore(today);
    }).length;
    return AiToolResult(
      ok: true,
      data: {'today_count': todayTasks.length, 'overdue_count': overdue},
    );
  }

  Future<AiToolResult> _getOverdue(
    Map<String, dynamic> params,
    AiToolContext context,
  ) async {
    final tasks = await _db.fetchTasksForSummary();
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final rows = tasks.where((task) {
      final due = task.deadline ?? task.dueDate;
      return task.status == 0 && due != null && due.isBefore(start);
    }).toList();
    return AiToolResult(ok: true, data: {'tasks': _tasksJson(rows)});
  }

  Future<AiToolResult> _getCompletedInRange(
    Map<String, dynamic> params,
    AiToolContext context,
  ) async {
    final start = _dateParam(params, 'start');
    final end = _dateParam(params, 'end');
    if (start == null || end == null) {
      return const AiToolResult(ok: false, message: 'start and end required');
    }
    final tasks = await _db.fetchTasksForSummary();
    final rows = tasks.where((task) {
      final completedAt = task.completedAt ?? task.updatedAt;
      return task.status == 1 &&
          !completedAt.isBefore(start) &&
          completedAt.isBefore(end);
    }).toList();
    return AiToolResult(ok: true, data: {'tasks': _tasksJson(rows)});
  }

  Future<AiToolResult> _setWhen(
    Map<String, dynamic> params,
    AiToolContext context,
  ) async {
    final taskId = params['task_id'] as String?;
    final when = _whenType(params['when_type'] as String?);
    if (taskId == null || when == null) {
      return const AiToolResult(
          ok: false, message: 'task_id and when_type required');
    }
    await _db.setTaskWhen(taskId, when, date: _dateParam(params, 'due_date'));
    return const AiToolResult(ok: true);
  }

  Future<AiToolResult> _setTags(
    Map<String, dynamic> params,
    AiToolContext context,
  ) async {
    final taskId = params['task_id'] as String?;
    final tagIds = (params['tag_ids'] as List?)?.whereType<String>().toSet();
    if (taskId == null || tagIds == null) {
      return const AiToolResult(
          ok: false, message: 'task_id and tag_ids required');
    }
    await _db.setTagsForTask(taskId, tagIds);
    return const AiToolResult(ok: true);
  }

  Future<AiToolResult> _setPriority(
    Map<String, dynamic> params,
    AiToolContext context,
  ) async {
    final taskId = params['task_id'] as String?;
    final priority = _intParam(params, 'priority');
    if (taskId == null || priority == null) {
      return const AiToolResult(
          ok: false, message: 'task_id and priority required');
    }
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        priority: Value(priority),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return const AiToolResult(ok: true);
  }

  Future<AiToolResult> _complete(
    Map<String, dynamic> params,
    AiToolContext context,
  ) async {
    final taskId = params['task_id'] as String?;
    if (taskId == null) {
      return const AiToolResult(ok: false, message: 'task_id required');
    }
    await _db.toggleTaskStatus(taskId, true);
    return const AiToolResult(ok: true);
  }

  Future<AiToolResult> _createTask(
    Map<String, dynamic> params,
    AiToolContext context,
  ) async {
    final title = (params['title'] as String?)?.trim();
    if (title == null || title.isEmpty) {
      return const AiToolResult(ok: false, message: 'title required');
    }
    final id = params['id'] as String? ?? const Uuid().v4();
    final now = DateTime.now();
    await _db.insertTask(
      TasksCompanion.insert(
        id: id,
        title: title,
        notes: Value(params['notes'] as String? ?? ''),
        priority: Value(_intParam(params, 'priority') ?? 0),
        projectId: Value(params['project_id'] as String?),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    return AiToolResult(ok: true, data: {'task_id': id});
  }

  Future<AiToolResult> _moveToProject(
    Map<String, dynamic> params,
    AiToolContext context,
  ) async {
    final taskId = params['task_id'] as String?;
    if (taskId == null) {
      return const AiToolResult(ok: false, message: 'task_id required');
    }
    await _db.moveTaskToProject(taskId, params['project_id'] as String?);
    return const AiToolResult(ok: true);
  }

  Future<AiToolResult> _setDeadline(
    Map<String, dynamic> params,
    AiToolContext context,
  ) async {
    final taskId = params['task_id'] as String?;
    if (taskId == null) {
      return const AiToolResult(ok: false, message: 'task_id required');
    }
    await _db.setTaskDeadline(taskId, _dateParam(params, 'deadline'));
    return const AiToolResult(ok: true);
  }

  Future<AiToolResult> _setReminder(
    Map<String, dynamic> params,
    AiToolContext context,
  ) async {
    final taskId = params['task_id'] as String?;
    if (taskId == null) {
      return const AiToolResult(ok: false, message: 'task_id required');
    }
    await _db.setTaskReminder(taskId, _dateParam(params, 'reminder_at'));
    return const AiToolResult(ok: true);
  }

  Future<AiToolResult> _delete(
    Map<String, dynamic> params,
    AiToolContext context,
  ) async {
    final taskId = params['task_id'] as String?;
    if (taskId == null) {
      return const AiToolResult(ok: false, message: 'task_id required');
    }
    await _db.deleteTask(taskId);
    return const AiToolResult(ok: true);
  }

  Future<AiToolResult> _bulkUpdate(
    Map<String, dynamic> params,
    AiToolContext context,
  ) async {
    final taskIds = (params['task_ids'] as List?)?.whereType<String>().toList();
    final changes = params['changes'];
    if (taskIds == null || changes is! Map<String, dynamic>) {
      return const AiToolResult(
        ok: false,
        message: 'task_ids and changes required',
      );
    }
    for (final taskId in taskIds) {
      if (changes.containsKey('when_type')) {
        final when = _whenType(changes['when_type'] as String?);
        if (when != null) {
          await _db.setTaskWhen(taskId, when,
              date: _dateParam(changes, 'due_date'));
        }
      }
      if (changes.containsKey('priority')) {
        await _setPriority(
            {'task_id': taskId, 'priority': changes['priority']}, context);
      }
    }
    return AiToolResult(ok: true, data: {'updated': taskIds.length});
  }

  List<Map<String, dynamic>> _tasksJson(Iterable<Task> tasks) {
    return tasks
        .map(
          (task) => {
            'id': task.id,
            'title': task.title,
            'when_type': task.whenType,
            'due_date': task.dueDate?.toIso8601String(),
            'deadline': task.deadline?.toIso8601String(),
            'priority': task.priority,
            'project_id': task.projectId,
            'status': task.status,
            'completed_at': task.completedAt?.toIso8601String(),
          },
        )
        .toList(growable: false);
  }

  int? _intParam(Map<String, dynamic> params, String key) {
    final value = params[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  DateTime? _dateParam(Map<String, dynamic> params, String key) {
    final value = params[key];
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  WhenType? _whenType(String? value) {
    switch (value) {
      case 'none':
      case 'inbox':
        return WhenType.none;
      case 'today':
        return WhenType.today;
      case 'this_evening':
      case 'evening':
        return WhenType.thisEvening;
      case 'someday':
        return WhenType.someday;
      case 'scheduled':
      case 'upcoming':
        return WhenType.scheduled;
      default:
        return null;
    }
  }
}

String encodeToolResult(AiToolResult result) => jsonEncode(result.toJson());
