import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/player.dart';
import '../hive_database.dart';
import 'dart:convert';

class AppState with ChangeNotifier {
  bool _isDarkTheme = true;
  int? _currentSessionId;
  List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> _sessions = [];
  String? _currentSessionPassword;
  Session _session = Session();
  bool _isReadOnlyMode = false;

  int? get currentSessionId => _currentSessionId;
  List<Map<String, dynamic>> get players => _players;
  List<Map<String, dynamic>> get sessions => _sessions;
  String? get currentSessionPassword => _currentSessionPassword;
  Session get session => _session;
  bool get isDarkTheme => _isDarkTheme;
  bool get isReadOnlyMode => _isReadOnlyMode;

  set session(Session newSession) {
    _session = newSession;
    notifyListeners();
  }

  Future<void> loadSessions() async {
    try {
      // Load sessions ONLY from Hive
      final hiveSessions = await HiveSessionDatabase.instance.getAllSessions();
      print('AppState: Loaded ${hiveSessions.length} sessions from Hive database');
      _sessions = hiveSessions;
      notifyListeners();
    } catch (e) {
      print('AppState: Error loading sessions from Hive: $e');
      // If error occurs, provide empty sessions list
      _sessions = [];
      notifyListeners();
    }
  }

  Future<void> createSession(String name) async {
    try {
      // Ensure name is not empty
      final sessionName = name.trim().isEmpty ? "New Session" : name.trim();
      print('AppState: Creating new session with name: "$sessionName"');
      
      // Store ONLY in Hive
      final sessionId = await HiveSessionDatabase.instance.insertSession(sessionName);
      print('AppState: Created new session with ID $sessionId in Hive');
      
      // Load sessions to make sure the new session is in the list
      await loadSessions();
      
      // Explicitly verify the session before loading
      final allSessions = await HiveSessionDatabase.instance.getAllSessions();
      final sessionInfo = allSessions.firstWhere(
        (s) => s['id'] == sessionId, 
        orElse: () => {'name': sessionName, 'id': sessionId}
      );
      
      print('AppState: Verified session name before loading: "${sessionInfo['name']}"');
      
      // Now load the session with the verified session ID
      await loadSession(sessionId);
      
      // Double-check the session name was set correctly
      print('AppState: After loadSession, session name is: "${_session.sessionName}"');
      print('AppState: After loadSession, currentSessionPassword is: "$_currentSessionPassword"');
    } catch (e) {
      print('AppState: Error creating session in Hive: $e');
      throw Exception('Could not create session: $e');
    }
  }

  Future<void> loadSession(int sessionId) async {
    print('AppState.loadSession called with sessionId: $sessionId');
    
    if (sessionId <= 0) {
      print('Invalid session ID: $sessionId');
      throw Exception('Invalid session ID');
    }
    
    try {
      // CRITICAL STEP: First, get the exact session name from the database
      // This will ensure we have the correct name regardless of which database is used
      final sessionData = await HiveSessionDatabase.instance.getSession(sessionId);
      if (sessionData == null) {
        print('Session not found in database: $sessionId');
        throw Exception('Session not found');
      }
      
      final correctSessionName = sessionData['name'] ?? '';
      print('Found session name from direct lookup: "$correctSessionName"');
      
      // Now set the current session ID and load players
      _currentSessionId = sessionId;
      _players = await HiveSessionDatabase.instance.getPlayersForSession(sessionId);
      print('Loaded ${_players.length} players for session');
      _players.sort((a, b) => a['name'].compareTo(b['name']));
      
      // CRITICAL: Set the current session password to the correct name
      // This is the primary source of the name shown in the UI
      _currentSessionPassword = correctSessionName;
      print('Set currentSessionPassword to: "$_currentSessionPassword"');
      
      // Create the session with the correct name
      _session = Session(sessionName: correctSessionName);
      print('Created new Session with sessionName: "${_session.sessionName}"');
      
      // Load session settings if they exist
      try {
        final settings = await HiveSessionDatabase.instance.getSessionSettings(sessionId);
        print('Session settings: ${settings != null ? 'Found' : 'Not found'}');
        if (settings != null) {
          // Create a new session with settings but preserve the correct name
          _session = Session(
            sessionName: correctSessionName,  // Make sure we keep the session name
            enableMatchDuration: settings['enableMatchDuration'],
            matchDuration: settings['matchDuration'],
            matchSegments: settings['matchSegments'],
            enableTargetDuration: settings['enableTargetDuration'],
            targetPlayDuration: settings['targetPlayDuration'],
            enableSound: settings['enableSound'],
          );
          print('Loaded session settings with name: "${_session.sessionName}"');
        }
      } catch (e) {
        print('Error loading session settings, using defaults: $e');
        // Continue with default settings if we can't load settings
      }
      
      // Initialize players from database
      try {
        for (var player in _players) {
          _session.addPlayer(player['name']);
          _session.updatePlayerTime(player['name'], player['timer_seconds'] ?? 0);
        }
      } catch (e) {
        print('Error initializing players: $e');
        // Continue with the session even if player initialization fails
      }
      
      print('Session loaded successfully, currentSessionId: $_currentSessionId');
      print('Final session name in AppState: "${_session.sessionName}"');
      print('Final currentSessionPassword: "$_currentSessionPassword"');
      
      _isReadOnlyMode = false;
      notifyListeners();
    } catch (e) {
      print('Error during session load: $e');
      _currentSessionId = null;
      _currentSessionPassword = null;
      _isReadOnlyMode = false;
      throw e;  // Re-throw to allow proper error handling
    }
  }

