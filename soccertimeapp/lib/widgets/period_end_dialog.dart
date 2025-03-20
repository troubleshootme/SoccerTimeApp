import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/session.dart';

class PeriodEndDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        var session = appState.session;
        var periodName = _getPeriodLabel(session.currentPeriod, session.matchSegments);
        var nextPeriod = session.currentPeriod + 1;
        var nextPeriodName = nextPeriod <= session.matchSegments
            ? _getPeriodLabel(nextPeriod, session.matchSegments)
            : 'Match';

        return Container(
          color: Colors.black54,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$periodName Ended.\nStart $nextPeriodName?',
                  style: TextStyle(fontSize: 24, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: appState.startNextPeriod,
                  child: Text('Start', style: TextStyle(fontSize: 36)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 60, vertical: 30),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getPeriodLabel(int period, int segments) {
    var suffix = segments == 2 ? 'Half' : 'Quarter';
    return '$period${period == 1 ? 'st' : period == 2 ? 'nd' : period == 3 ? 'rd' : 'th'} $suffix';
  }
}