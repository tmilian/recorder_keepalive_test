import 'dart:async';

import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../repositories/master_repository.dart';

/// Controller simplifié gérant uniquement l'UI state et l'orchestration
/// Toute la logique métier est déléguée au MasterRepository
class LessonController extends GetxController {
  // Injection du MasterRepository
  late final MasterRepository _masterRepo;

  // UI State variables
  final isInitialized = false.obs;
  final currentStep = ''.obs;
  final statusMessage = ''.obs;
  final recordedFiles = <String>[].obs;

  // Performance metrics
  final initTime = 0.obs;
  final lastActionTime = 0.obs;

  // Getter pour le VideoPlayerController (nécessaire pour l'UI)
  VideoPlayerController? get videoController => _masterRepo.videoController;

  // Test data - URLs publiques pour test
  final audioUrls = [
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
  ];

  final videoUrls = [
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
  ];

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    // Récupérer le MasterRepository depuis GetX
    _masterRepo = Get.find<MasterRepository>();

    // Le MasterRepository est déjà initialisé dans main.dart
    if (_masterRepo.isInitialized) {
      isInitialized.value = true;
      statusMessage.value = '✅ Ready | Stream KEEP-ALIVE 🔴';
      print('✓ LessonController initialized with MasterRepository');
    } else {
      statusMessage.value = '❌ MasterRepository not initialized';
      print('❌ MasterRepository not initialized');
    }
  }

  // ==================== ACTIONS ====================

  Future<void> playAudio(int index) async {
    if (index >= audioUrls.length) return;

    currentStep.value = 'Playing Audio ${index + 1}';

    try {
      final initDuration = await _masterRepo.playAudioUrl(audioUrls[index]);

      lastActionTime.value = initDuration.inMilliseconds;
      statusMessage.value = '🔊 Audio (${initDuration.inMilliseconds}ms)';

      // Jouer pendant 5 secondes puis arrêter
      await Future.delayed(const Duration(seconds: 5));
      await _masterRepo.stopAudio();
    } catch (e) {
      statusMessage.value = '❌ Audio error: $e';
      print('Audio play error: $e');
    }
  }

  Future<void> playVideo(int index) async {
    if (index >= videoUrls.length) return;

    final sw = Stopwatch()..start();
    currentStep.value = 'Playing Video ${index + 1}';

    try {
      // Le MasterRepository s'occupe de pause l'audio automatiquement
      await _masterRepo.playVideo(videoUrls[index]);

      sw.stop();
      lastActionTime.value = sw.elapsedMilliseconds;
      statusMessage.value = '🎬 Video (${sw.elapsedMilliseconds}ms)';

      // Jouer pendant 5 secondes puis pause
      await Future.delayed(const Duration(seconds: 5));
      await _masterRepo.pauseVideo();
    } catch (e) {
      statusMessage.value = '❌ Video error: $e';
      print('Video play error: $e');
    }
  }

  Future<void> startRecording() async {
    try {
      currentStep.value = 'Recording ${recordedFiles.length + 1}';

      // Démarrer l'enregistrement (le MasterRepository s'occupe de tout)
      final resumeTime = await _masterRepo.startRecording();

      statusMessage.value = '🎤 Recording (⚡ ${resumeTime}ms)';
      print('📍 Started recording at ${DateTime.now()}');

      // Enregistrer pendant 3 secondes
      await Future.delayed(const Duration(seconds: 3));

      // Arrêter et sauvegarder
      final filePath = await _masterRepo.stopRecording();

      if (filePath != null) {
        recordedFiles.add(filePath);
        statusMessage.value = '✅ Saved recording ${recordedFiles.length}';
        print('📍 Stopped recording at ${DateTime.now()}');
      } else {
        statusMessage.value = '⚠️ No audio data captured';
      }
    } catch (e) {
      statusMessage.value = '❌ Recording error: $e';
      print('Recording error: $e');
    }
  }

  Future<void> playRecordedFile(int index) async {
    if (index >= recordedFiles.length) return;

    currentStep.value = 'Playing Recording ${index + 1}';

    try {
      await _masterRepo.playAudioFile(recordedFiles[index]);
      statusMessage.value = '🔊 Playing recorded file ${index + 1}';

      // Laisser jouer pendant quelques secondes
      await Future.delayed(const Duration(seconds: 3));
      await _masterRepo.stopAudio();
    } catch (e) {
      statusMessage.value = '❌ Playback error: $e';
      print('Playback error: $e');
    }
  }

  // ==================== TEST WORKFLOW ====================

  Future<void> runFullTestCycle() async {
    if (!isInitialized.value) {
      statusMessage.value = '❌ Not initialized';
      return;
    }

    statusMessage.value = '🚀 Starting test cycle...';

    try {
      // Cycle 1: Video -> Audio -> Record -> Audio -> Record
      await playVideo(0);
      await Future.delayed(const Duration(seconds: 1));

      await playAudio(0);
      await Future.delayed(const Duration(seconds: 1));

      await startRecording();
      await Future.delayed(const Duration(seconds: 1));

      await playAudio(1);
      await Future.delayed(const Duration(seconds: 1));

      await startRecording();
      await Future.delayed(const Duration(seconds: 1));

      // Cycle 2: Video -> Audio -> Record
      await playVideo(1);
      await Future.delayed(const Duration(seconds: 1));

      await playAudio(2);
      await Future.delayed(const Duration(seconds: 1));

      await startRecording();
      await Future.delayed(const Duration(seconds: 1));

      statusMessage.value =
          '✅ Test completed! ${recordedFiles.length} recordings';
      currentStep.value = 'Test completed';
    } catch (e) {
      statusMessage.value = '❌ Test cycle error: $e';
      print('Test cycle error: $e');
    }
  }

  @override
  void onClose() {
    // Le MasterRepository sera dispose dans main.dart ou au niveau app
    // On ne le dispose pas ici car il peut être partagé
    super.onClose();
  }
}
