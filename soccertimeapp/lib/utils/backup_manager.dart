import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../hive_database.dart';
import 'package:permission_handler/permission_handler.dart';

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
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}_${now.millisecond.toString().padLeft(3, '0')}';
    return '${backupFileNameBase}_$timestamp.$backupFileExt';
  }

  /// Request storage permission for Android
  Future<bool> _requestStoragePermission() async {
    try {
      // Check if permission is already granted
      var status = await Permission.storage.status;
      if (status.isGranted) {
        return true;
      }
      
      // If denied, request permission
      status = await Permission.storage.request();
      if (status.isGranted) {
        return true;
      }
      
      // If still not granted, try requesting external storage permission
      status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    } catch (e) {
      print('Error requesting storage permission: $e');
      return false;
    }
  }

  /// Creates a backup of all session data and saves it directly to the Downloads folder
  Future<String?> backupSessions(BuildContext context) async {
    try {
      // Request permission first
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage permission denied. Cannot create backup file.'),
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
        throw Exception('Storage permission denied');
      }
      
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
      
      // Create a multi-backup strategy where we save to multiple locations
      // to ensure at least one copy is accessible after reinstallation
      List<String> successPaths = [];
      List<String> primaryPaths = []; // Paths to try first
      List<String> secondaryPaths = []; // Fallback paths
      Exception? lastError;
      
      // STRATEGY 1: Public Downloads folders - most user-accessible
      primaryPaths.addAll([
        '/storage/emulated/0/Download',
        '/sdcard/Download',
        '/storage/emulated/0/Downloads',
        '/sdcard/Downloads',
      ]);
      
      // STRATEGY 2: Try DCIM folder which is typically excluded from app uninstall cleanup
      primaryPaths.addAll([
        '/storage/emulated/0/DCIM/SoccerTimeBackups',
        '/sdcard/DCIM/SoccerTimeBackups',
      ]);
      
      // Try to create DCIM backup directory if it doesn't exist
      for (int i = 4; i < primaryPaths.length; i++) {
        try {
          await Directory(primaryPaths[i]).create(recursive: true);
          print('Created backup directory: ${primaryPaths[i]}');
        } catch (e) {
          print('Failed to create directory ${primaryPaths[i]}: $e');
        }
      }
      
      // STRATEGY 3: Application specific directories - less accessible but more reliable
      try {
        // App's documents directory - will be removed on uninstall
        final documentsDir = await getApplicationDocumentsDirectory();
        if (documentsDir != null) {
          secondaryPaths.add(documentsDir.path);
        }
        
        // External storage directories - may be preserved after uninstall
        if (Platform.isAndroid) {
          final externalStoragePaths = await getExternalStorageDirectories();
          if (externalStoragePaths != null && externalStoragePaths.isNotEmpty) {
            secondaryPaths.addAll(externalStoragePaths.map((dir) => dir.path));
          }
        }
        
        // Cache directory - just in case, but will likely be cleared
        final tempDir = await getTemporaryDirectory();
        secondaryPaths.add(tempDir.path);
        
      } catch (e) {
        print('Error getting app-specific directories: $e');
      }
      
      // STRATEGY 4: External storage directory (main)
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          secondaryPaths.add(externalDir.path);
        }
      } catch (e) {
        print('Error getting external storage directory: $e');
      }
      
      // First try primary paths
      bool backupSaved = false;
      String? primaryFilePath;
      
      for (final path in primaryPaths) {
        if (backupSaved) continue;
        
        try {
          final downloadDir = Directory(path);
          final dirExists = await downloadDir.exists();
          if (!dirExists) {
            // Try to create directory if it doesn't exist
            try {
              await downloadDir.create(recursive: true);
              print('Created directory: $path');
            } catch (e) {
              print('Failed to create directory $path: $e');
              continue;
            }
          }
          
          print('Trying to save to: $path');
          final backupFile = File('$path/$backupFileName');
          
          await backupFile.writeAsString(jsonData);
          successPaths.add(backupFile.path);
          
          if (primaryFilePath == null) {
            primaryFilePath = backupFile.path;
            backupSaved = true;
            print('Primary backup saved to: $primaryFilePath');
          } else {
            print('Additional backup saved to: ${backupFile.path}');
          }
        } catch (e) {
          print('Failed to save to $path: $e');
          lastError = e as Exception;
        }
      }
      
      // Then try secondary paths for redundancy, but don't set backupSaved flag
      for (final path in secondaryPaths) {
        try {
          final dirPath = Directory(path);
          if (await dirPath.exists()) {
            print('Trying to save backup copy to: $path');
            final backupFile = File('$path/$backupFileName');
            
            await backupFile.writeAsString(jsonData);
            successPaths.add(backupFile.path);
            print('Backup copy saved to: ${backupFile.path}');
          }
        } catch (e) {
          print('Failed to save backup copy to $path: $e');
        }
      }
      
      // If at least one backup was saved successfully
      if (successPaths.isNotEmpty) {
        final filePath = primaryFilePath ?? successPaths.first;
        
        // Show success message with the file path
        _showBackupSuccess(context, filePath);
        
        // Show a more detailed message if we saved to multiple locations
        if (successPaths.length > 1) {
          print('Successfully created ${successPaths.length} backup copies');
        }
        
        return filePath;
      } else {
        throw lastError ?? Exception('Could not access any storage locations for backup');
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
  
  /// Shows a dialog to select which backup file to restore
  Future<Map<String, dynamic>?> _showBackupSelectionDialog(BuildContext context, List<File> backups) async {
    // Format date from filename for display
    String formatBackupDate(String filePath) {
      final fileName = filePath.split('/').last;
      
      // Match the new timestamp format that includes seconds and milliseconds
      final dateMatch = RegExp(r'(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})_?(\d{3})?').firstMatch(fileName);
      
      if (dateMatch != null) {
        final year = dateMatch.group(1);
        final month = dateMatch.group(2);
        final day = dateMatch.group(3);
        final hour = dateMatch.group(4);
        final minute = dateMatch.group(5);
        final second = dateMatch.group(6);
        final millisecond = dateMatch.group(7) ?? '';
        
        if (millisecond.isNotEmpty) {
          return '$year-$month-$day $hour:$minute:$second.$millisecond';
        } else {
          return '$year-$month-$day $hour:$minute:$second';
        }
      }
      
      // Fallback if pattern doesn't match
      return fileName;
    }
    
    bool deleteOtherBackups = false;
    
    return await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Select Backup to Restore'),
          content: Container(
            width: double.maxFinite,
            height: 350, // Increased height to accommodate checkbox
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: backups.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final backup = backups[index];
                      final fileName = backup.path.split('/').last;
                      final formattedDate = formatBackupDate(fileName);
                      
                      // Get file size information for display
                      int fileSize = 0;
                      try {
                        fileSize = backup.lengthSync();
                      } catch (e) {
                        print('Error getting file size: $e');
                      }
                      
                      // Format file size
                      String formattedSize = '';
                      if (fileSize < 1024) {
                        formattedSize = '$fileSize B';
                      } else if (fileSize < 1024 * 1024) {
                        formattedSize = '${(fileSize / 1024).toStringAsFixed(1)} KB';
                      } else {
                        formattedSize = '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
                      }
                      
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text('Backup from $formattedDate'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fileName, 
                                  style: TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                              Text('Size: $formattedSize',
                                  style: TextStyle(fontSize: 12)),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () => Navigator.of(context).pop({
                            'backup': backup,
                            'deleteOthers': deleteOtherBackups
                          }),
                        ),
                      );
                    },
                  ),
                ),
                CheckboxListTile(
                  title: Text(
                    'Restore this backup and DELETE all other backups',
                    style: TextStyle(fontSize: 14),
                  ),
                  value: deleteOtherBackups,
                  onChanged: (value) {
                    setState(() {
                      deleteOtherBackups = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Restores session data from a backup file in Downloads folder
  Future<bool> restoreSessions(BuildContext context) async {
    try {
      // Request permission first
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage permission denied. Cannot access backup files.'),
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
        return false;
      }
      
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
      final result = await _showBackupSelectionDialog(context, availableBackups);
      if (result == null) {
        return false; // User canceled
      }
      
      final selectedBackup = result['backup'] as File;
      final deleteOtherBackups = result['deleteOthers'] as bool;
      
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
      
      // Delete other backups if requested
      if (deleteOtherBackups) {
        int deletedCount = 0;
        for (final backup in availableBackups) {
          if (backup.path != selectedBackup.path) {
            try {
              await backup.delete();
              deletedCount++;
            } catch (e) {
              print('Error deleting backup: ${backup.path}: $e');
            }
          }
        }
        print('Deleted $deletedCount other backup files');
      }
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(deleteOtherBackups
          ? 'Successfully restored $restoredSessions sessions and deleted ${availableBackups.length - 1} other backups'
          : 'Successfully restored $restoredSessions sessions')),
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
    
    // Try multiple paths for Downloads folder with more comprehensive options
    final paths = [
      '/storage/emulated/0/Download',    // Primary storage path
      '/sdcard/Download',                // Alternative path
      '/storage/emulated/0/Downloads',   // Another common path
      '/sdcard/Downloads',               // Alternative path
      '/storage/self/primary/Download',  // Another Android path variant
      '/storage/emulated/0/Android/data/com.example.soccertimeapp/files', // App-specific external storage
    ];
    
    // Add path for user-facing folders on Android 10+
    if (Platform.isAndroid) {
      try {
        final externalStoragePaths = await getExternalStorageDirectories();
        if (externalStoragePaths != null) {
          for (var dir in externalStoragePaths) {
            print('External storage directory: ${dir.path}');
            paths.add(dir.path);
          }
        }
      } catch (e) {
        print('Error getting external storage directories: $e');
      }
    }
    
    // Also try to get the external storage directory
    try {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        print('External storage directory for finding backups: ${externalDir.path}');
        paths.add(externalDir.path);
        
        // Navigate up to find Download folder
        var current = externalDir;
        var pathParts = current.path.split('/');
        
        // Try to find the Download folder by navigating up the directory tree
        for (int i = pathParts.length; i >= 3; i--) {
          var basePath = pathParts.sublist(0, i).join('/');
          for (var downloadName in ['Download', 'Downloads']) {
            var downloadPath = '$basePath/$downloadName';
            var downloadDir = Directory(downloadPath);
            if (await downloadDir.exists()) {
              print('Found Download folder at: $downloadPath');
              paths.add(downloadPath);
            }
          }
        }
      }
    } catch (e) {
      print('Error finding external directory for backups: $e');
    }
    
    // Add Documents directory as another option
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      if (documentsDir != null) {
        print('Documents directory for finding backups: ${documentsDir.path}');
        paths.add(documentsDir.path);
      }
    } catch (e) {
      print('Error finding documents directory: $e');
    }
    
    // Add temporary directory as a fallback
    try {
      final tempDir = await getTemporaryDirectory();
      print('Temporary directory for finding backups: ${tempDir.path}');
      paths.add(tempDir.path);
    } catch (e) {
      print('Error finding temporary directory: $e');
    }
    
    // For root paths and DCIM folder
    try {
      final dcimPaths = [
        '/storage/emulated/0',
        '/sdcard',
        '/storage/emulated/0/DCIM',
        '/sdcard/DCIM',
      ];
      paths.addAll(dcimPaths);
    } catch (e) {
      print('Error adding DCIM paths: $e');
    }
    
    // Recursive search for backup files
    Future<void> searchDirectoryRecursively(String path, int depth) async {
      if (depth > 3) return; // Limit recursion depth to avoid excessive searching
      
      try {
        final dir = Directory(path);
        if (await dir.exists()) {
          final entities = await dir.list().toList();
          
          // Search for backup files in current directory
          for (final entity in entities) {
            if (entity is File && 
                entity.path.contains(backupFileNameBase) && 
                entity.path.endsWith(backupFileExt)) {
              print('Found backup file: ${entity.path}');
              if (!backups.any((file) => file.path == entity.path)) {
                backups.add(entity);
              }
            }
          }
          
          // Recursively search subdirectories
          if (depth < 2) { // Only go deeper for top-level directories
            for (final entity in entities) {
              if (entity is Directory) {
                // Skip certain system directories to speed up search
                if (!entity.path.contains('/Android/data') &&
                    !entity.path.contains('/Android/obb') &&
                    !entity.path.contains('/Android/media') &&
                    !entity.path.contains('.thumbnails') &&
                    !entity.path.contains('.cache')) {
                  await searchDirectoryRecursively(entity.path, depth + 1);
                }
              }
            }
          }
        }
      } catch (e) {
        print('Error searching directory $path: $e');
      }
    }
    
    // Check each path for backup files
    for (final path in paths) {
      try {
        print('Searching for backups in: $path');
        final downloadDir = Directory(path);
        if (await downloadDir.exists()) {
          // List all files in directory
          final entities = await downloadDir.list().toList();
          print('Found ${entities.length} files/directories in $path');
          
          // Filter for backup files
          for (final entity in entities) {
            if (entity is File && 
                entity.path.contains(backupFileNameBase) && 
                entity.path.endsWith(backupFileExt)) {
              print('Found backup file: ${entity.path}');
              if (!backups.any((file) => file.path == entity.path)) {
                backups.add(entity);
              }
            }
          }
          
          // For specific directories, try a limited recursive search
          if (path.contains('Download') || path.contains('Downloads') || 
              path.contains('Documents') || path.contains('DCIM')) {
            await searchDirectoryRecursively(path, 0);
          }
        }
      } catch (e) {
        print('Error listing files in $path: $e');
      }
    }
    
    // If still no backups found and we're on Android, try content resolver approach
    if (backups.isEmpty && Platform.isAndroid) {
      try {
        print('Trying alternative approach to find backups');
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/backup_finder.txt');
        await tempFile.writeAsString('Searching for backups');
      } catch (e) {
        print('Error in alternative approach: $e');
      }
    }
    
    print('Total backup files found: ${backups.length}');
    for (final backup in backups) {
      print('  ${backup.path}');
    }
    
    return backups;
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