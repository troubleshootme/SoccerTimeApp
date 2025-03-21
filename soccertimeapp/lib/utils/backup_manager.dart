import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../hive_database.dart';

class BackupManager {
  // Singleton pattern
  static final BackupManager _instance = BackupManager._internal();
  factory BackupManager() => _instance;
  BackupManager._internal();

  // Backup file name with format pattern for timestamps
  static const String backupFileNameBase = 'soccertime_backup';
  static const String backupFileExt = 'json';

  // Generate a backup filename with timestamp
  String _getBackupFileName() {
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return '${backupFileNameBase}_$timestamp.$backupFileExt';
  }

  /// Creates a backup of all session data and saves it directly to the Downloads folder
  Future<String?> backupSessions(BuildContext context) async {
    try {
      // Initialize the database
      await HiveSessionDatabase.instance.init();
      
      // Get all sessions
      final sessions = await HiveSessionDatabase.instance.getAllSessions();
      
      // For each session, get its players and settings
      final backupData = <Map<String, dynamic>>[];
      
      for (final session in sessions) {
        final sessionId = session['id'];
        final players = await HiveSessionDatabase.instance.getPlayersForSession(sessionId);
        final settings = await HiveSessionDatabase.instance.getSessionSettings(sessionId);
        
        backupData.add({
          'session': session,
          'players': players,
          'settings': settings,
        });
      }
      
      // Convert to JSON with nice formatting for better readability
      final jsonData = JsonEncoder.withIndent('  ').convert(backupData);
      
      // Generate a unique filename with timestamp
      final backupFileName = _getBackupFileName();
      
      // Try multiple paths for Downloads folder
      final paths = [
        '/storage/emulated/0/Download',    // Primary storage path
        '/sdcard/Download',                // Alternative path
      ];
      
      // Also try to get the external storage directory
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Navigate up to find Download folder
          var current = externalDir;
          var pathParts = current.path.split('/');
          
          // Try to find the Download folder by navigating up the directory tree
          for (int i = pathParts.length; i >= 3; i--) {
            var basePath = pathParts.sublist(0, i).join('/');
            var downloadPath = '$basePath/Download';
            var downloadDir = Directory(downloadPath);
            if (await downloadDir.exists()) {
              paths.add(downloadPath);
              break;
            }
          }
        }
      } catch (e) {
        print('Error finding external directory: $e');
      }
      
      // Try each path until one works
      String? filePath;
      Exception? lastError;
      
      for (final path in paths) {
        try {
          final downloadDir = Directory(path);
          if (await downloadDir.exists()) {
            final backupFile = File('$path/$backupFileName');
            
            // No need to delete since filename is unique with timestamp
            await backupFile.writeAsString(jsonData);
            filePath = backupFile.path;
            print('Backup saved to: $filePath');
            break;
          }
        } catch (e) {
          print('Failed to save to $path: $e');
          lastError = e as Exception;
        }
      }
      
