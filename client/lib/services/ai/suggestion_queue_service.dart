import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../database/database.dart';
import 'tool_registry.dart';

enum AiSuggestionSurface {
  chat('chat'),
  today('today'),
  inbox('inbox'),
  project('project'),
  autoplan('autoplan');

  const AiSuggestionSurface(this.id);
  final String id;
}

class AiSuggestionQueueService {
  AiSuggestionQueueService(this._db);

  final AppDatabase _db;

  Future<String> enqueue({
    required AiSuggestionSurface surface,
    required String toolName,
    required Map<String, dynamic> args,
    required String previewText,
    required Map<String, dynamic> preview,
    String? conversationId,
  }) async {
    final id = const Uuid().v4();
    await _db.into(_db.aiSuggestions).insert(
          AiSuggestionsCompanion(
            id: Value(id),
            surface: Value(surface.id),
            toolName: Value(toolName),
            argsJson: Value(jsonEncode(args)),
            previewText: Value(previewText),
            previewJson: Value(jsonEncode(preview)),
            conversationId: Value(conversationId),
            createdAt: Value(DateTime.now()),
          ),
        );
    return id;
  }

  Future<List<AiSuggestion>> pending({AiSuggestionSurface? surface}) {
    final query = _db.select(_db.aiSuggestions)
      ..where((s) => s.status.equals('pending'))
      ..orderBy([
        (s) => OrderingTerm(
              expression: s.createdAt,
              mode: OrderingMode.desc,
            ),
      ]);
    if (surface != null) {
      query.where((s) => s.surface.equals(surface.id));
    }
    return query.get();
  }

  Future<void> markAccepted(String id) async {
    await (_db.update(_db.aiSuggestions)..where((s) => s.id.equals(id))).write(
      AiSuggestionsCompanion(
        status: const Value('accepted'),
        resolvedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markRejected(String id, {String? reason}) async {
    await (_db.update(_db.aiSuggestions)..where((s) => s.id.equals(id))).write(
      AiSuggestionsCompanion(
        status: const Value('rejected'),
        rejectionReason: Value(reason),
        resolvedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<AiToolResult> accept(
    String id, {
    required AiToolRegistry registry,
    required AiToolContext context,
  }) async {
    final suggestion = await (_db.select(_db.aiSuggestions)
          ..where((s) => s.id.equals(id)))
        .getSingle();
    final args = jsonDecode(suggestion.argsJson) as Map<String, dynamic>;
    final result = await registry.require(suggestion.toolName).execute(
          args,
          context,
        );
    if (result.ok) {
      await markAccepted(id);
    }
    return result;
  }
}
