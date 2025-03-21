import 'dart:convert';
import 'package:csv/csv.dart';
// import 'package:file_picker/file_picker.dart'; // Removed file_picker import
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/session.dart';
import '../utils/format_time.dart';
import 'package:share_plus/share_plus.dart';

class FileService {
  Future<String?> exportToCsv(Session session, String sessionPassword) async {
    try {
      List<List<dynamic>> rows = [
        ['Player', 'Time'],
      ];
      session.players.forEach((name, player) {
        rows.add([name, formatTime(player.totalTime)]);
      });
      
      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);
      
      // Create filename with session name for better identification
      final fileName = '${session.sessionName.replaceAll(' ', '_')}_times.csv';
      
      // Try to save directly to Downloads folder
      try {
        final downloadsPath = '/storage/emulated/0/Download';
        final downloadDir = Directory(downloadsPath);
        
        if (!await downloadDir.exists()) {
          throw Exception('Could not access Downloads folder');
        }
        
        final file = File('$downloadsPath/$fileName');
        await file.writeAsString(csv);
        
        final filePath = file.path;
        print('CSV exported to: $filePath');
        
        return filePath;
      } catch (e) {
        print('Error saving to Downloads, using fallback method: $e');
        return await _fallbackShareCsv(csv, fileName);
      }
    } catch (e) {
      print('Error exporting CSV: $e');
      rethrow;
    }
  }
  
  Future<String?> _fallbackShareCsv(String csvContent, String fileName) async {
    // Get temp directory for saving file
    var dir = await getTemporaryDirectory();
    var file = File('${dir.path}/$fileName');
    
    // Write to file
    await file.writeAsString(csvContent);
    
    // Share the file
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Soccer Time App - Player Times',
      text: 'Please save this CSV file to your Downloads folder',
    );
    
    print('CSV shared using Share.shareXFiles: ${file.path}');
    return 'Shared as $fileName';
  }

  Future<void> backupSession(Session session, String sessionPassword) async {
    // Get temp directory for saving file
    var dir = await getTemporaryDirectory();
    var file = File('${dir.path}/${sessionPassword}_backup.json');
    
    // Convert session to JSON and write to file
    await file.writeAsString(jsonEncode(session.toJson()));
    
    // In a real app, use a file sharing plugin to share the file
    print('Backup saved to: ${file.path}');
  }

  Future<Session?> restoreSession() async {
    // In a real app, this would use file_picker to allow user to select a file
    // Since we removed that dependency, we're returning a dummy session for testing
    print('File picking not supported. Returning dummy session.');
    return Session();
  }
}