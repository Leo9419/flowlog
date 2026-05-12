class AiPrivacyFilter {
  const AiPrivacyFilter({
    this.highPrivacyMode = false,
    this.includeNotes = false,
  });

  final bool highPrivacyMode;
  final bool includeNotes;

  Map<String, dynamic> taskPayload({
    required String id,
    required String title,
    required int whenType,
    required DateTime? dueDate,
    required DateTime? deadline,
    required int priority,
    required String? projectName,
    required List<String> tagNames,
    required String? notes,
    required String? deviceId,
    required String? accountId,
    required String? etag,
    required DateTime? completedAt,
  }) {
    final payload = <String, dynamic>{
      'id': id,
      'title': title,
      'when_type': whenType,
      'due_date': dueDate?.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'priority': priority,
      'project_name':
          highPrivacyMode ? _hashedLabel('project', projectName) : projectName,
      'tag_names': highPrivacyMode
          ? tagNames.map((name) => _hashedLabel('tag', name)).toList()
          : tagNames,
      'completed_at': completedAt?.toIso8601String(),
    };
    if (includeNotes && !highPrivacyMode && notes != null && notes.isNotEmpty) {
      payload['notes'] = notes;
    }
    return payload;
  }

  String? _hashedLabel(String prefix, String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return '${prefix}_${_hash6(value)}';
  }

  String _hash6(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0').substring(0, 6);
  }
}
