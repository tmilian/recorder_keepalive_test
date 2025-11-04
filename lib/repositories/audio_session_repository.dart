import 'dart:async';
import 'package:audio_session/audio_session.dart';

/// Repository gérant la configuration de l'audio session iOS/Android
/// et les interruptions (appels, Siri, déconnexion casque, etc.)
class AudioSessionRepository {
  AudioSession? _session;
  StreamSubscription? _interruptionSubscription;
  StreamSubscription? _becomingNoisySubscription;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialise et configure l'audio session pour recording + playback simultané
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ AudioSessionRepository already initialized');
      return;
    }

    try {
      _session = await AudioSession.instance;

      // Configuration pour permettre recording + playback simultané
      await _session!.configure(
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

      // Setup interruption handling
      _setupInterruptionHandling();

      _isInitialized = true;

      print('✓ AudioSessionRepository initialized');
      print('  - Category: playAndRecord');
      print('  - Options: allowBluetooth, defaultToSpeaker, mixWithOthers');
      print('  - Recording + playback simultaneously enabled');
    } catch (e) {
      print('⚠️ Audio session configuration error: $e');
      // Continuer quand même, ça peut marcher sans config explicite sur certains devices
      _isInitialized = true; // On considère quand même initialisé
    }
  }

  /// Configure la gestion des interruptions (appels, Siri, etc.)
  void _setupInterruptionHandling() {
    if (_session == null) return;

    // Gérer les interruptions (appels téléphoniques, Siri, etc.)
    _interruptionSubscription =
        _session!.interruptionEventStream.listen((event) {
      print('🔔 Audio interruption: ${event.type}');

      if (event.begin) {
        // Interruption commence (ex: appel entrant)
        print('  ⏸️  Interruption began');
        // Le repository gère ça de manière autonome
        // Les autres repositories (recording, playback) détecteront automatiquement
      } else {
        // Interruption se termine
        print('  ▶️  Interruption ended');
        // On pourrait reprendre automatiquement ici si nécessaire
      }
    });

    // Gérer le débranchement des écouteurs
    _becomingNoisySubscription = _session!.becomingNoisyEventStream.listen((_) {
      print('🔇 Device becoming noisy (headphones unplugged)');
      // Gérer le débranchement des écouteurs
      // Typiquement on voudrait pause la lecture audio/vidéo
    });
  }

  /// Nettoie les ressources
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
