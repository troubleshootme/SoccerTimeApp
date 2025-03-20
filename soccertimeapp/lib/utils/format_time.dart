String formatTime(int seconds) {
  var mins = seconds ~/ 60;
  var secs = seconds % 60;
  return '$mins:${secs < 10 ? '0$secs' : secs}';
}