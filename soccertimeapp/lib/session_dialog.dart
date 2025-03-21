import 'package:flutter/material.dart';
import 'database.dart';
import 'utils/app_themes.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';

class SessionDialog extends StatelessWidget {
  final Function(int sessionId) onSessionSelected;

  const SessionDialog({Key? key, required this.onSessionSelected}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<AppState>(context).isDarkTheme;
    final theme = isDark ? AppThemes.darkTheme() : AppThemes.lightTheme();
    
    return Dialog(
      backgroundColor: isDark ? AppThemes.darkCardBackground : AppThemes.lightCardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sessions', 
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                color: isDark ? AppThemes.darkText : AppThemes.lightText,
              )
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showCreateSessionDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Create New Session'),
            ),
            const SizedBox(height: 16),
            _buildSessionList(context),
          ],
        ),
      ),
    );
  }

  void _showCreateSessionDialog(BuildContext context) {
    final controller = TextEditingController();
    final isDark = Provider.of<AppState>(context, listen: false).isDarkTheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppThemes.darkCardBackground : AppThemes.lightCardBackground,
        title: Text(
          'New Session',
          style: TextStyle(
            color: isDark ? AppThemes.darkText : AppThemes.lightText,
          ),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(
            color: isDark ? AppThemes.darkText : AppThemes.lightText,
          ),
          decoration: InputDecoration(
            labelText: 'Session Name',
            labelStyle: TextStyle(
              color: isDark ? AppThemes.darkText.withOpacity(0.7) : AppThemes.lightText.withOpacity(0.7),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue,
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue,
                width: 2,
              ),
            ),
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
            )
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final sessionId = await SessionDatabase.instance.insertSession(controller.text);
                onSessionSelected(sessionId);
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: Text(
              'Create',
              style: TextStyle(
                color: isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList(BuildContext context) {
    final isDark = Provider.of<AppState>(context).isDarkTheme;
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SessionDatabase.instance.getAllSessions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue,
            ),
          );
        }
        
        final sessions = snapshot.data!;
        
        if (sessions.isEmpty) {
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
        
        return SizedBox(
          height: 200,
          child: ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
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
                    session['name'],
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
                  onTap: () {
                    onSessionSelected(session['id']);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}