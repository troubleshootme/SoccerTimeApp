import 'dart:async';
import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/player.dart';
import '../models/match_log_entry.dart';
import '../services/session_service.dart';
import '../services/audio_service.dart';
import '../utils/format_time.dart';

class AppState with ChangeNotifier {
  Session _session = Session();
  String? _currentSessionPassword;
  bool _isDarkTheme = true;
  Timer? _timer;
  bool _isSaving = false;
  final SessionService _sessionService = SessionService();
  final AudioService _audioService = AudioService();

  AppState() {
    _loadTheme();
    _startTimer();
  }

  // Getters
  Session get session => _session;
  String? get currentSessionPassword => _currentSessionPassword;
  bool get isDarkTheme => _isDarkTheme;

  // Setter for session
  set session(Session newSession) {
    _session = newSession;
    notifyListeners();
  }

  // Theme Management
  void _loadTheme() async {
    _isDarkTheme = await _sessionService.loadTheme();
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkTheme = !_isDarkTheme;
    _sessionService.saveTheme(_isDarkTheme);
    notifyListeners();
  }

  // Session Management
  Future<bool> checkSessionExists(String password) async {
    return await _sessionService.checkSessionExists(password);
  }

  Future<void> startOrResumeSession(String password) async {
    _currentSessionPassword = password;
    await _sessionService.saveSessionPassword(password);
    bool exists = await checkSessionExists(password);
    if (!exists) {
      _session = Session(
        matchDuration: 90 * 60, // 90 minutes
        enableMatchDuration: true,
        matchSegments: 2, // Ensure this is set to 2 for halves (H1, H2)
        currentPeriod: 1,
        players: <String, Player>{}, // Explicitly mutable map
        matchLog: <MatchLogEntry>[], // Explicitly mutable list
      );
      try {
        _session.matchLog.add(MatchLogEntry(
          matchTime: formatTime(_session.matchTime),
          timestamp: DateTime.now().toIso8601String(),
          details: "New session '$password' started",
        ));
        print('New session created for password: $password');
      } catch (e) {
        print('Error adding match log entry for new session: $e');
        // Optionally, reinitialize matchLog to ensure it's mutable
        _session.matchLog = [];
        _session.matchLog.add(MatchLogEntry(
          matchTime: formatTime(_session.matchTime),
          timestamp: DateTime.now().toIso8601String(),
          details: "New session '$password' started",
        ));
      }
    } else {
      _session = await _sessionService.loadSession(password);
      _session.matchLog.add(MatchLogEntry(
        matchTime: formatTime(_session.matchTime),
        timestamp: DateTime.now().toIso8601String(),
        details: "Session '$password' resumed",
      ));
    }
    await saveSession();
    notifyListeners();
  }

  Future<void> exitSession() async {
    await saveSession();
    _currentSessionPassword = null;
    _session = Session();
    await _sessionService.clearSessionPassword();
    notifyListeners();
  }

  // Player Management
  void addPlayer(String name) {
    if (_session.players.containsKey(name)) return;
    var player = Player(name: name);
    try {
      _session.players[name] = player; // Attempt to add player
    } catch (e) {
      print('Error adding player: $e');
      // Reinitialize session with the new player
      _session = Session(players: {..._session.players, name: player}, matchLog: _session.matchLog);
    }
    _session.currentOrder.add(name);
    _session.matchLog.add(MatchLogEntry(
      matchTime: formatTime(_session.matchTime),
      timestamp: DateTime.now().toIso8601String(),
      details: "$name added to roster",
    ));
    saveSession();
    notifyListeners();
  }

  void togglePlayer(String name) {
    if (_session.isPaused || _isPeriodEnd()) return;
    var player = _session.players[name]!;
    var now = DateTime.now().millisecondsSinceEpoch;
    if (!player.active) {
      player.active = true;
      player.startTime = now;
      if (!_session.matchRunning) {
        _session.matchStartTime = now;
        _session.matchRunning = true;
      }
      _session.matchLog.add(MatchLogEntry(
        matchTime: formatTime(_session.matchTime),
        timestamp: DateTime.now().toIso8601String(),
        details: "$name entered the game",
      ));
    } else {
      player.active = false;
      var elapsed = (now - player.startTime) ~/ 1000;
      player.totalTime += elapsed >= 0 ? elapsed : 0;
      player.startTime = 0;
      if (_session.matchRunning && _session.players.values.every((p) => !p.active)) {
        var matchElapsed = (now - _session.matchStartTime) ~/ 1000;
        _session.matchTime += matchElapsed >= 0 ? matchElapsed : 0;
        _session.matchRunning = false;
      }
      _session.matchLog.add(MatchLogEntry(
        matchTime: formatTime(_session.matchTime),
        timestamp: DateTime.now().toIso8601String(),
        details: "$name left the game",
      ));
    }
    saveSession();
    notifyListeners();
  }

