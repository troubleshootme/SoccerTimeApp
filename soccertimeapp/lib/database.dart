import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform, Directory;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class SessionDatabase {
  static final SessionDatabase instance = SessionDatabase._init();
  static Database? _database;
  static SharedPreferences? _prefs;
  static bool _hasTriedFallback = false;

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
      // Test if we can write to the database
      await _database!.execute('PRAGMA user_version = 1');
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

  Future<Database> _initDB(String filePath) async {
    try {
      // First try app documents directory
      final documentsDirectory = await getApplicationDocumentsDirectory();
      await Directory(documentsDirectory.path).create(recursive: true);
      final path = join(documentsDirectory.path, filePath);
      print('Using database path: $path');
      
      return await openDatabase(
        path, 
        version: 1, 
        onCreate: _createDB,
        singleInstance: true,
        readOnly: false
      );
    } catch (e) {
      print('Error accessing app documents directory: $e');
      
      // If app documents fail, try databases directory
      try {
        final dbPath = await getDatabasesPath();
        await Directory(dbPath).create(recursive: true);
        final path = join(dbPath, filePath);
        print('Using alternative database path: $path');
        
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
    if (kIsWeb) {
      final prefs = await this.prefs;
      final sessions = prefs.getString('sessions') ?? '[]';
      final sessionList = List<Map<String, dynamic>>.from(jsonDecode(sessions));
      final newId = sessionList.isEmpty ? 1 : sessionList.map((s) => s['id'] as int).reduce((a, b) => a > b ? a : b) + 1;
      final session = {'id': newId, 'name': name, 'created_at': DateTime.now().millisecondsSinceEpoch};
      sessionList.add(session);
      await prefs.setString('sessions', jsonEncode(sessionList));
      return newId;
    } else {
      final db = await database;
      final data = {'name': name, 'created_at': DateTime.now().millisecondsSinceEpoch};
      return await db.insert('sessions', data);
    }
  }

  Future<List<Map<String, dynamic>>> getAllSessions() async {
    if (kIsWeb) {
      final prefs = await this.prefs;
      final sessions = prefs.getString('sessions') ?? '[]';
      final sessionList = List<Map<String, dynamic>>.from(jsonDecode(sessions));
      sessionList.sort((a, b) => (b['created_at'] as int).compareTo(a['created_at'] as int));
      return sessionList;
    } else {
      final db = await database;
      return await db.query('sessions', orderBy: 'created_at DESC');
    }
  }

  Future<List<Map<String, dynamic>>> getPlayersForSession(int sessionId) async {
    if (kIsWeb) {
      final prefs = await this.prefs;
      final players = prefs.getString('players_$sessionId') ?? '[]';
      return List<Map<String, dynamic>>.from(jsonDecode(players));
    } else {
      final db = await database;
      return await db.query('players', where: 'session_id = ?', whereArgs: [sessionId]);
    }
  }

  Future<int> insertPlayer(int sessionId, String name, int timerSeconds) async {
    if (kIsWeb) {
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
      final db = await database;
      final data = {'session_id': sessionId, 'name': name, 'timer_seconds': timerSeconds};
      return await db.insert('players', data);
    }
  }

  Future<void> updatePlayerTimer(int playerId, int timerSeconds) async {
    if (kIsWeb) {
      final prefs = await this.prefs;
      final sessions = await getAllSessions();
      final session = sessions.firstWhere((s) => s['id'] == playerId, orElse: () => {'id': -1});
      final sessionId = session['id'] != -1 ? session['id'] : null;
      if (sessionId != null) {
        final playersKey = 'players_$sessionId';
        final players = prefs.getString(playersKey) ?? '[]';
        final playerList = List<Map<String, dynamic>>.from(jsonDecode(players));
        final playerIndex = playerList.indexWhere((p) => p['id'] == playerId);
        if (playerIndex != -1) {
          playerList[playerIndex]['timer_seconds'] = timerSeconds;
          await prefs.setString(playersKey, jsonEncode(playerList));
        }
      }
    } else {
      final db = await database;
      await db.update(
        'players',
        {'timer_seconds': timerSeconds},
        where: 'id = ?',
        whereArgs: [playerId],
      );
    }
  }

  Future<void> saveSessionSettings(int sessionId, Map<String, dynamic> settings) async {
    if (kIsWeb) {
      final prefs = await this.prefs;
      await prefs.setString('settings_$sessionId', jsonEncode(settings));
    } else {
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
    }
  }

  Future<Map<String, dynamic>?> getSessionSettings(int sessionId) async {
    if (kIsWeb) {
      final prefs = await this.prefs;
      final settings = prefs.getString('settings_$sessionId');
      if (settings == null) return null;
      return Map<String, dynamic>.from(jsonDecode(settings));
    } else {
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
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}