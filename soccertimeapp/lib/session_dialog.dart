import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'hive_database.dart';
import 'models/session.dart';
import 'utils/app_themes.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';

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
                  child: ElevatedButton(
                    onPressed: () => _showCreateSessionDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Create New Session'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSessionList(context),
            const SizedBox(height: 16),
            if (_sessions.isNotEmpty) 
              TextButton.icon(
                onPressed: () => _showClearAllSessionsDialog(context),
                icon: Icon(
                  Icons.delete_forever, 
                  color: Colors.red.shade400,
                ),
                label: Text(
                  'Clear All Sessions',
                  style: TextStyle(
                    color: Colors.red.shade400,
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
                    child: const Text('Create'),
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
          ),
        ),
        content: Text(
          'Are you sure you want to delete all sessions? This action cannot be undone.',
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
}