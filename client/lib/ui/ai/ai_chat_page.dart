import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ai_cloud_service.dart';
import '../../services/ai_local_agent_service.dart';
import '../../services/ai/action_log_service.dart';
import '../../services/ai/agentic_chat_service.dart';
import '../../services/ai/suggestion_queue_service.dart';
import '../../services/ai/tool_registry.dart';
import '../../services/ai/trust_policy.dart';
import '../../state/app_settings.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  List<_ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _conversationId;
  bool _historyLoaded = false;
  bool _sending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_historyLoaded) {
      _historyLoaded = true;
      _loadPersistedChat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final l = AppLocalizations.of(context);
    final settings = Provider.of<AppSettings>(context, listen: false);
    if (!_ensureAssistantReady(settings, l)) return;

    setState(() {
      _messages.add(_ChatMessage(role: _ChatRole.user, content: text));
      _sending = true;
    });
    _controller.clear();
    _scrollToBottom();

    final db = Provider.of<AppDatabase>(context, listen: false);
    final ai = Provider.of<AiCloudService>(context, listen: false);
    final localAgent = Provider.of<AiLocalAgentService>(context, listen: false);
    final conversationId = await _ensureConversation(db);
    await db.insertAiMessage(
      conversationId: conversationId,
      role: 'user',
      content: text,
    );
    final resolvedTasks = await _resolveTasksForQuery(db, _queryText(text), l);
    final contextText = await _buildTaskContext(
      resolvedTasks.tasks,
      db,
      emptyMessage: resolvedTasks.emptyMessage,
    );
    final history = _buildHistory();

    String reply;
    try {
      final registry = AiToolRegistry(db);
      final plan = settings.aiProvider == AiProviderType.claudeCode
          ? await localAgent.generateAgenticChatPlan(
              context: contextText,
              history: history,
              toolNames: registry.toolNames,
            )
          : await ai.generateAgenticChatPlan(
              context: contextText,
              history: history,
              toolNames: registry.toolNames,
            );
      final execution = await AiAgenticChatService(
        registry: registry,
        trustPolicy: AiTrustPolicy(),
        suggestions: AiSuggestionQueueService(db),
        actionLog: AiActionLogService(db),
      ).executeToolCalls(
        plan.toolCalls,
        origin: AiActionOrigin.chat,
        conversationId: conversationId,
      );
      reply = _agenticReply(plan.reply, execution);
    } on FormatException {
      reply = settings.aiProvider == AiProviderType.claudeCode
          ? await localAgent.generateChatReply(
              context: contextText,
              history: history,
            )
          : await ai.generateChatReply(
              context: contextText,
              history: history,
            );
    } catch (error) {
      reply = error.toString();
      setState(() {
        _messages.add(_ChatMessage(
          role: _ChatRole.assistant,
          content: reply,
          isError: true,
        ));
        _sending = false;
      });
      await db.insertAiMessage(
        conversationId: conversationId,
        role: 'assistant',
        content: reply,
        isError: true,
      );
      _scrollToBottom();
      return;
    }

    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(role: _ChatRole.assistant, content: reply));
      _sending = false;
    });
    await db.insertAiMessage(
      conversationId: conversationId,
      role: 'assistant',
      content: reply,
    );
    _scrollToBottom();
  }

  String _agenticReply(
    String baseReply,
    AiAgenticExecutionResult execution,
  ) {
    final parts = <String>[];
    if (baseReply.trim().isNotEmpty) {
      parts.add(baseReply.trim());
    }
    if (execution.executedCount > 0) {
      parts.add('已执行 ${execution.executedCount} 个低风险操作。');
    }
    if (execution.pendingCount > 0) {
      parts.add('有 ${execution.pendingCount} 个操作需要你确认。');
    }
    if (execution.failures.isNotEmpty) {
      parts.add('失败：${execution.failures.join('；')}');
    }
    return parts.isEmpty ? '已处理。' : parts.join('\n');
  }

  Future<void> _acceptSuggestion(AiSuggestion suggestion) async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final result = await AiSuggestionQueueService(db).accept(
      suggestion.id,
      registry: AiToolRegistry(db),
      context: AiToolContext(
        origin: AiActionOrigin.chat,
        conversationId: _conversationId,
      ),
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(result.ok ? '已应用 AI 建议' : 'AI 建议应用失败')),
    );
  }

  Future<void> _rejectSuggestion(AiSuggestion suggestion) async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    await AiSuggestionQueueService(db).markRejected(suggestion.id);
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('已拒绝 AI 建议')),
    );
  }

  Future<void> _loadPersistedChat() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final conversations = await db.watchAiConversations().first;
    final conversationId = conversations.isEmpty
        ? await db.ensureAiConversation(title: 'AI Chat')
        : conversations.first.id;
    final messages = await db.watchAiMessages(conversationId).first;
    if (!mounted) return;
    setState(() {
      _conversationId = conversationId;
      _messages = messages.map(_messageFromRow).toList(growable: true);
    });
    _scrollToBottom();
  }

  Future<String> _ensureConversation(AppDatabase db) async {
    final existing = _conversationId;
    if (existing != null) return existing;
    final id = await db.ensureAiConversation(title: 'AI Chat');
    if (mounted) {
      setState(() => _conversationId = id);
    } else {
      _conversationId = id;
    }
    return id;
  }

  _ChatMessage _messageFromRow(AiMessage message) {
    return _ChatMessage(
      role: message.role == 'user' ? _ChatRole.user : _ChatRole.assistant,
      content: message.content,
      isError: message.isError,
    );
  }

  bool _ensureAssistantReady(AppSettings settings, AppLocalizations l) {
    switch (settings.aiProvider) {
      case AiProviderType.cloud:
        if (settings.aiCloudEndpoint.trim().isEmpty ||
            settings.aiCloudApiKey.trim().isEmpty ||
            settings.aiCloudModel.trim().isEmpty) {
          _showSnack(l.aiCloudConfigMissing);
          return false;
        }
        return true;
      case AiProviderType.claudeCode:
        if (settings.aiClaudeCommand.trim().isEmpty) {
          _showSnack(l.aiClaudeConfigMissing);
          return false;
        }
        return true;
      case AiProviderType.local:
        _showSnack(l.aiLocalConfigMissing);
        return false;
    }
  }

  Future<_ResolvedTasks> _resolveTasksForQuery(
    AppDatabase db,
    String query,
    AppLocalizations l,
  ) async {
    final normalized = query.trim().toLowerCase();
    if (_isTodayQuery(normalized, l)) {
      final tasks = await db.fetchTasksForSummary();
      final now = DateTime.now();
      final todayTasks = _filterTasksForToday(tasks, now);
      return _ResolvedTasks(
        tasks: todayTasks,
        emptyMessage: l.aiChatNoTasksToday,
      );
    }

    final tasks = await db.searchTasksForChat(query, limit: 20);
    final resolvedTasks =
        tasks.isEmpty ? await db.recentTasksForChat(limit: 20) : tasks;
    return _ResolvedTasks(tasks: resolvedTasks);
  }

  String _queryText(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('/find ')) {
      return trimmed.substring('/find '.length).trim();
    }
    return trimmed;
  }

  bool _isTodayQuery(String query, AppLocalizations l) {
    final today = l.today.toLowerCase();
    return query.contains(today) || query.contains('today');
  }

  List<Task> _filterTasksForToday(List<Task> tasks, DateTime now) {
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final results = <Task>[];
    for (final task in tasks) {
      final dueDate = task.dueDate;
      if (dueDate == null) continue;
      if (!dueDate.isBefore(start) && dueDate.isBefore(end)) {
        results.add(task);
      }
    }
    return results;
  }

  Future<void> _generateReport(_ReportRange range) async {
    if (_sending) return;
    final l = AppLocalizations.of(context);
    final settings = Provider.of<AppSettings>(context, listen: false);
    if (!_ensureAssistantReady(settings, l)) return;

    final actionLabel = _reportActionLabel(l, range);
    setState(() {
      _messages.add(_ChatMessage(role: _ChatRole.user, content: actionLabel));
      _sending = true;
    });
    _scrollToBottom();

    final db = Provider.of<AppDatabase>(context, listen: false);
    final ai = Provider.of<AiCloudService>(context, listen: false);
    final localAgent = Provider.of<AiLocalAgentService>(context, listen: false);
    final weekStartIndex =
        MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final conversationId = await _ensureConversation(db);
    await db.insertAiMessage(
      conversationId: conversationId,
      role: 'user',
      content: actionLabel,
    );
    final tasks = await db.fetchTasksForSummary();
    final projects = await db.select(db.projects).get();
    final projectNames = <String, String>{
      for (final project in projects) project.id: project.name,
    };
    final now = DateTime.now();
    final rangeStart = _rangeStart(range, now, weekStartIndex);
    final rangeEnd = _rangeEnd(rangeStart, range);
    final payload = _buildReportPayload(
      tasks: tasks,
      projectNames: projectNames,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      locale: l.locale,
      range: range,
    );
    final prompt = _buildReportPrompt(payload);

    String reply;
    try {
      reply = settings.aiProvider == AiProviderType.claudeCode
          ? await localAgent.generateSummary(prompt: prompt)
          : await ai.generateSummary(prompt: prompt);
    } on FormatException catch (error) {
      final message = error.message == 'missing_config'
          ? settings.aiProvider == AiProviderType.claudeCode
              ? l.aiClaudeConfigMissing
              : l.aiCloudConfigMissing
          : l.aiChatReportFailed;
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          role: _ChatRole.assistant,
          content: message,
          isError: true,
        ));
        _sending = false;
      });
      await db.insertAiMessage(
        conversationId: conversationId,
        role: 'assistant',
        content: message,
        isError: true,
      );
      _scrollToBottom();
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          role: _ChatRole.assistant,
          content: l.aiChatReportFailed,
          isError: true,
        ));
        _sending = false;
      });
      await db.insertAiMessage(
        conversationId: conversationId,
        role: 'assistant',
        content: l.aiChatReportFailed,
        isError: true,
      );
      _scrollToBottom();
      return;
    }

    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(role: _ChatRole.assistant, content: reply));
      _sending = false;
    });
    await db.insertAiMessage(
      conversationId: conversationId,
      role: 'assistant',
      content: reply,
    );
    _scrollToBottom();
  }

  String _reportActionLabel(AppLocalizations l, _ReportRange range) {
    switch (range) {
      case _ReportRange.week:
        return l.aiChatReportWeekly;
      case _ReportRange.month:
        return l.aiChatReportMonthly;
      case _ReportRange.year:
        return l.aiChatReportYearly;
    }
  }

  DateTime _rangeStart(
      _ReportRange range, DateTime now, int firstDayOfWeekIndex) {
    switch (range) {
      case _ReportRange.week:
        return _startOfWeek(now, firstDayOfWeekIndex);
      case _ReportRange.month:
        return DateTime(now.year, now.month, 1);
      case _ReportRange.year:
        return DateTime(now.year, 1, 1);
    }
  }

  DateTime _rangeEnd(DateTime rangeStart, _ReportRange range) {
    switch (range) {
      case _ReportRange.week:
        return rangeStart.add(const Duration(days: 7));
      case _ReportRange.month:
        return _startOfNextMonth(rangeStart);
      case _ReportRange.year:
        return DateTime(rangeStart.year + 1, 1, 1);
    }
  }

  DateTime _startOfNextMonth(DateTime date) {
    if (date.month == DateTime.december) {
      return DateTime(date.year + 1, 1, 1);
    }
    return DateTime(date.year, date.month + 1, 1);
  }

  Map<String, dynamic> _buildReportPayload({
    required List<Task> tasks,
    required Map<String, String> projectNames,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required Locale locale,
    required _ReportRange range,
  }) {
    final now = DateTime.now();
    final completedTasks = tasks
        .where((task) => _isCompletedInRange(task, rangeStart, rangeEnd))
        .toList();
    final createdTasks = tasks
        .where((task) => _isInRange(task.createdAt, rangeStart, rangeEnd))
        .toList();
    final dueTasks = tasks.where((task) {
      final date = task.endDate ?? task.dueDate;
      return date != null && _isInRange(date, rangeStart, rangeEnd);
    }).toList();
    final openTasks = tasks.where((task) => task.status == 0).toList();
    final overdueTasks = tasks
        .where((task) =>
            task.status == 0 &&
            (task.endDate ?? task.dueDate) != null &&
            (task.endDate ?? task.dueDate)!.isBefore(now))
        .toList();

    const maxItems = 50;
    return {
      'language': locale.languageCode,
      'timezone_offset': DateTime.now().timeZoneOffset.inMinutes,
      'range_type': _reportRangeKey(range),
      'range_start': rangeStart.toIso8601String(),
      'range_end': rangeEnd.toIso8601String(),
      'counts': {
        'completed': completedTasks.length,
        'created': createdTasks.length,
        'due': dueTasks.length,
        'overdue': overdueTasks.length,
        'open': openTasks.length,
      },
      'completed_tasks':
          _mapTasks(completedTasks.take(maxItems).toList(), projectNames),
      'created_tasks':
          _mapTasks(createdTasks.take(maxItems).toList(), projectNames),
      'due_tasks': _mapTasks(dueTasks.take(maxItems).toList(), projectNames),
      'overdue_tasks': _mapTasks(overdueTasks.take(20).toList(), projectNames),
      'open_tasks': _mapTasks(openTasks.take(20).toList(), projectNames),
    };
  }

  List<Map<String, dynamic>> _mapTasks(
    List<Task> tasks,
    Map<String, String> projectNames,
  ) {
    final l = AppLocalizations.of(context);
    return tasks.map((task) {
      return {
        'id': task.id,
        'title': task.title,
        'project': _projectName(task, projectNames, l),
        'priority': task.priority,
        'status': task.status,
        'created_at': task.createdAt.toIso8601String(),
        'start_date': task.dueDate?.toIso8601String(),
        'end_date': task.endDate?.toIso8601String(),
        'completed_at': _effectiveCompletedAt(task)?.toIso8601String(),
      };
    }).toList(growable: false);
  }

  String _projectName(
    Task task,
    Map<String, String> projectNames,
    AppLocalizations l,
  ) {
    final projectId = task.projectId;
    if (projectId == null || projectId.trim().isEmpty) {
      return l.inbox;
    }
    return projectNames[projectId] ?? l.unknownProject;
  }

  String _reportRangeKey(_ReportRange range) {
    switch (range) {
      case _ReportRange.week:
        return 'weekly';
      case _ReportRange.month:
        return 'monthly';
      case _ReportRange.year:
        return 'yearly';
    }
  }

  String _buildReportPrompt(Map<String, dynamic> payload) {
    final jsonPayload = jsonEncode(payload);
    return '''You are an assistant that writes a report for the user.
Use the JSON below to summarize the period. Output must be Markdown.
Rules:
- Use the language in "language" ("zh" for Chinese, "en" for English).
- Include a short overview, metrics, and sections for completed, created, due, overdue, and open.
- Be concise and use bullet points where helpful.
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

  List<Map<String, String>> _buildHistory() {
    final history = <Map<String, String>>[];
    final start = _messages.length > 8 ? _messages.length - 8 : 0;
    for (var i = start; i < _messages.length; i++) {
      final msg = _messages[i];
      history.add({
        'role': msg.role == _ChatRole.user ? 'user' : 'assistant',
        'content': msg.content,
      });
    }
    return history;
  }

  Future<String> _buildTaskContext(
    List<Task> tasks,
    AppDatabase db, {
    String? emptyMessage,
  }) async {
    final now = DateTime.now();
    final offset = _formatOffset(now.timeZoneOffset);
    final todayText =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final lines = <String>[
      'Current local date/time: ${now.toIso8601String()} (UTC$offset). Today is $todayText.',
    ];
    if (tasks.isEmpty) {
      lines.add(emptyMessage ?? 'No tasks available.');
      return lines.join('\n');
    }

    final projects = await db.select(db.projects).get();
    final projectMap = <String, String>{
      for (final project in projects) project.id: project.name,
    };
    for (final task in tasks) {
      final status = task.status == 1 ? 'done' : 'open';
      final startText = task.dueDate == null
          ? 'no start'
          : task.isAllDay
              ? 'start ${task.dueDate!.toIso8601String().split('T').first}'
              : 'start ${task.dueDate!.toIso8601String()}';
      final endText = task.endDate == null
          ? 'no end'
          : 'end ${task.endDate!.toIso8601String()}';
      final listName = task.projectId == null
          ? 'Inbox'
          : (projectMap[task.projectId] ?? 'Unknown');
      final tags = await db.getTagsForTask(task.id);
      final tagText = tags.isEmpty
          ? ''
          : ' tags:${tags.map((t) => '#${t.name}').join(' ')}';
      final noteText = (task.content == null || task.content!.trim().isEmpty)
          ? ''
          : ' notes:${_truncate(task.content!.trim(), 120)}';
      lines.add(
          '- [$status] ${task.title} ($startText, $endText, list:$listName)$tagText$noteText');
    }
    return lines.join('\n');
  }

  String _formatOffset(Duration offset) {
    final totalMinutes = offset.inMinutes;
    final sign = totalMinutes < 0 ? '-' : '+';
    final absMinutes = totalMinutes.abs();
    final hours = absMinutes ~/ 60;
    final minutes = absMinutes % 60;
    final hourText = hours.toString().padLeft(2, '0');
    final minuteText = minutes.toString().padLeft(2, '0');
    return '$sign$hourText:$minuteText';
  }

  String _truncate(String value, int max) {
    if (value.length <= max) return value;
    return '${value.substring(0, max)}...';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildQuickActions(AppLocalizations l) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          label: Text(l.aiChatReportWeekly),
          onPressed: _sending ? null : () => _generateReport(_ReportRange.week),
        ),
        ActionChip(
          label: Text(l.aiChatReportMonthly),
          onPressed:
              _sending ? null : () => _generateReport(_ReportRange.month),
        ),
        ActionChip(
          label: Text(l.aiChatReportYearly),
          onPressed: _sending ? null : () => _generateReport(_ReportRange.year),
        ),
      ],
    );
  }

  Widget _buildPendingSuggestions(AppDatabase db) {
    final query = db.select(db.aiSuggestions)
      ..where((s) => s.surface.equals(AiSuggestionSurface.chat.id))
      ..where((s) => s.status.equals('pending'));
    return StreamBuilder<List<AiSuggestion>>(
      stream: query.watch(),
      builder: (context, snapshot) {
        final suggestions = snapshot.data ?? const <AiSuggestion>[];
        if (suggestions.isEmpty) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: [
              for (final suggestion in suggestions)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            suggestion.previewText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _rejectSuggestion(suggestion),
                          child: const Text('拒绝'),
                        ),
                        FilledButton(
                          onPressed: () => _acceptSuggestion(suggestion),
                          child: const Text('接受'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final db = Provider.of<AppDatabase>(context, listen: false);

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    l.aiChatEmpty,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _ChatBubble(message: message);
                  },
                ),
        ),
        if (_sending)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              l.aiChatLoading,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: _buildQuickActions(l),
        ),
        _buildPendingSuggestions(db),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: l.aiChatInputHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _sending ? null : _send,
                child: Text(l.aiChatSend),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _ChatRole { user, assistant }

enum _ReportRange { week, month, year }

class _ResolvedTasks {
  const _ResolvedTasks({
    required this.tasks,
    this.emptyMessage,
  });

  final List<Task> tasks;
  final String? emptyMessage;
}

class _ChatMessage {
  const _ChatMessage({
    required this.role,
    required this.content,
    this.isError = false,
  });

  final _ChatRole role;
  final String content;
  final bool isError;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == _ChatRole.user;
    final bubbleColor = isUser
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
        : theme.colorScheme.surfaceContainerHighest;
    final textColor =
        message.isError ? theme.colorScheme.error : theme.colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SelectableText(
          message.content,
          style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
        ),
      ),
    );
  }
}