  void resetPlayerTime(String name) {
    var player = _session.players[name]!;
    player.time = 0;
    player.totalTime = 0;
    player.active = false;
    player.startTime = 0;
    if (_session.matchRunning && _session.players.values.every((p) => !p.active)) {
      var now = DateTime.now().millisecondsSinceEpoch;
      var elapsed = (now - _session.matchStartTime) ~/ 1000;
      _session.matchTime += elapsed >= 0 ? elapsed : 0;
      _session.matchRunning = false;
    }
    _session.matchLog.add(MatchLogEntry(
      matchTime: formatTime(_session.matchTime),
      timestamp: DateTime.now().toIso8601String(),
      details: "$name's time reset to 0",
    ));
    saveSession();
    notifyListeners();
  }

  void removePlayer(String name) {
    _session.players.remove(name);
    _session.currentOrder.remove(name);
    if (_session.matchRunning && _session.players.values.every((p) => !p.active)) {
      var now = DateTime.now().millisecondsSinceEpoch;
      var elapsed = (now - _session.matchStartTime) ~/ 1000;
      _session.matchTime += elapsed >= 0 ? elapsed : 0;
      _session.matchRunning = false;
    }
    _session.matchLog.add(MatchLogEntry(
      matchTime: formatTime(_session.matchTime),
      timestamp: DateTime.now().toIso8601String(),
      details: "$name removed from roster",
    ));
    saveSession();
    notifyListeners();
  }

  void resetAll() {
    _session.players.forEach((name, player) {
      player.time = 0;
      player.totalTime = 0;
      player.active = false;
      player.startTime = 0;
    });
    _session.matchTime = 0;
    _session.matchStartTime = 0;
    _session.matchRunning = false;
    _session.currentPeriod = 1;
    _session.hasWhistlePlayed = false;
    _session.matchLog = [];
    _session.matchLog.add(MatchLogEntry(
      matchTime: formatTime(_session.matchTime),
      timestamp: DateTime.now().toIso8601String(),
      details: "All times and log reset",
    ));
    saveSession();
    notifyListeners();
  }

  // Match Timer Management
  void _startTimer() {
    _timer = Timer.periodic(Duration(milliseconds: 1000), (timer) {
      if (!_session.matchRunning || _session.isPaused || _isPeriodEnd()) return;
      var now = DateTime.now().millisecondsSinceEpoch;
      var anyPlayerActive = false;
      var maxPlayerTime = 0;

      _session.players.forEach((name, player) {
        if (player.active && player.startTime > 0) {
          var elapsed = (now - player.startTime) ~/ 1000;
          player.time = player.totalTime + (elapsed >= 0 ? elapsed : 0);
          anyPlayerActive = true;
          maxPlayerTime = maxPlayerTime > player.time ? maxPlayerTime : player.time;
        }
      });

      if (anyPlayerActive && _session.matchRunning && _session.matchStartTime > 0) {
        var elapsed = (now - _session.matchStartTime) ~/ 1000;
        _session.matchTime = (_session.matchTime + (elapsed >= 0 ? elapsed : 0)) > maxPlayerTime
            ? _session.matchTime + (elapsed >= 0 ? elapsed : 0)
            : maxPlayerTime;
        _session.matchStartTime = now;
      } else {
        _session.matchTime = _session.matchTime > maxPlayerTime ? _session.matchTime : maxPlayerTime;
      }

      if (_isPeriodEnd() && _session.enableMatchDuration) {
        _session.matchRunning = false;
        if (_session.enableSound && !_session.hasWhistlePlayed) {
          _audioService.playWhistle();
          _session.hasWhistlePlayed = true;
        }
      }

      saveSession();
      notifyListeners();
    });
  }

  bool _isPeriodEnd() {
    var periodDuration = _session.matchDuration / _session.matchSegments;
    var periodEndTime = _session.currentPeriod * periodDuration;
    return _session.matchTime >= periodEndTime && _session.currentPeriod <= _session.matchSegments;
  }

