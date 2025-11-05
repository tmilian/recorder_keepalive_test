import 'dart:async';

import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../repositories/master_repository.dart';

class LessonController extends GetxController {
  late final MasterRepository _masterRepo;

  final isInitialized = false.obs;
  final playingVideo = false.obs;
  final currentStep = ''.obs;
  final statusMessage = ''.obs;
  final recordedFiles = <String>[].obs;

  final initTime = 0.obs;
  final lastActionTime = 0.obs;

  VideoPlayerController? get videoController => _masterRepo.videoController;

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
    _masterRepo = Get.find<MasterRepository>();

    if (_masterRepo.isInitialized) {
      isInitialized.value = true;
      statusMessage.value = '✅ Ready | Stream KEEP-ALIVE 🔴';
      print('✓ LessonController initialized with MasterRepository');
    } else {
      statusMessage.value = '❌ MasterRepository not initialized';
      print('❌ MasterRepository not initialized');
    }
  }

  Future<void> playAudio(int index) async {
    if (index >= audioUrls.length) return;

    currentStep.value = 'Playing Audio ${index + 1}';

    try {
      await _masterRepo.playAudioUrl(
        audioUrls[index],
        maxDuration: const Duration(seconds: 5),
        onStart: (initDuration) {
          lastActionTime.value = initDuration.inMilliseconds;
          statusMessage.value = '🔊 Audio (${initDuration.inMilliseconds}ms)';
        },
      );

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
      await _masterRepo.playVideo(videoUrls[index]);

      playingVideo.value = true;

      sw.stop();
      lastActionTime.value = sw.elapsedMilliseconds;
      statusMessage.value = '🎬 Video (${sw.elapsedMilliseconds}ms)';

      await Future.delayed(const Duration(seconds: 5));
      await _masterRepo.pauseVideo();

      playingVideo.value = false;
    } catch (e) {
      statusMessage.value = '❌ Video error: $e';
      print('Video play error: $e');
    }
  }

  Future<void> startRecording() async {
    try {
      currentStep.value = 'Recording ${recordedFiles.length + 1}';

      final resumeTime = await _masterRepo.startRecording();

      statusMessage.value = '🎤 Recording (⚡ ${resumeTime}ms)';
      print('📍 Started recording at ${DateTime.now()}');

      await Future.delayed(const Duration(seconds: 3));

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

      await Future.delayed(const Duration(seconds: 3));
      await _masterRepo.stopAudio();
    } catch (e) {
      statusMessage.value = '❌ Playback error: $e';
      print('Playback error: $e');
    }
  }

  Future<void> playVideoAndRecord({int videoIndex = 0}) async {
    if (!isInitialized.value) {
      statusMessage.value = '❌ Not initialized';
      return;
    }

    if (videoIndex >= videoUrls.length) return;

    currentStep.value = 'Video + Recording ${recordedFiles.length + 1}';

    try {
      final result = await _masterRepo.playVideoAndRecord(
          videoUrl: videoUrls[videoIndex],
          duration: const Duration(seconds: 5),
          onStartVideo: () {
            playingVideo.value = true;
          });

      playingVideo.value = false;

      if (result.recordedFilePath != null) {
        recordedFiles.add(result.recordedFilePath!);
        lastActionTime.value = result.recordInitTime;
        statusMessage.value =
            '✅ Video+Record done! (🎬${result.videoInitTime}ms / 🎤${result.recordInitTime}ms)';
        print('📍 Video + Record completed at ${DateTime.now()}');
      } else {
        statusMessage.value = '⚠️ No audio data captured during video playback';
      }
    } catch (e) {
      statusMessage.value = '❌ Video+Record error: $e';
      print('Video+Record error: $e');
    }
  }

  Future<void> runFullTestCycle() async {
    if (!isInitialized.value) {
      statusMessage.value = '❌ Not initialized';
      return;
    }

    statusMessage.value = '🚀 Starting test cycle...';

    try {
      await playVideo(0);
      await playAudio(0);
      await startRecording();
      await playAudio(1);
      await startRecording();

      await playVideo(1);
      await playAudio(2);
      await startRecording();

      statusMessage.value =
          '✅ Test completed! ${recordedFiles.length} recordings';
      currentStep.value = 'Test completed';
    } catch (e) {
      statusMessage.value = '❌ Test cycle error: $e';
      print('Test cycle error: $e');
    }
  }
}
