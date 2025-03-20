import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  Map<int, bool> _isTimerRunning = {};
  Map<int, int> _timerValues = {};

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    for (var i = 0; i < appState.players.length; i++) {
      _timerValues[i] = appState.players[i]['timer_seconds'] ?? 0;
      _isTimerRunning[i] = false;
    }
  }

  Future<void> _toggleTimer(int index) async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.currentSessionId == null) return;

    setState(() {
      _isTimerRunning[index] = !(_isTimerRunning[index] ?? false);
      if (_isTimerRunning[index]!) {
        Future.delayed(Duration(seconds: 1), () async {
          if (_isTimerRunning[index]!) {
            setState(() {
              _timerValues[index] = (_timerValues[index] ?? 0) + 1;
            });
            await appState.updatePlayerTimer(appState.players[index]['id'], _timerValues[index]!);
            await _toggleTimer(index);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('SoccerTimeApp'),
        actions: [
          IconButton(
            icon: Icon(appState.isDarkTheme ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => appState.toggleTheme(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: appState.players.length,
              itemBuilder: (context, index) {
                final player = appState.players[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  child: ElevatedButton(
                    onPressed: () => _toggleTimer(index),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(player['name']),
                        Text('${_timerValues[index] ?? player['timer_seconds']}s'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => appState.addPlayer('New Player'),
        child: const Icon(Icons.add),
      ),
    );
  }
}