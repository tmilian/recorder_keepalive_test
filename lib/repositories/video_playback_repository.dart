import 'package:video_player/video_player.dart';

class VideoPlaybackRepository {
  VideoPlayerController? _videoController;
  String? _currentVideoUrl;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  VideoPlayerController? get controller => _videoController;

  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ VideoPlaybackRepository already initialized');
      return;
    }

    _isInitialized = true;
    print('✓ VideoPlaybackRepository initialized');
  }

  Future<void> playVideo(String url, {bool muted = false}) async {
    if (!_isInitialized) {
      throw Exception('VideoPlaybackRepository not initialized');
    }

    try {
      if (_currentVideoUrl != url) {
        await _disposeCurrentController();

        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );

        await _videoController!.initialize();
        _currentVideoUrl = url;

        print('🎬 Video controller initialized for: $url');
      } else {
        print('🔄 Reusing existing video controller for: $url');
      }

      if (muted) {
        await _videoController!.setVolume(0.0);
        print('🔇 Video muted');
      } else {
        await _videoController!.setVolume(1.0);
      }

      await _videoController!.seekTo(Duration.zero);
      await _videoController!.play();

      print('▶️ Playing video: $url ${muted ? "(muted)" : ""}');
    } catch (e) {
      print('❌ Error playing video: $e');
      rethrow;
    }
  }

  Future<void> pause() async {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }

    try {
      await _videoController!.pause();
      print('⏸️ Video paused');
    } catch (e) {
      print('❌ Error pausing video: $e');
    }
  }

  Future<void> resume() async {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }

    try {
      await _videoController!.play();
      print('▶️ Video resumed');
    } catch (e) {
      print('❌ Error resuming video: $e');
    }
  }

  Future<void> stop() async {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }

    try {
      await _videoController!.pause();
      await _videoController!.seekTo(Duration.zero);
      print('⏹️ Video stopped');
    } catch (e) {
      print('❌ Error stopping video: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }

    try {
      await _videoController!.setVolume(volume);
      print('🔊 Video volume set to: $volume');
    } catch (e) {
      print('❌ Error setting video volume: $e');
    }
  }

  Future<void> _disposeCurrentController() async {
    if (_videoController != null) {
      await _videoController!.dispose();
      _videoController = null;
      _currentVideoUrl = null;
      print('🧹 Previous video controller disposed');
    }
  }

  Future<void> dispose() async {
    await _disposeCurrentController();
    _isInitialized = false;
    print('🧹 VideoPlaybackRepository disposed');
  }
}
