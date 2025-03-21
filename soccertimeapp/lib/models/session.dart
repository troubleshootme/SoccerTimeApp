import '../models/player.dart';
import '../models/match_log_entry.dart';

class Session {
  final Map<String, Player> players = {};
  final List<String> currentOrder = [];
  List<String> activeBeforePause = [];
  
  int matchTime = 0;
  int currentPeriod = 1;
  bool hasWhistlePlayed = false;
  bool matchRunning = false;
  bool isPaused = false;
  
  // Settings
  bool enableMatchDuration;
  int matchDuration;
  int matchSegments;
  bool enableTargetDuration;
  int targetPlayDuration;
  bool enableSound;
  
  // Session name
  String sessionName;
  
  Session({
    this.sessionName = '',
    this.enableMatchDuration = false,
    this.matchDuration = 5400, // 90 minutes in seconds
    this.matchSegments = 2,
    this.enableTargetDuration = false,
    this.targetPlayDuration = 1200, // 20 minutes in seconds
    this.enableSound = true,
  });
  
  void addPlayer(String name) {
    if (!players.containsKey(name)) {
      players[name] = Player(name: name);
      currentOrder.add(name);
    }
  }
  
  void updatePlayerTime(String name, int seconds) {
    if (players.containsKey(name)) {
      players[name]!.totalTime = seconds;
      players[name]!.time = seconds;
    }
  }
  
  void resetAllPlayers() {
    // Reset all player timers but keep the players
    for (var player in players.values) {
      player.totalTime = 0;
      player.time = 0;
      player.active = false;
      player.startTime = 0;
    }
  }
  
  void resetSessionState() {
    // Reset match time and period tracking
    matchTime = 0;
    currentPeriod = 1;
    hasWhistlePlayed = false;
    matchRunning = false;
    isPaused = false;
    
    // Clear active before pause list
    activeBeforePause.clear();
  }
  
  void togglePlayerActive(String name) {
    if (players.containsKey(name)) {
      players[name]!.active = !players[name]!.active;
    }
  }

  Map<String, dynamic> toJson() => {
        'players': players.map((name, player) => MapEntry(name, player.toJson())),
        'currentOrder': currentOrder,
        'isPaused': isPaused,
        'activeBeforePause': activeBeforePause,
        'targetPlayDuration': targetPlayDuration,
        'enableTargetDuration': enableTargetDuration,
        'matchTime': matchTime,
        'matchStartTime': 0,
        'matchRunning': matchRunning,
        'matchDuration': matchDuration,
        'enableMatchDuration': enableMatchDuration,
        'matchSegments': matchSegments,
        'currentPeriod': currentPeriod,
        'hasWhistlePlayed': hasWhistlePlayed,
        'enableSound': enableSound,
        'matchLog': [],
        'sessionName': sessionName,
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        sessionName: json['sessionName'] ?? '',
        enableMatchDuration: json['enableMatchDuration'] ?? false,
        matchDuration: json['matchDuration'] ?? 5400,
        matchSegments: json['matchSegments'] ?? 2,
        enableTargetDuration: json['enableTargetDuration'] ?? false,
        targetPlayDuration: json['targetPlayDuration'] ?? 1200,
        enableSound: json['enableSound'] ?? true,
      );
}