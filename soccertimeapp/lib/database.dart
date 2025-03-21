import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'dart:convert';

class SessionDatabase {
  static final SessionDatabase instance = SessionDatabase._init();
  static Database? _database;
  static SharedPreferences? _prefs;

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
    _database = await _initDB('sessions.db');
    return _database!;
  }

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
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
    final db = await database;
    final data = {'name': name, 'created_at': DateTime.now().millisecondsSinceEpoch};
    return await db.insert('sessions', data);
  }

  Future<List<Map<String, dynamic>>> getAllSessions() async {
    final db = await database;
    return await db.query('sessions', orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getPlayersForSession(int sessionId) async {
    final db = await database;
    return await db.query('players', where: 'session_id = ?', whereArgs: [sessionId]);
  }

  Future<int> insertPlayer(int sessionId, String name, int timerSeconds) async {
    final db = await database;
    final data = {'session_id': sessionId, 'name': name, 'timer_seconds': timerSeconds};
    return await db.insert('players', data);
  }

  Future<void> updatePlayerTimer(int playerId, int timerSeconds) async {
    final db = await database;
    await db.update(
      'players',
      {'timer_seconds': timerSeconds},
      where: 'id = ?',
      whereArgs: [playerId],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}