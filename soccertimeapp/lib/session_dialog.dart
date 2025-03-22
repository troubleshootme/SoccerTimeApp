import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'hive_database.dart';
import 'models/session.dart';
import 'utils/app_themes.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'utils/backup_manager.dart';

class SessionDialog extends StatefulWidget {
  final Function(int sessionId) onSessionSelected;

  const SessionDialog({Key? key, required this.onSessionSelected}) : super(key: key);

  @override
  _SessionDialogState createState() => _SessionDialogState();
}

class _SessionDialogState extends State<SessionDialog> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSessions();
  }
  
  Future<void> _loadSessions() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Ensure Hive is initialized before trying to get sessions
      await HiveSessionDatabase.instance.init();
      
      // Get sessions from Hive only
      _sessions = await HiveSessionDatabase.instance.getAllSessions();
      
      // Debug log of all sessions
      print('Session list in dialog contains ${_sessions.length} sessions:');
      for (var session in _sessions) {
        print('  Session ID: ${session['id']}, Name: "${session['name']}"');
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading sessions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _sessions = []; // Set to empty list on error
        });
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sessions: $e'))
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<AppState>(context).isDarkTheme;
    
    return Dialog(
      backgroundColor: isDark ? AppThemes.darkCardBackground : AppThemes.lightCardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Soccer Time App', 
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: isDark ? AppThemes.darkText : AppThemes.lightText,
              )
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a session to continue', 
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppThemes.darkText.withOpacity(0.7) : AppThemes.lightText.withOpacity(0.7),
              )
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showCreateSessionDialog(context),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Create New Session',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _backupSessions(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.white.withOpacity(0.9), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.transparent,
                    ),
                    icon: Icon(
                      Icons.backup,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    label: Text(
                      'Backup Sessions',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _restoreSessions(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.white.withOpacity(0.9), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.transparent,
                    ),
                    icon: Icon(
                      Icons.restore,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    label: Text(
                      'Restore Sessions',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSessionList(context),
            const SizedBox(height: 16),
            if (_sessions.isNotEmpty) 
              OutlinedButton.icon(
                onPressed: () => _showClearAllSessionsDialog(context),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.red.shade400),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(
                  Icons.delete_forever, 
                  color: Colors.red.shade400,
                ),
                label: Text(
                  'Clear All Sessions',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCreateSessionDialog(BuildContext context) {
    final controller = TextEditingController();
    final isDark = Provider.of<AppState>(context, listen: false).isDarkTheme;
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? AppThemes.darkCardBackground : AppThemes.lightCardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Create New Session',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppThemes.darkText : AppThemes.lightText,
                ),
              ),
              const SizedBox(height: 16),
              Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    color: isDark ? AppThemes.darkText : AppThemes.lightText,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Session Name',
                    labelStyle: TextStyle(
                      color: isDark ? AppThemes.darkText.withOpacity(0.7) : AppThemes.lightText.withOpacity(0.7),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.red,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.red,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a session name';
                    }
                    // Check for duplicate session names
                    if (_sessions.any((session) => session['name'].toString().toLowerCase() == value.toLowerCase())) {
                      return 'Session name already exists';
                    }
                    return null;
                  },
                  onFieldSubmitted: (value) => _createSession(context, controller, formKey),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context), 
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue,
                        letterSpacing: 1.0,
                      ),
                    )
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _createSession(context, controller, formKey),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Create',
                      style: TextStyle(
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _createSession(BuildContext context, TextEditingController controller, GlobalKey<FormState> formKey) async {
    if (formKey.currentState!.validate()) {
      final sessionName = controller.text.trim();
      if (sessionName.isNotEmpty) {
        try {
          setState(() {
            _isLoading = true; // Show loading indicator
          });
          
          // First close the dialog to prevent double taps
          Navigator.pop(context);
          
          print('Creating session with name: $sessionName');
          final sessionId = await HiveSessionDatabase.instance.insertSession(sessionName);
          print('Session created with ID: $sessionId and name: $sessionName');
          
          // Reload sessions to ensure the list is up-to-date
          await _loadSessions();
          
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            
            widget.onSessionSelected(sessionId);
          }
        } catch (e) {
          print('Error creating session: $e');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error creating session: $e')),
            );
          }
        }
      } else {
        // Show error for empty name (although validator should catch this)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Session name cannot be empty')),
        );
      }
    }
  }
  
  void _showClearAllSessionsDialog(BuildContext context) {
    final isDark = Provider.of<AppState>(context, listen: false).isDarkTheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppThemes.darkCardBackground : AppThemes.lightCardBackground,
        title: Text(
          'Clear All Sessions',
          style: TextStyle(
            color: isDark ? AppThemes.darkText : AppThemes.lightText,
            letterSpacing: 1.0,
          ),
        ),
        content: Text(
          'Are you sure you want to delete all sessions? This action cannot be undone.',
          style: TextStyle(
            color: isDark ? AppThemes.darkText : AppThemes.lightText,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue,
                letterSpacing: 1.0,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await HiveSessionDatabase.instance.clearAllSessions();
              Navigator.pop(context);
              _loadSessions(); // Refresh the list
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList(BuildContext context) {
    final isDark = Provider.of<AppState>(context).isDarkTheme;
    
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue,
        ),
      );
    }
    
    if (_sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No sessions yet. Create a new one!',
          style: TextStyle(
            color: isDark ? AppThemes.darkText.withOpacity(0.7) : AppThemes.lightText.withOpacity(0.7),
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    
    // Debug log of all sessions
    print('Session list in dialog contains ${_sessions.length} sessions:');
    for (var session in _sessions) {
      print('  Session ID: ${session['id']}, Name: "${session['name']}"');
    }
    
    return Container(
      constraints: BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final session = _sessions[index];
          final sessionId = session['id'];
          final sessionName = session['name'] ?? 'Session $sessionId';
          final date = DateTime.fromMillisecondsSinceEpoch(session['created_at']);
          final formattedDate = '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
          
          return Card(
            color: isDark ? AppThemes.darkCardBackground.withOpacity(0.7) : AppThemes.lightCardBackground.withOpacity(0.7),
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isDark ? AppThemes.darkSecondaryBlue.withOpacity(0.3) : AppThemes.lightSecondaryBlue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ListTile(
              title: Text(
                sessionName,
                style: TextStyle(
                  color: isDark ? AppThemes.darkText : AppThemes.lightText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                formattedDate,
                style: TextStyle(
                  color: isDark ? AppThemes.darkText.withOpacity(0.7) : AppThemes.lightText.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  Icons.delete,
                  color: Colors.red.shade300,
                  size: 20,
                ),
                onPressed: () => _showDeleteSessionDialog(context, session),
              ),
              onTap: () {
                print('Selected session: ID=$sessionId, Name="$sessionName"');
                widget.onSessionSelected(sessionId);
                Navigator.pop(context);
              },
            ),
          );
        },
      ),
    );
  }
  
  void _showDeleteSessionDialog(BuildContext context, Map<String, dynamic> session) {
    final isDark = Provider.of<AppState>(context, listen: false).isDarkTheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppThemes.darkCardBackground : AppThemes.lightCardBackground,
        title: Text(
          'Delete Session',
          style: TextStyle(
            color: isDark ? AppThemes.darkText : AppThemes.lightText,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${session['name']}"?',
          style: TextStyle(
            color: isDark ? AppThemes.darkText : AppThemes.lightText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await HiveSessionDatabase.instance.deleteSession(session['id']);
              Navigator.pop(context);
              _loadSessions(); // Refresh the list
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Implement backup sessions method
  Future<void> _backupSessions(BuildContext context) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      print('Starting backup process...');
      final filePath = await BackupManager().backupSessions(context);
      
      setState(() {
        _isLoading = false;
      });
      
      if (filePath != null) {
        print('Backup successful to: $filePath');
        BackupManager().showBackupSuccess(context, filePath);
      } else {
        print('Backup returned null path');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed - could not create backup file')),
        );
      }
    } catch (e) {
      print('Error during backup: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during backup: $e'),
          duration: Duration(seconds: 7),
          action: SnackBarAction(
            label: 'Details',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Backup Error Details'),
                  content: SingleChildScrollView(
                    child: Text('$e\n\nMake sure you have granted storage permissions to the app.'),
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
  }
  
  // Implement restore sessions method
  Future<void> _restoreSessions(BuildContext context) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      print('Starting restore process...');
      final success = await BackupManager().restoreSessions(context);
      
      if (success) {
        print('Restore successful');
        // Reload sessions list after restore
        await _loadSessions();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sessions restored successfully')),
        );
      } else {
        print('Restore unsuccessful');
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error during restore: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during restore: $e'),
          duration: Duration(seconds: 7),
          action: SnackBarAction(
            label: 'Details',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Restore Error Details'),
                  content: SingleChildScrollView(
                    child: Text('$e\n\nMake sure you have granted storage permissions to the app and have valid backup files available.'),
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
  }
}