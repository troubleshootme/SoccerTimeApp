import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../utils/format_time.dart';
import '../models/player.dart';
import '../models/session.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PlayerButton extends StatelessWidget {
  final String name;
  final Player player;
  final int targetPlayDuration;
  final bool enableTargetDuration;

  PlayerButton({
    required this.name,
    required this.player,
    required this.targetPlayDuration,
    required this.enableTargetDuration,
  });

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    var time = player.active && !appState.session.isPaused && !_isPeriodEnd(appState.session)
        ? player.totalTime +
            (DateTime.now().millisecondsSinceEpoch - player.startTime) ~/ 1000
        : player.totalTime;
    var progress = enableTargetDuration
        ? (time / targetPlayDuration * 100).clamp(0, 100)
        : 0.0;
    var isGoalReached = enableTargetDuration && time >= targetPlayDuration;

    return GestureDetector(
      onTap: () => appState.togglePlayer(name),
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Player Options'),
            actions: [
              TextButton(
                onPressed: () {
                  appState.resetPlayerTime(name);
                  Navigator.pop(context);
                },
                child: Text('Reset Time'),
              ),
              TextButton(
                onPressed: () {
                  appState.removePlayer(name);
                  Navigator.pop(context);
                },
                child: Text('Remove Player'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ],
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: kIsWeb ? 6 : 12),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            colors: player.active
                ? [Colors.green, Colors.greenAccent]
                : [Colors.red, Color.fromRGBO(255, 102, 102, 1)],
          ),
          border: Border.all(
            color: isGoalReached
                ? (Theme.of(context).brightness == Brightness.dark
                    ? Colors.yellow
                    : Colors.orange)
                : Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: player.active
                  ? Colors.green.withOpacity(0.4)
                  : Colors.red.withOpacity(0.4),
              blurRadius: 5,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (enableTargetDuration)
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0.2),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.2, 0.2, 0.4],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          tileMode: TileMode.repeated,
                          transform: GradientRotation(45 * 3.14159 / 180),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: kIsWeb ? 20 : 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 2,
                        offset: Offset(0, 2),
                      ),
                    ],
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black54
                        : Colors.black12,
                  ),
                  child: Text(
                    formatTime(time),
                    style: TextStyle(
                      fontSize: kIsWeb ? 20 : 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isPeriodEnd(Session session) {
    var periodDuration = session.matchDuration / session.matchSegments;
    var periodEndTime = session.currentPeriod * periodDuration;
    return session.enableMatchDuration &&
        session.matchTime >= periodEndTime &&
        session.currentPeriod <= session.matchSegments;
  }
}