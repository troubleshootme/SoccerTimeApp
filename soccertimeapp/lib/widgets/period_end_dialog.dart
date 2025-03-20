import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class PeriodEndDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final session = appState.session;
    final isGameOver = session.currentPeriod >= session.matchSegments;
    final periodTerminology = session.matchSegments == 2 ? 'Half' : 'Quarter';
    
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: EdgeInsets.all(24),
          margin: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isGameOver 
                  ? 'Game Over!' 
                  : '${_getOrdinal(session.currentPeriod)} $periodTerminology Ended',
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              if (!isGameOver) Text(
                'Ready for ${_getOrdinal(session.currentPeriod + 1)} $periodTerminology?',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
              SizedBox(height: 30),
              if (!isGameOver) 
                ElevatedButton(
                  onPressed: () {
                    // First call startNextPeriod and then pauseAll to resume
                    appState.startNextPeriod();
                    appState.pauseAll();
                  },
                  child: Text('Start Next $periodTerminology'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Close'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getOrdinal(int number) {
    if (number == 1) return '1st';
    if (number == 2) return '2nd';
    if (number == 3) return '3rd';
    return '${number}th';
  }
}