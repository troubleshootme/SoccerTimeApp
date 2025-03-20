import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';

class SessionDatabase {
  static final SessionDatabase instance = SessionDatabase._init();
  static Database? _database;
  static SharedPreferences? _prefs;

  SessionDatabase._init() {
    // Initialize FFI for desktop platforms
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (kIsWeb) throw UnsupportedError('SQLite not supported on web');
    if (_database != null) return _database!;
    _database = await _initDB('sessions.db');
    return _database!;
  }

  Future<SharedPreferences> get prefs async {
    if (kIsWeb) {
      _prefs ??= await SharedPreferences.getInstance();
      return _prefs!;
    }
    throw UnsupportedError('SharedPreferences only for web');
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
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
      final players = prefs.getString('players_$sessionId') ?? '[]';
      final playerList = List<Map<String, dynamic>>.from(jsonDecode(players));
      final newId = playerList.isEmpty ? 1 : playerList.map((p) => p['id'] as int).reduce((a, b) => a > b ? a : b) + 1;
      final player = {'id': newId, 'session_id': sessionId, 'name': name, 'timer_seconds': timerSeconds};
      playerList.add(player);
      await prefs.setString('players_$sessionId', jsonEncode(playerList));
      return newId;
    } else {
      final db = await database;
      final data = {'session_id': sessionId, 'name': name, 'timer_seconds': timerSeconds};
      return await db.insert('players', data);
    }
  }

  Future<void> updatePlayerTimer(int playerId, int timerSeconds) async {
    if (kIsWeb) {
      // Handle updating player timer in SharedPreferences if needed
      throw UnsupportedError('Updating player timer not supported on web');
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

  Future close() async {
    final db = await database;
    db.close();
  }
}