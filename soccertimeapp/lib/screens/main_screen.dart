import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/player_button.dart';
import '../widgets/match_timer.dart';
import '../screens/settings_screen.dart';
import '../screens/match_log_screen.dart';
import '../widgets/period_end_dialog.dart';
import '../models/player.dart';
import '../models/session.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/format_time.dart';
import '../widgets/resizable_container.dart';

class MainScreen extends StatelessWidget {
  bool _isPeriodEnd(Session session) {
    var periodDuration = session.matchDuration / session.matchSegments;
    var periodEndTime = session.currentPeriod * periodDuration;
    return session.enableMatchDuration &&
        session.matchTime >= periodEndTime &&
        session.currentPeriod <= session.matchSegments;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        var session = appState.session;
        var players = session.players.entries
            .map((entry) => MapEntry(entry.key, entry.value))
            .toList()
            .asMap()
            .entries
            .toList();
        players.sort((a, b) {
          var timeA = a.value.value.active
              ? a.value.value.totalTime +
                  (DateTime.now().millisecondsSinceEpoch - a.value.value.startTime) ~/ 1000
              : a.value.value.totalTime;
          var timeB = b.value.value.active
              ? b.value.value.totalTime +
                  (DateTime.now().millisecondsSinceEpoch - b.value.value.startTime) ~/ 1000
              : b.value.value.totalTime;
          if (timeB != timeA) return timeB.compareTo(timeA);
          return session.currentOrder.indexOf(a.value.key).compareTo(session.currentOrder.indexOf(b.value.key));
        });

        return Scaffold(
          appBar: AppBar(
            title: Text('Soccer Time'),
          ),
          body: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(kIsWeb ? 8.0 : 16.0),
                child: Column(
                  children: [
                    MatchTimer(),
                    SizedBox(height: kIsWeb ? 8 : 16),
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Add Player'),
                            content: TextField(
                              decoration: InputDecoration(labelText: 'Player Name'),
                              onSubmitted: (name) {
                                if (name.isNotEmpty) {
                                  appState.addPlayer(name);
                                  Navigator.pop(context);
                                }
                              },
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancel'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text('Add Player'),
                    ),
                    SizedBox(height: kIsWeb ? 8 : 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: session.players.length,
                        itemBuilder: (context, index) {
                          var entry = session.players.entries.elementAt(index);
                          return PlayerButton(
                            name: entry.key,
                            player: entry.value,
                            targetPlayDuration: session.targetPlayDuration,
                            enableTargetDuration: session.enableTargetDuration,
                          );
                        },
                      ),
                    ),
                    SizedBox(height: kIsWeb ? 8 : 16),
                    ResizableContainer(
                      initialHeight: kIsWeb ? 250 : 350,
                      minHeight: 50,
                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                      handleOnTop: true,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text('Player', style: TextStyle(fontSize: kIsWeb ? 14 : 16, color: Colors.white))),
                            DataColumn(label: Text('Time', style: TextStyle(fontSize: kIsWeb ? 14 : 16, color: Colors.white))),
                          ],
                          rows: players.map((entry) {
                            var name = entry.value.key;
                            var player = entry.value.value;
                            var time = player.active && !session.isPaused && !_isPeriodEnd(session)
                                ? player.totalTime +
                                    (DateTime.now().millisecondsSinceEpoch - player.startTime) ~/ 1000
                                : player.totalTime;
                            return DataRow(
                              cells: [
                                DataCell(Text(name, style: TextStyle(fontSize: kIsWeb ? 14 : 16, color: Colors.white))),
                                DataCell(Text(formatTime(time), style: TextStyle(fontSize: kIsWeb ? 14 : 16, color: Colors.white))),
                              ],
                              color: MaterialStateProperty.resolveWith<Color?>((states) {
                                if (player.active) return Colors.green.withOpacity(0.2);
                                if (session.enableTargetDuration && time >= session.targetPlayDuration) {
                                  return Colors.yellow.withOpacity(0.2);
                                }
                                return Colors.red.withOpacity(0.2);
                              }),
                            );
                          }).toList(),
                          dataRowHeight: kIsWeb ? 40 : 48,
                          headingRowHeight: kIsWeb ? 40 : 48,
                          columnSpacing: kIsWeb ? 20 : 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey[900],
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 5,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: kIsWeb ? 8 : 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              ElevatedButton(
                                onPressed: !session.isPaused ? appState.pauseAll : null,
                                child: Text('Pause'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  minimumSize: Size(double.infinity, 50),
                                  disabledBackgroundColor: Colors.blue.withOpacity(0.5),
                                ),
                              ),
                              SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: appState.resetAll,
                                child: Text('Reset'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  minimumSize: Size(double.infinity, 50),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => SettingsScreen()),
                                  );
                                },
                                child: Text('Settings'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  minimumSize: Size(double.infinity, 50),
                                ),
                              ),
                              SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: appState.exitSession,
                                child: Text('Exit'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  minimumSize: Size(double.infinity, 50),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (session.isPaused && !_isPeriodEnd(session))
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: ElevatedButton(
                      onPressed: appState.pauseAll,
                      child: Text('Resume', style: TextStyle(fontSize: 36)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(horizontal: 60, vertical: 30),
                      ),
                    ),
                  ),
                ),
              if (_isPeriodEnd(session))
                PeriodEndDialog(),
            ],
          ),
        );
      },
    );
  }
}