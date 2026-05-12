import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../state/app_settings.dart';
import 'ai/agentic_chat_service.dart';

typedef AiLocalAgentRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

typedef AiExecutableExists = bool Function(String path);

class AiLocalAgentService {
  AiLocalAgentService(
    this._settings, {
    AiLocalAgentRunner? runner,
    AiExecutableExists? executableExists,
  })  : _runner = runner ?? Process.run,
        _executableExists = executableExists ?? _defaultExecutableExists;

  final AppSettings _settings;
  final AiLocalAgentRunner _runner;
  final AiExecutableExists _executableExists;

  Future<void> testClaudeCode() async {
    _resolveExecutable(_settings.aiClaudeCommand.trim());
  }

  Future<String> generateChatReply({
    required String context,
    required List<Map<String, String>> history,
  }) async {
    final output = await _runClaude(
      ['-p', _buildChatPrompt(context: context, history: history)],
      timeout: const Duration(seconds: 120),
    );
    if (output.trim().isEmpty) {
      throw const FormatException('empty_response');
    }
    return output.trim();
  }

  Future<String> generateSummary({required String prompt}) async {
    final output = await _runClaude(
      ['-p', prompt],
      timeout: const Duration(seconds: 120),
    );
    if (output.trim().isEmpty) {
      throw const FormatException('empty_response');
    }
    return output.trim();
  }

  Future<AiAgenticChatPlan> generateAgenticChatPlan({
    required String context,
    required List<Map<String, String>> history,
    required List<String> toolNames,
  }) async {
    final output = await _runClaude(
      [
        '-p',
        _buildAgenticPrompt(
          context: context,
          history: history,
          toolNames: toolNames,
        ),
      ],
      timeout: const Duration(seconds: 120),
    );
    final jsonText = _extractJsonObject(output.trim()) ?? output.trim();
    return AiAgenticChatPlan.fromJson(
      jsonDecode(jsonText) as Map<String, dynamic>,
    );
  }

  Future<String> _runClaude(
    List<String> args, {
    required Duration timeout,
  }) async {
    final commandParts = _splitCommand(_settings.aiClaudeCommand.trim());
    if (commandParts.isEmpty) {
      throw const FormatException('missing_config');
    }
    final executable = _resolveExecutable(commandParts.first);
    final result = await _runWithFallbacks(
      executable,
      [...commandParts.skip(1), ...args],
      timeout: timeout,
    );
    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      throw FormatException(
          stderr.isEmpty ? 'process_${result.exitCode}' : stderr);
    }
    return result.stdout.toString();
  }

  Future<ProcessResult> _runWithFallbacks(
    String executable,
    List<String> arguments, {
    required Duration timeout,
  }) async {
    ProcessException? lastProcessException;
    for (final candidate in _candidateExecutables(executable)) {
      try {
        return await _runner(candidate, arguments).timeout(timeout);
      } on ProcessException catch (error) {
        lastProcessException = error;
      }
    }
    if (lastProcessException != null) {
      throw FormatException(lastProcessException.message);
    }
    throw const FormatException('process_failed');
  }

  List<String> _candidateExecutables(String executable) {
    if (executable.contains('/')) {
      return [executable];
    }
    final home = Platform.environment['HOME'];
    return [
      executable,
      '/opt/homebrew/bin/$executable',
      '/usr/local/bin/$executable',
      if (home != null && home.trim().isNotEmpty)
        '${home.trim()}/.local/bin/$executable',
      if (home != null && home.trim().isNotEmpty)
        '${home.trim()}/.npm-global/bin/$executable',
    ];
  }

  String _resolveExecutable(String executable) {
    if (executable.trim().isEmpty) {
      throw const FormatException('missing_config');
    }
    for (final candidate in _candidateExecutables(executable)) {
      if (_executableExists(candidate)) {
        return candidate;
      }
    }
    throw const FormatException('executable_not_found');
  }

  static bool _defaultExecutableExists(String path) {
    if (path.contains('/')) {
      return File(path).existsSync();
    }
    final pathEnv = Platform.environment['PATH'] ?? '';
    for (final dir in pathEnv.split(':')) {
      if (dir.trim().isEmpty) continue;
      if (File('${dir.trim()}/$path').existsSync()) {
        return true;
      }
    }
    return false;
  }

  List<String> _splitCommand(String command) {
    final matches = RegExp(r'''"[^"]+"|'[^']+'|\S+''').allMatches(command);
    return matches
        .map((match) => match.group(0)!.trim())
        .where((part) => part.isNotEmpty)
        .map((part) {
      if ((part.startsWith('"') && part.endsWith('"')) ||
          (part.startsWith("'") && part.endsWith("'"))) {
        return part.substring(1, part.length - 1);
      }
      return part;
    }).toList(growable: false);
  }

  String _buildChatPrompt({
    required String context,
    required List<Map<String, String>> history,
  }) {
    return '''You are FlowLog AI. Answer in the user's language.

Task context:
$context

Conversation:
${_formatHistory(history)}
''';
  }

  String _buildAgenticPrompt({
    required String context,
    required List<Map<String, String>> history,
    required List<String> toolNames,
  }) {
    return '''You are FlowLog AI. You can answer questions and plan task changes by returning tool calls.
Return ONLY a JSON object with keys {"reply": string, "tool_calls": array}.
Each tool call must be {"name": string, "arguments": object}.
Use only these tools: ${toolNames.join(', ')}.
If no tool is needed, return an empty tool_calls array.
Respond in the user language.

Task context:
$context

Conversation:
${_formatHistory(history)}
''';
  }

  String _formatHistory(List<Map<String, String>> history) {
    return history
        .map((item) {
          final role = item['role'] ?? 'user';
          final content = item['content'] ?? '';
          return '$role: $content';
        })
        .join('\n')
        .trim();
  }

  String? _extractJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    return text.substring(start, end + 1);
  }
}
