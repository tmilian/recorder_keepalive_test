import 'package:video_player/video_player.dart';

/// Repository gérant la lecture vidéo
/// OPTIMISÉ : réutilise le VideoPlayerController au lieu de le recréer à chaque fois
class VideoPlaybackRepository {
  VideoPlayerController? _videoController;
  String? _currentVideoUrl;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  VideoPlayerController? get controller => _videoController;

  /// Initialise le repository (sans charger de vidéo)
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ VideoPlaybackRepository already initialized');
      return;
    }

    _isInitialized = true;
    print('✓ VideoPlaybackRepository initialized');
  }

  /// Joue une vidéo depuis une URL
  /// OPTIMISATION : réutilise le controller si c'est la même URL
  Future<void> playVideo(String url) async {
    if (!_isInitialized) {
      throw Exception('VideoPlaybackRepository not initialized');
    }

    try {
      // Si c'est une nouvelle URL, on doit recréer le controller
      if (_currentVideoUrl != url) {
        await _disposeCurrentController();

        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(url),
        );

        await _videoController!.initialize();
        _currentVideoUrl = url;

        print('🎬 Video controller initialized for: $url');
      } else {
        // Même URL, on réutilise le controller existant
        print('🔄 Reusing existing video controller for: $url');
      }

      // Jouer la vidéo (depuis le début si réutilisé)
      await _videoController!.seekTo(Duration.zero);
      await _videoController!.play();

      print('▶️ Playing video: $url');
    } catch (e) {
      print('❌ Error playing video: $e');
      rethrow;
    }
  }

  /// Pause la vidéo en cours
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

  /// Reprend la lecture de la vidéo
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

  /// Arrête la vidéo et la remet au début
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

  /// Dispose le controller actuel (helper privé)
  Future<void> _disposeCurrentController() async {
    if (_videoController != null) {
      await _videoController!.dispose();
      _videoController = null;
      _currentVideoUrl = null;
      print('🧹 Previous video controller disposed');
    }
  }

  /// Nettoie les ressources
  Future<void> dispose() async {
    await _disposeCurrentController();
    _isInitialized = false;
    print('🧹 VideoPlaybackRepository disposed');
  }
}
