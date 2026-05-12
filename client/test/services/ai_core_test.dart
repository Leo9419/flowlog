import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowlog_client/database/database.dart';
import 'package:flowlog_client/services/ai_local_agent_service.dart';
import 'package:flowlog_client/services/ai/action_log_service.dart';
import 'package:flowlog_client/services/ai/agentic_chat_service.dart';
import 'package:flowlog_client/services/ai/privacy_filter.dart';
import 'package:flowlog_client/services/ai/suggestion_queue_service.dart';
import 'package:flowlog_client/services/ai/tool_registry.dart';
import 'package:flowlog_client/services/ai/trust_policy.dart';
import 'package:flowlog_client/state/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AI provider settings', () {
    test('persists Claude Code provider and defaults command to claude',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);

      expect(settings.aiClaudeCommand, 'claude');

      await settings.setAiProvider(AiProviderType.claudeCode);
      final reloaded = AppSettings(prefs);

      expect(reloaded.aiProvider, AiProviderType.claudeCode);
      expect(reloaded.aiProvider.id, 'claude_code');
    });
  });

  group('AiLocalAgentService', () {
    test('runs Claude Code with prompt mode and parses agentic JSON', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);
      await settings.setAiClaudeCommand('claude');

      String? executable;
      List<String>? arguments;
      final service = AiLocalAgentService(
        settings,
        runner: (command, args) async {
          executable = command;
          arguments = args;
          return ProcessResult(
            42,
            0,
            '{"reply":"Done","tool_calls":[{"name":"set_when","arguments":{"task_id":"t1","when_type":"today"}}]}',
            '',
          );
        },
      );

      final plan = await service.generateAgenticChatPlan(
        context: 'Task t1',
        history: const [
          {'role': 'user', 'content': 'move it to today'},
        ],
        toolNames: const ['set_when'],
      );

      expect(executable, 'claude');
      expect(arguments, contains('-p'));
      expect(plan.reply, 'Done');
      expect(plan.toolCalls.single.name, 'set_when');
      expect(plan.toolCalls.single.arguments['task_id'], 't1');
    });

    test('falls back to common Homebrew path when claude is not on PATH',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);

      final commands = <String>[];
      final service = AiLocalAgentService(
        settings,
        executableExists: (path) => path == '/opt/homebrew/bin/claude',
        runner: (command, args) async {
          commands.add(command);
          return ProcessResult(43, 0, '1.0.0', '');
        },
      );

      final reply = await service.generateChatReply(
        context: 'Task context',
        history: const [
          {'role': 'user', 'content': 'hello'},
        ],
      );

      expect(reply, '1.0.0');
      expect(commands, ['/opt/homebrew/bin/claude']);
    });

    test('testClaudeCode only resolves the executable without launching it',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);

      var launched = false;
      final service = AiLocalAgentService(
        settings,
        executableExists: (path) => path == '/opt/homebrew/bin/claude',
        runner: (command, args) async {
          launched = true;
          return ProcessResult(44, 0, '', '');
        },
      );

      await service.testClaudeCode();

      expect(launched, isFalse);
    });

    test('checks npm global install path when resolving claude', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);

      final service = AiLocalAgentService(
        settings,
        executableExists: (path) => path.endsWith('/.npm-global/bin/claude'),
        runner: (command, args) async => ProcessResult(45, 0, '', ''),
      );

      await service.testClaudeCode();
    });
  });

  group('TrustPolicy', () {
    test('routes low tools to immediate execution', () {
      final policy = AiTrustPolicy();

      expect(
        policy.routeFor(AiTrustLevel.low),
        AiTrustRoute.executeImmediately,
      );
    });

    test('routes medium tools to undoable suggestions by default', () {
      final policy = AiTrustPolicy();

      expect(
        policy.routeFor(AiTrustLevel.medium),
        AiTrustRoute.suggestionWithUndo,
      );
    });

    test('routes high tools to mandatory preview by default', () {
      final policy = AiTrustPolicy();

      expect(
        policy.routeFor(AiTrustLevel.high),
        AiTrustRoute.mandatoryPreview,
      );
    });
  });

  group('AiPrivacyFilter', () {
    test('removes system ids and notes by default', () {
      final filtered = const AiPrivacyFilter().taskPayload(
        id: 'task-1',
        title: 'Pay rent',
        whenType: 1,
        dueDate: DateTime(2026, 5, 11),
        deadline: null,
        priority: 5,
        projectName: 'Personal',
        tagNames: const ['home'],
        notes: 'bank account details',
        deviceId: 'device-1',
        accountId: 'account-1',
        etag: 'etag-1',
        completedAt: null,
      );

      expect(filtered, isNot(containsPair('device_id', 'device-1')));
      expect(filtered, isNot(containsPair('account_id', 'account-1')));
      expect(filtered, isNot(containsPair('etag', 'etag-1')));
      expect(filtered, isNot(contains('notes')));
      expect(filtered['project_name'], 'Personal');
      expect(filtered['tag_names'], ['home']);
    });

    test('hashes project and tags in high privacy mode', () {
      final filtered = const AiPrivacyFilter(highPrivacyMode: true).taskPayload(
        id: 'task-1',
        title: 'Pay rent',
        whenType: 1,
        dueDate: null,
        deadline: null,
        priority: 5,
        projectName: 'Personal',
        tagNames: const ['home'],
        notes: 'hidden',
        deviceId: null,
        accountId: null,
        etag: null,
        completedAt: null,
      );

      expect(
          filtered['project_name'], matches(RegExp(r'^project_[0-9a-f]{6}$')));
      expect(filtered['tag_names'], [matches(RegExp(r'^tag_[0-9a-f]{6}$'))]);
      expect(filtered, isNot(contains('notes')));
    });
  });

  group('AiToolRegistry', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('registers all phase 1 tools with stable trust levels', () {
      final registry = AiToolRegistry(db);

      expect(
          registry.toolNames,
          containsAll(<String>[
            'search_tasks',
            'get_view_tasks',
            'get_today_summary',
            'get_overdue',
            'get_completed_in_range',
            'set_when',
            'set_tags',
            'set_priority',
            'complete',
            'create_task',
            'move_to_project',
            'set_deadline',
            'set_reminder',
            'delete',
            'bulk_update',
          ]));
      expect(registry.require('set_when').trustLevel, AiTrustLevel.low);
      expect(registry.require('create_task').trustLevel, AiTrustLevel.medium);
      expect(registry.require('delete').trustLevel, AiTrustLevel.high);
    });

    test('set_when writes through the database mutation path', () async {
      await db.into(db.tasks).insert(
            TasksCompanion.insert(id: 't1', title: 'Task'),
          );
      final registry = AiToolRegistry(db);

      final result = await registry.require('set_when').execute(
        const {'task_id': 't1', 'when_type': 'today'},
        const AiToolContext(origin: AiActionOrigin.chat),
      );

      final task = await (db.select(db.tasks)..where((t) => t.id.equals('t1')))
          .getSingle();
      expect(result.ok, isTrue);
      expect(task.whenType, WhenType.today.value);
      expect(task.isDirty, isTrue);
    });
  });

  group('AiActionLogService', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('records AI writes in the independent action log', () async {
      final service = AiActionLogService(db);

      final id = await service.record(
        toolName: 'set_when',
        argsJson: '{"task_id":"t1"}',
        resultJson: '{"ok":true}',
        trustLevel: AiTrustLevel.low,
        origin: AiActionOrigin.chat,
      );

      final rows = await db.select(db.aiActionLog).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, id);
      expect(rows.single.toolName, 'set_when');
      expect(rows.single.undone, isFalse);
    });
  });

  group('AI chat persistence DAO', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('creates a conversation and appends ordered messages', () async {
      final conversationId = await db.ensureAiConversation(title: 'Today plan');

      await db.insertAiMessage(
        conversationId: conversationId,
        role: 'user',
        content: 'Plan today',
      );
      await db.insertAiMessage(
        conversationId: conversationId,
        role: 'assistant',
        content: 'Done',
      );

      final conversations = await db.watchAiConversations().first;
      final messages = await db.watchAiMessages(conversationId).first;
      expect(conversations.single.id, conversationId);
      expect(conversations.single.title, 'Today plan');
      expect(messages.map((m) => m.role), ['user', 'assistant']);
      expect(messages.map((m) => m.content), ['Plan today', 'Done']);
    });
  });

  group('AiSuggestionQueueService', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('enqueues pending suggestions and resolves accepted suggestions',
        () async {
      final queue = AiSuggestionQueueService(db);

      final id = await queue.enqueue(
        surface: AiSuggestionSurface.chat,
        toolName: 'create_task',
        args: const {'title': 'Buy milk'},
        previewText: 'Create task: Buy milk',
        preview: const {'title': 'Buy milk'},
        conversationId: 'c1',
      );

      final pending = await queue.pending(surface: AiSuggestionSurface.chat);
      expect(pending, hasLength(1));
      expect(pending.single.id, id);
      expect(pending.single.status, 'pending');

      await queue.markAccepted(id);

      final resolved = await db.select(db.aiSuggestions).getSingle();
      expect(resolved.status, 'accepted');
      expect(resolved.resolvedAt, isNotNull);
    });

    test('accept executes the queued tool through the registry', () async {
      final queue = AiSuggestionQueueService(db);
      final registry = AiToolRegistry(db);
      final id = await queue.enqueue(
        surface: AiSuggestionSurface.chat,
        toolName: 'create_task',
        args: const {'title': 'Queued task'},
        previewText: 'Create task: Queued task',
        preview: const {'title': 'Queued task'},
      );

      final result = await queue.accept(
        id,
        registry: registry,
        context: const AiToolContext(origin: AiActionOrigin.chat),
      );

      final tasks = await db.select(db.tasks).get();
      final suggestion = await db.select(db.aiSuggestions).getSingle();
      expect(result.ok, isTrue);
      expect(tasks.single.title, 'Queued task');
      expect(suggestion.status, 'accepted');
    });
  });

  group('AiAgenticChatService', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.into(db.tasks).insert(
            TasksCompanion.insert(id: 't1', title: 'Task 1'),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test('executes low trust tool calls immediately and logs them', () async {
      final service = AiAgenticChatService(
        registry: AiToolRegistry(db),
        trustPolicy: AiTrustPolicy(),
        suggestions: AiSuggestionQueueService(db),
        actionLog: AiActionLogService(db),
      );

      final result = await service.executeToolCalls(
        const [
          AiPlannedToolCall(
            name: 'set_when',
            arguments: {'task_id': 't1', 'when_type': 'today'},
          ),
        ],
        origin: AiActionOrigin.chat,
        conversationId: 'c1',
      );

      final task = await (db.select(db.tasks)..where((t) => t.id.equals('t1')))
          .getSingle();
      final logs = await db.select(db.aiActionLog).get();
      final suggestions = await db.select(db.aiSuggestions).get();
      expect(result.executedCount, 1);
      expect(result.pendingCount, 0);
      expect(task.whenType, WhenType.today.value);
      expect(logs.single.toolName, 'set_when');
      expect(suggestions, isEmpty);
    });

    test('queues medium and high trust tool calls for review', () async {
      final service = AiAgenticChatService(
        registry: AiToolRegistry(db),
        trustPolicy: AiTrustPolicy(),
        suggestions: AiSuggestionQueueService(db),
        actionLog: AiActionLogService(db),
      );

      final result = await service.executeToolCalls(
        const [
          AiPlannedToolCall(
            name: 'create_task',
            arguments: {'title': 'Needs approval'},
          ),
          AiPlannedToolCall(
            name: 'delete',
            arguments: {'task_id': 't1'},
          ),
        ],
        origin: AiActionOrigin.chat,
        conversationId: 'c1',
      );

      final tasks = await db.select(db.tasks).get();
      final suggestions = await db.select(db.aiSuggestions).get();
      expect(result.executedCount, 0);
      expect(result.pendingCount, 2);
      expect(tasks.single.title, 'Task 1');
      expect(suggestions.map((s) => s.toolName), ['create_task', 'delete']);
      expect(suggestions.every((s) => s.status == 'pending'), isTrue);
    });

    test('parses model JSON plans into typed tool calls', () {
      final plan = AiAgenticChatPlan.fromJson(const {
        'reply': 'I will update one task.',
        'tool_calls': [
          {
            'name': 'set_when',
            'arguments': {'task_id': 't1', 'when_type': 'today'},
          }
        ],
      });

      expect(plan.reply, 'I will update one task.');
      expect(plan.toolCalls.single.name, 'set_when');
      expect(plan.toolCalls.single.arguments['task_id'], 't1');
    });
  });
}
