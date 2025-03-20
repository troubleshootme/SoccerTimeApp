import 'dart:async';
import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/player.dart';
import '../models/match_log_entry.dart';
import '../services/session_service.dart';
import '../services/audio_service.dart';
import '../utils/format_time.dart';
import '../database.dart';

class AppState with ChangeNotifier {
  Session _session = Session();
  String? _currentSessionPassword;
  bool _isDarkTheme = false;
  Timer? _timer;
  bool _isSaving = false;
  Timer? _saveDebounceTimer;
  final SessionService _sessionService = SessionService();
  final AudioService _audioService = AudioService();
  int? _currentSessionId;
  List<Map<String, dynamic>> _players = [];

  AppState() {
    _loadTheme();
    _startTimer();
  }

  // Getters
  Session get session => _session;
  String? get currentSessionPassword => _currentSessionPassword;
  bool get isDarkTheme => _isDarkTheme;
  int? get currentSessionId => _currentSessionId;
  List<Map<String, dynamic>> get players => _players;

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
    
    try {
      bool exists = await checkSessionExists(password);
      print('Session exists: $exists for password: $password');
      
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
        try {
          _session = await _sessionService.loadSession(password);
          
          // Verify that matchLog is properly initialized
          if (_session.matchLog == null) {
            print('Warning: matchLog was null, initializing empty list');
            _session = Session(
              matchDuration: _session.matchDuration,
              enableMatchDuration: _session.enableMatchDuration,
              matchSegments: _session.matchSegments,
              currentPeriod: _session.currentPeriod,
              players: _session.players,
              matchLog: <MatchLogEntry>[],
            );
          }
          
          _session.matchLog.add(MatchLogEntry(
            matchTime: formatTime(_session.matchTime),
            timestamp: DateTime.now().toIso8601String(),
            details: "Session '$password' resumed",
          ));
        } catch (e) {
          print('Error in session loading: $e');
          // Create a new session if loading fails
          _session = Session(
            matchDuration: 90 * 60,
            enableMatchDuration: true,
            matchSegments: 2,
            currentPeriod: 1,
            players: <String, Player>{},
            matchLog: <MatchLogEntry>[],
          );
          _session.matchLog.add(MatchLogEntry(
            matchTime: formatTime(_session.matchTime),
            timestamp: DateTime.now().toIso8601String(),
            details: "New session created due to loading error",
          ));
        }
      }
      
