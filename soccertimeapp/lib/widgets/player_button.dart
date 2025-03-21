import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../utils/format_time.dart';
import '../models/player.dart';
import '../models/session.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as math;

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
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            colors: player.active
                ? [Colors.green.shade800, Colors.green]
                : [Colors.red.shade800, Colors.red],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isGoalReached
                ? Colors.yellow
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
            // Player content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: kIsWeb ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
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
                      color: Colors.black45,
                    ),
                    child: Text(
                      formatTime(time),
                      style: TextStyle(
                        fontSize: kIsWeb ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Progress bar as overlay at bottom of button
            if (enableTargetDuration)
              Positioned(
                left: 10, 
                right: 10,
                bottom: 6,
                child: Container(
                  height: 6, // Made slightly smaller
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.black38,
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        width: (progress / 100) * (MediaQuery.of(context).size.width - 70), // Adjust based on screen width
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            colors: isGoalReached 
                                ? [Colors.yellow.shade600, Colors.amber]
                                : [Colors.lightBlue.shade300, Colors.blue],
                            begin: Alignment.centerLeft, 
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isGoalReached 
                                ? Colors.yellow.withOpacity(0.6)
                                : Colors.blue.withOpacity(0.4),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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

class DiagonalStripesPainter extends CustomPainter {
  final double stripeWidth;
  final Color stripeColor;
  final double stripeSpacing;

  DiagonalStripesPainter({
    required this.stripeWidth,
    required this.stripeColor,
    required this.stripeSpacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stripeColor
      ..style = PaintingStyle.fill;

    double totalWidth = size.width + size.height;
    int numStripes = (totalWidth / (stripeWidth + stripeSpacing)).ceil() + 2;
    
    for (int i = -2; i < numStripes; i++) {
      double startX = -size.height + i * (stripeWidth + stripeSpacing);
      
      final path = Path()
        ..moveTo(startX, 0)
        ..lineTo(startX + stripeWidth, 0)
        ..lineTo(startX + stripeWidth + size.height, size.height)
        ..lineTo(startX + size.height, size.height)
        ..close();
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DiagonalStripesPainter oldDelegate) => 
      oldDelegate.stripeWidth != stripeWidth ||
      oldDelegate.stripeColor != stripeColor ||
      oldDelegate.stripeSpacing != stripeSpacing;
}