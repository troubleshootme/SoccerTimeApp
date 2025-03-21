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

  Future<void> addPlayer(String name) async {
    if (_currentSessionId == null || name.trim().isEmpty) return;
    final trimmedName = name.trim();
    
    // Check if player already exists
    if (_session.players.containsKey(trimmedName)) return;
    
    // Add to session
    _session.addPlayer(trimmedName);
    
    try {
      // Add to database
      final playerId = await SessionDatabase.instance.insertPlayer(_currentSessionId!, trimmedName, 0);
      
      // Add locally if database succeeded
      Map<String, dynamic> newPlayer = {
        'id': playerId,
        'name': trimmedName,
        'timer_seconds': 0,
        'session_id': _currentSessionId!,
      };
      
      try {
        // Safely add to the players list
        if (_players is List) {
          // Handle immutable lists by creating a new one
          List<Map<String, dynamic>> newList = List<Map<String, dynamic>>.from(_players);
          newList.add(newPlayer);
          _players = newList;
        } else {
          // Direct add if possible
          _players.add(newPlayer);
        }
        
        // Sort alphabetically
        _players.sort((a, b) => a['name'].compareTo(b['name']));
      } catch (e) {
        print('Error adding player to UI list: $e');
        // Create a new player list if the current one is problematic
        _players = [newPlayer];
      }
      
      // Save session changes
      await saveSession();
    } catch (e) {
      print('Error adding player to database: $e');
      // Continue with in-memory session even if database fails
    }
    
    // Notify listeners to update UI
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
  
  Future<void> togglePlayer(String playerName) async {
    if (_session.players.containsKey(playerName)) {
      final player = _session.players[playerName]!;
      
      // Calculate time before toggling
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      if (player.active) {
        // Player is active, deactivate them
        if (player.startTime > 0) {
          // Update total time
          int elapsed = now - player.startTime;
          player.totalTime += elapsed;
          player.time = player.totalTime;
        }
        player.active = false;
        player.startTime = 0;
      } else {
        // Player is inactive, activate them
        player.active = true;
        player.startTime = now;
      }
      
      // Update player in database if needed
      final playerIndex = _players.indexWhere((p) => p['name'] == playerName);
      if (playerIndex != -1 && _currentSessionId != null) {
        final playerId = _players[playerIndex]['id'];
        // We don't await here to improve UI responsiveness
        SessionDatabase.instance.updatePlayerTimer(playerId, player.totalTime);
      }
      
      notifyListeners();
    }
  }
  
  Future<void> saveSession() async {
    if (_currentSessionId == null) return;
    
    // Update player times in database
    for (var playerName in _session.players.keys) {
      final playerIndex = _players.indexWhere((p) => p['name'] == playerName);
      final playerTime = _session.players[playerName]!.totalTime;
      
      if (playerIndex != -1) {
        final playerId = _players[playerIndex]['id'] as int;
        await SessionDatabase.instance.updatePlayerTimer(playerId, playerTime);
        
        // Update local list
        _players[playerIndex]['timer_seconds'] = playerTime;
      }
    }
    
    // Save session settings
    await SessionDatabase.instance.saveSessionSettings(_currentSessionId!, {
      'enableMatchDuration': _session.enableMatchDuration,
      'matchDuration': _session.matchDuration,
      'matchSegments': _session.matchSegments,
      'enableTargetDuration': _session.enableTargetDuration,
      'targetPlayDuration': _session.targetPlayDuration,
      'enableSound': _session.enableSound,
    });
    
    // No need to notify listeners here as the caller should do it if needed
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

  Future<void> resetSession() async {
    // Reset match time and player timers
    _session.matchTime = 0;
    _session.currentPeriod = 1;
    _session.hasWhistlePlayed = false;
    _session.matchRunning = false;
    
    // Reset all player timers
    for (var playerName in _session.players.keys) {
      final player = _session.players[playerName]!;
      player.totalTime = 0;
      player.time = 0;
      player.active = false;
      player.startTime = 0;
      
      // Update player in database
      final playerIndex = _players.indexWhere((p) => p['name'] == playerName);
      if (playerIndex != -1 && _currentSessionId != null) {
        final playerId = _players[playerIndex]['id'];
        await SessionDatabase.instance.updatePlayerTimer(playerId, 0);
        // Update local list
        _players[playerIndex]['timer_seconds'] = 0;
      }
    }
    
    // Save changes to database
    await saveSession();
    notifyListeners();
  }

  void startNextPeriod() {
    // Increment period
    _session.currentPeriod++;
    // Reset the whistle flag
    _session.hasWhistlePlayed = false;
    // Unpause session
    _session.isPaused = false;
    
    // Notify listeners to update UI
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
    _session.activeBeforePause = [];
    for (var playerName in _session.players.keys) {
      if (_session.players[playerName]!.active) {
        _session.activeBeforePause.add(playerName);
        
        // Deactivate the player
        _session.players[playerName]!.active = false;
      }
    }
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

  // Add missing resetPlayerTime method
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
      
      notifyListeners();
    }
  }
  
  // Add missing removePlayer method
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
}