import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../database/database.dart';
import 'trust_policy.dart';

enum AiActionOrigin {
  chat('chat'),
  autoplan('autoplan'),
  card('card'),
  coach('coach');

  const AiActionOrigin(this.id);
  final String id;
}

class AiActionLogService {
  AiActionLogService(this._db);

  final AppDatabase _db;

  Future<String> record({
    required String toolName,
    required String argsJson,
    required String resultJson,
    required AiTrustLevel trustLevel,
    required AiActionOrigin origin,
    String? conversationId,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    await _db.into(_db.aiActionLog).insert(
          AiActionLogCompanion(
            id: Value(id),
            toolName: Value(toolName),
            argsJson: Value(argsJson),
            resultJson: Value(resultJson),
            trustLevel: Value(trustLevel.id),
            origin: Value(origin.id),
            conversationId: Value(conversationId),
            createdAt: Value(now),
          ),
        );
    return id;
  }
}
