import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_state.dart';
import '../models/match_log_entry.dart';
import '../utils/app_themes.dart';
import 'package:intl/intl.dart';

class MatchLogScreen extends StatefulWidget {
  @override
  _MatchLogScreenState createState() => _MatchLogScreenState();
}

class _MatchLogScreenState extends State<MatchLogScreen> {
  bool _isAscendingOrder = true; // Default to ascending (match time order)
  
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkTheme;
    
    // Get logs based on sort order
    final logs = _isAscendingOrder 
        ? appState.session.getSortedMatchLogAscending()
        : appState.session.getSortedMatchLog();
    
    return Scaffold(
      backgroundColor: isDark ? AppThemes.darkBackground : AppThemes.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppThemes.darkPrimaryBlue : AppThemes.lightPrimaryBlue,
        title: Text('Match Log'),
        actions: [
          // Sort order toggle
          IconButton(
            icon: Icon(_isAscendingOrder ? Icons.arrow_upward : Icons.arrow_downward),
            tooltip: _isAscendingOrder ? 'Oldest first' : 'Newest first',
            onPressed: () {
              setState(() {
                _isAscendingOrder = !_isAscendingOrder;
              });
            },
          ),
          if (logs.isNotEmpty)
            IconButton(
              icon: Icon(Icons.share),
              tooltip: 'Share Match Log',
              onPressed: () => _shareMatchLog(context, appState),
            ),
        ],
      ),
      body: logs.isEmpty
          ? _buildEmptyState(context, isDark)
          : _buildLogList(context, logs, isDark),
      floatingActionButton: FloatingActionButton(
        backgroundColor: isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue,
        onPressed: () => Navigator.pop(context),
        child: Icon(Icons.close),
      ),
    );
  }
  
  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: isDark ? Colors.white70 : Colors.black45,
          ),
          SizedBox(height: 16),
          Text(
            'No match events recorded yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black45,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Events will appear here as the match progresses',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black38,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildLogList(BuildContext context, List<MatchLogEntry> logs, bool isDark) {
    return ListView.builder(
      itemCount: logs.length,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      itemBuilder: (context, index) {
        final entry = logs[index];
        
        // Determine icon based on the event description
        IconData icon = _getEventIcon(entry.details);
        
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isDark ? Colors.grey[850] : Colors.white,
          elevation: 1,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isDark 
                  ? AppThemes.darkSecondaryBlue.withOpacity(0.7)
                  : AppThemes.lightSecondaryBlue.withOpacity(0.7),
              child: Icon(
                icon,
                color: Colors.white,
                size: 18,
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.deepPurple.withOpacity(0.2) : Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDark ? Colors.deepPurple.withOpacity(0.3) : Colors.deepPurple.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    entry.matchTime,
                    style: TextStyle(
                      color: isDark ? Colors.deepPurple.shade200 : Colors.deepPurple.shade700,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'RobotoMono',
                      fontSize: 14,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.details,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              _formatTimestamp(entry.timestamp),
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 12,
              ),
            ),
            trailing: _getTimeAgo(entry.timestamp),
          ),
        );
      },
    );
  }
  
  // Format ISO timestamp to a more user-friendly format
  String _formatTimestamp(String timestamp) {
    try {
      final DateTime dateTime = DateTime.parse(timestamp);
      final DateFormat formatter = DateFormat('MMM d, h:mm a');
      return formatter.format(dateTime);
    } catch (e) {
      return timestamp;
    }
  }
  
  // Get an appropriate icon based on the event description
  IconData _getEventIcon(String details) {
    final lowerDetails = details.toLowerCase();
    
    if (lowerDetails.contains('entered the game')) {
      return Icons.login;
    } else if (lowerDetails.contains('left the game')) {
      return Icons.logout;
    } else if (lowerDetails.contains('paused')) {
      return Icons.pause_circle;
    } else if (lowerDetails.contains('resumed')) {
      return Icons.play_circle;
    } else if (lowerDetails.contains('quarter') || lowerDetails.contains('half')) {
      if (lowerDetails.contains('ended')) {
        return Icons.sports_score;
      } else if (lowerDetails.contains('started')) {
        return Icons.sports;
      }
    } else if (lowerDetails.contains('reset')) {
      return Icons.refresh;
    } else if (lowerDetails.contains('added to roster')) {
      return Icons.person_add;
    } else if (lowerDetails.contains('removed from roster')) {
      return Icons.person_remove;
    } else if (lowerDetails.contains('session')) {
      return Icons.start;
    }
    
    // Default icon
    return Icons.event_note;
  }
  
  // Display relative time
  Widget _getTimeAgo(String timestamp) {
    try {
      final eventTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(eventTime);
      
      String timeAgo;
      
      if (difference.inSeconds < 60) {
        timeAgo = 'Just now';
      } else if (difference.inMinutes < 60) {
        timeAgo = '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        timeAgo = '${difference.inHours}h ago';
      } else {
        timeAgo = '${difference.inDays}d ago';
      }
      
      return Text(
        timeAgo,
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
    } catch (e) {
      return Text('');
    }
  }
  
  // Share the match log as text
  void _shareMatchLog(BuildContext context, AppState appState) {
    final logText = appState.exportMatchLogToText();
    
    if (logText.isNotEmpty) {
      Share.share(
        logText,
        subject: 'Match Log: ${appState.session.sessionName}',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No match events to share')),
      );
    }
  }
}