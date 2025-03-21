import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../session_dialog.dart';
import '../utils/app_themes.dart';

class SessionPromptScreen extends StatefulWidget {
  @override
  _SessionPromptScreenState createState() => _SessionPromptScreenState();
}

class _SessionPromptScreenState extends State<SessionPromptScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSessionDialog(context);
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
              onPressed: () => _showSessionDialog(context),
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

  void _showSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SessionDialog(
        onSessionSelected: (sessionId) async {
          final appState = Provider.of<AppState>(context, listen: false);
          await appState.loadSession(sessionId);
          Navigator.pushReplacementNamed(context, '/main');
        },
      ),
    );
  }
}