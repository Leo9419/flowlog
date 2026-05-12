import 'dart:convert';

import 'action_log_service.dart';
import 'suggestion_queue_service.dart';
import 'tool_registry.dart';
import 'trust_policy.dart';

class AiPlannedToolCall {
  const AiPlannedToolCall({
    required this.name,
    required this.arguments,
  });

  final String name;
  final Map<String, dynamic> arguments;
}

class AiAgenticExecutionResult {
  const AiAgenticExecutionResult({
    required this.executedCount,
    required this.pendingCount,
    this.failures = const <String>[],
  });

  final int executedCount;
  final int pendingCount;
  final List<String> failures;
}

class AiAgenticChatPlan {
  const AiAgenticChatPlan({
    required this.reply,
    this.toolCalls = const <AiPlannedToolCall>[],
  });

  final String reply;
  final List<AiPlannedToolCall> toolCalls;

  factory AiAgenticChatPlan.fromJson(Map<String, dynamic> json) {
    final reply = json['reply'];
    final rawCalls = json['tool_calls'];
    if (reply is! String) {
      throw const FormatException('missing_reply');
    }
    final calls = <AiPlannedToolCall>[];
    if (rawCalls is List) {
      for (final item in rawCalls) {
        if (item is! Map<String, dynamic>) continue;
        final name = item['name'];
        final arguments = item['arguments'];
        if (name is String && arguments is Map<String, dynamic>) {
          calls.add(AiPlannedToolCall(name: name, arguments: arguments));
        }
      }
    }
    return AiAgenticChatPlan(reply: reply.trim(), toolCalls: calls);
  }
}

class AiAgenticChatService {
  const AiAgenticChatService({
    required AiToolRegistry registry,
    required AiTrustPolicy trustPolicy,
    required AiSuggestionQueueService suggestions,
    required AiActionLogService actionLog,
  })  : _registry = registry,
        _trustPolicy = trustPolicy,
        _suggestions = suggestions,
        _actionLog = actionLog;

  final AiToolRegistry _registry;
  final AiTrustPolicy _trustPolicy;
  final AiSuggestionQueueService _suggestions;
  final AiActionLogService _actionLog;

  Future<AiAgenticExecutionResult> executeToolCalls(
    List<AiPlannedToolCall> calls, {
    required AiActionOrigin origin,
    String? conversationId,
  }) async {
    var executed = 0;
    var pending = 0;
    final failures = <String>[];

    for (final call in calls) {
      final tool = _registry.require(call.name);
      final trustLevel = _trustPolicy.levelForTool(
        call.name,
        tool.trustLevel,
      );
      final route = _trustPolicy.routeFor(trustLevel);
      final context = AiToolContext(
        origin: origin,
        conversationId: conversationId,
      );

      switch (route) {
        case AiTrustRoute.executeImmediately:
          final result = await tool.execute(call.arguments, context);
          await _actionLog.record(
            toolName: call.name,
            argsJson: jsonEncode(call.arguments),
            resultJson: jsonEncode(result.toJson()),
            trustLevel: trustLevel,
            origin: origin,
            conversationId: conversationId,
          );
          if (result.ok) {
            executed++;
          } else {
            failures.add('${call.name}: ${result.message ?? 'failed'}');
          }
          break;
        case AiTrustRoute.suggestionWithUndo:
        case AiTrustRoute.mandatoryPreview:
          await _suggestions.enqueue(
            surface: _surfaceForOrigin(origin),
            toolName: call.name,
            args: call.arguments,
            previewText: _previewText(call.name, call.arguments),
            preview: {
              'tool_name': call.name,
              'args': call.arguments,
              'trust_level': trustLevel.id,
            },
            conversationId: conversationId,
          );
          pending++;
          break;
      }
    }

    return AiAgenticExecutionResult(
      executedCount: executed,
      pendingCount: pending,
      failures: failures,
    );
  }

  AiSuggestionSurface _surfaceForOrigin(AiActionOrigin origin) {
    switch (origin) {
      case AiActionOrigin.chat:
        return AiSuggestionSurface.chat;
      case AiActionOrigin.autoplan:
        return AiSuggestionSurface.autoplan;
      case AiActionOrigin.card:
        return AiSuggestionSurface.today;
      case AiActionOrigin.coach:
        return AiSuggestionSurface.today;
    }
  }

  String _previewText(String toolName, Map<String, dynamic> args) {
    final taskId = args['task_id'];
    final title = args['title'];
    if (title is String && title.trim().isNotEmpty) {
      return '$toolName: ${title.trim()}';
    }
    if (taskId is String && taskId.trim().isNotEmpty) {
      return '$toolName: ${taskId.trim()}';
    }
    return toolName;
  }
}
