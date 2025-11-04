import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Repository gérant l'enregistrement audio avec le pattern keep-alive (pause/resume)
/// Le stream audio reste actif en permanence pour des performances maximales
/// Intègre également le speech-to-text pour tester la reconnaissance vocale en simultané
class AudioRecordingRepository {
  AudioRecorder? _audioRecorder;
  Stream<Uint8List>? _audioStream;
  StreamSubscription<Uint8List>? _streamSubscription;

  // Speech-to-text (keep-alive mode aussi)
  final SpeechToText _speechToText = SpeechToText();
  bool _speechInitialized = false;
  bool _isTranscribing = false; // Flag pour logger ou non les résultats
  String _lastRecognizedWords = '';

  // Keep-alive state
  bool _isRecorderActive = false;
  bool get isRecorderActive => _isRecorderActive;

  // Recording capture state
  bool _isCapturing = false;
  List<Uint8List> _currentRecordingChunks = [];
  int _recordingCounter = 0;

  // Liste des fichiers enregistrés
  final List<String> _recordedFiles = [];
  List<String> get recordedFiles => List.unmodifiable(_recordedFiles);

  /// Initialise le recorder et démarre le stream en mode keep-alive
  /// Le stream reste actif mais en pause pour des performances optimales
  /// Initialise également le speech-to-text
  Future<void> initialize() async {
    if (_isRecorderActive) {
      print('⚠️ AudioRecordingRepository already initialized');
      return;
    }

    _audioRecorder = AudioRecorder();

    // Vérifier les permissions
    if (!await _audioRecorder!.hasPermission()) {
      throw Exception('No recording permission');
    }

    // Initialiser le speech-to-text ET le démarrer en mode KEEP-ALIVE continu
    try {
      _speechInitialized = await _speechToText.initialize(
        onError: (error) => print('❌ STT Error: $error'),
        onStatus: (status) => print('🎙️ STT Status: $status'),
      );

      if (_speechInitialized) {
        print('✓ Speech-to-text initialized');

        // Démarrer l'écoute en continu (KEEP-ALIVE comme le recorder)
        await _speechToText.listen(
          onResult: (result) {
            // Logger seulement si on est en train de transcrire
            if (_isTranscribing) {
              _lastRecognizedWords = result.recognizedWords;
              print(
                  '🗣️ STT: "${result.recognizedWords}" (final: ${result.finalResult})');
            }
            // Sinon on ignore silencieusement (le STT continue d'écouter)
          },
          listenFor:
              const Duration(hours: 1), // Très longue durée = mode continu
          pauseFor: const Duration(seconds: 30), // Pause si silence prolongé
          partialResults: true,
          cancelOnError: false, // Ne pas arrêter sur erreur
        );

        print('✓ Speech-to-text listening started - KEEP-ALIVE MODE');
        print(
            '  🎙️ Listening continuously (results logged only during capture)');
      } else {
        print('⚠️ Speech-to-text initialization failed');
      }
    } catch (e) {
      print('⚠️ Speech-to-text error: $e');
      _speechInitialized = false;
    }

    // Démarrer le stream IMMÉDIATEMENT
    // La session audio reste active en permanence (KEEP-ALIVE)
    _audioStream = await _audioRecorder!.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      ),
    );

    // Écouter le stream mais ne capturer les chunks que si _isCapturing = true
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

    // Mettre immédiatement en pause (keep-alive sans capture)
    await _audioRecorder?.pause();

    print('✓ AudioRecordingRepository initialized - KEEP-ALIVE MODE');
    print('  📡 Stream active, ready for instant resume');
    print('  ⏸️ Paused by default (no capture)');
  }

  /// Démarre une capture d'enregistrement (resume le stream et active la capture)
  /// Active également le logging de la transcription STT (qui écoute déjà en continu)
  Future<int> startCapture() async {
    if (!_isRecorderActive) {
      throw Exception('Recorder not initialized');
    }

    // Clear les chunks précédents
    _currentRecordingChunks.clear();
    _lastRecognizedWords = '';

    final sw = Stopwatch()..start();

    // Resume le recorder (déjà initialisé, donc instantané)
    await _audioRecorder?.resume();

    // Activer la capture audio - INSTANTANÉ, pas de latence !
    _isCapturing = true;

    // Activer le logging de transcription (le STT écoute déjà en continu)
    _isTranscribing = true;

    sw.stop();
    final resumeTime = sw.elapsedMilliseconds;

    print('📍 Started capturing at ${DateTime.now()} (⚡ ${resumeTime}ms)');
    print('   🎤 Audio recording: ✓');
    print(
        '   🗣️ Speech-to-text: ${_speechInitialized ? "✓ (already listening)" : "✗"}');

    return resumeTime;
  }

  /// Arrête la capture en cours et sauvegarde l'enregistrement
  /// Désactive le logging de transcription (mais le STT continue d'écouter en continu)
  /// Retourne le chemin du fichier sauvegardé
  Future<String?> stopCapture() async {
    if (!_isRecorderActive || !_isCapturing) {
      print('⚠️ No capture in progress');
      return null;
    }

    // Désactiver le logging de transcription (le STT continue d'écouter)
    _isTranscribing = false;

    // Logger la transcription finale si elle existe
    if (_lastRecognizedWords.isNotEmpty) {
      print('📝 Final transcription: "$_lastRecognizedWords"');
    }

    // Arrêter la capture
    _isCapturing = false;

    print('📍 Stopped capturing at ${DateTime.now()}');
    print('📦 Captured ${_currentRecordingChunks.length} chunks');
    print('   🗣️ STT still listening in background (keep-alive)');

    // Pause le recorder (keep-alive, mais pas de capture)
    await _audioRecorder?.pause();

    // Sauvegarder les chunks dans un fichier
    return await _saveRecordedChunks();
  }

  /// Sauvegarde les chunks capturés dans un fichier WAV
  Future<String?> _saveRecordedChunks() async {
    if (_currentRecordingChunks.isEmpty) {
      print('⚠️ No audio data captured');
      return null;
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

      _recordedFiles.add(filePath);
      _recordingCounter++;

      print('💾 Saved recording to: $filePath');
      print('📊 File size: ${(wavFile.length / 1024).toStringAsFixed(1)} KB');

      return filePath;
    } catch (e) {
      print('❌ Save error: $e');
      return null;
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

  /// Nettoie les ressources
  Future<void> dispose() async {
    // Arrêter la capture
    _isCapturing = false;

    // Arrêter le speech-to-text si actif
    if (_speechInitialized && _speechToText.isListening) {
      await _speechToText.stop();
    }

    // Annuler la subscription au stream
    await _streamSubscription?.cancel();
    _streamSubscription = null;

    // Arrêter le recorder (arrête le stream)
    await _audioRecorder?.stop();
    await _audioRecorder?.dispose();

    _audioRecorder = null;
    _audioStream = null;
    _isRecorderActive = false;

    print('🧹 AudioRecordingRepository disposed');
  }
}
