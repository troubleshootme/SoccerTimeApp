import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final player = AudioPlayer();
  
  Future<void> playWhistle() async {
    try {
      await player.play(AssetSource('whistle.mp3'));
    } catch (e) {
      print('Error playing whistle sound: $e');
    }
  }
}
