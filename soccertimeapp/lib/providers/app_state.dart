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
    
    // Get session info to get the name
    final allSessions = await SessionDatabase.instance.getAllSessions();
    final sessionInfo = allSessions.firstWhere((s) => s['id'] == sessionId, orElse: () => {'name': ''});
    final sessionName = sessionInfo['name'] ?? '';
    _currentSessionPassword = sessionName;
    
    // Initialize session with default values
    _session = Session(sessionName: sessionName);
    
    // Load session settings if they exist
    final settings = await SessionDatabase.instance.getSessionSettings(sessionId);
    if (settings != null) {
      _session = Session(
        sessionName: sessionName,
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
    _session = Session(sessionName: name);
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
    _players.sort((a, b) => a['name'].compareTo(b['name']));
    
    // Get session info for the name
    final allSessions = await SessionDatabase.instance.getAllSessions();
    final sessionInfo = allSessions.firstWhere((s) => s['id'] == sessionId, orElse: () => {'name': ''});
    final sessionName = sessionInfo['name'] ?? '';
    _currentSessionPassword = sessionName;
    
    // Initialize an empty session
    _session = Session(
      sessionName: sessionName,
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
        sessionName: sessionName,
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
  
  Future<void> resetPlayerTime(String playerName) async {
    if (_currentSessionId == null) return;
    if (_session.players.containsKey(playerName)) {
      // Reset the player's time
      _session.players[playerName]!.totalTime = 0;
      _session.players[playerName]!.time = 0;
      
      // Ensure the player is not active but can be activated again
      if (_session.players[playerName]!.active) {
        _session.players[playerName]!.active = false;
        _session.players[playerName]!.startTime = 0;
      }
      
      // Update in database
      if (_currentSessionId != null) {
        // Find player in _players list
        final playerIndex = _players.indexWhere((p) => p['name'] == playerName);
        if (playerIndex != -1) {
          // Use the player's ID to update the timer
          final playerId = _players[playerIndex]['id'] as int;
          await SessionDatabase.instance.updatePlayerTimer(playerId, 0);
          
          // Update local list
          _players[playerIndex]['timer_seconds'] = 0;
        }
      }
      
      saveSession();
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

  void startNextPeriod() {
    // Move to next period
    _session.currentPeriod++;
    
    // Get active players from before the pause
    List<String> activePlayers = List.from(_session.activeBeforePause);
    
    // Set match running if we still have periods left
    if (_session.currentPeriod <= _session.matchSegments) {
      _session.matchRunning = true;
      _session.isPaused = false;
      
      // Reactivate players that were active before period ended
      for (var playerName in activePlayers) {
        // Check if player exists and is not already active
        if (_session.players.containsKey(playerName) && !_session.players[playerName]!.active) {
          _session.players[playerName]!.active = true;
          _session.players[playerName]!.startTime = DateTime.now().millisecondsSinceEpoch;
        }
      }
      
      // Clear the activeBeforePause list
      _session.activeBeforePause.clear();
    } else {
      // Match is over
      _session.matchRunning = false;
    }
    
    saveSession();
    notifyListeners();
  }
  
  void pauseAll() {
    // This is a proxy to the pauseAll function in MainScreen
    // In this implementation, we just update the session state
    _session.isPaused = !_session.isPaused;
    
    if (_session.isPaused) {
      // Store active players and deactivate them
      _session.activeBeforePause = [];
      for (var playerName in _session.players.keys) {
        if (_session.players[playerName]!.active) {
          _session.activeBeforePause.add(playerName);
          // Deactivate the player
          togglePlayer(playerName);
        }
      }
    } else {
      // Reactivate players that were active before pause
      for (var playerName in _session.activeBeforePause) {
        if (_session.players.containsKey(playerName)) {
          togglePlayer(playerName);
        }
      }
      _session.activeBeforePause = [];
    }
    
    saveSession();
    notifyListeners();
  }

  // Store active players and handle state changes for period transitions
  void storeActivePlayersForPeriodChange() {
    // Store active players
    _session.activeBeforePause = [];
    for (var playerName in _session.players.keys) {
      if (_session.players[playerName]!.active) {
        _session.activeBeforePause.add(playerName);
        
        // Deactivate player and update their time
        final player = _session.players[playerName]!;
        final timeElapsed = (DateTime.now().millisecondsSinceEpoch - player.startTime) ~/ 1000;
        player.totalTime += timeElapsed;
        player.active = false;
      }
    }
    
    // Update session state
    _session.isPaused = true;
    saveSession();
    notifyListeners();
  }

  // Rename a player
  Future<void> renamePlayer(String oldName, String newName) async {
    if (_currentSessionId == null) return;
    if (_session.players.containsKey(oldName)) {
      // Get the player's current data
      final player = _session.players[oldName]!;
      
      // Remove the old player entry
      _session.players.remove(oldName);
      
      // Add with the new name but keeping the same time data
      _session.players[newName] = Player(
        name: newName,
        totalTime: player.totalTime,
        active: player.active,
        startTime: player.startTime,
        time: player.time,
      );
      
      // Update in database
      if (_currentSessionId != null) {
        // Find the player in our list
        final playerIndex = _players.indexWhere((p) => p['name'] == oldName);
        if (playerIndex != -1) {
          // Remove the old entry
          final oldPlayerId = _players[playerIndex]['id'];
          _players.removeAt(playerIndex);
          
          // Add the new entry
          final newPlayerId = await SessionDatabase.instance.insertPlayer(
            _currentSessionId!, 
            newName, 
            player.totalTime
          );
          
          // Add to local list
          _players.add({
            'id': newPlayerId,
            'name': newName,
            'timer_seconds': player.totalTime,
            'session_id': _currentSessionId!,
          });
          
          // Sort the player list alphabetically
          _players.sort((a, b) => a['name'].compareTo(b['name']));
        }
      }
      
      saveSession();
      notifyListeners();
    }
  }
}