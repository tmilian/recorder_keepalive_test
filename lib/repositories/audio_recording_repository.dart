import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecordingRepository {
  AudioRecorder? _audioRecorder;
  Stream<Uint8List>? _audioStream;
  final List<StreamSubscription> _streamSubscriptions = [];

  bool _isRecorderActive = false;
  bool get isRecorderActive => _isRecorderActive;

  RecordState _recordState = RecordState.pause;

  bool _isCapturing = false;
  final List<Uint8List> _currentRecordingChunks = [];
  int _recordingCounter = 0;

  final List<String> _recordedFiles = [];
  List<String> get recordedFiles => List.unmodifiable(_recordedFiles);

  Future<void> initialize() async {
    if (_isRecorderActive) {
      print('⚠️ AudioRecordingRepository already initialized');
      return;
    }

    _audioRecorder = AudioRecorder();

    if (!await _audioRecorder!.hasPermission()) {
      throw Exception('No recording permission');
    }

    _streamSubscriptions.add(_audioRecorder!.onStateChanged().listen((state) {
      print('⚡️Audio recorder state changed: $state');
      _recordState = state;
    }));

    _audioStream = await _audioRecorder!.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
        audioInterruption: AudioInterruptionMode.pauseResume,
      ),
    );

    _streamSubscriptions.add(_audioStream!.listen(
      (chunk) {
        if (_isCapturing) {
          _currentRecordingChunks.add(chunk);
        }
      },
      onError: (error) {
        print('❌ Stream error: $error');
      },
    ));

    _isRecorderActive = true;

    print('✓ AudioRecordingRepository initialized - KEEP-ALIVE MODE');
    print('  📡 Stream active, ready for instant resume');
    print('  ⏸️ Paused by default (no capture)');
  }

  Future<int> startCapture() async {
    if (!_isRecorderActive) {
      throw Exception('Recorder not initialized');
    }

    final sw = Stopwatch()..start();

    if (_recordState == RecordState.pause) {
      await _audioRecorder?.resume();
    }

    _currentRecordingChunks.clear();
    _isCapturing = true;

    sw.stop();
    final resumeTime = sw.elapsedMilliseconds;

    print('📍 Started capturing at ${DateTime.now()} (⚡ ${resumeTime}ms)');
    print('   🎤 Audio recording: ✓');

    return resumeTime;
  }

  Future<String?> stopCapture() async {
    if (!_isRecorderActive || !_isCapturing) {
      print('⚠️ No capture in progress');
      return null;
    }

    _isCapturing = false;

    print('📍 Stopped capturing at ${DateTime.now()}');
    print('📦 Captured ${_currentRecordingChunks.length} chunks');
    print('   🗣️ STT still listening in background (keep-alive)');

    // await _audioRecorder?.pause();

    return await _saveRecordedChunks();
  }

  Future<String?> _saveRecordedChunks() async {
    if (_currentRecordingChunks.isEmpty) {
      print('⚠️ No audio data captured');
      return null;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final filePath =
          '${tempDir.path}/recording_${_recordingCounter}_$timestamp.wav';

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

      final wavFile = _createWavFile(combinedBuffer, 44100, 1, 16);

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

  Uint8List _createWavFile(
    Uint8List pcmData,
    int sampleRate,
    int numChannels,
    int bitsPerSample,
  ) {
    final dataSize = pcmData.length;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;

    final fileSize = 36 + dataSize;

    final buffer = BytesBuilder();

    buffer.add([0x52, 0x49, 0x46, 0x46]);
    buffer.add(_uint32ToBytes(fileSize));
    buffer.add([0x57, 0x41, 0x56, 0x45]);

    buffer.add([0x66, 0x6D, 0x74, 0x20]);
    buffer.add(_uint32ToBytes(16));
    buffer.add(_uint16ToBytes(1));
    buffer.add(_uint16ToBytes(numChannels));
    buffer.add(_uint32ToBytes(sampleRate));
    buffer.add(_uint32ToBytes(byteRate));
    buffer.add(_uint16ToBytes(blockAlign));
    buffer.add(_uint16ToBytes(bitsPerSample));

    buffer.add([0x64, 0x61, 0x74, 0x61]);
    buffer.add(_uint32ToBytes(dataSize));
    buffer.add(pcmData);

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

  Future<void> dispose() async {
    _isCapturing = false;

    for (final subscription in _streamSubscriptions) {
      await subscription.cancel();
    }
    _streamSubscriptions.clear();

    await _audioRecorder?.stop();
    await _audioRecorder?.dispose();

    _audioRecorder = null;
    _audioStream = null;
    _isRecorderActive = false;

    print('🧹 AudioRecordingRepository disposed');
  }
}
