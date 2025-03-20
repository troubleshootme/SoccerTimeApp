import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class MatchLogScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        var matchLog = appState.session.matchLog;
        return Scaffold(
          appBar: AppBar(
            title: Text('Match Log'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: matchLog.isEmpty
                ? Center(child: Text('No log entries yet.'))
                : ListView.builder(
                    itemCount: matchLog.length,
                    itemBuilder: (context, index) {
                      var entry = matchLog[index];
                      return ListTile(
                        title: Text('${entry.matchTime} - ${entry.details}'),
                      );
                    },
                  ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.pop(context),
            child: Icon(Icons.close),
          ),
        );
      },
    );
  }
}