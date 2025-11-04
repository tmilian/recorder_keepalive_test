import 'dart:async';

import 'package:audio_session/audio_session.dart';

class AudioSessionRepository {
  AudioSession? _session;
  StreamSubscription? _interruptionSubscription;
  StreamSubscription? _becomingNoisySubscription;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ AudioSessionRepository already initialized');
      return;
    }

    try {
      _session = await AudioSession.instance;

      await _session!.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth |
                  AVAudioSessionCategoryOptions.defaultToSpeaker |
                  AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );

      _setupInterruptionHandling();

      _isInitialized = true;

      print('✓ AudioSessionRepository initialized');
      print('  - Category: playAndRecord');
      print('  - Options: allowBluetooth, defaultToSpeaker, mixWithOthers');
      print('  - Recording + playback simultaneously enabled');
    } catch (e) {
      print('⚠️ Audio session configuration error: $e');

      _isInitialized = true;
    }
  }

  void _setupInterruptionHandling() {
    if (_session == null) return;

    _interruptionSubscription =
        _session!.interruptionEventStream.listen((event) {
      print('🔔 Audio interruption: ${event.type}');

      if (event.begin) {
        print('  ⏸️  Interruption began');
      } else {
        print('  ▶️  Interruption ended');
      }
    });

    _becomingNoisySubscription = _session!.becomingNoisyEventStream.listen((_) {
      print('🔇 Device becoming noisy (headphones unplugged)');
    });
  }

  Future<void> dispose() async {
    await _interruptionSubscription?.cancel();
    await _becomingNoisySubscription?.cancel();
    _interruptionSubscription = null;
    _becomingNoisySubscription = null;
    _session = null;
    _isInitialized = false;
    print('🧹 AudioSessionRepository disposed');
  }
}
