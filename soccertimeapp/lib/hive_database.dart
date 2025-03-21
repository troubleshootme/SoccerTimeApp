import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:soccertimeapp/models/session.dart';
import 'package:soccertimeapp/models/player.dart';
import 'package:soccertimeapp/models/session_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HiveSessionDatabase {
  static const String sessionBoxName = 'sessions';
  static const String playersBoxName = 'players';
  static const String settingsBoxName = 'sessionSettings';
  
  static HiveSessionDatabase? _instance;
  static HiveSessionDatabase get instance => _instance ??= HiveSessionDatabase._();
  
  bool _initialized = false;
  Box<Map>? _sessionsBox;
  Box<Map>? _playersBox;
  Box<Map>? _settingsBox;
  
  HiveSessionDatabase._();
  
  Future<void> init() async {
    // If already initialized and boxes are still open, just return
    if (_initialized && 
        _sessionsBox != null && _sessionsBox!.isOpen &&
        _playersBox != null && _playersBox!.isOpen &&
        _settingsBox != null && _settingsBox!.isOpen) {
      return;
    }
    
    // Initialize Hive
    await Hive.initFlutter();
    
    // Open boxes (or reuse existing ones if they're still open)
    _sessionsBox = _sessionsBox?.isOpen == true ? _sessionsBox : await Hive.openBox<Map>(sessionBoxName);
    _playersBox = _playersBox?.isOpen == true ? _playersBox : await Hive.openBox<Map>(playersBoxName);
    _settingsBox = _settingsBox?.isOpen == true ? _settingsBox : await Hive.openBox<Map>(settingsBoxName);
    
    _initialized = true;
    print('Hive database initialized');
  }
  
  // SESSIONS
  
  Future<int> insertSession(String name) async {
    await init();
    
    // Find the next available ID
    final usedIds = _sessionsBox!.keys.cast<int>().toList();
    usedIds.sort();
    
    // Get the next ID (either max+1 or 1 if empty)
    final sessionId = usedIds.isEmpty ? 1 : usedIds.last + 1;
    
    // Ensure name is not empty
    final sessionName = name.trim().isEmpty ? "Session $sessionId" : name.trim();
    
    // Store session in Hive
    final sessionData = {
      'id': sessionId,
      'name': sessionName, 
      'created_at': DateTime.now().millisecondsSinceEpoch
    };
    
    // Store using the same ID as the key
    await _sessionsBox!.put(sessionId, sessionData);
    print('Inserted session with ID $sessionId into Hive with name "$sessionName"');
    
    return sessionId;
  }
  
  Future<List<Map<String, dynamic>>> getAllSessions() async {
    await init();
    final List<Map<String, dynamic>> sessions = [];
    
    // Get all sessions from the box
    final keys = _sessionsBox!.keys.cast<int>().toList();
    keys.sort(); // Sort keys to maintain order
    
    for (final key in keys) {
      try {
        final rawSession = _sessionsBox!.get(key);
        if (rawSession == null) continue;
        
        // Convert to Map<String, dynamic>
        final Map<dynamic, dynamic> originalMap = Map<dynamic, dynamic>.from(rawSession);
        final Map<String, dynamic> session = {};
        
        // Copy values with string keys
        originalMap.forEach((k, v) {
          session[k.toString()] = v;
        });
        
        // Ensure ID matches the storage key
        session['id'] = key;
        
        // Ensure session has a valid name
        if (session['name'] == null || session['name'].toString().trim().isEmpty) {
          session['name'] = 'Session ${key}';
          // Update the session in storage with the valid name
          await updateSession(session);
        }
        
        sessions.add(session);
        print('Retrieved session: key=$key, id=${session['id']}, name=${session['name']}');
      } catch (e) {
        print('Error processing session with key $key: $e');
      }
    }
    
    // Sort by created_at timestamp (newest first)
    sessions.sort((a, b) => 
      (b['created_at'] ?? 0).compareTo(a['created_at'] ?? 0)
    );
    
    print('Retrieved ${sessions.length} sessions from Hive');
    return sessions;
  }
  
  Future<Map<String, dynamic>?> getSession(int id) async {
    await init();
    try {
      final sessionMap = _sessionsBox!.get(id);
      if (sessionMap == null) {
        print('HiveSessionDatabase: Session not found with id: $id');
        return null;
      }
      
      try {
        // First convert to Map<dynamic, dynamic> then to Map<String, dynamic>
        final dynamicMap = Map<dynamic, dynamic>.from(sessionMap);
        final session = Map<String, dynamic>.fromEntries(
          dynamicMap.entries.map((entry) => MapEntry(entry.key.toString(), entry.value))
        );
        
        // Ensure session name is not null or empty
        if (session['name'] == null || session['name'] == '') {
          session['name'] = 'Session $id';
          print('Fixed empty session name for session $id when retrieving');
          
          // Save the fixed session back to storage
          await updateSession(session);
        }
        
        print('HiveSessionDatabase: Successfully retrieved session: id=$id, name="${session['name']}"');
        return session;
      } catch (e) {
        print('HiveSessionDatabase: Error casting session data: $e');
        return null;
      }
    } catch (e) {
      print('HiveSessionDatabase: Error retrieving session: $e');
      return null;
    }
  }
  
  Future<bool> updateSession(Map<String, dynamic> session) async {
    await init();
    
    try {
      final sessionId = session['id'];
      if (sessionId == null) {
        print('Cannot update session: No ID provided');
        return false;
      }
      
      // Convert to Map<dynamic, dynamic> for Hive storage
      final Map<dynamic, dynamic> storageMap = {};
      session.forEach((k, v) {
        storageMap[k] = v;
      });
      
      await _sessionsBox!.put(sessionId, storageMap);
      print('Updated session with ID $sessionId');
      return true;
    } catch (e) {
      print('Error updating session: $e');
      return false;
    }
  }
  
  Future<bool> deleteSession(int id) async {
    await init();
    
    await _sessionsBox!.delete(id);
    
    // Also delete all players for this session
    final playersToDelete = await getPlayersForSession(id);
    for (final player in playersToDelete) {
      await deletePlayer(player['id']);
    }
    
    // Delete session settings
    await _settingsBox!.delete(id);
    
    print('Deleted session $id from Hive');
    return true;
  }
  
  // PLAYERS
  
  Future<int> insertPlayer(int sessionId, String name, int timerSeconds) async {
    await init();
    
    // Create player ID
    final playerId = (_playersBox!.length + 1);
    
    // Create player data
    final playerData = {
      'id': playerId,
      'session_id': sessionId,
      'name': name,
      'timer_seconds': timerSeconds
    };
    
    // Store in Hive
    await _playersBox!.put(playerId, playerData);
    print('Inserted player with ID $playerId into Hive');
    
    return playerId;
  }
  
  Future<List<Map<String, dynamic>>> getPlayersForSession(int sessionId) async {
    await init();
    
    final List<Map<String, dynamic>> players = [];
    
    for (var key in _playersBox!.keys) {
      final playerMap = _playersBox!.get(key);
      if (playerMap != null) {
        try {
          final player = Map<String, dynamic>.from(playerMap);
          if (player['session_id'] == sessionId) {
            players.add(player);
          }
        } catch (e) {
          print('Error parsing player $key: $e');
        }
      }
    }
    
    print('Loaded ${players.length} players for session $sessionId from Hive');
    return players;
  }
  
  Future<bool> updatePlayerTimer(int playerId, int timerSeconds) async {
    await init();
    
    final playerMap = _playersBox!.get(playerId);
    if (playerMap != null) {
      try {
        final player = Map<String, dynamic>.from(playerMap);
        player['timer_seconds'] = timerSeconds;
        await _playersBox!.put(playerId, player);
        print('Updated player $playerId timer to $timerSeconds seconds');
        return true;
      } catch (e) {
        print('Error updating player $playerId: $e');
        return false;
      }
    }
    return false;
  }
  
  Future<bool> deletePlayer(int id) async {
    await init();
    
    await _playersBox!.delete(id);
    print('Deleted player $id from Hive');
    return true;
  }
  
  // SESSION SETTINGS
  
  Future<bool> saveSessionSettings(int sessionId, Map<String, dynamic> settings) async {
    await init();
    
    await _settingsBox!.put(sessionId, settings);
    print('Saved settings for session $sessionId to Hive');
    return true;
  }
  
  Future<Map<String, dynamic>?> getSessionSettings(int sessionId) async {
    await init();
    
    final settingsMap = _settingsBox!.get(sessionId);
    if (settingsMap != null) {
      try {
        return Map<String, dynamic>.from(settingsMap);
      } catch (e) {
        print('Error parsing session settings for session $sessionId: $e');
        return null;
      }
    }
    return null;
  }
  
  // CLEANUP
  
  Future<void> close() async {
    await _sessionsBox?.close();
    await _playersBox?.close();
    await _settingsBox?.close();
    print('Hive database closed');
  }
  
  Future<void> clearAllSessions() async {
    await init();
    
    // Clear all boxes
    await _sessionsBox!.clear();
    await _playersBox!.clear();
    await _settingsBox!.clear();
    
    print('Cleared all sessions from Hive database');
  }
} 