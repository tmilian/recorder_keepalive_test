import 'package:video_player/video_player.dart';

import 'audio_playback_repository.dart';
import 'audio_recording_repository.dart';
import 'audio_session_repository.dart';
import 'video_playback_repository.dart';

class PlayVideoAndRecordResult {
  final String? recordedFilePath;
  final int videoInitTime;
  final int recordInitTime;
  final int totalTime;

  PlayVideoAndRecordResult({
    required this.recordedFilePath,
    required this.videoInitTime,
    required this.recordInitTime,
    required this.totalTime,
  });
}

class MasterRepository {
  late final AudioSessionRepository _audioSessionRepo;
  late final AudioRecordingRepository _audioRecordingRepo;
  late final AudioPlaybackRepository _audioPlaybackRepo;
  late final VideoPlaybackRepository _videoPlaybackRepo;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  VideoPlayerController? get videoController => _videoPlaybackRepo.controller;
  List<String> get recordedFiles => _audioRecordingRepo.recordedFiles;

  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ MasterRepository already initialized');
      return;
    }

    print('🚀 Initializing MasterRepository...');
    final sw = Stopwatch()..start();

    try {
      _audioSessionRepo = AudioSessionRepository();
      _audioRecordingRepo = AudioRecordingRepository();
      _audioPlaybackRepo = AudioPlaybackRepository();
      _videoPlaybackRepo = VideoPlaybackRepository();

      await Future.wait([
        _audioRecordingRepo.initialize(),
        _audioPlaybackRepo.initialize(),
        _videoPlaybackRepo.initialize(),
      ]);

      await _audioSessionRepo.initialize();

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

  Future<void> playAudioUrl(
    String url, {
    Duration maxDuration = const Duration(seconds: 5),
    Function(Duration)? onStart,
  }) async {
    _ensureInitialized();
    return await _audioPlaybackRepo.playUrl(
      url,
      maxDuration: maxDuration,
      onStart: onStart,
    );
  }

  Future<void> playAudioFile(String filePath) async {
    _ensureInitialized();
    await _audioPlaybackRepo.playFile(filePath);
  }

  Future<void> stopAudio() async {
    _ensureInitialized();
    await _audioPlaybackRepo.stop();
  }

  Future<void> playVideo(String url, {bool muted = false}) async {
    _ensureInitialized();

    await _audioPlaybackRepo.pause();

    await _videoPlaybackRepo.playVideo(url, muted: muted);
  }

  Future<void> pauseVideo() async {
    _ensureInitialized();
    await _videoPlaybackRepo.pause();
  }

  Future<void> stopVideo() async {
    _ensureInitialized();
    await _videoPlaybackRepo.stop();
  }

  Future<int> startRecording() async {
    _ensureInitialized();

    await _audioPlaybackRepo.pause();
    await _videoPlaybackRepo.pause();

    return await _audioRecordingRepo.startCapture();
  }

  Future<String?> stopRecording() async {
    _ensureInitialized();
    return await _audioRecordingRepo.stopCapture();
  }

  Future<void> stopAll() async {
    if (!_isInitialized) return;

    await Future.wait([
      _audioPlaybackRepo.stop(),
      _videoPlaybackRepo.stop(),
    ]);

    print('⏹️ All playback stopped');
  }

  Future<String?> recordForDuration(Duration duration) async {
    _ensureInitialized();

    final resumeTime = await startRecording();
    print('📍 Recording started (⚡ ${resumeTime}ms)');

    await Future.delayed(duration);

    final filePath = await stopRecording();

    return filePath;
  }

  Future<PlayVideoAndRecordResult> playVideoAndRecord({
    required String videoUrl,
    required Duration duration,
    required Function() onStartVideo,
  }) async {
    _ensureInitialized();

    print(
        '🎬🎤 Starting simultaneous video playback (muted) and audio recording');
    final sw = Stopwatch()..start();

    await _audioPlaybackRepo.pause();

    await _videoPlaybackRepo.playVideo(videoUrl, muted: true);
    onStartVideo();
    final videoInitTime = sw.elapsedMilliseconds;
    print('🎬 Video started (muted) in ${videoInitTime}ms');

    final recordStartTime = await _audioRecordingRepo.startCapture();
    print('🎤 Recording started in ${recordStartTime}ms');

    await Future.delayed(duration);

    final filePath = await _audioRecordingRepo.stopCapture();
    await _videoPlaybackRepo.pause();

    sw.stop();
    print('✅ Test completed in ${sw.elapsedMilliseconds}ms');
    print('   - Video init: ${videoInitTime}ms');
    print('   - Record init: ${recordStartTime}ms');
    print('   - Total duration: ${sw.elapsedMilliseconds}ms');

    return PlayVideoAndRecordResult(
      recordedFilePath: filePath,
      videoInitTime: videoInitTime,
      recordInitTime: recordStartTime,
      totalTime: sw.elapsedMilliseconds,
    );
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception(
          'MasterRepository not initialized. Call initialize() first.');
    }
  }

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
