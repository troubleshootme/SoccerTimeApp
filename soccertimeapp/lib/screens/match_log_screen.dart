import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class MatchLogScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    // Since we no longer have match logs, just show an empty screen
    return Scaffold(
      appBar: AppBar(
        title: Text('Match Log'),
      ),
      body: Center(
        child: Text('Match logging is not available in this version'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context),
        child: Icon(Icons.close),
      ),
    );
  }
}