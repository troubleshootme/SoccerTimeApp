import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('SoccerTimeApp')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: appState.players.length,
              itemBuilder: (context, index) {
                final player = appState.players[index];
                return ElevatedButton(
                  onPressed: () {}, // Add timer logic here
                  child: Text('${player['name']} - ${player['timer_seconds']}s'),
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