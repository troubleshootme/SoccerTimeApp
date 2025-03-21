class Player {
  String name;
  int totalTime; // Total time in seconds
  bool active;
  int startTime; // Timestamp when player became active (0 if inactive)
  int time; // Current calculated time including active time

  Player({
    required this.name,
    this.totalTime = 0,
    this.active = false,
    this.startTime = 0,
    this.time = 0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'totalTime': totalTime,
        'active': active,
        'startTime': startTime,
        'time': time,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        name: json['name'] as String,
        totalTime: json['totalTime'] ?? 0,
        active: json['active'] ?? false,
        startTime: json['startTime'] ?? 0,
        time: json['time'] ?? 0,
      );
}