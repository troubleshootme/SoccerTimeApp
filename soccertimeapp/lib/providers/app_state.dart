import 'package:flutter/material.dart';
import '../database.dart';
import '../models/session.dart';
import '../models/player.dart';

class AppState with ChangeNotifier {
  bool _isDarkTheme = true;
  int? _currentSessionId;
  List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> _sessions = [];
  String? _currentSessionPassword;
  Session _session = Session();

  int? get currentSessionId => _currentSessionId;
  List<Map<String, dynamic>> get players => _players;
  List<Map<String, dynamic>> get sessions => _sessions;
  String? get currentSessionPassword => _currentSessionPassword;
  Session get session => _session;

  set session(Session newSession) {
    _session = newSession;
    notifyListeners();
  }

  Future<void> loadSession(int sessionId) async {
    _currentSessionId = sessionId;
    _players = await SessionDatabase.instance.getPlayersForSession(sessionId);
    _players.sort((a, b) => a['name'].compareTo(b['name']));
    
    // Initialize session with default values
    _session = Session();
    
    // Load session settings if they exist
    final settings = await SessionDatabase.instance.getSessionSettings(sessionId);
    if (settings != null) {
      _session = Session(
        enableMatchDuration: settings['enableMatchDuration'],
        matchDuration: settings['matchDuration'],
        matchSegments: settings['matchSegments'],
        enableTargetDuration: settings['enableTargetDuration'],
        targetPlayDuration: settings['targetPlayDuration'],
        enableSound: settings['enableSound'],
      );
    }
    
    // Initialize players from database
    for (var player in _players) {
      _session.addPlayer(player['name']);
      _session.updatePlayerTime(player['name'], player['timer_seconds'] ?? 0);
    }
    
    notifyListeners();
  }

  Future<void> createSession(String name) async {
    _currentSessionId = await SessionDatabase.instance.insertSession(name);
    _currentSessionPassword = name;
    _players = [];
    _session = Session();
    notifyListeners();
  }

  Future<void> updatePlayerTimer(int playerId, int timerSeconds) async {
    if (_currentSessionId != null) {
      await SessionDatabase.instance.updatePlayerTimer(playerId, timerSeconds);
      _players = await SessionDatabase.instance.getPlayersForSession(_currentSessionId!);
      
      final playerIndex = _players.indexWhere((p) => p['id'] == playerId);
      if (playerIndex != -1) {
        final playerName = _players[playerIndex]['name'];
        _session.updatePlayerTime(playerName, timerSeconds);
      }
    }
    notifyListeners();
  }

  bool get isDarkTheme => _isDarkTheme;

  void toggleTheme() {
    _isDarkTheme = !_isDarkTheme;
    notifyListeners();
  }

  void addPlayer(String name) async {
    if (_currentSessionId != null) {
      await SessionDatabase.instance.insertPlayer(_currentSessionId!, name, 0);
      _players = await SessionDatabase.instance.getPlayersForSession(_currentSessionId!);
      _players.sort((a, b) => a['name'].compareTo(b['name']));
      
      _session.addPlayer(name);
    } else {
      _players.add({'name': name, 'timer_seconds': 0});
      _session.addPlayer(name);
    }
    notifyListeners();
  }
  
  Future<void> toggleMatchDuration(bool value) async {
    _session.enableMatchDuration = value;
    await saveSession();
    notifyListeners();
  }
  
  Future<void> updateMatchDuration(int minutes) async {
    _session.matchDuration = minutes * 60;
    await saveSession();
    notifyListeners();
  }
  
  Future<void> updateMatchSegments(int segments) async {
    _session.matchSegments = segments;
    await saveSession();
    notifyListeners();
  }
  
  Future<void> toggleTargetDuration(bool value) async {
    _session.enableTargetDuration = value;
    await saveSession();
    notifyListeners();
  }
  
  Future<void> updateTargetDuration(int minutes) async {
    _session.targetPlayDuration = minutes * 60;
    await saveSession();
    notifyListeners();
  }
  
  Future<void> toggleSound(bool value) async {
    _session.enableSound = value;
    await saveSession();
    notifyListeners();
  }
  
