import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

class LessonController extends GetxController {
  // Audio & Video players
  AudioPlayer? _audioPlayer;
  AudioRecorder? _audioRecorder;
  VideoPlayerController? _videoController;

  VideoPlayerController? get videoController => _videoController;

  // State
  final isInitialized = false.obs;
  final currentStep = ''.obs;
  final statusMessage = ''.obs;
  final recordedFiles = <String>[].obs;

  // Performance metrics
  final initTime = 0.obs;
  final lastActionTime = 0.obs;

  // Keep-alive state with streaming
  bool _isRecorderActive = false;
  Stream<Uint8List>? _audioStream;
  StreamSubscription<Uint8List>? _streamSubscription;
  List<Uint8List> _currentRecordingChunks = [];
  bool _isCapturing = false;
  int _recordingCounter = 0;

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
    _setupAudioSessionInterruptionHandling();
  }

  void _setupAudioSessionInterruptionHandling() {
    // Gérer les interruptions (appels téléphoniques, etc.)
    AudioSession.instance.then((session) {
      session.interruptionEventStream.listen((event) {
        print('🔔 Audio interruption: ${event.type}');

        if (event.begin) {
          // Interruption commence (ex: appel entrant)
          print('  ⏸️  Interruption began');
          // On pourrait pause la capture ici si nécessaire
        } else {
          // Interruption se termine
          print('  ▶️  Interruption ended');
          // On pourrait reprendre ici
        }
      });

      session.becomingNoisyEventStream.listen((_) {
        print('🔇 Device becoming noisy (headphones unplugged)');
        // Gérer le débranchement des écouteurs
      });
    });
  }

  Future<void> _initialize() async {
    statusMessage.value = 'Requesting permissions...';

    // Demander les permissions
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      statusMessage.value = '❌ Microphone permission denied';
      return;
    }

    statusMessage.value = 'Configuring audio session...';

    // Configurer l'audio session AVANT tout
    await _configureAudioSession();

    statusMessage.value = 'Initializing...';
    final sw = Stopwatch()..start();

    try {
      await Future.wait([
        _initAudioPlayer(),
        _initRecorderWithStreamKeepAlive(),
      ]);

      sw.stop();
      initTime.value = sw.elapsedMilliseconds;
      isInitialized.value = true;
      statusMessage.value = '✅ Init ${initTime.value}ms | Stream KEEP-ALIVE 🔴';
    } catch (e) {
      statusMessage.value = '❌ Init error: $e';
      print('Initialization error: $e');
    }
  }

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;

      // Configuration pour permettre recording + playback simultané
      await session.configure(
        AudioSessionConfiguration(
          // Mode le plus permissif : playAndRecord
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,

          // Options critiques pour iOS :
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth |
                  AVAudioSessionCategoryOptions.defaultToSpeaker |
                  AVAudioSessionCategoryOptions.mixWithOthers,

          // Mode pour meilleures performances
          avAudioSessionMode: AVAudioSessionMode.defaultMode,

          // Permet à d'autres apps de jouer en même temps
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,

          // Configuration Android
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );

      print('✓ Audio session configured:');
      print('  - Category: playAndRecord');
      print('  - Options: allowBluetooth, defaultToSpeaker, mixWithOthers');
      print('  - This allows recording + playback simultaneously');
    } catch (e) {
      print('⚠️ Audio session configuration error: $e');
      // Continuer quand même, ça peut marcher sans config explicite sur certains devices
    }
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer = AudioPlayer();
    print('✓ AudioPlayer initialized');
  }

  Future<void> _initRecorderWithStreamKeepAlive() async {
    _audioRecorder = AudioRecorder();

    // Vérifier les permissions
    if (!await _audioRecorder!.hasPermission()) {
      throw Exception('No recording permission');
    }

    // Démarrer le stream IMMÉDIATEMENT
    // La session audio reste active en permanence
    _audioStream = await _audioRecorder!.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      ),
    );

    // Écouter le stream mais ne pas capturer les chunks pour l'instant
    _streamSubscription = _audioStream!.listen(
      (chunk) {
        // On ne capture que si _isCapturing est true
        if (_isCapturing) {
          _currentRecordingChunks.add(chunk);
        }
        // Sinon on ignore les chunks (ils sont perdus, c'est normal)
      },
      onError: (error) {
        print('❌ Stream error: $error');
      },
    );

    _isRecorderActive = true;
    await _audioRecorder?.pause();

    print('✓ AudioRecorder stream started - REAL KEEP-ALIVE MODE');
    print('  📡 Stream active, capturing continuously');
    print('  ⚠️ Check for recording indicator on device!');
  }

  // ==================== ACTIONS ====================

  Future<void> playAudio(int index) async {
    if (index >= audioUrls.length) return;

    final sw = Stopwatch()..start();
    currentStep.value = 'Playing Audio ${index + 1}';

    try {
      await _audioPlayer?.stop();
      await _audioPlayer?.setUrl(audioUrls[index]);
      final sub = _audioPlayer?.playerStateStream.listen((state) async {
        if (state.playing) {
          sw.stop();
          lastActionTime.value = sw.elapsedMilliseconds;
          statusMessage.value = '🔊 Audio (${sw.elapsedMilliseconds}ms)';
          await Future.delayed(const Duration(seconds: 5));
          await _audioPlayer?.stop();
        }
      });
      await _audioPlayer?.play();

      sub?.cancel();
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
      await _videoController?.dispose();

      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrls[index]),
      );

      await _videoController!.initialize();
      await _videoController!.play();

      sw.stop();
      lastActionTime.value = sw.elapsedMilliseconds;
      statusMessage.value = '🎬 Video (${sw.elapsedMilliseconds}ms)';

      await Future.delayed(const Duration(seconds: 5));
      await _videoController?.pause();
    } catch (e) {
      statusMessage.value = '❌ Video error: $e';
      print('Video play error: $e');
    }
  }

  Future<void> startRecording() async {
    if (!_isRecorderActive) {
      statusMessage.value = '❌ Recorder not active';
      return;
    }

    final sw = Stopwatch()..start();
    currentStep.value = 'Recording ${_recordingCounter + 1}';

    await _audioRecorder?.resume();

    try {
      // Clear les chunks précédents
      _currentRecordingChunks.clear();

      // Activer la capture - INSTANTANÉ, pas de latence !
      _isCapturing = true;

      sw.stop();
      lastActionTime.value = sw.elapsedMilliseconds;
      statusMessage.value = '🎤 Recording (⚡ ${sw.elapsedMilliseconds}ms)';

      print('📍 Started capturing at ${DateTime.now()}');

      // Enregistrer pendant 3 secondes
      await Future.delayed(const Duration(seconds: 3));

      // Arrêter la capture
      _isCapturing = false;

      print('📍 Stopped capturing at ${DateTime.now()}');
      print('📦 Captured ${_currentRecordingChunks.length} chunks');

      await _audioRecorder?.pause();

      // Sauvegarder les chunks dans un fichier
      await _saveRecordedChunks();
    } catch (e) {
      _isCapturing = false;
      statusMessage.value = '❌ Recording error: $e';
      print('Recording error: $e');
    }
  }

  Future<void> _saveRecordedChunks() async {
    if (_currentRecordingChunks.isEmpty) {
      statusMessage.value = '⚠️ No audio data captured';
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Sauvegarder en WAV pour pouvoir le rejouer facilement
      final filePath =
          '${tempDir.path}/recording_${_recordingCounter}_$timestamp.wav';

      // Combiner tous les chunks en un seul buffer
      final totalLength = _currentRecordingChunks.fold<int>(
        0,
        (sum, chunk) => sum + chunk.length,
      );

      final combinedBuffer = Uint8List(totalLength);
      var offset = 0;
      for (final chunk in _currentRecordingChunks) {
        combinedBuffer.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      // Créer un fichier WAV avec header
      final wavFile = _createWavFile(combinedBuffer, 44100, 1, 16);

      // Écrire dans le fichier
      final file = File(filePath);
      await file.writeAsBytes(wavFile);

      recordedFiles.add(filePath);
      _recordingCounter++;

      statusMessage.value =
          '✅ Saved ${(wavFile.length / 1024).toStringAsFixed(1)} KB';

      print('💾 Saved recording to: $filePath');
      print('📊 File size: ${wavFile.length} bytes');
    } catch (e) {
      statusMessage.value = '❌ Save error: $e';
      print('Save error: $e');
    }
  }

  /// Crée un fichier WAV avec header à partir de PCM raw data
  Uint8List _createWavFile(
    Uint8List pcmData,
    int sampleRate,
    int numChannels,
    int bitsPerSample,
  ) {
    final dataSize = pcmData.length;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;

    // Taille totale du fichier
    final fileSize = 36 + dataSize;

    final buffer = BytesBuilder();

    // RIFF Header
    buffer.add([0x52, 0x49, 0x46, 0x46]); // "RIFF"
    buffer.add(_uint32ToBytes(fileSize)); // File size - 8
    buffer.add([0x57, 0x41, 0x56, 0x45]); // "WAVE"

    // fmt sub-chunk
    buffer.add([0x66, 0x6D, 0x74, 0x20]); // "fmt "
    buffer.add(_uint32ToBytes(16)); // Subchunk1Size (16 for PCM)
    buffer.add(_uint16ToBytes(1)); // AudioFormat (1 = PCM)
    buffer.add(_uint16ToBytes(numChannels)); // NumChannels
    buffer.add(_uint32ToBytes(sampleRate)); // SampleRate
    buffer.add(_uint32ToBytes(byteRate)); // ByteRate
    buffer.add(_uint16ToBytes(blockAlign)); // BlockAlign
    buffer.add(_uint16ToBytes(bitsPerSample)); // BitsPerSample

    // data sub-chunk
    buffer.add([0x64, 0x61, 0x74, 0x61]); // "data"
    buffer.add(_uint32ToBytes(dataSize)); // Subchunk2Size
    buffer.add(pcmData); // The actual audio data

    return buffer.toBytes();
  }

  List<int> _uint32ToBytes(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }

  List<int> _uint16ToBytes(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
    ];
  }

  Future<void> playRecordedFile(int index) async {
    if (index >= recordedFiles.length) return;

    currentStep.value = 'Playing Recording ${index + 1}';

    try {
      await _audioPlayer?.stop();
      await _audioPlayer?.setFilePath(recordedFiles[index]);
      await _audioPlayer?.play();

      statusMessage.value = '🔊 Playing recorded file ${index + 1}';

      // Attendre la fin de la lecture
      final duration = _audioPlayer?.duration;
      if (duration != null) {
        await Future.delayed(duration);
      }

      await _audioPlayer?.stop();
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
    _dispose();
    super.onClose();
  }

  Future<void> _dispose() async {
    // Arrêter la capture
    _isCapturing = false;

    // Annuler la subscription au stream
    await _streamSubscription?.cancel();
    _streamSubscription = null;

    // Arrêter le recorder (arrête le stream)
    await _audioRecorder?.stop();
    await _audioRecorder?.dispose();

    // Dispose les autres ressources
    await _audioPlayer?.dispose();
    await _videoController?.dispose();

    _audioPlayer = null;
    _audioRecorder = null;
    _videoController = null;
    _audioStream = null;
    _isRecorderActive = false;

    print('🧹 Resources disposed');
  }
}
