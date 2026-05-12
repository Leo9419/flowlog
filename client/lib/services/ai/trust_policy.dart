enum AiTrustLevel {
  low('low'),
  medium('medium'),
  high('high');

  const AiTrustLevel(this.id);
  final String id;

  static AiTrustLevel fromId(String id) {
    return AiTrustLevel.values.firstWhere(
      (level) => level.id == id,
      orElse: () => AiTrustLevel.medium,
    );
  }
}

enum AiTrustRoute {
  executeImmediately,
  suggestionWithUndo,
  mandatoryPreview,
}

class AiTrustPolicy {
  AiTrustPolicy({Map<String, AiTrustLevel> overrides = const {}})
      : _overrides = overrides;

  final Map<String, AiTrustLevel> _overrides;

  AiTrustLevel levelForTool(String toolName, AiTrustLevel defaultLevel) {
    return _overrides[toolName] ?? defaultLevel;
  }

  AiTrustRoute routeFor(AiTrustLevel level) {
    switch (level) {
      case AiTrustLevel.low:
        return AiTrustRoute.executeImmediately;
      case AiTrustLevel.medium:
        return AiTrustRoute.suggestionWithUndo;
      case AiTrustLevel.high:
        return AiTrustRoute.mandatoryPreview;
    }
  }
}
