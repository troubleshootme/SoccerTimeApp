import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../models/session.dart';
import '../providers/app_state.dart';
import '../utils/format_time.dart';
import '../widgets/resizable_container.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PlayerTimesScreen extends StatelessWidget {
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
            title: Text('Player Times'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ResizableContainer(
              initialHeight: kIsWeb ? 350 : 450,
              minHeight: 200,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                    var time = player.active && !session.isPaused
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
          ),
        );
      },
    );
  }
} 