  Future<void> updatePlayerTimer(int playerId, int timerSeconds) async {
    if (_currentSessionId != null) {
      try {
        await HiveSessionDatabase.instance.updatePlayerTimer(playerId, timerSeconds);
        _players = await HiveSessionDatabase.instance.getPlayersForSession(_currentSessionId!);
      
        final playerIndex = _players.indexWhere((p) => p['id'] == playerId);
        if (playerIndex != -1) {
          final playerName = _players[playerIndex]['name'];
          _session.updatePlayerTime(playerName, timerSeconds);
        }
      } catch (e) {
        print('Error updating player timer in Hive: $e');
      }
    }
    notifyListeners();
  }

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
      // Add to Hive database
      final playerId = await HiveSessionDatabase.instance.insertPlayer(_currentSessionId!, trimmedName, 0);
      
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
      print('Error adding player to Hive database: $e');
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
          // Update total time - add safeguard for large timestamp differences
          int elapsed = now - player.startTime;
          // Sanity check: Don't add more than 1 day of time (86400 seconds)
          if (elapsed > 0 && elapsed < 86400) {
            player.totalTime += elapsed;
          }
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
        _players[playerIndex]['timer_seconds'] = player.totalTime;
        // We don't await here to improve UI responsiveness
        try {
          HiveSessionDatabase.instance.updatePlayerTimer(playerId, player.totalTime);
        } catch (e) {
          print('Error updating player in Hive: $e');
        }
      }
      
      notifyListeners();
    }
  }
  
  Future<void> saveSession() async {
    if (_currentSessionId == null) return;
    
    try {
      // Update player times in Hive database
      for (var playerName in _session.players.keys) {
        final playerIndex = _players.indexWhere((p) => p['name'] == playerName);
        final playerTime = _session.players[playerName]!.totalTime;
        
        if (playerIndex != -1) {
          final playerId = _players[playerIndex]['id'] as int;
          await HiveSessionDatabase.instance.updatePlayerTimer(playerId, playerTime);
          
          // Update local list
          _players[playerIndex]['timer_seconds'] = playerTime;
        }
      }
      
      // Save session settings to Hive
      await HiveSessionDatabase.instance.saveSessionSettings(_currentSessionId!, {
        'enableMatchDuration': _session.enableMatchDuration,
        'matchDuration': _session.matchDuration,
        'matchSegments': _session.matchSegments,
        'enableTargetDuration': _session.enableTargetDuration,
        'targetPlayDuration': _session.targetPlayDuration,
        'enableSound': _session.enableSound,
      });
    } catch (e) {
      print('Error saving to Hive database: $e');
    }
    
    // No need to notify listeners here as the caller should do it if needed
  }

  Future<void> setCurrentSession(int sessionId) async {
    try {
      _currentSessionId = sessionId;
      
      _players = await HiveSessionDatabase.instance.getPlayersForSession(sessionId);
      _players.sort((a, b) => a['name'].compareTo(b['name']));
      
      // Get session directly from database to ensure we have the correct name
      final sessionData = await HiveSessionDatabase.instance.getSession(sessionId);
      if (sessionData == null) {
        print('Session not found: $sessionId');
        throw Exception('Session not found');
      }
      
      final sessionName = sessionData['name'] ?? '';
      print('Loaded session name: "$sessionName"');
      _currentSessionPassword = sessionName;
      
      // Initialize session with correct name
      _session = Session(
        sessionName: sessionName,
        enableMatchDuration: false,
        matchDuration: 90,
        matchSegments: 2,
        enableTargetDuration: false,
        targetPlayDuration: 20,
        enableSound: true,
      );
      
      // Load session settings from Hive
      final settings = await HiveSessionDatabase.instance.getSessionSettings(sessionId);
      if (settings != null) {
        _session = Session(
          sessionName: sessionName, // Make sure we preserve the correct name
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
      
      print('Session loaded with name: "${_session.sessionName}", ID: $sessionId');
    } catch (e) {
      print('Error loading session from Hive: $e');
      throw Exception('Error loading session: $e');
    }
    
    notifyListeners();
  }

  Future<void> resetAllPlayers() async {
    // Reset player states in the session model
    _session.resetAllPlayers();
    
    // If in read-only mode, just update the UI without trying to persist changes
    if (_isReadOnlyMode) {
      print('In read-only mode, resetting all players without persisting to database');
      notifyListeners();
      return;
    }
    
    // If we're not in read-only mode, try to update the database
    try {
      // Update all player timers in Hive database
      if (_currentSessionId != null) {
        for (final entry in _session.players.entries) {
          // Find player ID from the players list
          final playerIndex = _players.indexWhere((p) => p['name'] == entry.key);
          if (playerIndex != -1) {
            final playerId = _players[playerIndex]['id'] as int;
            await HiveSessionDatabase.instance.updatePlayerTimer(playerId, entry.value.time);
            
            // Update local list
            _players[playerIndex]['timer_seconds'] = 0;
          }
        }
      }
    } catch (e) {
      print('Error resetting players in Hive: $e');
    }
    
    notifyListeners();
  }

  Future<void> resetSession() async {
    // Reset match time and player timers
    _session.matchTime = 0;
    _session.currentPeriod = 1;
    _session.hasWhistlePlayed = false;
    _session.matchRunning = false;
    
    try {
      // Reset all player timers and update in Hive
      for (var playerName in _session.players.keys) {
        final player = _session.players[playerName]!;
        // Reset all time fields to prevent any calculation issues
        player.totalTime = 0;
        player.time = 0;
        player.active = false;
        player.startTime = 0;
        
        // Update player in Hive database
        final playerIndex = _players.indexWhere((p) => p['name'] == playerName);
        if (playerIndex != -1 && _currentSessionId != null) {
          final playerId = _players[playerIndex]['id'];
          await HiveSessionDatabase.instance.updatePlayerTimer(playerId, 0);
          // Update local list
          _players[playerIndex]['timer_seconds'] = 0;
        }
      }
      
      // Save changes to Hive database
      await saveSession();
    } catch (e) {
      print('Error resetting session in Hive: $e');
    }
    
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
    if (!_session.players.containsKey(oldName) || newName.trim().isEmpty) return;
    
    // Don't rename if new name already exists
    if (_session.players.containsKey(newName)) return;
    
    // Get the player data
    final player = _session.players[oldName]!;
    
    // Create a new player with the new name but same data
    _session.players[newName] = Player(
      name: newName,
      totalTime: player.totalTime,
      active: player.active,
      startTime: player.startTime,
      time: player.time,
    );
    
    // Remove the old player
    _session.players.remove(oldName);
    
    // Update the database
    if (_currentSessionId != null) {
      final playerIndex = _players.indexWhere((p) => p['name'] == oldName);
      if (playerIndex != -1) {
        // Use the player's ID to update the name
        final playerId = _players[playerIndex]['id'] as int;
        // We should have a renamePlayer method in database, but for now
        // just update the local list
        _players[playerIndex]['name'] = newName;
      }
    }
    
    notifyListeners();
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
          await HiveSessionDatabase.instance.updatePlayerTimer(playerId, 0);
          
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

  void clearCurrentSession() {
    _currentSessionId = null;
    _currentSessionPassword = null;
    _players = [];
    _session = Session(); // Reset to a new blank session
    notifyListeners();
  }

  Future<void> togglePlayerActive(String name) async {
    // Toggle the player's active state in the session model
    _session.togglePlayerActive(name);
    
    // If in read-only mode, just update the UI without trying to persist changes
    if (_isReadOnlyMode) {
      print('In read-only mode, toggling player $name without persisting to database');
      notifyListeners();
      return;
    }
    
    // If we're not in read-only mode, try to update the database
    try {
      // Update player timer in Hive database
      if (_currentSessionId != null) {
        final player = _session.players[name];
        if (player != null) {
          // Find player ID from the players list
          final playerIndex = _players.indexWhere((p) => p['name'] == name);
          if (playerIndex != -1) {
            final playerId = _players[playerIndex]['id'] as int;
            await HiveSessionDatabase.instance.updatePlayerTimer(playerId, player.time);
          }
        }
      }
    } catch (e) {
      print('Error updating player active state in Hive: $e');
    }
    
    notifyListeners();
  }

  Future<void> resetSessionState() async {
    // Reset the session state
    _session.resetSessionState();
    
    // If in read-only mode, just update the UI without trying to persist changes
    if (_isReadOnlyMode) {
      print('In read-only mode, resetting session state without persisting to database');
      notifyListeners();
      return;
    }
    
    // If we're not in read-only mode, try to update the database
    try {
      // No need to update the database for session state reset
      // as it only affects runtime state
    } catch (e) {
      print('Error resetting session state: $e');
    }
    
    notifyListeners();
  }

  Future<void> deleteSession(int sessionId) async {
    try {
      // Delete from Hive
      await HiveSessionDatabase.instance.deleteSession(sessionId);
      
      // Reload the sessions list
      await loadSessions();
      
      // If the current session was deleted, clear it
      if (_currentSessionId == sessionId) {
        _currentSessionId = null;
        _currentSessionPassword = null;
        _session = Session();
        _players = [];
        notifyListeners();
      }
    } catch (e) {
      print('Error deleting session from Hive: $e');
      throw Exception('Could not delete session: $e');
    }
  }
}