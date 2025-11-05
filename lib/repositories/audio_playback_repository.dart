import 'package:just_audio/just_audio.dart';

class AudioPlaybackRepository {
  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  AudioPlayer? get player => _audioPlayer;

  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ AudioPlaybackRepository already initialized');
      return;
    }

    _audioPlayer = AudioPlayer(
      androidApplyAudioAttributes: false,
      handleAudioSessionActivation: false,
    );
    _isInitialized = true;

    print('✓ AudioPlaybackRepository initialized');
  }

  Future<void> playUrl(
    String url, {
    Duration maxDuration = const Duration(seconds: 5),
    Function(Duration)? onStart,
  }) async {
    if (!_isInitialized || _audioPlayer == null) {
      throw Exception('AudioPlaybackRepository not initialized');
    }

    try {
      final sw = Stopwatch()..start();
      await _audioPlayer!.stop();
      await _audioPlayer!.setUrl(url);
      final sub = _audioPlayer?.playerStateStream.listen((state) async {
        if (state.playing) {
          sw.stop();
          onStart?.call(sw.elapsed);
          await Future.delayed(maxDuration);
          await _audioPlayer?.stop();
        }
      });
      print('🔊 Playing audio from URL: $url');
      await _audioPlayer!.play();

      sub?.cancel();
    } catch (e) {
      print('❌ Error playing URL: $e');
      rethrow;
    }
  }

  Future<void> playFile(String filePath) async {
    if (!_isInitialized || _audioPlayer == null) {
      throw Exception('AudioPlaybackRepository not initialized');
    }

    try {
      await _audioPlayer!.stop();
      await _audioPlayer!.setFilePath(filePath);
      await _audioPlayer!.play();
      print('🔊 Playing audio from file: $filePath');
    } catch (e) {
      print('❌ Error playing file: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_isInitialized || _audioPlayer == null) return;

    try {
      await _audioPlayer!.stop();
      print('⏹️ Audio stopped');
    } catch (e) {
      print('❌ Error stopping audio: $e');
    }
  }

  Future<void> pause() async {
    if (!_isInitialized || _audioPlayer == null) return;

    try {
      await _audioPlayer!.pause();
      print('⏸️ Audio paused');
    } catch (e) {
      print('❌ Error pausing audio: $e');
    }
  }

  Future<void> resume() async {
    if (!_isInitialized || _audioPlayer == null) return;

    try {
      await _audioPlayer!.play();
      print('▶️ Audio resumed');
    } catch (e) {
      print('❌ Error resuming audio: $e');
    }
  }

  Future<void> dispose() async {
    await _audioPlayer?.dispose();
    _audioPlayer = null;
    _isInitialized = false;
    print('🧹 AudioPlaybackRepository disposed');
  }
}