      await saveSession();
      notifyListeners();
    } catch (e) {
      print('Error in startOrResumeSession: $e');
      // Create a new session as fallback
      _session = Session(
        matchDuration: 90 * 60,
        enableMatchDuration: true,
        matchSegments: 2,
        currentPeriod: 1,
        players: <String, Player>{},
        matchLog: <MatchLogEntry>[],
      );
      _session.matchLog.add(MatchLogEntry(
        matchTime: formatTime(_session.matchTime),
        timestamp: DateTime.now().toIso8601String(),
        details: "New emergency session for '$password'",
      ));
      await saveSession();
      notifyListeners();
    }
  }

  Future<void> exitSession() async {
    await saveSession();
    _currentSessionPassword = null;
    _session = Session();
    await _sessionService.clearSessionPassword();
    notifyListeners();
  }

  // Player Management
  Future<void> addPlayer(String name) async {
    if (_currentSessionId != null) {
      await SessionDatabase.instance.insertPlayer(_currentSessionId!, name, 0);
      _players = await SessionDatabase.instance.getPlayersForSession(_currentSessionId!);
      _players.sort((a, b) => a['name'].compareTo(b['name'])); // Sort players by name
    }
    notifyListeners();
  }

  void togglePlayer(String name) {
    // Don't allow toggling if the period has ended
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
    _timer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (!_session.matchRunning || _session.isPaused) return;
      
      // Check for period end first
      if (_isPeriodEnd()) return;
      
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

      saveSession();
      notifyListeners();
    });
  }

  bool _isPeriodEnd() {
    var periodDuration = _session.matchDuration / _session.matchSegments;
    var periodEndTime = _session.currentPeriod * periodDuration;
    bool isPeriodEnd = _session.enableMatchDuration &&
        _session.matchTime >= periodEndTime &&
        _session.currentPeriod <= _session.matchSegments;
    
    // If we detect period end, ensure the session is paused
    if (isPeriodEnd && !_session.isPaused) {
      _pauseForPeriodEnd();
    }
    
    return isPeriodEnd;
  }

  // New method to handle pausing specifically for period end
  void _pauseForPeriodEnd() {
    var now = DateTime.now().millisecondsSinceEpoch;
    _session.activeBeforePause = [];
    
    // Store all active players
    _session.players.forEach((name, player) {
      if (player.active) {
        _session.activeBeforePause.add(name);
        var elapsed = (now - player.startTime) ~/ 1000;
        player.totalTime += elapsed >= 0 ? elapsed : 0;
        player.active = false;
        player.startTime = 0;
      }
    });
    
    // Update match time
    if (_session.matchRunning) {
      var elapsed = (now - _session.matchStartTime) ~/ 1000;
      _session.matchTime += elapsed >= 0 ? elapsed : 0;
      _session.matchStartTime = 0;
      _session.matchRunning = false;
    }
    
    // Mark as paused and log the event
    _session.isPaused = true;
    _session.matchLog.add(MatchLogEntry(
      matchTime: formatTime(_session.matchTime),
      timestamp: DateTime.now().toIso8601String(),
      details: "Period ${_session.currentPeriod} ended",
    ));
    
    // Play whistle if enabled
    if (_session.enableSound && !_session.hasWhistlePlayed) {
      _audioService.playWhistle();
      _session.hasWhistlePlayed = true;
    }
    
    saveSession();
    notifyListeners();
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
      // Don't automatically start the match - keep it paused
      _session.matchRunning = false;
      
      var periodName = _getPeriodLabel(_session.currentPeriod, _session.matchSegments);
      _session.matchLog.add(MatchLogEntry(
        matchTime: formatTime(_session.matchTime),
        timestamp: DateTime.now().toIso8601String(),
        details: "$periodName ready to start",
      ));
      
      // Keep isPaused true to require explicit resuming
      _session.isPaused = true;
    } else {
      _session.matchRunning = false;
      _session.matchTime = _session.matchDuration;
      _session.currentPeriod = _session.matchSegments + 1;
      _session.isPaused = false; // Game is over, no need to keep paused
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
  Future<void> toggleMatchDuration(bool value) async {
    _session.enableMatchDuration = value;
    await saveSession(immediate: true);
    notifyListeners();
  }

  Future<void> updateMatchDuration(int minutes) async {
    _session.matchDuration = minutes * 60;
    await saveSession(immediate: true);
    notifyListeners();
  }

  Future<void> updateMatchSegments(int segments) async {
    _session.matchSegments = segments;
    _session.currentPeriod = 1;
    _session.hasWhistlePlayed = false;
    await saveSession(immediate: true);
    notifyListeners();
  }

  Future<void> toggleTargetDuration(bool value) async {
    _session.enableTargetDuration = value;
    await saveSession(immediate: true);
    notifyListeners();
  }

  Future<void> updateTargetDuration(int minutes) async {
    _session.targetPlayDuration = minutes * 60;
    await saveSession(immediate: true);
    notifyListeners();
  }

  Future<void> toggleSound(bool value) async {
    _session.enableSound = value;
    await saveSession(immediate: true);
    notifyListeners();
  }

  // Session Persistence
  Future<void> saveSession({bool immediate = false}) async {
    if (_currentSessionPassword == null) return;
    
    // Cancel any pending save operations
    _saveDebounceTimer?.cancel();
    
    // For immediate saves, don't use debounce
    if (immediate) {
      if (_isSaving) {
        // Wait for current save to finish
        await Future.delayed(Duration(milliseconds: 100));
        return saveSession(immediate: true);
      }
      
      try {
        _isSaving = true;
        await _sessionService.saveSession(_currentSessionPassword!, _session);
        print('Session saved immediately at ${DateTime.now()}');
      } catch (e) {
        print('Error saving session immediately: $e');
      } finally {
        _isSaving = false;
      }
      return;
    }
    
    // For regular saves, use debounce
    _saveDebounceTimer = Timer(Duration(milliseconds: 300), () async {
      if (_isSaving) return;
      
      try {
        _isSaving = true;
        await _sessionService.saveSession(_currentSessionPassword!, _session);
        print('Session saved at ${DateTime.now()}');
      } catch (e) {
        print('Error saving session: $e');
      } finally {
        _isSaving = false;
      }
    });
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

  Future<void> loadSession(int sessionId) async {
    _currentSessionId = sessionId;
    _players = await SessionDatabase.instance.getPlayersForSession(sessionId);
    _players.sort((a, b) => a['name'].compareTo(b['name'])); // Sort players by name
    notifyListeners();
  }

  Future<void> createSession(String name) async {
    _currentSessionId = await SessionDatabase.instance.insertSession(name);
    _players = []; // Reset players for the new session
    notifyListeners();
  }

  Future<void> updatePlayerTimer(int playerId, int timerSeconds) async {
    if (_currentSessionId != null) {
      await SessionDatabase.instance.updatePlayerTimer(playerId, timerSeconds);
      _players = await SessionDatabase.instance.getPlayersForSession(_currentSessionId!);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _saveDebounceTimer?.cancel();
    super.dispose();
  }
}