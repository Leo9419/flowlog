import 'dart:convert';
import 'dart:io';

import '../state/app_settings.dart';
import 'ai/agentic_chat_service.dart';
import 'ai_local_service.dart';

class AiCloudService {
  AiCloudService(this._settings, {HttpClient? client})
      : _client = client ?? HttpClient();

  final AppSettings _settings;
  final HttpClient _client;

  void dispose() {
    _client.close(force: true);
  }

  Future<AiQuickAddDraft> parseQuickAdd({
    required String input,
    required DateTime now,
  }) async {
    final endpoint = _normalizeEndpoint(_settings.aiCloudEndpoint);
    final apiKey = _settings.aiCloudApiKey.trim();
    final model = _settings.aiCloudModel.trim();
    if (endpoint.isEmpty || apiKey.isEmpty || model.isEmpty) {
      throw const FormatException('missing_config');
    }

    final prompt = _buildQuickAddPrompt(input: input, now: now);
    final request = await _client.postUrl(Uri.parse(_buildChatUrl(endpoint)));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    request.add(utf8.encode(jsonEncode({
      'model': model,
      'messages': [
        {
          'role': 'system',
          'content': 'You are a task parser for FlowLog. Return only JSON.',
        },
        {
          'role': 'user',
          'content': prompt,
        },
      ],
      'temperature': 0.2,
    })));

    final response = await request.close().timeout(const Duration(seconds: 60));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw FormatException(
          _extractErrorMessage(body) ?? 'http_${response.statusCode}');
    }

    final payload = jsonDecode(body) as Map<String, dynamic>;
    final content = _extractChatContent(payload);
    if (content == null || content.trim().isEmpty) {
      throw const FormatException('empty_response');
    }

