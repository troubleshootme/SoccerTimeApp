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
  
  // Match log
  final List<MatchLogEntry> matchLog = [];
  
  Session({
    this.sessionName = '',
    this.enableMatchDuration = false,
    this.matchDuration = 5400, // 90 minutes in seconds
    this.matchSegments = 2,
    this.enableTargetDuration = false,
    this.targetPlayDuration = 1200, // 20 minutes in seconds
    this.enableSound = true,
  });
  
  // Clear the match log
  void clearMatchLog() {
    matchLog.clear();
  }
  
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
  
  // Format the current match time as mm:ss
  String get formattedMatchTime {
    final minutes = matchTime ~/ 60;
    final seconds = matchTime % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  // Add a new log entry
  void addMatchLogEntry(String details) {
    final entry = MatchLogEntry(
      matchTime: formattedMatchTime,
      timestamp: DateTime.now().toIso8601String(),
      details: details,
    );
    matchLog.add(entry);
  }
  
  // Get match log entries sorted by timestamp (newest first)
  List<MatchLogEntry> getSortedMatchLog() {
    final sortedLog = List<MatchLogEntry>.from(matchLog);
    sortedLog.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first
    return sortedLog;
  }
  
  // Get match log entries sorted by match time in ascending order
  List<MatchLogEntry> getSortedMatchLogAscending() {
    final sortedLog = List<MatchLogEntry>.from(matchLog);
    
    // First convert match time strings to comparable values (minutes * 60 + seconds)
    Map<MatchLogEntry, int> timeValues = {};
    for (var entry in sortedLog) {
      final parts = entry.matchTime.split(':');
      if (parts.length == 2) {
        final minutes = int.tryParse(parts[0]) ?? 0;
        final seconds = int.tryParse(parts[1]) ?? 0;
        timeValues[entry] = minutes * 60 + seconds;
      } else {
        timeValues[entry] = 0;
      }
    }
    
    // Sort based on the time values (ascending)
    sortedLog.sort((a, b) => timeValues[a]!.compareTo(timeValues[b]!));
    return sortedLog;
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
        'matchLog': matchLog.map((entry) => entry.toJson()).toList(),
        'sessionName': sessionName,
      };

  factory Session.fromJson(Map<String, dynamic> json) {
    final session = Session(
      sessionName: json['sessionName'] ?? '',
      enableMatchDuration: json['enableMatchDuration'] ?? false,
      matchDuration: json['matchDuration'] ?? 5400,
      matchSegments: json['matchSegments'] ?? 2,
      enableTargetDuration: json['enableTargetDuration'] ?? false,
      targetPlayDuration: json['targetPlayDuration'] ?? 1200,
      enableSound: json['enableSound'] ?? true,
    );
    
    // Load match log if available
    if (json['matchLog'] is List) {
      for (var entry in json['matchLog']) {
        if (entry is Map<String, dynamic>) {
          session.matchLog.add(MatchLogEntry.fromJson(entry));
        }
      }
    }
    
    return session;
  }
}