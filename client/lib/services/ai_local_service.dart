import 'dart:convert';
import 'dart:io';

import '../state/app_settings.dart';

class AiQuickAddDraft {
  const AiQuickAddDraft({
    required this.title,
    this.dueDate,
    this.endDate,
    required this.isAllDay,
    this.notes,
    this.tags = const [],
  });

  final String title;
  final DateTime? dueDate;
  final DateTime? endDate;
  final bool isAllDay;
  final String? notes;
  final List<String> tags;

  AiQuickAddDraft copyWith({
    String? title,
    DateTime? dueDate,
    DateTime? endDate,
    bool? isAllDay,
    String? notes,
    List<String>? tags,
  }) {
    return AiQuickAddDraft(
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      endDate: endDate ?? this.endDate,
      isAllDay: isAllDay ?? this.isAllDay,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
    );
  }
}

class AiLocalService {
  AiLocalService(this._settings, {HttpClient? client})
      : _client = client ?? HttpClient();

  final AppSettings _settings;
  final HttpClient _client;

  void dispose() {
    _client.close(force: true);
  }

  Future<List<String>> fetchAvailableModels() async {
    final endpoint = _normalizeEndpoint(_settings.aiLocalEndpoint);
    if (endpoint.isEmpty) {
      throw const FormatException('missing_config');
    }

    final request = await _client.getUrl(Uri.parse('$endpoint/api/tags'));
    final response = await request.close().timeout(const Duration(seconds: 8));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw FormatException(
          _extractErrorMessage(body) ?? 'http_${response.statusCode}');
    }

    final payload = jsonDecode(body) as Map<String, dynamic>;
    final models = payload['models'] as List<dynamic>? ?? const [];
    final names = <String>[];
    for (final item in models) {
      if (item is Map<String, dynamic>) {
        final name = item['name'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          names.add(name.trim());
        }
      }
    }
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  Future<bool> checkModelAvailable() async {
    final model = _settings.aiLocalModel.trim();
    if (model.isEmpty) {
      throw const FormatException('missing_config');
    }
    final names = await fetchAvailableModels();

    final targetBase = model.split(':').first.toLowerCase();
    for (final name in names) {
      final nameBase = name.split(':').first.toLowerCase();
      if (name.toLowerCase() == model.toLowerCase() || nameBase == targetBase) {
        return true;
      }
    }
    return false;
  }

  Future<AiQuickAddDraft> parseQuickAdd({
    required String input,
    required DateTime now,
  }) async {
    final endpoint = _normalizeEndpoint(_settings.aiLocalEndpoint);
    final model = _settings.aiLocalModel.trim();
    if (endpoint.isEmpty || model.isEmpty) {
      throw const FormatException('missing_config');
    }

    final prompt = _buildQuickAddPrompt(input: input, now: now);
    final request = await _client.postUrl(Uri.parse('$endpoint/api/generate'));
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(jsonEncode({
      'model': model,
      'prompt': prompt,
      'stream': false,
      'format': 'json',
    })));

    final response = await request.close().timeout(const Duration(seconds: 60));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw FormatException(
          _extractErrorMessage(body) ?? 'http_${response.statusCode}');
    }

    final payload = jsonDecode(body) as Map<String, dynamic>;
    final responseText = payload['response'] as String?;
    if (responseText == null || responseText.trim().isEmpty) {
      throw const FormatException('empty_response');
    }

    final jsonText =
        _extractJsonObject(responseText.trim()) ?? responseText.trim();
    final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
    final draft = _parseDraft(parsed, fallbackTitle: input.trim());
    final inlineTags = _extractInlineTags(input);
    if (inlineTags.isEmpty) {
      return draft;
    }
    final mergedTags = _mergeTags(draft.tags, inlineTags);
    return draft.copyWith(tags: mergedTags);
  }

  Future<String> generateSummary({
    required String prompt,
  }) async {
    final endpoint = _normalizeEndpoint(_settings.aiLocalEndpoint);
    final model = _settings.aiLocalModel.trim();
    if (endpoint.isEmpty || model.isEmpty) {
      throw const FormatException('missing_config');
    }

    final request = await _client.postUrl(Uri.parse('$endpoint/api/generate'));
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(jsonEncode({
      'model': model,
      'prompt': prompt,
      'stream': false,
    })));

    final response =
        await request.close().timeout(const Duration(seconds: 120));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw FormatException(
          _extractErrorMessage(body) ?? 'http_${response.statusCode}');
    }

    final payload = jsonDecode(body) as Map<String, dynamic>;
    final responseText = payload['response'] as String?;
    if (responseText == null || responseText.trim().isEmpty) {
      throw const FormatException('empty_response');
    }
    return responseText.trim();
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

  String _buildQuickAddPrompt({
    required String input,
    required DateTime now,
  }) {
    final offset = _formatOffset(now.timeZoneOffset);
    return '''You are a task parser for FlowLog.
Return ONLY a JSON object with keys:
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
- Current local time: ${now.toIso8601String()} (UTC$offset).
Input: $input''';
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

  String _normalizeEndpoint(String endpoint) {
    var value = endpoint.trim();
    if (value.isEmpty) return value;
    if (!value.contains('://')) {
      value = 'http://$value';
    }
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  String? _extractErrorMessage(String body) {
    try {
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final message = payload['error'] as String?;
      return message?.trim();
    } catch (_) {
      return null;
    }
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
