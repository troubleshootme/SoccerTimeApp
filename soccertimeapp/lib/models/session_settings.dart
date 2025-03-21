class SessionSettings {
  final bool enableMatchDuration;
  final int matchDuration;
  final int matchSegments;
  final bool enableTargetDuration;
  final int targetPlayDuration;
  final bool enableSound;

  SessionSettings({
    this.enableMatchDuration = false,
    this.matchDuration = 90,
    this.matchSegments = 2,
    this.enableTargetDuration = false,
    this.targetPlayDuration = 20,
    this.enableSound = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'enableMatchDuration': enableMatchDuration,
      'matchDuration': matchDuration,
      'matchSegments': matchSegments,
      'enableTargetDuration': enableTargetDuration,
      'targetPlayDuration': targetPlayDuration,
      'enableSound': enableSound,
    };
  }

  factory SessionSettings.fromMap(Map<String, dynamic> map) {
    return SessionSettings(
      enableMatchDuration: map['enableMatchDuration'] ?? false,
      matchDuration: map['matchDuration'] ?? 90,
      matchSegments: map['matchSegments'] ?? 2,
      enableTargetDuration: map['enableTargetDuration'] ?? false,
      targetPlayDuration: map['targetPlayDuration'] ?? 20,
      enableSound: map['enableSound'] ?? true,
    );
  }
} 