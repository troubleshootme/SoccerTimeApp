// DEPRECATED - This file is no longer used by the application.
// All database operations now use hive_database.dart
// This file is kept for historical reference only.
// Do not use this file for any new functionality.

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform, Directory, File;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:soccertimeapp/hive_database.dart';  // Import the correct Hive database file

class SessionDatabase {
  static final SessionDatabase instance = SessionDatabase._init();
  static Database? _database;
  static SharedPreferences? _prefs;
  static bool _hasTriedFallback = false;
  static bool? _isInReadOnlyMode;  // Cache the read-only status

  SessionDatabase._init() {
    if (!kIsWeb) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
    }
  }

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite not supported on web');
    }
    if (_database != null) return _database!;
    
    try {
      _database = await _initDB('sessions.db');
      
      // Disable the PRAGMA test that keeps failing
      // await _database!.execute('PRAGMA user_version = 1');
      
      return _database!;
    } catch (e) {
      print('Database access error: $e');
      if (!_hasTriedFallback) {
        _hasTriedFallback = true;
        _database = null; // Reset database to try fallback
        return await database; // Retry with fallback path
      }
      // If fallback fails, use a temporary in-memory database
      print('Using in-memory database as fallback');
      _database = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: _createDB
      );
      return _database!;
    }
  }

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<bool> _isReadOnly() async {
    // Return cached value if available - reset the cache each time app starts
    if (_isInReadOnlyMode != null) {
      // Even if we think we're in read-only mode, let's double check
      // after every 3 app launches to see if we can recover
      final prefs = await this.prefs;
      final checkCount = prefs.getInt('read_only_check_count') ?? 0;
      
      if (_isInReadOnlyMode == true && checkCount >= 3) {
        // Reset check counter and force a fresh check
        await prefs.setInt('read_only_check_count', 0);
        _isInReadOnlyMode = null;
        print('Forced re-check of read-only status after 3 app launches');
      } else if (_isInReadOnlyMode == true) {
        // Increment counter
        await prefs.setInt('read_only_check_count', checkCount + 1);
        return true;
      } else {
        return _isInReadOnlyMode!;
      }
    }
    
    if (kIsWeb) {
      _isInReadOnlyMode = true;
      return true; // Web always uses SharedPreferences
    }
    
    try {
      final db = await database;
      
      // We'll skip the PRAGMA test since it causes issues on Android
      // Instead, we'll rely solely on the transaction test
      
      // Try a more complex test with a transaction
      bool isReadOnlyDatabase = false;
      try {
        await db.transaction((txn) async {
          // Do a test insert and delete
          final testId = await txn.insert('sessions', 
            {'name': 'test_write_access', 'created_at': DateTime.now().millisecondsSinceEpoch});
          await txn.delete('sessions', where: 'id = ?', whereArgs: [testId]);
          
          // If we get here without error, database is writable
          isReadOnlyDatabase = false;
          
          // Force rollback by throwing exception
          throw Exception('_test_rollback');
        });
      } catch (e) {
        // If we catch our test exception, that's fine
        if (e.toString().contains('_test_rollback')) {
          // Normal case - transaction was rolled back successfully
          print('Write test successful and rolled back');
          isReadOnlyDatabase = false;
        } else if (e.toString().contains('read-only') || 
                   e.toString().contains('database is locked') || 
                   e.toString().contains('disk image is malformed')) {
          // Error indicating read-only mode
          print('Database is read-only: $e');
          isReadOnlyDatabase = true;
          
          // Try to close and reopen the database once to fix issues
          try {
            print('Attempting to fix read-only database by closing and reopening');
            await close();
            _database = null;
            _isInReadOnlyMode = null;
            
            // Force create a new database connection
            await database;
            
            // Instead of PRAGMA test which fails on Android, 
            // we'll try the transaction test again
            bool secondTestResult = false;
            try {
              final newDb = await database;
              await newDb.transaction((txn) async {
                final testId = await txn.insert('sessions', 
                  {'name': 'test_write_access_2', 'created_at': DateTime.now().millisecondsSinceEpoch});
                await txn.delete('sessions', where: 'id = ?', whereArgs: [testId]);
                throw Exception('_test_rollback');
              });
            } catch (retryError) {
              if (retryError.toString().contains('_test_rollback')) {
                print('Second write test successful after reopening');
                secondTestResult = true;
              }
            }
            
            // Set read-only status based on second test
            isReadOnlyDatabase = !secondTestResult;
            
            print(isReadOnlyDatabase 
                ? 'Database still in read-only mode after reopening'
                : 'Successfully fixed database read-only issue');
          } catch (reopenError) {
            print('Failed to reopen database: $reopenError');
            isReadOnlyDatabase = true;
          }
        } else {
          // Unexpected error
          print('Database test failed with error: $e');
          // Default to non-read-only if error is unclear
          isReadOnlyDatabase = false;
        }
      }
      
      // Update the cached value
      _isInReadOnlyMode = isReadOnlyDatabase;
      return isReadOnlyDatabase;
    } catch (e) {
      print('Database access error in _isReadOnly: $e');
      // Default to true (read-only) for safety if we can't determine
      _isInReadOnlyMode = true;
      return true;
    }
  }

  Future<Database> _initDB(String filePath) async {
    try {
      // First try app documents directory
      final documentsDirectory = await getApplicationDocumentsDirectory();
      await Directory(documentsDirectory.path).create(recursive: true);
      final path = join(documentsDirectory.path, filePath);
      print('Using database path: $path');
      
      // Check if we need to fix permissions on existing database
      File dbFile = File(path);
      if (await dbFile.exists()) {
        // Only check for corruption and reset database if we have issues
        bool isCorrupted = await _isDatabaseCorrupted(dbFile);
        
        if (isCorrupted) {
          // Only if actually corrupted, recover the database
          await _recoverDatabase(dbFile, path);
          
          // If file exists but we still have issues, try deleting and recreating it
          try {
            // Try more aggressive approach - close any existing connections
            final db = await openDatabase(
              path, 
              version: 1,
              readOnly: true,
              singleInstance: true
            );
            await db.close();
          } catch (e) {
            print('Warning when closing existing database connection: $e');
            // Continue even if this fails
          }
          
          try {
            // Delete the existing database file that might be locked BUT ONLY IF CORRUPTED
            await dbFile.delete();
            print('Deleted existing database file due to corruption');
            
            // Create a fresh database with write access
            return await openDatabase(
              path, 
              version: 1, 
              onCreate: _createDB,
              singleInstance: true,
              readOnly: false
            );
          } catch (e) {
            print('Error recreating database with write access: $e');
            // If recreating fails, try regular open
            return await openDatabase(
              path, 
              version: 1, 
              onCreate: _createDB,
              singleInstance: true,
              readOnly: false
            );
          }
        } else {
          // If the database is valid, just open it normally
          print('Database file exists and appears valid, opening normally');
          return await openDatabase(
            path, 
            version: 1, 
            onCreate: _createDB,
            singleInstance: true,
            readOnly: false
          );
        }
      } else {
        // If the file doesn't exist, create it with full permissions
        print('Database file does not exist, creating new one');
        return await openDatabase(
          path, 
          version: 1, 
          onCreate: _createDB,
          singleInstance: true,
          readOnly: false
        );
      }
    } catch (e) {
      print('Error accessing app documents directory: $e');
      
      // If app documents fail, try databases directory
      try {
        final dbPath = await getDatabasesPath();
        await Directory(dbPath).create(recursive: true);
        final path = join(dbPath, filePath);
        print('Using alternative database path: $path');
        
        File dbFile = File(path);
        if (await dbFile.exists()) {
          // Check if actually corrupted before deleting
          if (await _isDatabaseCorrupted(dbFile)) {
            try {
              // Try deleting the file to ensure it's not locked
              await dbFile.delete();
              print('Deleted existing database file in alternate location due to corruption');
            } catch (deleteError) {
              print('Failed to delete database in alternate location: $deleteError');
            }
          }
        }
        
        return await openDatabase(
          path, 
          version: 1, 
          onCreate: _createDB,
          singleInstance: true,
          readOnly: false
        );
      } catch (e) {
        print('Error accessing databases directory: $e');
        // If all fails, use in-memory database
        if (!_hasTriedFallback) {
          throw e; // Let the caller handle this to try a fallback
        }
        return await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: _createDB
        );
      }
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE players (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        timer_seconds INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE session_settings (
        session_id INTEGER PRIMARY KEY,
        enable_match_duration BOOLEAN NOT NULL DEFAULT 0,
        match_duration INTEGER NOT NULL DEFAULT 90,
        match_segments INTEGER NOT NULL DEFAULT 2,
        enable_target_duration BOOLEAN NOT NULL DEFAULT 0,
        target_play_duration INTEGER NOT NULL DEFAULT 20,
        enable_sound BOOLEAN NOT NULL DEFAULT 1,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<int> insertSession(String name) async {
    // Ensure name is not empty
    final sessionName = name.trim().isEmpty ? "New Session" : name.trim();
    print('Inserting session with name: $sessionName');
    
    // Check if we're in read-only mode - but use our cached value to avoid repeated tests
    final isReadOnly = _isInReadOnlyMode ?? await _isReadOnly();
    
    if (kIsWeb || isReadOnly) {
      print('Using SharedPreferences for session storage (read-only mode)');
      final prefs = await this.prefs;
      final sessions = prefs.getString('sessions') ?? '[]';
      final sessionList = List<Map<String, dynamic>>.from(jsonDecode(sessions));
      final newId = sessionList.isEmpty ? 1 : sessionList.map((s) => s['id'] as int).reduce((a, b) => a > b ? a : b) + 1;
      final session = {'id': newId, 'name': sessionName, 'created_at': DateTime.now().millisecondsSinceEpoch};
      sessionList.add(session);
      await prefs.setString('sessions', jsonEncode(sessionList));
      print('Session saved to SharedPreferences with ID: $newId and name: $sessionName');
      
      // Also synchronize to Hive for cross-database compatibility
      try {
        // Import directly to HiveSessionDatabase
        final hiveDB = HiveSessionDatabase.instance;
        await hiveDB.syncSessionFromSQLite(newId, session);
      } catch (e) {
        print('Failed to sync session to Hive: $e');
      }
      
      return newId;
    } else {
      try {
        print('Using SQLite database for session storage');
        final db = await database;
        final data = {'name': sessionName, 'created_at': DateTime.now().millisecondsSinceEpoch};
        final newId = await db.insert('sessions', data);
        print('Successfully inserted session with ID: $newId and name: $sessionName');
        
        // Sync the new session to Hive
        try {
          // Create complete session data with ID
          final sessionData = {
            'id': newId,
            'name': sessionName,
            'created_at': DateTime.now().millisecondsSinceEpoch
          };
          
          // Import directly to HiveSessionDatabase
          final hiveDB = HiveSessionDatabase.instance;
          await hiveDB.syncSessionFromSQLite(newId, sessionData);
        } catch (e) {
          print('Failed to sync session to Hive: $e');
        }
        
        return newId;
      } catch (e) {
        // If database access fails, fallback to shared prefs
        print('Database error in insertSession: $e - using SharedPreferences fallback');
        _isInReadOnlyMode = true; // Force read-only mode going forward
        
        final prefs = await SharedPreferences.getInstance();
        final sessions = prefs.getString('sessions') ?? '[]';
        final sessionList = List<Map<String, dynamic>>.from(jsonDecode(sessions));
        final newId = sessionList.isEmpty ? 1 : sessionList.map((s) => s['id'] as int).reduce((a, b) => a > b ? a : b) + 1;
        final session = {'id': newId, 'name': sessionName, 'created_at': DateTime.now().millisecondsSinceEpoch};
        sessionList.add(session);
        await prefs.setString('sessions', jsonEncode(sessionList));
        print('Session saved to SharedPreferences with ID: $newId and name: $sessionName');
        
        // Also synchronize to Hive
        try {
          final hiveDB = HiveSessionDatabase.instance;
          await hiveDB.syncSessionFromSQLite(newId, session);
        } catch (e) {
          print('Failed to sync session to Hive: $e');
        }
        
        return newId;
      }
    }
  }

  Future<List<Map<String, dynamic>>> getAllSessions() async {
    // Check if we're in read-only mode - but use our cached value to avoid repeated tests
    final isReadOnly = _isInReadOnlyMode ?? await _isReadOnly();
    
    if (kIsWeb || isReadOnly) {
      try {
        print('Getting all sessions from SharedPreferences (read-only mode)');
        final prefs = await this.prefs;
        final sessions = prefs.getString('sessions');
        if (sessions == null || sessions.isEmpty) {
          return []; // Return empty list if no sessions found
        }
        try {
          final result = List<Map<String, dynamic>>.from(jsonDecode(sessions));
          print('Found ${result.length} sessions in SharedPreferences');
          return result;
        } catch (e) {
          print('Error parsing sessions JSON: $e');
          return []; // Return empty list if JSON parsing fails
        }
      } catch (e) {
        print('Error getting sessions from SharedPreferences: $e');
        return []; // Return empty list on any error
      }
    } else {
      try {
        print('Getting all sessions from SQLite database');
        final db = await database;
        final result = await db.query('sessions', orderBy: 'created_at DESC');
        print('Found ${result.length} sessions in database');
        return result;
      } catch (e) {
        // If database access fails, fallback to shared prefs
        print('Database error in getAllSessions: $e - using SharedPreferences fallback');
        _isInReadOnlyMode = true; // Force read-only mode going forward
        
        try {
          final prefs = await SharedPreferences.getInstance();
          final sessions = prefs.getString('sessions');
          if (sessions == null || sessions.isEmpty) {
            return []; // Return empty list if no sessions found
          }
          final result = List<Map<String, dynamic>>.from(jsonDecode(sessions));
          print('Found ${result.length} sessions in SharedPreferences (fallback)');
          return result;
        } catch (innerError) {
          print('Error in SharedPreferences fallback: $innerError');
          return []; // Return empty list if all fails
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> getPlayersForSession(int sessionId) async {
    // Check if we're in read-only mode
    final isReadOnly = await _isReadOnly();
    
    if (kIsWeb || isReadOnly) {
      final prefs = await this.prefs;
      final players = prefs.getString('players_$sessionId') ?? '[]';
      return List<Map<String, dynamic>>.from(jsonDecode(players));
    } else {
      try {
        final db = await database;
        return await db.query('players', where: 'session_id = ?', whereArgs: [sessionId]);
      } catch (e) {
        // If database access fails, fallback to shared prefs
        print('Database error in getPlayersForSession: $e - using SharedPreferences fallback');
        final prefs = await SharedPreferences.getInstance();
        final players = prefs.getString('players_$sessionId') ?? '[]';
        return List<Map<String, dynamic>>.from(jsonDecode(players));
      }
    }
  }

  Future<int> insertPlayer(int sessionId, String name, int timerSeconds) async {
    // Check if we're in read-only mode
    final isReadOnly = await _isReadOnly();
    
    if (kIsWeb || isReadOnly) {
      final prefs = await this.prefs;
      final playersKey = 'players_$sessionId';
      final players = prefs.getString(playersKey) ?? '[]';
      final playerList = List<Map<String, dynamic>>.from(jsonDecode(players));
      final newId = playerList.isEmpty ? 1 : playerList.map((p) => p['id'] as int).reduce((a, b) => a > b ? a : b) + 1;
      final player = {'id': newId, 'session_id': sessionId, 'name': name, 'timer_seconds': timerSeconds};
      playerList.add(player);
      await prefs.setString(playersKey, jsonEncode(playerList));
      return newId;
    } else {
      try {
        final db = await database;
        final data = {'session_id': sessionId, 'name': name, 'timer_seconds': timerSeconds};
        return await db.insert('players', data);
      } catch (e) {
        // If database access fails, fallback to shared prefs
        print('Database error in insertPlayer: $e - using SharedPreferences fallback');
        final prefs = await SharedPreferences.getInstance();
        final playersKey = 'players_$sessionId';
        final players = prefs.getString(playersKey) ?? '[]';
        final playerList = List<Map<String, dynamic>>.from(jsonDecode(players));
        final newId = playerList.isEmpty ? 1 : playerList.map((p) => p['id'] as int).reduce((a, b) => a > b ? a : b) + 1;
        final player = {'id': newId, 'session_id': sessionId, 'name': name, 'timer_seconds': timerSeconds};
        playerList.add(player);
        await prefs.setString(playersKey, jsonEncode(playerList));
        return newId;
      }
    }
  }

  Future<void> updatePlayerTimer(int playerId, int timerSeconds) async {
    // Check if we're in read-only mode
    final isReadOnly = await _isReadOnly();
    
    if (kIsWeb || isReadOnly) {
      // In read-only mode, we need to find the player by ID and update them in SharedPreferences
      try {
        final prefs = await this.prefs;
        // Find the session that contains this player
        final allSessions = await getAllSessions();
        
        // Look through all sessions for this player
        for (var session in allSessions) {
          final sessionId = session['id'];
          final playersKey = 'players_$sessionId';
          final playersJson = prefs.getString(playersKey);
          
          if (playersJson != null) {
            List<Map<String, dynamic>> players = List<Map<String, dynamic>>.from(jsonDecode(playersJson));
            // Try to find the player by ID
            final playerIndex = players.indexWhere((p) => p['id'] == playerId);
            
            if (playerIndex != -1) {
              // Update the player's timer
              players[playerIndex]['timer_seconds'] = timerSeconds;
              // Save back to prefs
              await prefs.setString(playersKey, jsonEncode(players));
              return; // Found and updated
            }
          }
        }
        
        print('Player with ID $playerId not found in any session (read-only mode)');
      } catch (e) {
        print('Error updating player timer in read-only mode: $e');
      }
    } else {
      try {
        final db = await database;
        await db.update(
          'players',
          {'timer_seconds': timerSeconds},
          where: 'id = ?',
          whereArgs: [playerId],
        );
      } catch (e) {
        print('Database error in updatePlayerTimer: $e - using SharedPreferences fallback');
        // Fall back to read-only approach
        final isReadOnly = await _isReadOnly();
        if (!isReadOnly) {
          _isInReadOnlyMode = true; // Force read-only mode if we can't write
        }
        await updatePlayerTimer(playerId, timerSeconds);
      }
    }
  }

  // Helper method to find player by name (for read-only mode)
  Future<void> updatePlayerTimerByName(int sessionId, String playerName, int timerSeconds) async {
    // Check if we're in read-only mode
    final isReadOnly = await _isReadOnly();
    
    if (kIsWeb || isReadOnly) {
      try {
        final prefs = await this.prefs;
        final playersKey = 'players_$sessionId';
        final playersJson = prefs.getString(playersKey);
        
        if (playersJson != null) {
          List<Map<String, dynamic>> players = List<Map<String, dynamic>>.from(jsonDecode(playersJson));
          // Find the player by name
          final playerIndex = players.indexWhere((p) => p['name'] == playerName);
          
          if (playerIndex != -1) {
            // Update the player's timer
            players[playerIndex]['timer_seconds'] = timerSeconds;
            // Save back to prefs
            await prefs.setString(playersKey, jsonEncode(players));
          } else {
            print('Player $playerName not found in session $sessionId (read-only mode)');
          }
        }
      } catch (e) {
        print('Error updating player by name: $e');
      }
    } else {
      try {
        final db = await database;
        // Find the player ID first
        final playerRows = await db.query(
          'players',
          columns: ['id'],
          where: 'session_id = ? AND name = ?',
          whereArgs: [sessionId, playerName],
        );
        
        if (playerRows.isNotEmpty) {
          final playerId = playerRows.first['id'] as int;
          await db.update(
            'players',
            {'timer_seconds': timerSeconds},
            where: 'id = ?',
            whereArgs: [playerId],
          );
        } else {
          print('Player $playerName not found in session $sessionId');
        }
      } catch (e) {
        print('Database error in updatePlayerTimerByName: $e');
        // Fall back to read-only approach
        final isReadOnly = await _isReadOnly();
        if (!isReadOnly) {
          _isInReadOnlyMode = true; // Force read-only mode if we can't write
        }
        await updatePlayerTimerByName(sessionId, playerName, timerSeconds);
      }
    }
  }

  Future<void> saveSessionSettings(int sessionId, Map<String, dynamic> settings) async {
    // Check if we're in read-only mode
    final isReadOnly = await _isReadOnly();
    
    if (kIsWeb || isReadOnly) {
      final prefs = await this.prefs;
      await prefs.setString('settings_$sessionId', jsonEncode(settings));
    } else {
      try {
        final db = await database;
        
        // Check if settings exist for this session
        final List<Map<String, dynamic>> existing = await db.query(
          'session_settings',
          where: 'session_id = ?',
          whereArgs: [sessionId],
        );
        
        if (existing.isEmpty) {
          // Insert new settings
          await db.insert('session_settings', {
            'session_id': sessionId,
            'enable_match_duration': settings['enableMatchDuration'] ? 1 : 0,
            'match_duration': settings['matchDuration'],
            'match_segments': settings['matchSegments'],
            'enable_target_duration': settings['enableTargetDuration'] ? 1 : 0,
            'target_play_duration': settings['targetPlayDuration'],
            'enable_sound': settings['enableSound'] ? 1 : 0,
          });
        } else {
          // Update existing settings
          await db.update(
            'session_settings',
            {
              'enable_match_duration': settings['enableMatchDuration'] ? 1 : 0,
              'match_duration': settings['matchDuration'],
              'match_segments': settings['matchSegments'],
              'enable_target_duration': settings['enableTargetDuration'] ? 1 : 0,
              'target_play_duration': settings['targetPlayDuration'],
              'enable_sound': settings['enableSound'] ? 1 : 0,
            },
            where: 'session_id = ?',
            whereArgs: [sessionId],
          );
        }
      } catch (e) {
        // If database access fails, fallback to shared prefs
        print('Database error in saveSessionSettings: $e - using SharedPreferences fallback');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('settings_$sessionId', jsonEncode(settings));
      }
    }
  }

  Future<Map<String, dynamic>?> getSessionSettings(int sessionId) async {
    // Check if we're in read-only mode
    final isReadOnly = await _isReadOnly();
    
    if (kIsWeb || isReadOnly) {
      final prefs = await this.prefs;
      final settings = prefs.getString('settings_$sessionId');
      if (settings == null) {
        // Return default settings when no saved settings exist
        return {
          'enableMatchDuration': false,
          'matchDuration': 90 * 60,
          'matchSegments': 2,
          'enableTargetDuration': false,
          'targetPlayDuration': 20 * 60,
          'enableSound': true,
        };
      }
      return Map<String, dynamic>.from(jsonDecode(settings));
    } else {
      try {
        final db = await database;
        final List<Map<String, dynamic>> results = await db.query(
          'session_settings',
          where: 'session_id = ?',
          whereArgs: [sessionId],
        );
        
        if (results.isEmpty) return null;
        
        final dbSettings = results.first;
        return {
          'enableMatchDuration': dbSettings['enable_match_duration'] == 1,
          'matchDuration': dbSettings['match_duration'],
          'matchSegments': dbSettings['match_segments'],
          'enableTargetDuration': dbSettings['enable_target_duration'] == 1,
          'targetPlayDuration': dbSettings['target_play_duration'],
          'enableSound': dbSettings['enable_sound'] == 1,
        };
      } catch (e) {
        // If database access fails, fallback to shared prefs
        print('Database error in getSessionSettings: $e - using SharedPreferences fallback');
        final prefs = await SharedPreferences.getInstance();
        final settings = prefs.getString('settings_$sessionId');
        if (settings == null) {
          // Return default settings when no saved settings exist
          return {
            'enableMatchDuration': false,
            'matchDuration': 90 * 60,
            'matchSegments': 2,
            'enableTargetDuration': false,
            'targetPlayDuration': 20 * 60,
            'enableSound': true,
          };
        }
        return Map<String, dynamic>.from(jsonDecode(settings));
      }
    }
  }

  Future<void> close() async {
    if (_database != null) {
      try {
        print('Closing database connection');
        
        // First check if database is already closed
        if (_database!.isOpen) {
          try {
            await _database!.execute('PRAGMA optimize');
          } catch (e) {
            print('Failed to optimize database on close: $e');
          }
          
          await _database!.close();
        }
        
        // If we're in read-only mode and shutting down, try to clean up the database file
        // to avoid future read-only issues
        if (_isInReadOnlyMode == true) {
          print('Detected read-only mode on close, attempting to clean up database file');
          try {
            // Get the database path
            final documentsDirectory = await getApplicationDocumentsDirectory();
            final path = join(documentsDirectory.path, 'sessions.db');
            final dbFile = File(path);
            
            // Create a backup before deleting
            if (await dbFile.exists()) {
              final backupPath = path + '.backup';
              try {
                await dbFile.copy(backupPath);
                print('Created database backup at $backupPath');
              } catch (e) {
                print('Failed to create backup: $e');
              }
              
              // Delete the database file
              try {
                await dbFile.delete();
                print('Deleted database file to fix read-only issues on next launch');
              } catch (e) {
                print('Failed to delete database file: $e');
              }
            }
          } catch (e) {
            print('Error cleaning up database file: $e');
          }
        }
        
        _database = null;
        // Reset read-only mode cache so we check again next time
        _isInReadOnlyMode = null;
        _hasTriedFallback = false; // Reset fallback flag
        print('Database connection closed');
      } catch (e) {
        print('Error closing database: $e');
        // Force reset the database even if close fails
        _database = null;
        _isInReadOnlyMode = null;
      }
    }
  }

  Future<void> deleteSession(int sessionId) async {
    // Check if we're in read-only mode
    final isReadOnly = await _isReadOnly();
    
    if (kIsWeb || isReadOnly) {
      final prefs = await this.prefs;
      final sessions = prefs.getString('sessions') ?? '[]';
      final sessionList = List<Map<String, dynamic>>.from(jsonDecode(sessions));
      sessionList.removeWhere((session) => session['id'] == sessionId);
      await prefs.setString('sessions', jsonEncode(sessionList));
      
      // Also delete related settings and players
      await prefs.remove('settings_$sessionId');
      await prefs.remove('players_$sessionId');
    } else {
      try {
        final db = await database;
        await db.delete('players', where: 'session_id = ?', whereArgs: [sessionId]);
        await db.delete('session_settings', where: 'session_id = ?', whereArgs: [sessionId]);
        await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
      } catch (e) {
        // If database access fails, fallback to shared prefs
        print('Database error in deleteSession: $e - using SharedPreferences fallback');
        final prefs = await SharedPreferences.getInstance();
        
        // Delete session from sessions list
        final sessions = prefs.getString('sessions') ?? '[]';
        final sessionList = List<Map<String, dynamic>>.from(jsonDecode(sessions));
        sessionList.removeWhere((session) => session['id'] == sessionId);
        await prefs.setString('sessions', jsonEncode(sessionList));
        
        // Delete related settings and players
        await prefs.remove('settings_$sessionId');
        await prefs.remove('players_$sessionId');
      }
    }
  }
  
  Future<void> clearAllSessions() async {
    // Check if we're in read-only mode
    final isReadOnly = await _isReadOnly();
    
    if (kIsWeb || isReadOnly) {
      final prefs = await this.prefs;
      await prefs.setString('sessions', '[]');
      
      // Also clear any session-specific keys
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith('settings_') || key.startsWith('players_')) {
          await prefs.remove(key);
        }
      }
    } else {
      try {
        final db = await database;
        await db.delete('players');
        await db.delete('session_settings');
        await db.delete('sessions');
      } catch (e) {
        // If database access fails, fallback to shared prefs
        print('Database error in clearAllSessions: $e - using SharedPreferences fallback');
        final prefs = await SharedPreferences.getInstance();
        
        // Clear all sessions
        await prefs.setString('sessions', '[]');
        
        // Also clear any session-specific keys
        final allKeys = prefs.getKeys();
        for (final key in allKeys) {
          if (key.startsWith('settings_') || key.startsWith('players_')) {
            await prefs.remove(key);
          }
        }
      }
    }
  }

  // Check if database seems corrupt
  Future<bool> _isDatabaseCorrupted(File dbFile) async {
    try {
      // Check if database file is very small (likely corrupted)
      final fileSize = await dbFile.length();
      if (fileSize < 100) {
        print('Database file seems corrupted (size too small: $fileSize bytes)');
        return true;
      }
      
      // Try to open and perform a simple query
      try {
        final db = await openDatabase(
          dbFile.path,
          version: 1,
          readOnly: true,
          singleInstance: false
        );
        
        try {
          // Try to read SQLite header and check the sessions table
          final version = await db.rawQuery('SELECT sqlite_version()');
          
          // Make sure we can access the necessary tables
          try {
            // Try to count the number of sessions (this will fail if table structure is corrupt)
            final count = await db.rawQuery('SELECT COUNT(*) FROM sessions');
            print('Database integrity verified: found ${count.first.values.first} sessions');
            await db.close();
            return false; // Database seems valid
          } catch (tableError) {
            // If we can't query our tables, the database schema may be corrupted
            print('Database tables appear corrupted: $tableError');
            await db.close();
            return true;
          }
        } catch (e) {
          print('Database seems corrupted (version query failed): $e');
          try {
            await db.close();
          } catch (_) {}
          return true;
        }
      } catch (e) {
        print('Database seems corrupted (open failed): $e');
        return true;
      }
    } catch (e) {
      print('Error checking if database is corrupted: $e');
      // In case of uncertainty, assume NOT corrupt to avoid data loss
      return false;
    }
  }
  
  // Try to recover a corrupted database
  Future<void> _recoverDatabase(File dbFile, String path) async {
    try {
      print('Attempting to recover database at $path');
      
      // Create backup
      final backupPath = path + '.bak';
      try {
        await dbFile.copy(backupPath);
        print('Created backup at $backupPath');
      } catch (e) {
        print('Failed to create backup: $e');
      }
      
      try {
        // Delete the corrupted database
        await dbFile.delete();
        print('Deleted corrupted database file');
        
        // Create empty valid database
        final db = await openDatabase(
          path, 
          version: 1, 
          onCreate: _createDB,
          singleInstance: false
        );
        await db.close();
        print('Created new empty database');
        
        // Try to recover session data from SharedPreferences if available
        await _recoverFromSharedPreferences();
      } catch (e) {
        print('Error during database recovery: $e');
        // Try to restore from backup if recovery failed
        final backupFile = File(backupPath);
        if (await backupFile.exists()) {
          try {
            await backupFile.copy(path);
            print('Restored database from backup');
          } catch (e) {
            print('Failed to restore from backup: $e');
          }
        }
      }
    } catch (e) {
      print('Database recovery failed: $e');
    }
  }
  
  // Try to recover data from SharedPreferences
  Future<void> _recoverFromSharedPreferences() async {
    try {
      print('Attempting to recover data from SharedPreferences');
      final prefs = await SharedPreferences.getInstance();
      
      // Check if we have any session data
      final sessions = prefs.getString('sessions');
      if (sessions == null || sessions.isEmpty) {
        print('No sessions found in SharedPreferences for recovery');
        return;
      }
      
      // Data exists in SharedPreferences, mark database as read-only
      // to force using SharedPreferences data
      _isInReadOnlyMode = true;
      print('Recovery found session data in SharedPreferences, using it');
    } catch (e) {
      print('Error recovering from SharedPreferences: $e');
    }
  }

  // Method to reset the database state for testing
  static void resetDatabaseState() {
    _isInReadOnlyMode = null;
    _hasTriedFallback = false;
    _database = null;
    _prefs = null;
    print('Database static state has been reset');
  }
}