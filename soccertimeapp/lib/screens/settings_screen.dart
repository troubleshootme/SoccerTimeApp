import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/match_log_screen.dart';
import '../providers/app_state.dart';
import '../services/file_service.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _matchDurationController = TextEditingController();
  final _targetDurationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    var appState = Provider.of<AppState>(context, listen: false);
    _matchDurationController.text = (appState.session.matchDuration ~/ 60).toString();
    _targetDurationController.text = (appState.session.targetPlayDuration ~/ 60).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Settings'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Match Duration')),
                    Switch(
                      value: appState.session.enableMatchDuration,
                      onChanged: (value) => appState.toggleMatchDuration(value),
                    ),
                    if (appState.session.enableMatchDuration)
                      Expanded(
                        child: TextField(
                          controller: _matchDurationController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: 'Minutes'),
                          onSubmitted: (value) {
                            var minutes = int.tryParse(value) ?? 90;
                            if (minutes >= 1) appState.updateMatchDuration(minutes);
                          },
                        ),
                      ),
                  ],
                ),
                if (appState.session.enableMatchDuration)
                  Row(
                    children: [
                      Expanded(child: Text('Match Segments')),
                      DropdownButton<int>(
                        value: appState.session.matchSegments,
                        items: [
                          DropdownMenuItem(value: 2, child: Text('Halves')),
                          DropdownMenuItem(value: 4, child: Text('Quarters')),
                        ],
                        onChanged: (value) {
                          if (value != null) appState.updateMatchSegments(value);
                        },
                      ),
                    ],
                  ),
                Row(
                  children: [
                    Expanded(child: Text('Target Play Duration')),
                    Switch(
                      value: appState.session.enableTargetDuration,
                      onChanged: (value) => appState.toggleTargetDuration(value),
                    ),
                    if (appState.session.enableTargetDuration)
                      Expanded(
                        child: TextField(
                          controller: _targetDurationController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: 'Minutes'),
                          onSubmitted: (value) {
                            var minutes = int.tryParse(value) ?? 16;
                            if (minutes >= 1) appState.updateTargetDuration(minutes);
                          },
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Text('Theme')),
                    DropdownButton<bool>(
                      value: appState.isDarkTheme,
                      items: [
                        DropdownMenuItem(value: true, child: Text('Dark')),
                        DropdownMenuItem(value: false, child: Text('Light')),
                      ],
                      onChanged: (value) {
                        if (value != null) appState.toggleTheme();
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Text('Sound')),
                    Switch(
                      value: appState.session.enableSound,
                      onChanged: (value) => appState.toggleSound(value),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MatchLogScreen()),
                    );
                  },
                  child: Text('View Match Log'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Flutter handles app installation differently; this can be removed or replaced
                  },
                  child: Text('Install App'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await FileService().exportToCsv(appState.session, appState.currentSessionPassword ?? 'session');
                  },
                  child: Text('Export Times to CSV'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await FileService().backupSession(appState.session, appState.currentSessionPassword ?? 'session');
                  },
                  child: Text('Backup Session'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    var restoredSession = await FileService().restoreSession();
                    if (restoredSession != null && appState.currentSessionPassword != null) {
                      appState.session = restoredSession;
                      await appState.saveSession();
                      appState.notifyListeners();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Session restored successfully!')),
                      );
                    }
                  },
                  child: Text('Restore Session'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}