import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../session_dialog.dart';
import '../hive_database.dart';
import '../providers/app_state.dart';
import 'package:provider/provider.dart';
import 'main_screen.dart';
import '../utils/app_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionPromptScreen extends StatefulWidget {
  @override
  _SessionPromptScreenState createState() => _SessionPromptScreenState();
}

class _SessionPromptScreenState extends State<SessionPromptScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Show session dialog after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSessionDialog();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<AppState>(context).isDarkTheme;
    
    return Scaffold(
      backgroundColor: isDark ? AppThemes.darkBackground : AppThemes.lightBackground,
      appBar: AppBar(
        title: const Text('SoccerTimeApp'),
        backgroundColor: isDark ? AppThemes.darkPrimaryBlue : AppThemes.lightPrimaryBlue,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => Provider.of<AppState>(context, listen: false).toggleTheme(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/bcs-grad-logo.png',
              width: 150,
              height: 150,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.sports_soccer,
                  size: 150,
                  color: isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue,
                );
              },
            ),
            SizedBox(height: 24),
            Text(
              'Welcome to SoccerTimeApp',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? AppThemes.darkText : AppThemes.lightText,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Track player times with ease',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppThemes.darkText.withOpacity(0.7) : AppThemes.lightText.withOpacity(0.7),
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _showSessionDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Open Sessions',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSessionDialog() {
    // Initialize the database for the dialog
    HiveSessionDatabase.instance.init().then((_) {
      showDialog(
        context: context,
        barrierDismissible: false, // User must select a session
        builder: (context) => SessionDialog(
          onSessionSelected: (sessionId) async {
            try {
              print('Session selected: $sessionId');
              
              // Load the session
              final appState = Provider.of<AppState>(context, listen: false);
              
              // Get the session name before loading
              final allSessions = await HiveSessionDatabase.instance.getAllSessions();
              final sessionInfo = allSessions.firstWhere(
                (s) => s['id'] == sessionId, 
                orElse: () => {'name': ''}
              );
              
              final sessionName = sessionInfo['name'] ?? '';
              print('Session name from dialog: "$sessionName"');
              
              await appState.loadSession(sessionId);
              
              print('Session loaded, navigating to main screen');
              print('Final session name: "${appState.session.sessionName}"');
              print('Current session password: "${appState.currentSessionPassword}"');
              
              // Use pushReplacement instead of pop + push to avoid navigation issues
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => MainScreen()),
                );
              }
            } catch (e) {
              print('Error loading session: $e');
              // Show error dialog but stay on this screen
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Session Error'),
                    content: Text('Could not load the session: $e'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // Close error dialog
                          _showSessionDialog(); // Show session selection again
                        },
                        child: Text('Try Again'),
                      ),
                    ],
                  ),
                );
              }
            }
          },
        ),
      );
    });
  }
}