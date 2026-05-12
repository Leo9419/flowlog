import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ai_cloud_service.dart';
import '../../services/ai_local_service.dart';
import '../../state/app_settings.dart';

class WeeklyReportPage extends StatefulWidget {
  const WeeklyReportPage({super.key});

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  DateTime? _weekStart;
  bool _loading = false;
  String? _summary;
  String? _errorMessage;
  String? _errorDetails;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _weekStart ??= _startOfWeek(
      DateTime.now(),
      MaterialLocalizations.of(context).firstDayOfWeekIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.aiWeeklyReport),
      ),
      body: StreamBuilder<List<Task>>(
        stream: db.watchAllTasks(),
        builder: (context, taskSnapshot) {
          if (taskSnapshot.hasError) {
            return Center(child: Text('Error: ${taskSnapshot.error}'));
          }
          if (!taskSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = taskSnapshot.data ?? const <Task>[];
          return StreamBuilder<List<Project>>(
            stream: db.watchProjects(),
            builder: (context, projectSnapshot) {
              final projects = projectSnapshot.data ?? const <Project>[];
              return _buildContent(
                context,
                tasks: tasks,
                projects: projects,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required List<Task> tasks,
    required List<Project> projects,
  }) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final weekStart = _weekStart;
    if (weekStart == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final weekEnd = weekStart.add(const Duration(days: 7));
    final projectNames = {
      for (final project in projects) project.id: project.name,
    };

    final completedTasks = tasks
        .where((task) => _isCompletedInRange(task, weekStart, weekEnd))
        .toList();
    final createdTasks = tasks
        .where((task) => _isInRange(task.createdAt, weekStart, weekEnd))
        .toList();
    final dueTasks = tasks.where((task) {
      final date = task.endDate ?? task.dueDate;
      return date != null && _isInRange(date, weekStart, weekEnd);
    }).toList();

    final countsEmpty =
        completedTasks.isEmpty && createdTasks.isEmpty && dueTasks.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _WeekHeader(
          title: _formatWeekRange(weekStart, weekEnd),
          subtitle: l.aiWeeklyReportThisWeek,
          onPrevious: () => _shiftWeek(-1),
          onNext: () => _shiftWeek(1),
          onToday: _jumpToThisWeek,
        ),
        const SizedBox(height: 16),
        Text(l.aiWeeklyReportHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: l.completed,
                count: completedTasks.length,
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: l.created,
                count: createdTasks.length,
                icon: Icons.add_circle_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: l.dueThisWeek,
                count: dueTasks.length,
                icon: Icons.schedule_outlined,
              ),
            ),
          ],
        ),
        if (countsEmpty) ...[
          const SizedBox(height: 12),
          Text(
            l.aiWeeklyReportNoTasks,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading
                ? null
                : () => _generateSummary(
                      tasks: tasks,
                      projectNames: projectNames,
                      weekStart: weekStart,
                      weekEnd: weekEnd,
                    ),
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(
              _loading
                  ? l.aiWeeklyReportLoading
                  : (_summary == null
                      ? l.aiWeeklyReportGenerate
                      : l.aiWeeklyReportRegenerate),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          _ErrorCard(
            message: _errorMessage!,
            details: _errorDetails,
            onCopy: _errorDetails == null
                ? null
                : () => _showCopyableErrorDialog(_errorDetails!),
          ),
        ],
        if (_summary != null) ...[
          const SizedBox(height: 16),
          Text(l.aiWeeklyReportSummaryTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200] ?? theme.dividerColor),
            ),
            child: SelectableText(
              _summary!,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _summary == null ? null : _copySummary,
            icon: const Icon(Icons.copy_outlined),
            label: Text(l.copy),
          ),
        ],
      ],
    );
  }

  Future<void> _generateSummary({
    required List<Task> tasks,
    required Map<String, String> projectNames,
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _errorDetails = null;
    });

    final l = AppLocalizations.of(context);
    final payload = _buildSummaryPayload(
      tasks: tasks,
      projectNames: projectNames,
      weekStart: weekStart,
      weekEnd: weekEnd,
      locale: l.locale,
    );
    final prompt = _buildSummaryPrompt(payload);
    final settings = Provider.of<AppSettings>(context, listen: false);
    Future<String> Function() request;
    String missingConfigMessage;
    if (settings.aiProvider == AiProviderType.cloud) {
      if (settings.aiCloudEndpoint.trim().isEmpty ||
          settings.aiCloudApiKey.trim().isEmpty ||
          settings.aiCloudModel.trim().isEmpty) {
        setState(() {
          _errorMessage = l.aiCloudConfigMissing;
          _errorDetails = null;
          _loading = false;
        });
        return;
      }
      final aiService = Provider.of<AiCloudService>(context, listen: false);
      request = () => aiService.generateSummary(prompt: prompt);
      missingConfigMessage = l.aiCloudConfigMissing;
    } else {
      if (settings.aiLocalEndpoint.trim().isEmpty ||
          settings.aiLocalModel.trim().isEmpty) {
        setState(() {
          _errorMessage = l.aiLocalConfigMissing;
          _errorDetails = null;
          _loading = false;
        });
        return;
      }
      final aiService = Provider.of<AiLocalService>(context, listen: false);
      request = () => aiService.generateSummary(prompt: prompt);
      missingConfigMessage = l.aiLocalConfigMissing;
    }

    try {
      final summary = await request();
      if (!mounted) return;
      setState(() {
        _summary = summary;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      final message = error.message == 'missing_config'
          ? missingConfigMessage
          : l.aiWeeklyReportFailed;
      setState(() {
        _errorMessage = message;
        _errorDetails = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = l.aiWeeklyReportFailed;
        _errorDetails = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Map<String, dynamic> _buildSummaryPayload({
    required List<Task> tasks,
    required Map<String, String> projectNames,
    required DateTime weekStart,
    required DateTime weekEnd,
    required Locale locale,
  }) {
    final completedTasks = tasks
        .where((task) => _isCompletedInRange(task, weekStart, weekEnd))
        .toList();
    final createdTasks = tasks
        .where((task) => _isInRange(task.createdAt, weekStart, weekEnd))
        .toList();
    final dueTasks = tasks.where((task) {
      final date = task.endDate ?? task.dueDate;
      return date != null && _isInRange(date, weekStart, weekEnd);
    }).toList();

    return {
      'language': locale.languageCode,
      'timezone_offset': DateTime.now().timeZoneOffset.inMinutes,
      'week_start': weekStart.toIso8601String(),
      'week_end': weekEnd.toIso8601String(),
      'counts': {
        'completed': completedTasks.length,
        'created': createdTasks.length,
        'due': dueTasks.length,
      },
      'completed_tasks': _mapTasks(completedTasks, projectNames),
      'created_tasks': _mapTasks(createdTasks, projectNames),
      'due_tasks': _mapTasks(dueTasks, projectNames),
    };
  }

  List<Map<String, dynamic>> _mapTasks(
    List<Task> tasks,
    Map<String, String> projectNames,
  ) {
    return tasks.map((task) {
      return {
        'id': task.id,
        'title': task.title,
        'project': _projectName(task, projectNames),
        'priority': task.priority,
        'status': task.status,
        'created_at': task.createdAt.toIso8601String(),
        'start_date': task.dueDate?.toIso8601String(),
        'end_date': task.endDate?.toIso8601String(),
        'completed_at': _effectiveCompletedAt(task)?.toIso8601String(),
      };
    }).toList(growable: false);
  }

  String _projectName(Task task, Map<String, String> projectNames) {
    final l = AppLocalizations.of(context);
    final projectId = task.projectId;
    if (projectId == null || projectId.trim().isEmpty) {
      return l.inbox;
    }
    return projectNames[projectId] ?? l.unknownProject;
  }

  String _buildSummaryPrompt(Map<String, dynamic> payload) {
    final jsonPayload = jsonEncode(payload);
    return '''You are an assistant that writes a weekly report for the user.
Use the JSON below to summarize the week. Output must be Markdown.
Rules:
- Use the language in "language" ("zh" for Chinese, "en" for English).
- Include sections for completed work, new work, and due this week.
- Be concise and bullet-point items.
- If a section has no items, write "None".
JSON:
$jsonPayload''';
  }

  bool _isCompletedInRange(Task task, DateTime start, DateTime end) {
    if (task.status != 1) return false;
    final completedAt = _effectiveCompletedAt(task);
    if (completedAt == null) return false;
    return _isInRange(completedAt, start, end);
  }

  DateTime? _effectiveCompletedAt(Task task) {
    if (task.status != 1) return null;
    return task.completedAt ?? task.updatedAt;
  }

  bool _isInRange(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && value.isBefore(end);
  }

  DateTime _startOfWeek(DateTime date, int firstDayOfWeekIndex) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayIndex = dayStart.weekday % 7;
    var diff = dayIndex - firstDayOfWeekIndex;
    if (diff < 0) diff += 7;
    return dayStart.subtract(Duration(days: diff));
  }

  void _shiftWeek(int deltaWeeks) {
    final current = _weekStart;
    if (current == null) return;
    setState(() {
      _weekStart = current.add(Duration(days: 7 * deltaWeeks));
    });
  }

  void _jumpToThisWeek() {
    setState(() {
      _weekStart = _startOfWeek(
        DateTime.now(),
        MaterialLocalizations.of(context).firstDayOfWeekIndex,
      );
    });
  }

  String _formatWeekRange(DateTime start, DateTime end) {
    final endDate = end.subtract(const Duration(days: 1));
    return '${_formatDate(start)} - ${_formatDate(endDate)}';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _copySummary() async {
    final summary = _summary;
    if (summary == null) return;
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.copied)),
    );
  }

  Future<void> _showCopyableErrorDialog(String message) async {
    final l = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l.errorDetails),
          content: SelectableText(message),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: message));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.copied)),
                );
              },
              child: Text(l.copy),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.cancel),
            ),
          ],
        );
      },
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.title,
    required this.subtitle,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200] ?? theme.dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onToday,
            child: Text(subtitle),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
  });

  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200] ?? theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  count.toString(),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    this.details,
    this.onCopy,
  });

  final String message;
  final String? details;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200] ?? theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.red[700]),
          ),
          if (details != null && onCopy != null) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined, size: 16),
              label: Text(AppLocalizations.of(context).errorDetails),
            ),
          ],
        ],
      ),
    );
  }
}
