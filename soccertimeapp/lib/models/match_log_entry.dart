class MatchLogEntry {
  String matchTime;
  String timestamp;
  String details;

  MatchLogEntry({
    required this.matchTime,
    required this.timestamp,
    required this.details,
  });

  Map<String, dynamic> toJson() => {
        'matchTime': matchTime,
        'timestamp': timestamp,
        'details': details,
      };

  factory MatchLogEntry.fromJson(Map<String, dynamic> json) => MatchLogEntry(
        matchTime: json['matchTime'] ?? '',
        timestamp: json['timestamp'] ?? '',
        details: json['details'] ?? '',
      );
}