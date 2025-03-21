import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class PeriodEndDialog extends StatelessWidget {
  // Add callback for next period transition
  final VoidCallback? onNextPeriod;
  
  // Remove const constructor to avoid widget identity issues
  PeriodEndDialog({Key? key, this.onNextPeriod}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    try {
      final appState = Provider.of<AppState>(context, listen: false); // Use listen: false to prevent unnecessary rebuilds
      final currentPeriod = appState.session.currentPeriod;
      final totalPeriods = appState.session.matchSegments;
      final isGameOver = currentPeriod >= totalPeriods;

      return WillPopScope(
        onWillPop: () async {
          // Prevent back button from dismissing dialog without handling state
          if (Navigator.of(context).canPop()) {
            // Handle state before popping
            appState.saveSession();
          }
          return false; // Don't allow automatic pop
        },
        child: AlertDialog(
          title: Text(
            isGameOver ? 'Game Over' : 'End of Period $currentPeriod',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isGameOver
                    ? 'The game has ended.'
                    : 'Period $currentPeriod has ended.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              if (!isGameOver)
                Text(
                  'Start Period ${currentPeriod + 1}?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          actions: [
            if (!isGameOver)
              ElevatedButton(
                onPressed: () {
                  try {
                    // Use the callback instead of direct state manipulation
                    if (onNextPeriod != null) {
                      onNextPeriod!();
                    } else {
                      // Fallback to previous behavior if no callback
                      final appStateForAction = Provider.of<AppState>(context, listen: false);
                      appStateForAction.startNextPeriod();
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    print('Error starting next period: $e');
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: Text('Start Next Period'),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: Text(isGameOver ? 'OK' : 'Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error in PeriodEndDialog build: $e');
      // Return a simple dialog if build fails
      return AlertDialog(
        title: Text('Period Ended'),
        content: Text('Please close this dialog and restart the app if you see issues.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      );
    }
  }
}