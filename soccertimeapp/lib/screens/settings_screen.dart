import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/match_log_screen.dart';
import '../providers/app_state.dart';
import '../services/file_service.dart';
import '../utils/app_themes.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _matchDurationController = TextEditingController(text: "90");
  final _targetDurationController = TextEditingController(text: "16");
  
  bool _enableMatchDuration = true;
  bool _enableTargetDuration = true;
  bool _enableSound = false;
  String _matchSegments = "Halves";
  String _theme = "Dark";

  @override
  void initState() {
    super.initState();
    // Load values from AppState
    final appState = Provider.of<AppState>(context, listen: false);
    _enableMatchDuration = appState.session.enableMatchDuration;
    _enableTargetDuration = appState.session.enableTargetDuration;
    _enableSound = appState.session.enableSound;
    _matchSegments = appState.session.matchSegments == 2 ? "Halves" : "Quarters";
    _theme = appState.isDarkTheme ? "Dark" : "Light";
    _matchDurationController.text = (appState.session.matchDuration ~/ 60).toString();
    _targetDurationController.text = (appState.session.targetPlayDuration ~/ 60).toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<AppState>(context).isDarkTheme;
    
    return Scaffold(
      backgroundColor: isDark ? AppThemes.darkBackground : AppThemes.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppThemes.darkPrimaryBlue : AppThemes.lightPrimaryBlue,
        title: Text('Settings'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Match Duration
              _buildSettingRow(
                "Match Duration",
                Switch(
                  value: _enableMatchDuration,
                  activeColor: Colors.deepPurple,
                  activeTrackColor: Colors.deepPurple.withOpacity(0.5),
                  onChanged: (value) {
                    setState(() {
                      _enableMatchDuration = value;
                    });
                  },
                ),
                _enableMatchDuration ? TextField(
                  controller: _matchDurationController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: "Minutes",
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                ) : Container(),
              ),
              SizedBox(height: 8),
              
              // Match Segments - only visible when match duration is enabled
              _enableMatchDuration ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Match Segments",
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  DropdownButton<String>(
                    value: _matchSegments,
                    dropdownColor: isDark ? Colors.grey[850] : Colors.white,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    underline: Container(
                      height: 1,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _matchSegments = newValue;
                        });
                      }
                    },
                    items: <String>['Halves', 'Quarters']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ],
              ) : Container(),
              Divider(color: isDark ? Colors.white24 : Colors.black12),
              
              // Target Play Duration
              _buildSettingRow(
                "Target Play\nDuration",
                Switch(
                  value: _enableTargetDuration,
                  activeColor: Colors.deepPurple,
                  activeTrackColor: Colors.deepPurple.withOpacity(0.5),
                  onChanged: (value) {
                    setState(() {
                      _enableTargetDuration = value;
                    });
                  },
                ),
                _enableTargetDuration ? TextField(
                  controller: _targetDurationController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    labelText: "Minutes",
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                ) : Container(),
              ),
              SizedBox(height: 8),
              
              // Theme
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Theme",
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  DropdownButton<String>(
                    value: _theme,
                    dropdownColor: isDark ? Colors.grey[850] : Colors.white,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    underline: Container(
                      height: 1,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _theme = newValue;
                          Provider.of<AppState>(context, listen: false).toggleTheme();
                        });
                      }
                    },
                    items: <String>['Dark', 'Light']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ],
              ),
              Divider(color: isDark ? Colors.white24 : Colors.black12),
              
              // Sound
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Sound",
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  Switch(
                    value: _enableSound,
                    activeColor: Colors.grey,
                    activeTrackColor: Colors.grey.withOpacity(0.5),
                    onChanged: (value) {
                      setState(() {
                        _enableSound = value;
                      });
                    },
                  ),
                ],
              ),
              Divider(color: isDark ? Colors.white24 : Colors.black12),
              
              // Action buttons
              SizedBox(height: 16),
              _buildActionButton(
                "View Match Log",
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MatchLogScreen()),
                  );
                },
                isDark ? Colors.deepPurple[700]! : Colors.deepPurple,
              ),
              
              SizedBox(height: 12),
              _buildActionButton(
                "Export Times to CSV",
                () {
                  // Export logic using FileService
                  final appState = Provider.of<AppState>(context, listen: false);
                  if (appState.currentSessionPassword != null) {
                    FileService().exportToCsv(
                      appState.session, 
                      appState.currentSessionPassword!
                    ).then((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("CSV file exported successfully")),
                      );
                    }).catchError((error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error exporting CSV: $error")),
                      );
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("No active session to export")),
                    );
                  }
                },
                isDark ? Colors.indigo[700]! : Colors.indigo,
              ),
              
              SizedBox(height: 12),
              _buildActionButton(
                "Backup Session",
                () {
                  // Backup logic using FileService
                  final appState = Provider.of<AppState>(context, listen: false);
                  if (appState.currentSessionPassword != null) {
                    FileService().backupSession(
                      appState.session, 
                      appState.currentSessionPassword!
                    ).then((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Session backed up successfully")),
                      );
                    }).catchError((error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error backing up session: $error")),
                      );
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("No active session to back up")),
                    );
                  }
                },
                isDark ? Colors.teal[700]! : Colors.teal,
              ),
              
              SizedBox(height: 12),
              _buildActionButton(
                "Restore Session",
                () {
                  // Restore logic using FileService
                  final appState = Provider.of<AppState>(context, listen: false);
                  FileService().restoreSession().then((session) {
                    if (session != null) {
                      // Set the restored session
                      appState.session = session;
                      appState.saveSession();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Session restored successfully")),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("No session file selected or invalid file")),
                      );
                    }
                  }).catchError((error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error restoring session: $error")),
                    );
                  });
                },
                isDark ? Colors.amber[900]! : Colors.amber[700]!,
              ),
              
              SizedBox(height: 24),
              _buildActionButton(
                "Save Settings",
                () {
                  // Save all settings
                  final appState = Provider.of<AppState>(context, listen: false);
                  
                  // Update match duration if the field has a valid value
                  final matchDuration = int.tryParse(_matchDurationController.text) ?? 90;
                  if (matchDuration > 0) {
                    appState.updateMatchDuration(matchDuration);
                  }
                  
                  // Update target duration if the field has a valid value
                  final targetDuration = int.tryParse(_targetDurationController.text) ?? 16;
                  if (targetDuration > 0) {
                    appState.updateTargetDuration(targetDuration);
                  }
                  
                  // Update other settings
                  appState.toggleMatchDuration(_enableMatchDuration);
                  appState.toggleTargetDuration(_enableTargetDuration);
                  appState.toggleSound(_enableSound);
                  appState.updateMatchSegments(_matchSegments == "Halves" ? 2 : 4);
                  
                  // Save all settings to the database
                  appState.saveSession();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Settings saved successfully")),
                  );
                  Navigator.pop(context);
                },
                Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSettingRow(String label, Widget toggle, Widget input) {
    final isDark = Provider.of<AppState>(context).isDarkTheme;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 16,
            ),
          ),
        ),
        toggle,
        Expanded(
          flex: 2,
          child: input,
        ),
      ],
    );
  }
  
  Widget _buildActionButton(String text, VoidCallback onPressed, Color color) {
    final isDark = Provider.of<AppState>(context).isDarkTheme;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _matchDurationController.dispose();
    _targetDurationController.dispose();
    super.dispose();
  }
}