  void pauseAll() {
    var now = DateTime.now().millisecondsSinceEpoch;
    if (!_session.isPaused && !_isPeriodEnd()) {
      _session.activeBeforePause = [];
      _session.players.forEach((name, player) {
        if (player.active) {
          _session.activeBeforePause.add(name);
          var elapsed = (now - player.startTime) ~/ 1000;
          player.totalTime += elapsed >= 0 ? elapsed : 0;
          player.active = false;
          player.startTime = 0;
        }
      });
      if (_session.matchRunning) {
        var elapsed = (now - _session.matchStartTime) ~/ 1000;
        _session.matchTime += elapsed >= 0 ? elapsed : 0;
        _session.matchStartTime = 0;
        _session.matchRunning = false;
      }
      _session.matchLog.add(MatchLogEntry(
        matchTime: formatTime(_session.matchTime),
        timestamp: DateTime.now().toIso8601String(),
        details: "Match paused",
      ));
      _session.isPaused = true;
    } else if (_session.isPaused) {
      now = DateTime.now().millisecondsSinceEpoch;
      for (var name in _session.activeBeforePause) {
        var player = _session.players[name];
        if (player != null) {
          player.active = true;
          player.startTime = now;
        }
      }
      if (_session.activeBeforePause.isNotEmpty && !_session.matchRunning) {
        _session.matchStartTime = now;
        _session.matchRunning = true;
      }
      _session.matchLog.add(MatchLogEntry(
        matchTime: formatTime(_session.matchTime),
        timestamp: DateTime.now().toIso8601String(),
        details: "Match resumed",
      ));
      _session.isPaused = false;
      _session.activeBeforePause = [];
    }
    saveSession();
    notifyListeners();
  }

  void startNextPeriod() {
    var now = DateTime.now().millisecondsSinceEpoch;
    _session.currentPeriod++;
    _session.hasWhistlePlayed = false;
    if (_session.currentPeriod <= _session.matchSegments) {
      _session.matchStartTime = now;
      _session.matchRunning = true;
      for (var name in _session.activeBeforePause) {
        var player = _session.players[name];
        if (player != null) {
          player.active = true;
          player.startTime = now;
        }
      }
      _session.activeBeforePause = [];
      var periodName = _getPeriodLabel(_session.currentPeriod, _session.matchSegments);
      _session.matchLog.add(MatchLogEntry(
        matchTime: formatTime(_session.matchTime),
        timestamp: DateTime.now().toIso8601String(),
        details: "$periodName started",
      ));
      _session.isPaused = false;
    } else {
      _session.matchRunning = false;
      _session.matchTime = _session.matchDuration;
      _session.currentPeriod = _session.matchSegments + 1;
      _session.isPaused = false;
      _session.matchLog.add(MatchLogEntry(
        matchTime: formatTime(_session.matchTime),
        timestamp: DateTime.now().toIso8601String(),
        details: "Match completed",
      ));
    }
    saveSession();
    notifyListeners();
  }

  String _getPeriodLabel(int period, int segments) {
    var suffix = segments == 2 ? 'Half' : 'Quarter';
    return '$period${period == 1 ? 'st' : period == 2 ? 'nd' : period == 3 ? 'rd' : 'th'} $suffix';
  }

  // Settings Management
  void toggleMatchDuration(bool value) {
    _session.enableMatchDuration = value;
    saveSession();
    notifyListeners();
  }

  void updateMatchDuration(int minutes) {
    _session.matchDuration = minutes * 60;
    saveSession();
    notifyListeners();
  }

  void updateMatchSegments(int segments) {
    _session.matchSegments = segments;
    _session.currentPeriod = 1;
    _session.hasWhistlePlayed = false;
    saveSession();
    notifyListeners();
  }

  void toggleTargetDuration(bool value) {
    _session.enableTargetDuration = value;
    saveSession();
    notifyListeners();
  }

  void updateTargetDuration(int minutes) {
    _session.targetPlayDuration = minutes * 60;
    saveSession();
    notifyListeners();
  }

  void toggleSound(bool value) {
    _session.enableSound = value;
    saveSession();
    notifyListeners();
  }

  // Session Persistence
  Future<void> saveSession() async {
    if (_currentSessionPassword == null || _isSaving) return;
    _isSaving = true;
    await _sessionService.saveSession(_currentSessionPassword!, _session);
    _isSaving = false;
  }

  Future<String?> loadSessionPassword() async {
    return await _sessionService.loadSessionPassword();
  }

  void startNewSession(String password) async {
    _session = Session(
      matchDuration: 90 * 60, // 90 minutes
      enableMatchDuration: true,
      matchSegments: 2, // Ensure this is set to 2 for halves (H1, H2)
      currentPeriod: 1,
    );

    try {
      _session.matchLog.add(MatchLogEntry(
        matchTime: formatTime(_session.matchTime),
        timestamp: DateTime.now().toIso8601String(),
        details: "New session '$password' started",
      ));
    } catch (e) {
      print('Error adding match log entry for new session: $e');
      // Optionally, reinitialize matchLog to ensure it's mutable
      _session.matchLog = [];
      _session.matchLog.add(MatchLogEntry(
        matchTime: formatTime(_session.matchTime),
        timestamp: DateTime.now().toIso8601String(),
        details: "New session '$password' started",
      ));
    }
    await saveSession();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}