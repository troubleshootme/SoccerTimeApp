import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';
import '../models/player.dart';
import '../models/match_log_entry.dart';

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
      // Create a default session to use if anything goes wrong - MOVED TO TOP OF METHOD
      var defaultSession = Session(
        matchDuration: 90 * 60,
        enableMatchDuration: true,
        matchSegments: 2,
        currentPeriod: 1,
        players: <String, Player>{},
        matchLog: <MatchLogEntry>[],
      );
      
      var response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'load', 'password': password}),
      );
      
      if (response.statusCode == 200) {
        print('Load session response: ${response.body}');
        var rawData = jsonDecode(response.body);
        
        // Check if response is an array instead of an object
        if (rawData is List) {
          print('Warning: Received array instead of object, returning default session');
          return defaultSession;
        }
        
        // Now we know rawData is a Map
        if (rawData is Map<String, dynamic>) {
          // Create a corrected copy of the raw data
          var correctedData = Map<String, dynamic>.from(rawData);
          
          // Fix players property if it's an array instead of a map
          if (correctedData.containsKey('players') && correctedData['players'] is List) {
            print('Warning: players property is not a map, converting to empty map');
            correctedData['players'] = <String, dynamic>{};
          }
          
          // Ensure matchLog exists and is a list
          if (!correctedData.containsKey('matchLog')) {
            correctedData['matchLog'] = [];
          } else if (correctedData['matchLog'] is! List) {
            correctedData['matchLog'] = [];
          }
          
          // Make sure currentOrder exists and is a list
          if (!correctedData.containsKey('currentOrder')) {
            correctedData['currentOrder'] = [];
          } else if (correctedData['currentOrder'] is! List) {
            // If currentOrder is not a list, convert it
            correctedData['currentOrder'] = [];
          }
          
          // Make sure activeBeforePause exists and is a list
          if (!correctedData.containsKey('activeBeforePause')) {
            correctedData['activeBeforePause'] = [];
          } else if (correctedData['activeBeforePause'] is! List) {
            // If activeBeforePause is not a list, convert it
            correctedData['activeBeforePause'] = [];
          }
          
          // Set defaults for any missing properties
          if (!correctedData.containsKey('matchDuration')) {
            correctedData['matchDuration'] = 90 * 60;
          }
          if (!correctedData.containsKey('enableMatchDuration')) {
            correctedData['enableMatchDuration'] = true;
          }
          if (!correctedData.containsKey('matchSegments')) {
            correctedData['matchSegments'] = 2;
          }
          if (!correctedData.containsKey('currentPeriod')) {
            correctedData['currentPeriod'] = 1;
          }
          if (!correctedData.containsKey('targetPlayDuration')) {
            correctedData['targetPlayDuration'] = 16 * 60;
          }
          
          // Handle other defaults
          correctedData['isPaused'] = correctedData['isPaused'] ?? false;
          correctedData['enableTargetDuration'] = correctedData['enableTargetDuration'] ?? false;
          correctedData['matchTime'] = correctedData['matchTime'] ?? 0;
          correctedData['matchStartTime'] = correctedData['matchStartTime'] ?? 0;
          correctedData['matchRunning'] = correctedData['matchRunning'] ?? false;
          correctedData['hasWhistlePlayed'] = correctedData['hasWhistlePlayed'] ?? false;
          correctedData['enableSound'] = correctedData['enableSound'] ?? false;
          
          // Log our corrections
          print('Corrected data properties: ${correctedData.keys.toList()}');
          
          // Normal case: use the corrected data
          return Session.fromJson(correctedData);
        }
        
        print('Warning: Received unexpected data type, returning default session');
        return defaultSession;
      }
      
      print('Failed to load session. Status: ${response.statusCode}, Body: ${response.body}');
      return defaultSession; // Now this is in scope
    } catch (e) {
      print('Error loading session: $e');
      // Return a new session with explicit initialization for players and matchLog
      return Session(
        matchDuration: 90 * 60,
        enableMatchDuration: true,
        matchSegments: 2,
        currentPeriod: 1,
        players: <String, Player>{},
        matchLog: <MatchLogEntry>[],
      );
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