  Future<void> saveSession() async {
    if (_currentSessionId != null) {
      // Update all player times in the database
      for (var player in _players) {
        final name = player['name'];
        if (_session.players.containsKey(name)) {
          final totalTime = _session.players[name]!.totalTime;
          await SessionDatabase.instance.updatePlayerTimer(player['id'], totalTime);
        }
      }
      
      // Save session settings to the database
      await SessionDatabase.instance.saveSessionSettings(_currentSessionId!, {
        'enableMatchDuration': _session.enableMatchDuration,
        'matchDuration': _session.matchDuration,
        'matchSegments': _session.matchSegments,
        'enableTargetDuration': _session.enableTargetDuration,
        'targetPlayDuration': _session.targetPlayDuration,
        'enableSound': _session.enableSound,
      });
    }
    
    notifyListeners();
  }

  Future<void> loadSessions() async {
    _sessions = await SessionDatabase.instance.getAllSessions();
    notifyListeners();
  }

  Future<void> setCurrentSession(int sessionId) async {
    _currentSessionId = sessionId;
    _players = await SessionDatabase.instance.getPlayersForSession(sessionId);
    
    // Initialize an empty session
    _session = Session(
      enableMatchDuration: false,
      matchDuration: 90,
      matchSegments: 2,
      enableTargetDuration: false,
      targetPlayDuration: 20,
      enableSound: true,
    );
    
    // Load session settings if they exist
    final settings = await SessionDatabase.instance.getSessionSettings(sessionId);
    if (settings != null) {
      _session = Session(
        enableMatchDuration: settings['enableMatchDuration'],
        matchDuration: settings['matchDuration'],
        matchSegments: settings['matchSegments'],
        enableTargetDuration: settings['enableTargetDuration'],
        targetPlayDuration: settings['targetPlayDuration'],
        enableSound: settings['enableSound'],
      );
    }
    
    // Initialize players
    for (var player in _players) {
      final name = player['name'];
      final timerSeconds = player['timer_seconds'];
      _session.players[name] = Player(name: name, totalTime: timerSeconds);
    }
    
    notifyListeners();
  }

  Future<void> togglePlayer(String name) async {
    if (_session.players.containsKey(name)) {
      final player = _session.players[name]!;
      player.active = !player.active;
      
      if (player.active) {
        player.startTime = DateTime.now().millisecondsSinceEpoch;
      } else {
        // Calculate the time spent active
        final timeElapsed = (DateTime.now().millisecondsSinceEpoch - player.startTime) ~/ 1000;
        player.totalTime += timeElapsed;
        
        // Save the updated time
        final playerIndex = _players.indexWhere((p) => p['name'] == name);
        if (playerIndex != -1 && _currentSessionId != null) {
          await updatePlayerTimer(_players[playerIndex]['id'], player.totalTime);
        }
      }
      
      notifyListeners();
    }
  }
  
  Future<void> resetPlayerTime(String name) async {
    if (_session.players.containsKey(name)) {
      final player = _session.players[name]!;
      player.totalTime = 0;
      player.time = 0;
      player.active = false;
      
      // Save the updated time
      final playerIndex = _players.indexWhere((p) => p['name'] == name);
      if (playerIndex != -1 && _currentSessionId != null) {
        await updatePlayerTimer(_players[playerIndex]['id'], 0);
      }
      
      notifyListeners();
    }
  }
  
  Future<void> removePlayer(String name) async {
    if (_session.players.containsKey(name)) {
      // Remove from session
      _session.players.remove(name);
      
      // Remove from DB if needed
      if (_currentSessionId != null) {
        final playerIndex = _players.indexWhere((p) => p['name'] == name);
        if (playerIndex != -1) {
          final playerId = _players[playerIndex]['id'];
          // Ideally we'd have a deletePlayer method in the database class
          // For now, we'll just remove from our local list
          _players.removeAt(playerIndex);
        }
      } else {
        _players.removeWhere((p) => p['name'] == name);
      }
      
      notifyListeners();
    }
  }
  
  Future<void> resetSession() async {
    // Reset match time
    _session.matchTime = 0;
    _session.matchStartTime = 0;
    _session.matchRunning = false;
    _session.isPaused = false;
    
    // Reset all players
    for (var playerName in _session.players.keys) {
      await resetPlayerTime(playerName);
    }
    
    await saveSession();
    notifyListeners();
  }
}