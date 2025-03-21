import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  final AudioPlayer player = AudioPlayer();
  bool _isInitialized = false;
  
  AudioService() {
    _init();
  }
  
  Future<void> _init() async {
    try {
      // Pre-load the sound for faster playback
      await player.setSource(AssetSource('whistle.mp3'));
      _isInitialized = true;
    } catch (e) {
      print('Error initializing audio player: $e');
      _isInitialized = false;
    }
  }
  
  Future<void> playWhistle() async {
    if (!_isInitialized) {
      // Try to initialize again if it failed before
      await _init();
    }
    
    try {
      // Using the newer syntax for audioplayers 5.x.x
      if (_isInitialized) {
        await player.stop(); // Stop any currently playing sound
        await player.play(AssetSource('whistle.mp3'));
      } else {
        // Fallback: we couldn't play the sound, but we'll log it
        print('Whistle sound was requested but audio is not available');
      }
    } catch (e) {
      // Catch and log any errors, but don't crash the app
      print('Error playing whistle sound: $e');
    }
  }
  
  void dispose() {
    player.dispose();
  }
}
