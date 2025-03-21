import 'package:flutter/material.dart';
import '../database.dart';

class AppState with ChangeNotifier {
  bool _isDarkTheme = false;
  int? _currentSessionId;
  List<Map<String, dynamic>> _players = [];

  int? get currentSessionId => _currentSessionId;
  List<Map<String, dynamic>> get players => _players;

  Future<void> loadSession(int sessionId) async {
    _currentSessionId = sessionId;
    _players = await SessionDatabase.instance.getPlayersForSession(sessionId);
    _players.sort((a, b) => a['name'].compareTo(b['name']));
    notifyListeners();
  }

  Future<void> createSession(String name) async {
    _currentSessionId = await SessionDatabase.instance.insertSession(name);
    _players = [];
    notifyListeners();
  }

  Future<void> updatePlayerTimer(int playerId, int timerSeconds) async {
    if (_currentSessionId != null) {
      await SessionDatabase.instance.updatePlayerTimer(playerId, timerSeconds);
      _players = await SessionDatabase.instance.getPlayersForSession(_currentSessionId!);
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
    } else {
      _players.add({'name': name, 'timer_seconds': 0});
    }
    notifyListeners();
  }
}