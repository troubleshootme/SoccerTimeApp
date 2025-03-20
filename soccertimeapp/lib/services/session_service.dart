import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';

class SessionService {
  static const String _baseUrl = 'http://localhost:8000/session_handler.php'; // Use relative path for local server

  Future<bool> checkSessionExists(String password) async {
    try {
      print('Checking session for password: $password');
      var response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'check', 'password': password}),
      );

      print('Check session response status: ${response.statusCode}');
      print('Check session response body: ${response.body}');

      // Check for non-200 status codes
      if (response.statusCode != 200) {
        print('Check session failed with status: ${response.statusCode}');
        return false;
      }

      // Check for empty response body
      if (response.body.isEmpty) {
        print('Check session failed: Empty response body');
        return false;
      }

      var result;
      try {
        result = jsonDecode(response.body);
      } catch (e) {
        print('Failed to parse JSON response: $e');
        return false; // Assume session does not exist if JSON parsing fails
      }
      return result['exists'] ?? false;
    } catch (e) {
      print('Error checking session: $e');
      return false; // Return false if there was an error during the request
    }
  }

  Future<Session> loadSession(String password) async {
    try {
      var response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'load', 'password': password}),
      );
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        return Session.fromJson(data);
      }
      return Session();
    } catch (e) {
      print('Error loading session: $e');
      return Session();
    }
  }

  Future<void> saveSession(String password, Session session) async {
    try {
      await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'save',
          'password': password,
          'data': session.toJson(),
        }),
      );
    } catch (e) {
      print('Error saving session: $e');
    }
  }

  Future<void> saveSessionPassword(String password) async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString('sessionPassword', password);
  }

  Future<String?> loadSessionPassword() async {
    var prefs = await SharedPreferences.getInstance();
    return prefs.getString('sessionPassword');
  }

  Future<void> clearSessionPassword() async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessionPassword');
  }

  Future<void> saveTheme(bool isDarkTheme) async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', isDarkTheme);
  }

  Future<bool> loadTheme() async {
    var prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isDarkTheme') ?? true;
  }
}