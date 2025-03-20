import 'player.dart';
import 'match_log_entry.dart';

class Session {
  Map<String, Player> players;
  List<String> currentOrder;
  bool isPaused;
  List<String> activeBeforePause;
  int targetPlayDuration;
  bool enableTargetDuration;
  int matchTime;
  int matchStartTime;
  bool matchRunning;
  int matchDuration;
  bool enableMatchDuration;
  int matchSegments;
  int currentPeriod;
  bool hasWhistlePlayed;
  bool enableSound;
  List<MatchLogEntry> matchLog;

  Session({
    Map<String, Player> players = const {},
    List<String> currentOrder = const [],
    this.isPaused = false,
    List<String> activeBeforePause = const [],
    this.targetPlayDuration = 16 * 60,
    this.enableTargetDuration = false,
    this.matchTime = 0,
    this.matchStartTime = 0,
    this.matchRunning = false,
    this.matchDuration = 90 * 60,
    this.enableMatchDuration = true,
    this.matchSegments = 2,
    this.currentPeriod = 1,
    this.hasWhistlePlayed = false,
    this.enableSound = false,
    List<MatchLogEntry> matchLog = const [],
  })  : players = players,
        currentOrder = currentOrder,
        activeBeforePause = activeBeforePause,
        matchLog = matchLog;

  Map<String, dynamic> toJson() => {
        'players': players.map((name, player) => MapEntry(name, player.toJson())),
        'currentOrder': currentOrder,
        'isPaused': isPaused,
        'activeBeforePause': activeBeforePause,
        'targetPlayDuration': targetPlayDuration,
        'enableTargetDuration': enableTargetDuration,
        'matchTime': matchTime,
        'matchStartTime': matchStartTime,
        'matchRunning': matchRunning,
        'matchDuration': matchDuration,
        'enableMatchDuration': enableMatchDuration,
        'matchSegments': matchSegments,
        'currentPeriod': currentPeriod,
        'hasWhistlePlayed': hasWhistlePlayed,
        'enableSound': enableSound,
        'matchLog': matchLog.map((entry) => entry.toJson()).toList(),
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        players: (json['players'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(key, Player.fromJson(key, value)),
            ) ?? <String, Player>{},
        currentOrder: List<String>.from(json['currentOrder'] ?? []),
        isPaused: json['isPaused'] ?? false,
        activeBeforePause: List<String>.from(json['activeBeforePause'] ?? []),
        targetPlayDuration: json['targetPlayDuration'] ?? 16 * 60,
        enableTargetDuration: json['enableTargetDuration'] ?? false,
        matchTime: json['matchTime'] ?? 0,
        matchStartTime: json['matchStartTime'] ?? 0,
        matchRunning: json['matchRunning'] ?? false,
        matchDuration: json['matchDuration'] ?? 90 * 60,
        enableMatchDuration: json['enableMatchDuration'] ?? true,
        matchSegments: json['matchSegments'] ?? 2,
        currentPeriod: json['currentPeriod'] ?? 1,
        hasWhistlePlayed: json['hasWhistlePlayed'] ?? false,
        enableSound: json['enableSound'] ?? false,
        matchLog: (json['matchLog'] as List<dynamic>?)
                ?.map((entry) => MatchLogEntry.fromJson(entry))
                .toList() ?? <MatchLogEntry>[],
      );
}