      if (filePath != null) {
        // Show success message with the file path
        _showBackupSuccess(context, filePath);
        return filePath;
      } else {
        throw lastError ?? Exception('Could not access any Download folder');
      }
    } catch (e) {
      print('Error creating backup: $e');
      
      // Fallback to sharing method if direct save fails
      try {
        return await _fallbackToShareBackup(context);
      } catch (e2) {
        print('Even fallback method failed: $e2');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating backup: $e')),
        );
        return null;
      }
    }
  }
  
  /// Fallback method using share if direct file access fails
  Future<String?> _fallbackToShareBackup(BuildContext context) async {
    // Initialize the database
    await HiveSessionDatabase.instance.init();
    
    // Get all sessions
    final sessions = await HiveSessionDatabase.instance.getAllSessions();
    
    // For each session, get its players and settings
    final backupData = <Map<String, dynamic>>[];
    
    for (final session in sessions) {
      final sessionId = session['id'];
      final players = await HiveSessionDatabase.instance.getPlayersForSession(sessionId);
      final settings = await HiveSessionDatabase.instance.getSessionSettings(sessionId);
      
      backupData.add({
        'session': session,
        'players': players,
        'settings': settings,
      });
    }
    
    // Convert to JSON with nice formatting for better readability
    final jsonData = JsonEncoder.withIndent('  ').convert(backupData);
    
    // Generate a unique filename with timestamp
    final backupFileName = _getBackupFileName();
    
    // Create temp file and use share_plus
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$backupFileName');
    await tempFile.writeAsString(jsonData);
    
    await Share.shareXFiles(
      [XFile(tempFile.path)],
      subject: 'Soccer Time App Backup',
      text: 'Please save this file to your Downloads folder as $backupFileName',
    );
    
    print('Backup shared using share_plus (fallback method)');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please save the file to your Downloads folder as "$backupFileName"')),
    );
    
    return 'Shared as $backupFileName';
  }
  
  /// Restores session data from a backup file in Downloads folder
  Future<bool> restoreSessions(BuildContext context) async {
    try {
      // Find available backup files in all possible paths
      final availableBackups = await _findBackupFiles();
      
      if (availableBackups.isEmpty) {
        // Show error that no backup files were found
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No backup files found in Downloads folder.'),
            duration: Duration(seconds: 5),
          ),
        );
        return false;
      }
      
      // Sort backups by date (newest first)
      availableBackups.sort((a, b) => b.path.compareTo(a.path));
      
      // Show dialog to select which backup to restore
      final selectedBackup = await _showBackupSelectionDialog(context, availableBackups);
      if (selectedBackup == null) {
        return false; // User canceled
      }
      
      // Read the selected backup file
      final backupContent = await selectedBackup.readAsString();
      
      // Parse JSON
      late List<dynamic> backupData;
      try {
        backupData = jsonDecode(backupContent);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid backup file format. Please check the content and try again.')),
        );
        return false;
      }
      
      // Confirm with user before proceeding
      final shouldRestore = await _showRestoreConfirmation(context);
      if (!shouldRestore) {
        return false;
      }
      
      // Initialize database
      await HiveSessionDatabase.instance.init();
      
      // Clear existing data
      await HiveSessionDatabase.instance.clearAllSessions();
      
      // Restore each session with its players and settings
      int restoredSessions = 0;
      for (final item in backupData) {
        final session = item['session'];
        final players = item['players'];
        final settings = item['settings'];
        
        // Create session
        final sessionId = await HiveSessionDatabase.instance.insertSession(session['name']);
        
        // Restore players
        for (final player in players) {
          await HiveSessionDatabase.instance.insertPlayer(
            sessionId, 
            player['name'], 
            player['timer_seconds'] ?? 0,
          );
        }
        
        // Restore settings
        if (settings != null) {
          await HiveSessionDatabase.instance.saveSessionSettings(sessionId, settings);
        }
        
        restoredSessions++;
      }
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully restored $restoredSessions sessions')),
      );
      
      print('Successfully restored $restoredSessions sessions');
      return true;
    } catch (e) {
      print('Error restoring backup: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error restoring backup: $e')),
      );
      return false;
    }
  }
  
  /// Find all backup files in potential download folders
  Future<List<File>> _findBackupFiles() async {
    List<File> backups = [];
    
    // Try multiple paths for Downloads folder
    final paths = [
      '/storage/emulated/0/Download',    // Primary storage path
      '/sdcard/Download',                // Alternative path
    ];
    
    // Also try to get the external storage directory
    try {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        // Navigate up to find Download folder
        var current = externalDir;
        var pathParts = current.path.split('/');
        
        // Try to find the Download folder by navigating up the directory tree
        for (int i = pathParts.length; i >= 3; i--) {
          var basePath = pathParts.sublist(0, i).join('/');
          var downloadPath = '$basePath/Download';
          var downloadDir = Directory(downloadPath);
          if (await downloadDir.exists()) {
            paths.add(downloadPath);
            break;
          }
        }
      }
    } catch (e) {
      print('Error finding external directory: $e');
    }
    
    // Check each path for backup files
    for (final path in paths) {
      try {
        final downloadDir = Directory(path);
        if (await downloadDir.exists()) {
          // List all files in directory
          final entities = await downloadDir.list().toList();
          
          // Filter for backup files
          for (final entity in entities) {
            if (entity is File && 
                entity.path.contains(backupFileNameBase) && 
                entity.path.endsWith(backupFileExt)) {
              backups.add(entity);
            }
          }
        }
      } catch (e) {
        print('Error listing files in $path: $e');
      }
    }
    
    return backups;
  }
  
  /// Shows a dialog to select which backup file to restore
  Future<File?> _showBackupSelectionDialog(BuildContext context, List<File> backups) async {
    // Format date from filename for display
    String formatBackupDate(String filePath) {
      final fileName = filePath.split('/').last;
      final dateMatch = RegExp(r'(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})').firstMatch(fileName);
      
      if (dateMatch != null) {
        final year = dateMatch.group(1);
        final month = dateMatch.group(2);
        final day = dateMatch.group(3);
        final hour = dateMatch.group(4);
        final minute = dateMatch.group(5);
        
        return '$year-$month-$day $hour:$minute';
      }
      
      // Fallback if pattern doesn't match
      return fileName;
    }
    
    return await showDialog<File?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Backup to Restore'),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: backups.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final backup = backups[index];
              final fileName = backup.path.split('/').last;
              final formattedDate = formatBackupDate(fileName);
              
              return ListTile(
                title: Text('Backup from $formattedDate'),
                subtitle: Text(fileName, style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.of(context).pop(backup),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  /// Shows a confirmation dialog before restoring
  Future<bool> _showRestoreConfirmation(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restore Sessions'),
        content: Text(
          'Restoring from backup will replace all current sessions. This cannot be undone. Continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('Restore'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Shows a success message after backup
  void _showBackupSuccess(BuildContext context, String filePath) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Backup saved to Downloads folder'),
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Details',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Backup Successful'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Your backup was saved to:'),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          filePath,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'This file can be used to restore your data if you reinstall the app.',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('OK'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  
  /// Public method to show backup success message
  void showBackupSuccess(BuildContext context, String filePath) {
    _showBackupSuccess(context, filePath);
  }
} 