import 'dart:convert';
import 'package:csv/csv.dart';
// import 'package:file_picker/file_picker.dart'; // Removed file_picker import
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/session.dart';
import '../utils/format_time.dart';

class FileService {
  Future<void> exportToCsv(Session session, String sessionPassword) async {
    List<List<dynamic>> rows = [
      ['Player', 'Time'],
    ];
    session.players.forEach((name, player) {
      rows.add([name, formatTime(player.totalTime)]);
    });
    String csv = const ListToCsvConverter().convert(rows);
    var dir = await getTemporaryDirectory();
    var file = File('${dir.path}/${sessionPassword}_times.csv');
    await file.writeAsString(csv);
    // In a real app, use a file sharing plugin to share the file
    print('CSV exported to: ${file.path}');
  }

  Future<void> backupSession(Session session, String sessionPassword) async {
    var dir = await getTemporaryDirectory();
    var file = File('${dir.path}/${sessionPassword}_backup.json');
    await file.writeAsString(jsonEncode(session.toJson()));
    // In a real app, use a file sharing plugin to share the file
    print('Backup saved to: ${file.path}');
  }

  Future<Session?> restoreSession() async {
    // Mocked for now since file_picker is removed
    print('File picking not supported. Returning dummy session.');
    return Session(); // Return a dummy session for testing
  }
}