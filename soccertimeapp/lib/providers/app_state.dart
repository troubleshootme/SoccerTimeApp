import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/player.dart';
import '../models/match_log_entry.dart';
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
      
      _currentSessionId = sessionId;
      _currentSessionPassword = sessionName;
      
      // Clear players list
      _players = [];
      
      // Create new session model
      _session = Session(
        sessionName: sessionName,
      );
      
      // Log new session creation
      logMatchEvent("New session '$sessionName' created");
      
      // Store session settings in Hive
      await saveSession();
      
      // Reload sessions list to include the new one
      await loadSessions();
      
      notifyListeners();
    } catch (e) {
      print('AppState: Error creating session: $e');
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
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    
    // Check if player already exists (case insensitive)
    final playerExists = _session.players.keys.any(
      (key) => key.toLowerCase() == trimmedName.toLowerCase()
    );
    
    // Early exit if player already exists
    if (playerExists) return;
    
    try {
      // Bail out if we don't have a current session
      if (_currentSessionId == null) {
        print('Cannot add player: No active session');
        return;
      }
      
      // Add to the session model
      _session.addPlayer(trimmedName);
      
      // Store in Hive database
      final playerId = await HiveSessionDatabase.instance.insertPlayer(
        _currentSessionId!,
        trimmedName,
        0,
      );
      
      // Create player object for UI list
      final newPlayer = {
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
      
      // Log player addition
      logMatchEvent("$trimmedName added to roster");
      
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
      final wasActive = player.active;
      
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
        
        // Log player leaving the game
        logMatchEvent("$playerName left the game");
      } else {
        // Check if this is the first active player - if so, start match FIRST
        bool hasActivePlayer = _session.players.values.any((p) => p.active);
        if (!hasActivePlayer && !_session.matchRunning) {
          // Start the match timer BEFORE activating the player
          _session.matchRunning = true;
          logMatchEvent("Match started");
        }
        
        // THEN activate the player (after match timer has started)
        player.active = true;
        player.startTime = now;
        
        // Log player entering the game
        logMatchEvent("$playerName entered the game");
      }
      
      // Update player in database if needed
      final playerIndex = _players.indexWhere((p) => p['name'] == playerName);
      if (playerIndex != -1 && _currentSessionId != null) {
        final playerId = _players[playerIndex]['id'];
        
        try {
          await HiveSessionDatabase.instance.updatePlayerTimer(playerId, player.totalTime);
          
          // Update UI list
          _players[playerIndex]['timer_seconds'] = player.totalTime;
        } catch (e) {
          print('Error updating player timer in database: $e');
        }
      }
      
      // Check for match pausing - only need to check for pause here now
      bool hasActivePlayer = _session.players.values.any((p) => p.active);
      
      // If we just deactivated the last player, pause the match
      if (!hasActivePlayer && _session.matchRunning && wasActive) {
        _session.matchRunning = false;
        logMatchEvent("Match paused - no active players");
      }
      
      await saveSession();
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
        // Always set player times to zero when loading a session to ensure consistency
        _session.players[name] = Player(name: name, totalTime: 0);
      }
      
      // Match time is also reset to zero for consistency
      _session.matchTime = 0;
      
      // Log session loading
      logMatchEvent("Session '$sessionName' loaded with all times reset to zero");
      
      print('Session loaded with name: "${_session.sessionName}", ID: $sessionId');
      notifyListeners();
    } catch (e) {
      print('AppState: Error loading session: $e');
      throw Exception('Could not load session: $e');
    }
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
    
    // Clear the match log and add reset entry
    _session.clearMatchLog();
    _session.addMatchLogEntry("Session reset - all timers cleared");
    
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
    
    final trimmedNewName = newName.trim();
    if (!_session.players.containsKey(oldName) || trimmedNewName.isEmpty) return;
    
    // Don't rename if new name already exists
    if (_session.players.containsKey(trimmedNewName)) return;
    
    // Get the player data
    final player = _session.players[oldName]!;
    
    // Create a new player with the new name but same data
    _session.players[trimmedNewName] = Player(
      name: trimmedNewName,
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
        _players[playerIndex]['name'] = trimmedNewName;
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
  
  Future<void> removePlayer(String name) async {
    if (_session.players.containsKey(name)) {
      // Remove from session
      _session.players.remove(name);
      
      // Log player removal
      logMatchEvent("$name removed from roster");
      
      // Remove from DB if needed
      if (_currentSessionId != null) {
        final playerIndex = _players.indexWhere((p) => p['name'] == name);
        if (playerIndex != -1) {
          final playerId = _players[playerIndex]['id'];
          
          // Delete from Hive database
          try {
            await HiveSessionDatabase.instance.deletePlayer(playerId);
            print('Deleted player $name (ID: $playerId) from database');
          } catch (e) {
            print('Error deleting player from database: $e');
          }
          
          // Also remove from our local list
          _players.removeAt(playerIndex);
        }
      } else {
        _players.removeWhere((p) => p['name'] == name);
      }
      
      // Save the session to make changes persistent
      saveSession();
      
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
    // Get the current active state before toggling
    final wasActive = _session.players[name]?.active ?? false;
    
    // Toggle the player's active state in the session model
    _session.togglePlayerActive(name);
    
    // Get the new active state
    final isActive = _session.players[name]?.active ?? false;
    
    // Log player entry/exit
    if (isActive && !wasActive) {
      logMatchEvent("$name entered the game");
    } else if (!isActive && wasActive) {
      logMatchEvent("$name left the game");
    }
    
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
    
    // Clear the match log and add reset entry
    _session.clearMatchLog();
    _session.addMatchLogEntry("Session reset - all timers cleared");
    
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
      await saveSession();
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

  // Add an entry to the match log
  void logMatchEvent(String details) {
    _session.addMatchLogEntry(details);
    // No need to save to database here - will be saved with other session changes
    notifyListeners();
  }

  // Export match log to a string for sharing
  String exportMatchLogToText() {
    final buffer = StringBuffer();
    
    // Add session name as header
    buffer.writeln('MATCH LOG: ${_session.sessionName}');
    buffer.writeln('${DateTime.now().toString().split('.')[0]}'); // Date without milliseconds
    buffer.writeln('----------------------------------------');
    buffer.writeln();
    
    // Add log entries in chronological order (oldest first)
    final entries = List<MatchLogEntry>.from(_session.matchLog);
    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp)); // Sort oldest to newest
    
    for (var entry in entries) {
      // Format: [Time] Event details
      buffer.writeln('[${entry.matchTime}] ${entry.details}');
    }
    
    return buffer.toString();
  }

  // Modified version of existing methods that add logging
  
  // Log match pause/resume
  Future<void> toggleMatchRunning() async {
    _session.matchRunning = !_session.matchRunning;
    
    if (_session.matchRunning) {
      logMatchEvent("Match resumed");
    } else {
      logMatchEvent("Match paused");
    }
    
    await saveSession();
    notifyListeners();
  }
  
  // Helper for ordinal numbers (1st, 2nd, 3rd, etc.)
  String getOrdinal(int number) {
    if (number == 1) return '1st';
    if (number == 2) return '2nd';
    if (number == 3) return '3rd';
    return '${number}th';
  }
  
  // Update match time and check for period changes
  Future<void> updateMatchTime(int newTime) async {
    final oldTime = _session.matchTime;
    _session.matchTime = newTime;
    
    // Check for period changes
    if (_session.enableMatchDuration) {
      final segmentDuration = _session.matchDuration / _session.matchSegments;
      final oldPeriod = (oldTime / segmentDuration).floor() + 1;
      final newPeriod = (newTime / segmentDuration).floor() + 1;
      
      // If period changed, log it
      if (oldPeriod != newPeriod && newPeriod <= _session.matchSegments) {
        final periodName = _session.matchSegments == 2 ? 'half' : 'quarter';
        
        // Log end of previous period
        if (oldPeriod < newPeriod) {
          final periodNumber = getOrdinal(oldPeriod);
          logMatchEvent("$periodNumber $periodName ended");
          
          // Log start of new period
          final newPeriodNumber = getOrdinal(newPeriod);
          logMatchEvent("$newPeriodNumber $periodName started");
        }
      }
    }
    
    // Save session changes
    await saveSession();
    notifyListeners();
  }
}