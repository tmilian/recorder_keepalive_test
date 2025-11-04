import 'package:video_player/video_player.dart';

import 'audio_playback_repository.dart';
import 'audio_recording_repository.dart';
import 'audio_session_repository.dart';
import 'video_playback_repository.dart';

/// Repository maître orchestrant tous les sous-repositories
/// Point d'entrée unique pour le controller
class MasterRepository {
  // Sous-repositories
  late final AudioSessionRepository _audioSessionRepo;
  late final AudioRecordingRepository _audioRecordingRepo;
  late final AudioPlaybackRepository _audioPlaybackRepo;
  late final VideoPlaybackRepository _videoPlaybackRepo;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Getters pour accès direct si nécessaire (par exemple pour le VideoPlayerController)
  VideoPlayerController? get videoController => _videoPlaybackRepo.controller;
  List<String> get recordedFiles => _audioRecordingRepo.recordedFiles;

  /// Initialise tous les repositories dans le bon ordre
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ MasterRepository already initialized');
      return;
    }

    print('🚀 Initializing MasterRepository...');
    final sw = Stopwatch()..start();

    try {
      // 1. Créer les instances des repositories
      _audioSessionRepo = AudioSessionRepository();
      _audioRecordingRepo = AudioRecordingRepository();
      _audioPlaybackRepo = AudioPlaybackRepository();
      _videoPlaybackRepo = VideoPlaybackRepository();

      // 2. Initialiser dans le bon ordre
      // IMPORTANT : Audio session DOIT être configurée en premier
      await _audioSessionRepo.initialize();

      // 3. Initialiser les autres en parallèle (ils dépendent de la session audio)
      await Future.wait([
        _audioRecordingRepo.initialize(),
        _audioPlaybackRepo.initialize(),
        _videoPlaybackRepo.initialize(),
      ]);

      sw.stop();
      _isInitialized = true;

      print('✅ MasterRepository initialized in ${sw.elapsedMilliseconds}ms');
      print('   - AudioSession: ✓');
      print('   - AudioRecording (keep-alive): ✓');
      print('   - AudioPlayback: ✓');
      print('   - VideoPlayback: ✓');
    } catch (e) {
      print('❌ MasterRepository initialization error: $e');
      rethrow;
    }
  }

  // ==================== AUDIO PLAYBACK ====================

  /// Joue un audio depuis une URL
  Future<Duration> playAudioUrl(String url) async {
    _ensureInitialized();
    return await _audioPlaybackRepo.playUrl(url);
  }

  /// Joue un fichier audio local
  Future<void> playAudioFile(String filePath) async {
    _ensureInitialized();
    await _audioPlaybackRepo.playFile(filePath);
  }

  /// Arrête la lecture audio
  Future<void> stopAudio() async {
    _ensureInitialized();
    await _audioPlaybackRepo.stop();
  }

  // ==================== VIDEO PLAYBACK ====================

  /// Joue une vidéo depuis une URL
  /// ORCHESTRATION : pause l'audio avant de lancer la vidéo
  Future<void> playVideo(String url) async {
    _ensureInitialized();

    // Pause l'audio si en cours
    await _audioPlaybackRepo.pause();

    // Lance la vidéo
    await _videoPlaybackRepo.playVideo(url);
  }

  /// Pause la vidéo
  Future<void> pauseVideo() async {
    _ensureInitialized();
    await _videoPlaybackRepo.pause();
  }

  /// Arrête la vidéo
  Future<void> stopVideo() async {
    _ensureInitialized();
    await _videoPlaybackRepo.stop();
  }

  // ==================== AUDIO RECORDING ====================

  /// Démarre un enregistrement
  /// ORCHESTRATION : pause audio et vidéo avant de commencer l'enregistrement
  /// Retourne le temps de resume en ms (pour afficher les performances)
  Future<int> startRecording() async {
    _ensureInitialized();

    // Pause tout ce qui joue
    await _audioPlaybackRepo.pause();
    await _videoPlaybackRepo.pause();

    // Démarrer la capture
    return await _audioRecordingRepo.startCapture();
  }

  /// Arrête l'enregistrement en cours
  /// Retourne le chemin du fichier sauvegardé (ou null si erreur)
  Future<String?> stopRecording() async {
    _ensureInitialized();
    return await _audioRecordingRepo.stopCapture();
  }

  // ==================== ORCHESTRATION AVANCÉE ====================

  /// Arrête tout (audio, vidéo, recording)
  Future<void> stopAll() async {
    if (!_isInitialized) return;

    await Future.wait([
      _audioPlaybackRepo.stop(),
      _videoPlaybackRepo.stop(),
      // Note: on ne stop pas le recording car il est en keep-alive
    ]);

    print('⏹️ All playback stopped');
  }

  /// Workflow complet d'enregistrement avec durée
  /// Démarre, enregistre pendant [duration], puis arrête automatiquement
  /// Retourne le chemin du fichier enregistré
  Future<String?> recordForDuration(Duration duration) async {
    _ensureInitialized();

    // Démarrer l'enregistrement
    final resumeTime = await startRecording();
    print('📍 Recording started (⚡ ${resumeTime}ms)');

    // Attendre la durée spécifiée
    await Future.delayed(duration);

    // Arrêter et sauvegarder
    final filePath = await stopRecording();

    return filePath;
  }

  // ==================== HELPERS ====================

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception(
          'MasterRepository not initialized. Call initialize() first.');
    }
  }

  /// Nettoie tous les repositories
  Future<void> dispose() async {
    if (!_isInitialized) return;

    print('🧹 Disposing MasterRepository...');

    await Future.wait([
      _audioSessionRepo.dispose(),
      _audioRecordingRepo.dispose(),
      _audioPlaybackRepo.dispose(),
      _videoPlaybackRepo.dispose(),
    ]);

    _isInitialized = false;
    print('✅ MasterRepository disposed');
  }
}