    final jsonText = _extractJsonObject(content.trim()) ?? content.trim();
    final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
    final draft = _parseDraft(parsed, fallbackTitle: input.trim());
    final inlineTags = _extractInlineTags(input);
    if (inlineTags.isEmpty) {
      return draft;
    }
    return draft.copyWith(tags: _mergeTags(draft.tags, inlineTags));
  }

  Future<AiQuickAddDraft> parseQuickAddFromImage({
    required List<int> imageBytes,
    required DateTime now,
    String? hint,
    String mimeType = 'image/png',
  }) async {
    final endpoint = _normalizeEndpoint(_settings.aiCloudEndpoint);
    final apiKey = _settings.aiCloudApiKey.trim();
    final model = _settings.aiCloudModel.trim();
    if (endpoint.isEmpty || apiKey.isEmpty || model.isEmpty) {
      throw const FormatException('missing_config');
    }

    final prompt = _buildImageQuickAddPrompt(
      now: now,
      hint: hint,
    );
    final imageBase64 = base64Encode(imageBytes);
    final request = await _client.postUrl(Uri.parse(_buildChatUrl(endpoint)));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    request.add(utf8.encode(jsonEncode({
      'model': model,
      'messages': [
        {
          'role': 'system',
          'content': 'You are a task parser for FlowLog. Return only JSON.',
        },
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:$mimeType;base64,$imageBase64'},
            },
          ],
        },
      ],
      'temperature': 0.2,
      'max_tokens': 256,
    })));

    final response = await request.close().timeout(const Duration(seconds: 60));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw FormatException(
          _extractErrorMessage(body) ?? 'http_${response.statusCode}');
    }

    final payload = jsonDecode(body) as Map<String, dynamic>;
    final content = _extractChatContent(payload);
    if (content == null || content.trim().isEmpty) {
      throw const FormatException('empty_response');
    }

    final jsonText = _extractJsonObject(content.trim()) ?? content.trim();
    final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
    final draft =
        _parseDraft(parsed, fallbackTitle: hint?.trim() ?? 'New task');
    final inlineTags = _extractInlineTags(hint ?? '');
    if (inlineTags.isEmpty) {
      return draft;
    }
    return draft.copyWith(tags: _mergeTags(draft.tags, inlineTags));
  }

  Future<void> testConnection() async {
    final endpoint = _normalizeEndpoint(_settings.aiCloudEndpoint);
    final apiKey = _settings.aiCloudApiKey.trim();
    final model = _settings.aiCloudModel.trim();
    if (endpoint.isEmpty || apiKey.isEmpty || model.isEmpty) {
      throw const FormatException('missing_config');
    }

    final request = await _client.postUrl(Uri.parse(_buildChatUrl(endpoint)));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    request.add(utf8.encode(jsonEncode({
      'model': model,
      'messages': [
        {'role': 'user', 'content': 'ping'},
      ],
      'temperature': 0,
      'max_tokens': 8,
    })));

    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw FormatException(
          _extractErrorMessage(body) ?? 'http_${response.statusCode}');
    }

    final payload = jsonDecode(body) as Map<String, dynamic>;
    final content = _extractChatContent(payload);
    if (content == null || content.trim().isEmpty) {
      throw const FormatException('empty_response');
    }
  }

  Future<String> generateSummary({required String prompt}) async {
    final endpoint = _normalizeEndpoint(_settings.aiCloudEndpoint);
    final apiKey = _settings.aiCloudApiKey.trim();
    final model = _settings.aiCloudModel.trim();
    if (endpoint.isEmpty || apiKey.isEmpty || model.isEmpty) {
      throw const FormatException('missing_config');
    }

    final request = await _client.postUrl(Uri.parse(_buildChatUrl(endpoint)));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    request.add(utf8.encode(jsonEncode({
      'model': model,
      'messages': [
        {
          'role': 'system',
          'content': 'You are a helpful assistant.',
        },
        {
          'role': 'user',
          'content': prompt,
        },
      ],
      'temperature': 0.3,
    })));

    final response =
        await request.close().timeout(const Duration(seconds: 120));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw FormatException(
          _extractErrorMessage(body) ?? 'http_${response.statusCode}');
    }

    final payload = jsonDecode(body) as Map<String, dynamic>;
    final content = _extractChatContent(payload);
    if (content == null || content.trim().isEmpty) {
      throw const FormatException('empty_response');
    }
    return content.trim();
  }

  Future<String> generateChatReply({
    required String context,
    required List<Map<String, String>> history,
  }) async {
    final endpoint = _normalizeEndpoint(_settings.aiCloudEndpoint);
    final apiKey = _settings.aiCloudApiKey.trim();
    final model = _settings.aiCloudModel.trim();
    if (endpoint.isEmpty || apiKey.isEmpty || model.isEmpty) {
      throw const FormatException('missing_config');
    }

    final messages = <Map<String, Object>>[
      {
        'role': 'system',
        'content': 'You are FlowLog AI. Use only the provided task context. '
            'If the answer is not in the tasks, say you do not know. '
            'Respond in the user language.',
      },
      {
        'role': 'system',
        'content': 'Task context:\n$context',
      },
    ];
    for (final item in history) {
      final role = item['role'];
      final content = item['content'];
      if (role == null || content == null) continue;
      messages.add({'role': role, 'content': content});
    }

    final request = await _client.postUrl(Uri.parse(_buildChatUrl(endpoint)));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    request.add(utf8.encode(jsonEncode({
      'model': model,
      'messages': messages,
      'temperature': 0.3,
      'max_tokens': 512,
    })));

    final response =
        await request.close().timeout(const Duration(seconds: 120));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw FormatException(
          _extractErrorMessage(body) ?? 'http_${response.statusCode}');
    }

    final payload = jsonDecode(body) as Map<String, dynamic>;
    final content = _extractChatContent(payload);
    if (content == null || content.trim().isEmpty) {
      throw const FormatException('empty_response');
    }
    return content.trim();
  }

  Future<AiAgenticChatPlan> generateAgenticChatPlan({
    required String context,
    required List<Map<String, String>> history,
    required List<String> toolNames,
  }) async {
    final endpoint = _normalizeEndpoint(_settings.aiCloudEndpoint);
    final apiKey = _settings.aiCloudApiKey.trim();
    final model = _settings.aiCloudModel.trim();
    if (endpoint.isEmpty || apiKey.isEmpty || model.isEmpty) {
      throw const FormatException('missing_config');
    }

    final messages = <Map<String, Object>>[
      {
        'role': 'system',
        'content': 'You are FlowLog AI. You can answer questions and plan task '
            'changes by returning tool calls. Return ONLY a JSON object with '
            'keys {"reply": string, "tool_calls": array}. Each tool call must '
            'be {"name": string, "arguments": object}. Use only these tools: '
            '${toolNames.join(', ')}. If no tool is needed, return an empty '
            'tool_calls array. Respond in the user language.',
      },
      {
        'role': 'system',
        'content': 'Task context:\n$context',
      },
    ];
    for (final item in history) {
      final role = item['role'];
      final content = item['content'];
      if (role == null || content == null) continue;
      messages.add({'role': role, 'content': content});
    }

    final request = await _client.postUrl(Uri.parse(_buildChatUrl(endpoint)));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    request.add(utf8.encode(jsonEncode({
      'model': model,
      'messages': messages,
      'temperature': 0.2,
      'max_tokens': 700,
    })));

    final response =
        await request.close().timeout(const Duration(seconds: 120));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw FormatException(
          _extractErrorMessage(body) ?? 'http_${response.statusCode}');
    }

    final payload = jsonDecode(body) as Map<String, dynamic>;
    final content = _extractChatContent(payload);
    if (content == null || content.trim().isEmpty) {
      throw const FormatException('empty_response');
    }
    final jsonText = _extractJsonObject(content.trim()) ?? content.trim();
    return AiAgenticChatPlan.fromJson(
      jsonDecode(jsonText) as Map<String, dynamic>,
    );
  }

  String _buildChatUrl(String endpoint) {
    if (endpoint.endsWith('/v1/chat/completions') ||
        endpoint.endsWith('/v1/responses')) {
      return endpoint;
    }
    if (endpoint.endsWith('/v1')) {
      return '$endpoint/chat/completions';
    }
    if (endpoint.endsWith('/v1/')) {
      return '${endpoint}chat/completions';
    }
    if (endpoint.contains('/v1/')) {
      return endpoint;
    }
    return '$endpoint/v1/chat/completions';
  }

  String _buildQuickAddPrompt({
    required String input,
    required DateTime now,
  }) {
    final offset = _formatOffset(now.timeZoneOffset);
    return '''Return ONLY a JSON object with keys:
{"title": string, "start_date": string|null, "end_date": string|null, "is_all_day": boolean, "notes": string|null, "tags": string[]}
Rules:
- Use a concise task title.
- Remove tag markers from the title.
- start_date is when the task should appear or begin.
- end_date is the deadline/end time. If only one date/time is mentioned, use it as start_date and set end_date to null.
- If no date/time is mentioned, set start_date and end_date to null and is_all_day to false.
- If a date is mentioned without a time, set start_date to YYYY-MM-DDT00:00:00 and is_all_day to true.
- If a time is mentioned, set start_date to full local date/time and is_all_day to false.
- Extract tags from input (e.g. #work, 标签:工作) and return them as plain strings without #.
- If no tags, return an empty array.
Current local time: ${now.toIso8601String()} (UTC$offset).
Input: $input''';
  }

  String _buildImageQuickAddPrompt({
    required DateTime now,
    String? hint,
  }) {
    final offset = _formatOffset(now.timeZoneOffset);
    final hintText = (hint ?? '').trim();
    final hintLine = hintText.isEmpty ? 'Hint: (none)' : 'Hint: $hintText';
    return '''Analyze the image and return ONLY a JSON object with keys:
{"title": string, "start_date": string|null, "end_date": string|null, "is_all_day": boolean, "notes": string|null, "tags": string[]}
Rules:
- Choose the most actionable task from the image.
- Remove tag markers from the title.
- If multiple tasks exist, keep the best one as title and list the rest in notes.
- start_date is when the task should appear or begin.
- end_date is the deadline/end time. If only one date/time is mentioned, use it as start_date and set end_date to null.
- If no date/time is mentioned, set start_date and end_date to null and is_all_day to false.
- If a date is mentioned without a time, set start_date to YYYY-MM-DDT00:00:00 and is_all_day to true.
- If a time is mentioned, set start_date to full local date/time and is_all_day to false.
- Extract tags from the image text if present and return them as plain strings without #.
- If no tags, return an empty array.
Current local time: ${now.toIso8601String()} (UTC$offset).
$hintLine''';
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

  AiQuickAddDraft _parseDraft(
    Map<String, dynamic> payload, {
    required String fallbackTitle,
  }) {
    final titleRaw = payload['title'] ?? payload['task'] ?? payload['summary'];
    final title = titleRaw is String ? titleRaw.trim() : null;
    final finalTitle = (title == null || title.isEmpty) ? fallbackTitle : title;
    if (finalTitle.isEmpty) {
      throw const FormatException('empty_title');
    }

    final notesRaw =
        payload['notes'] ?? payload['content'] ?? payload['detail'];
    final notes = notesRaw is String ? notesRaw.trim() : null;

    final dueRaw = payload['start_date'] ??
        payload['startDate'] ??
        payload['due_date'] ??
        payload['dueDate'] ??
        payload['due'];
    final dueDate = _parseDateTime(dueRaw);
    final endRaw = payload['end_date'] ??
        payload['endDate'] ??
        payload['deadline'] ??
        payload['deadline_date'];
    final endDate = _parseDateTime(endRaw);

    final isAllDayRaw = payload['is_all_day'] ?? payload['isAllDay'];
    final isAllDay = _parseBool(isAllDayRaw);

    final tagsRaw = payload['tags'] ??
        payload['tag'] ??
        payload['labels'] ??
        payload['label'];
    final tags = _parseTags(tagsRaw);

    return AiQuickAddDraft(
      title: finalTitle,
      dueDate: dueDate,
      endDate: endDate,
      isAllDay: isAllDay,
      notes: notes == null || notes.isEmpty ? null : notes,
      tags: tags,
    );
  }

  List<String> _parseTags(dynamic value) {
    final results = <String>[];

    void addTag(String raw) {
      var cleaned = raw.trim();
      if (cleaned.isEmpty) return;
      cleaned = cleaned.replaceAll(RegExp(r'^[#@]+'), '');
      if (cleaned.isEmpty) return;
      results.add(cleaned);
    }

    if (value is List) {
      for (final item in value) {
        if (item is String) {
          addTag(item);
        } else if (item is Map<String, dynamic>) {
          final name = item['name'];
          if (name is String) {
            addTag(name);
          }
        }
      }
    } else if (value is String) {
      final parts = value.split(RegExp(r'[，,;；、]'));
      for (final part in parts) {
        addTag(part);
      }
    }

    final seen = <String>{};
    final unique = <String>[];
    for (final tag in results) {
      final key = tag.toLowerCase();
      if (seen.add(key)) {
        unique.add(tag);
      }
    }
    return unique;
  }

  List<String> _extractInlineTags(String input) {
    final matches = RegExp(r'[#@][^\s#@]+').allMatches(input);
    final tags = <String>[];
    for (final match in matches) {
      final raw = match.group(0);
      if (raw == null) continue;
      var cleaned = raw.replaceAll(RegExp(r'^[#@]+'), '').trim();
      if (cleaned.isEmpty) continue;
      tags.add(cleaned);
    }
    return _mergeTags(const <String>[], tags);
  }

  List<String> _mergeTags(List<String> primary, List<String> secondary) {
    final seen = <String>{};
    final merged = <String>[];
    for (final tag in [...primary, ...secondary]) {
      final key = tag.toLowerCase();
      if (seen.add(key)) {
        merged.add(tag);
      }
    }
    return merged;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == 'null') return null;
      try {
        return DateTime.parse(trimmed);
      } catch (_) {
        return null;
      }
    }
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == 'yes' || lower == '1';
    }
    if (value is num) return value != 0;
    return false;
  }

  String? _extractChatContent(Map<String, dynamic> payload) {
    final choices = payload['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          final content = message['content'];
          if (content is String) {
            return content;
          }
        }
        final text = first['text'];
        if (text is String) {
          return text;
        }
      }
    }
    final output = payload['output_text'];
    if (output is String) {
      return output;
    }
    return null;
  }

  String _normalizeEndpoint(String endpoint) {
    var value = endpoint.trim();
    if (value.isEmpty) return value;
    if (!value.contains('://')) {
      value = 'https://$value';
    }
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  String? _extractErrorMessage(String body) {
    try {
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final error = payload['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'] as String?;
        return message?.trim();
      }
      if (error is String) {
        return error.trim();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String? _extractJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      return null;
    }
    return text.substring(start, end + 1);
  }
}
